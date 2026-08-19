import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { CustomersService } from '../customers/customers.service';
import { InventoryService } from '../inventory/inventory.service';
import { CashierService } from '../cashier/cashier.service';
import {
  clampChangedSinceLimit,
  type ChangedSincePage,
} from '../../common/database/changed-since';
import { SaleRepository } from './sale.repository';
import type { FiscalSnapshotFields, SaleSyncEntity } from './sale.repository';
import {
  computeSaleTotal,
  applySaleDiscount,
  computeSubtotal,
  formatSaleNumber,
} from './sale.config';
import {
  CancelSaleDto,
  CreateSaleDto,
  ListSalesQueryDto,
  UpdateSaleDto,
} from './dto/sale.dto';

const DEFAULT_PAGE_SIZE = 20;

/** ISO → Date (mesma conversão do caixa, para os recortes por período). */
const parseDate = (v: string | undefined): Date | undefined =>
  v ? new Date(v) : undefined;

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

/** Linha já resolvida (snapshot pronto) antes de persistir. */
interface ResolvedItem {
  kind: 'product' | 'service';
  inventory_item_id: string | null;
  name: string;
  quantity: number;
  unit_price: number;
  subtotal: number;
}

/**
 * Serviço da Venda de balcão (`sale`) — entidade PRÓPRIA, NÃO é OS. Espelha o
 * padrão da OS para pagamento/nota, mas com caminho próprio (venda rápida sem
 * abrir OS). "Aponta, não invade":
 *  - estoque: baixa/estorno via `InventoryService` (só produto);
 *  - cliente: snapshot via `CustomersService` (opcional — balcão pode ser sem cadastro);
 *  - pagamento: DERIVADO do `CashierService` (a venda não guarda valor pago);
 *  - nota: disparada via `InvoiceService` (o Fiscal é dono do status; guardamos snapshot).
 * O caixa NÃO emite nota e NÃO toca a tabela da venda (ele recebe o total do dono).
 */
@Injectable()
export class SaleService {
  private readonly logger = new Logger(SaleService.name);

  /** Entidades deste módulo que o pull de sync pode puxar (whitelist). */
  private static readonly SYNC_ENTITIES = new Set<SaleSyncEntity>([
    'sale',
    'sale_item',
  ]);

  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: SaleRepository,
    private readonly audit: AuditService,
    private readonly customers: CustomersService,
    private readonly inventory: InventoryService,
    private readonly cashier: CashierService,
  ) {}

  // ===================== Criação =====================
  async createSale(user: AuthUser, dto: CreateSaleDto) {
    // Cliente OPCIONAL: se informado, ponteiro + snapshot via service público
    // (FORA da tx — getCustomer abre a própria; aninhar esgota o pool).
    let customerId: string | null = null;
    let customerName: string | null = null;
    if (dto.customerId) {
      const customer = await this.customers.getCustomer(user, dto.customerId);
      customerId = customer.id;
      customerName = customer.name;
    }

    const resolved = await this.resolveItems(dto.items);

    const bruto = computeSaleTotal(
      resolved.map((r) => ({ quantity: r.quantity, unitPrice: r.unit_price })),
    );
    // `total` é o valor A PAGAR (já líquido) — é ele que o caixa recebe e o
    // Fiscal emite. `discount` fica ao lado como registro do que foi concedido.
    const { total, discount } = applySaleDiscount(bruto, dto.discount ?? 0);

    const sale = await this.tenant.withTenantTx(async () => {
      const n = (await this.repo.maxSaleNumber()) + 1;
      const created = await this.repo.createSale(user.tenantId, {
        // Uuid do cliente quando veio (replay de venda criada offline); senão o
        // banco gera. O NÚMERO é sempre atribuído aqui — offline o aparelho usa
        // um provisório e o pull traz esta linha, já com o número real.
        ...(dto.id ? { id: dto.id } : {}),
        number: formatSaleNumber(n),
        customer_id: customerId,
        customer_name: customerName,
        status: 'active',
        total,
        discount,
        description: dto.description?.trim() || null,
        // Declarada fiado já na criação (ver CreateSaleDto.fiado).
        ...(dto.fiado ? { fiado_at: new Date() } : {}),
        created_by: user.userId,
      });
      for (const r of resolved) {
        await this.repo.addItem(user.tenantId, created.id, {
          kind: r.kind,
          inventory_item_id: r.inventory_item_id,
          name: r.name,
          quantity: r.quantity,
          unit_price: r.unit_price,
          subtotal: r.subtotal,
        });
      }
      return this.repo.findSaleById(created.id);
    });
    await this.audit.log(user.tenantId, user.userId, 'sale_create', sale!.id, {
      total,
      // Desconto concedido é informação auditável (quem deu, quanto, em qual venda).
      ...(discount > 0 ? { discount } : {}),
      items: resolved.length,
    });

    // Baixa de estoque (só produto vinculado) — FORA da tx (reconcile abre a própria).
    // best-effort por linha: falha de estoque não desfaz a venda (apenas loga).
    await this.applyStock(user, sale!.id, sale!.items, 'consume');

    return this.enrichOne(sale!, user.tenantId);
  }

  /**
   * Resolve as linhas informadas em snapshots prontos para persistir: item do
   * estoque re-snapshota nome/kind/preço (o cadastro é a verdade), avulso exige
   * nome. Sequencial e FORA de transação — `inventory.getItem` abre a própria.
   *
   * Compartilhado por criar e editar: o snapshot de uma linha tem de nascer igual
   * nos dois caminhos, senão editar uma venda mudaria silenciosamente o preço
   * que ela registrou.
   */
  private async resolveItems(
    itens: CreateSaleDto['items'],
  ): Promise<ResolvedItem[]> {
    const resolved: ResolvedItem[] = [];
    for (const it of itens) {
      let name = it.name?.trim() || '';
      let unitPrice = it.unitPrice ?? 0;
      let kind: 'product' | 'service' = it.kind ?? 'product';
      let inventoryItemId: string | null = null;

      if (it.inventoryItemId) {
        const invItem = await this.inventory.getItem(it.inventoryItemId);
        inventoryItemId = invItem.id;
        name = invItem.name;
        kind = (invItem.kind as 'product' | 'service') ?? kind;
        if (it.unitPrice === undefined) unitPrice = toNum(invItem.sale_price);
      } else if (!name) {
        throw new BadRequestException('Nome é obrigatório para item avulso.');
      }

      const quantity = it.quantity ?? 1;
      resolved.push({
        kind,
        inventory_item_id: inventoryItemId,
        name,
        quantity,
        unit_price: unitPrice,
        subtotal: computeSubtotal(quantity, unitPrice),
      });
    }
    return resolved;
  }

  // ===================== Leitura =====================
  async listSales(user: AuthUser, query: ListSalesQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listSales({
        status: query.status,
        customerId: query.customerId,
        q: query.q?.trim() || undefined,
        from: parseDate(query.from),
        to: parseDate(query.to),
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    // Tag de pagamento DERIVADA do caixa em UMA chamada batch (evita N+1). A venda
    // passa o PRÓPRIO total — o caixa não toca a tabela da venda. Cancelada não
    // pergunta o caixa (sai como a_receber/—). "Aponta, não invade".
    const active = items.filter((s) => s.status === 'active');
    const summaries = await this.cashier.getPaymentSummaryBatch(
      user.tenantId,
      active.map((s) => ({ id: s.id, total: toNum(s.total) })),
    );
    // Expõe o resumo COMPLETO (total/pago/saldo), não só a tag: o controle de
    // fiado precisa do saldo em aberto e o batch já o calculou. Simétrico ao
    // detalhe (`getSaleOrThrow`), que sempre devolveu `payment`.
    const enriched = items.map((s) => ({
      ...s,
      payment: summaries.get(s.id) ?? null,
      payment_status: (summaries.get(s.id)?.status ?? 'a_receber') as string,
    }));
    return { items: enriched, total, page, pageSize };
  }

  async getSaleOrThrow(id: string, tenantId?: string) {
    const sale = await this.tenant.withTenantTx(async () => {
      const found = await this.repo.findSaleById(id);
      if (!found) throw new NotFoundException('Venda não encontrada.');
      return found;
    });
    const tid = tenantId ?? sale.tenant_id;
    return this.enrichOne(sale, tid);
  }

  /**
   * Edita uma venda registrada: cliente, itens e desconto.
   *
   * Duas coisas a venda NÃO pode fazer, e por motivo concreto:
   *  - **nota emitida**: mudar o total deixaria a NF divergindo do que ela
   *    declara (problema fiscal, não preferência);
   *  - **total abaixo do já pago**: ficaríamos devendo troco ao cliente, e não
   *    existe mecanismo para representar esse crédito.
   * Nos dois casos o caminho é estornar o pagamento ou cancelar-e-refazer, e a
   * mensagem diz isso.
   *
   * Cliente vem por id + snapshot do nome via service público ("aponta, não
   * invade"). Itens SUBSTITUEM as linhas atuais e o total é recalculado aqui —
   * o cliente nunca manda total.
   */
  async updateSale(user: AuthUser, id: string, dto: UpdateSaleDto) {
    const trocaCliente = dto.customerId !== undefined;
    const trocaDesconto = dto.discount !== undefined;
    const trocaDescricao = dto.description !== undefined;

    let customerId: string | null = null;
    let customerName: string | null = null;
    if (dto.customerId) {
      // FORA da tx: getCustomer abre a própria (aninhar esgota o pool).
      const customer = await this.customers.getCustomer(user, dto.customerId);
      customerId = customer.id;
      customerName = customer.name;
    }
    // Snapshots FORA da tx (inventory.getItem abre a própria).
    const resolved = dto.items ? await this.resolveItems(dto.items) : null;

    // Estado atual + guardas, antes de mexer em qualquer coisa.
    const atual = await this.tenant.withTenantTx(() => this.repo.findSaleById(id));
    if (!atual) throw new NotFoundException('Venda não encontrada.');
    if (atual.status === 'canceled')
      throw new ConflictException('Venda cancelada não pode ser editada.');

    let total = toNum(atual.total);
    let discount = toNum(atual.discount);
    if (resolved || trocaDesconto) {
      const bruto = resolved
        ? computeSaleTotal(
            resolved.map((r) => ({
              quantity: r.quantity,
              unitPrice: r.unit_price,
            })),
          )
        : toNum(atual.total) + toNum(atual.discount);
      const aplicado = applySaleDiscount(
        bruto,
        trocaDesconto ? dto.discount! : discount,
      );
      total = aplicado.total;
      discount = aplicado.discount;
    }

    // Mudou dinheiro? Então as duas guardas valem.
    if (total !== toNum(atual.total)) {
      if (atual.fiscal_status && atual.fiscal_status !== 'rejeitada') {
        throw new ConflictException(
          'Esta venda já tem nota fiscal. Mudar o valor faria a nota divergir — '
            + 'cancele a venda e faça uma nova.',
        );
      }
      const pago = await this.cashier.getPaymentSummary(
        user.tenantId,
        id,
        toNum(atual.total),
      );
      if (total < pago.paid - 0.005) {
        throw new ConflictException(
          `O cliente já pagou ${pago.paid.toFixed(2)} nesta venda e o novo total `
            + `seria ${total.toFixed(2)}. Estorne o recebimento antes de reduzir `
            + 'o valor.',
        );
      }
    }

    // Linhas antigas guardadas ANTES de apagar: é por elas (refItemId) que o
    // estoque sabe o que devolver — reconciliar é keyed pelo id da linha, então
    // uma linha apagada sem estorno deixaria o produto baixado para sempre.
    const antigos = resolved
      ? await this.tenant.withTenantTx(() => this.repo.listItems(id))
      : [];

    const sale = await this.tenant.withTenantTx(async () => {
      if (trocaCliente) {
        await this.repo.setCustomer(id, {
          customer_id: customerId,
          customer_name: customerName,
        });
      }
      if (resolved) {
        await this.repo.deleteItems(id);
        for (const r of resolved) {
          await this.repo.addItem(user.tenantId, id, {
            kind: r.kind,
            inventory_item_id: r.inventory_item_id,
            name: r.name,
            quantity: r.quantity,
            unit_price: r.unit_price,
            subtotal: r.subtotal,
          });
        }
      }
      if (resolved || trocaDesconto) {
        await this.repo.setTotals(id, { total, discount });
      }
      if (trocaDescricao) {
        await this.repo.setDescription(id, dto.description?.trim() || null);
      }
      return this.repo.findSaleById(id);
    });

    await this.audit.log(user.tenantId, user.userId, 'sale_update', id, {
      ...(trocaCliente ? { customerId } : {}),
      ...(resolved ? { itens: resolved.length, total, discount } : {}),
      ...(trocaDescricao ? { descricao: dto.description?.trim() || null } : {}),
    });

    // Estoque FORA da tx: devolve o que as linhas antigas consumiram (alvo 0) e
    // consome o que as novas pedem. As linhas trocam de id, então não há como
    // "ajustar a mesma linha" — o diário registra devolução + consumo, que é o
    // que de fato aconteceu.
    if (resolved) {
      for (const antigo of antigos) {
        if (antigo.kind !== 'product' || !antigo.inventory_item_id) continue;
        await this.reconcile(user, id, antigo.id, antigo.inventory_item_id, 0);
      }
      await this.applyStock(user, id, sale!.items, 'consume');
    }

    return this.enrichOne(sale!, user.tenantId);
  }

  /** Reconcilia UMA linha para a quantidade-alvo, sem derrubar a operação. */
  private async reconcile(
    user: AuthUser,
    saleId: string,
    refItemId: string,
    inventoryItemId: string,
    targetQty: number,
  ): Promise<void> {
    try {
      await this.inventory.reconcileConsumption(user.tenantId, {
        inventoryItemId,
        refType: 'sale',
        refId: saleId,
        refItemId,
        targetQty,
        createdBy: user.userId,
      });
    } catch (e) {
      this.logger.warn(
        `Estoque (reconcile ${targetQty}) falhou (venda ${saleId}, linha ${refItemId}): ${
          (e as Error).message
        }`,
      );
    }
  }

  // ===================== Cancelamento (estorno lógico) =====================
  /**
   * Declara a venda como FIADO — recebeu zero e o operador assumiu a dívida.
   * Mesmo papel do `OsService.markFiado`: é a única prova de passagem pelo
   * caixa quando não há lançamento. Idempotente (offline repete mutação).
   */
  async markFiado(user: AuthUser, id: string) {
    const { sale, jaEra } = await this.tenant.withTenantTx(async () => {
      const found = await this.repo.findSaleById(id);
      if (!found) throw new NotFoundException('Venda não encontrada.');
      if (found.status === 'canceled')
        throw new ConflictException('Venda cancelada não pode virar fiado.');
      if (found.fiado_at) return { sale: found, jaEra: true };
      return { sale: await this.repo.setFiadoAt(id, new Date()), jaEra: false };
    });
    if (!jaEra) {
      await this.audit.log(user.tenantId, user.userId, 'sale_fiado', id);
    }
    return sale;
  }

  async cancelSale(user: AuthUser, id: string, dto: CancelSaleDto) {
    const sale = await this.tenant.withTenantTx(async () => {
      const found = await this.repo.findSaleById(id);
      if (!found) throw new NotFoundException('Venda não encontrada.');
      if (found.status === 'canceled')
        throw new ConflictException('Venda já cancelada.');
      await this.repo.cancelSale(id, {
        canceled_by: user.userId,
        canceled_reason: dto.reason?.trim() || null,
      });
      return found;
    });
    await this.audit.log(user.tenantId, user.userId, 'sale_cancel', id, {
      reason: dto.reason?.trim() || null,
    });

    // Devolve o estoque (estorno) — FORA da tx (reconcile abre a própria).
    await this.applyStock(user, id, sale.items, 'return');

    return this.getSaleOrThrow(id, user.tenantId);
  }

  // ===================== Nota fiscal =====================
  // A emissão da nota da venda é do módulo `invoice` (POST /invoices { saleId })
  // — o Fiscal lê a venda pelo service público abaixo e espelha o snapshot via
  // `setFiscalSnapshot`. Dependência ONE-WAY invoice→sale (sem forwardRef).

  /**
   * Venda + itens para consumo por OUTRO módulo (ex.: `invoice`) via service
   * público — "aponta, não invade": o chamador guarda só o id e busca aqui,
   * sem tocar as tabelas da venda.
   */
  async getSaleWithItems(id: string) {
    return this.tenant.withTenantTx(async () => {
      const sale = await this.repo.findSaleById(id);
      if (!sale) throw new NotFoundException('Venda não encontrada.');
      return sale;
    });
  }

  /**
   * Snapshot do status fiscal na venda (escrito pelo módulo Fiscal, dono do
   * dado — aqui é só espelho para exibição).
   */
  setFiscalSnapshot(
    tenantId: string,
    id: string,
    fields: FiscalSnapshotFields,
  ) {
    return this.tenant.runWithTenant(tenantId, () =>
      this.repo.setFiscalSnapshot(id, fields),
    );
  }

  // ===================== Seam público (consumido por report/caixa) =====================
  /** Total de uma venda ativa — o caixa/relatório lê por aqui (não toca a tabela). */
  getSaleValue(tenantId: string, id: string): Promise<number> {
    return this.tenant.runWithTenant(tenantId, () => this.repo.saleTotal(id));
  }

  /** Totais por id (batch) — mapa id → total (vendas ativas). */
  getSaleValueBatch(
    tenantId: string,
    ids: string[],
  ): Promise<Map<string, number>> {
    if (!ids.length) return Promise.resolve(new Map());
    return this.tenant.runWithTenant(tenantId, () => this.repo.saleTotals(ids));
  }

  /**
   * Linhas de vendas ATIVAS no range — para a lente "Vendas" do relatório
   * (histórico OS + venda). Read-only; tenant explícito (composição de relatório).
   * O pagamento NÃO é resolvido aqui (o relatório deriva via Caixa em batch).
   */
  async listForReport(
    tenantId: string,
    range: { from: Date; to: Date },
  ): Promise<
    Array<{
      id: string;
      number: string;
      customer_name: string | null;
      total: number;
      created_at: string;
    }>
  > {
    const rows = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.listForReport(range),
    );
    return rows.map((r) => ({
      id: r.id,
      number: r.number,
      customer_name: r.customer_name,
      total: toNum(r.total),
      created_at: r.created_at.toISOString(),
    }));
  }

  /**
   * Faturamento de vendas por dia no range — para compor "faturamento = OS + venda"
   * no relatório. Tenant explícito (composição). Mais recente por último (ASC).
   */
  async revenueByDay(
    tenantId: string,
    range: { from: Date; to: Date },
  ): Promise<Array<{ day: string; revenue: number; count: number }>> {
    const rows = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.revenueByDay(range),
    );
    return rows.map((r) => ({
      day: r.day,
      revenue: toNum(r.revenue),
      count: Number(r.count),
    }));
  }

  /**
   * Faturamento de vendas no range (para o agregador de receita do relatório:
   * receita = OS + sale). Tenant explícito (composição de relatório).
   */
  async revenueSummary(
    tenantId: string,
    range: { from: Date; to: Date },
  ): Promise<{ revenue: number; count: number }> {
    const agg = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.revenueAgg(range),
    );
    return { revenue: toNum(agg._sum.total), count: agg._count._all };
  }

  // ===================== Internos =====================
  /** Resumo de pagamento derivado do caixa + campo flat. Cancelada ⇒ não pergunta. */
  private async enrichOne(
    sale: { id: string; tenant_id: string; status: string; total: Prisma.Decimal | number },
    tenantId: string,
  ) {
    if (sale.status !== 'active') {
      return { ...sale, payment: null, payment_status: 'cancelada' };
    }
    const payment = await this.cashier.getPaymentSummary(
      tenantId,
      sale.id,
      toNum(sale.total),
    );
    return { ...sale, payment, payment_status: payment.status };
  }

  /**
   * Baixa (`consume`) ou devolve (`return`) o estoque das linhas-produto via
   * `InventoryService.reconcileConsumption` (idempotente, grava no diário com
   * refType 'sale'). FORA de transação de banco. best-effort por linha: erro de
   * estoque NÃO desfaz a venda/cancelamento — apenas loga.
   */
  private async applyStock(
    user: AuthUser,
    saleId: string,
    items: Array<{
      id: string;
      kind: string;
      inventory_item_id: string | null;
      quantity: Prisma.Decimal | number;
    }>,
    mode: 'consume' | 'return',
  ): Promise<void> {
    for (const item of items) {
      if (item.kind !== 'product' || !item.inventory_item_id) continue;
      try {
        await this.inventory.reconcileConsumption(user.tenantId, {
          inventoryItemId: item.inventory_item_id,
          refType: 'sale',
          refId: saleId,
          refItemId: item.id,
          targetQty: mode === 'consume' ? toNum(item.quantity) : 0,
          createdBy: user.userId,
        });
      } catch (e) {
        this.logger.warn(
          `Estoque (${mode}) falhou (venda ${saleId}, item ${item.id}): ${
            (e as Error).message
          }`,
        );
      }
    }
  }

  // ===================== Sync pull (offline) =====================
  /**
   * Página de mudanças de `sale`/`sale_item` para o pull de sync offline
   * ("aponta, não invade": o módulo `sync` só chama este service público).
   * Mesma shape JSON dos endpoints de leitura — linhas cruas do Prisma, como
   * `listSales` também devolve.
   */
  async listChangedSince(
    entity: string,
    cursor: { ts: string; id: string } | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    if (!SaleService.SYNC_ENTITIES.has(entity as SaleSyncEntity)) {
      throw new BadRequestException(
        `Entidade não pertence ao módulo sale: ${entity}`,
      );
    }
    const clamped = clampChangedSinceLimit(limit);
    return this.tenant.withTenantTx(() =>
      this.repo.listChangedSince(entity as SaleSyncEntity, cursor, clamped),
    );
  }
}
