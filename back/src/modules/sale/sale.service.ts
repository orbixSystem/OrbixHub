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
import { SaleRepository } from './sale.repository';
import type { FiscalSnapshotFields } from './sale.repository';
import {
  computeSaleTotal,
  computeSubtotal,
  formatSaleNumber,
} from './sale.config';
import { CancelSaleDto, CreateSaleDto, ListSalesQueryDto } from './dto/sale.dto';

const DEFAULT_PAGE_SIZE = 20;

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

    // Snapshot dos itens via inventory (sequencial, FORA da tx). Item do estoque
    // re-snapshot de nome/kind/preço; avulso exige nome.
    const resolved: ResolvedItem[] = [];
    for (const it of dto.items) {
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

    const total = computeSaleTotal(
      resolved.map((r) => ({ quantity: r.quantity, unitPrice: r.unit_price })),
    );

    const sale = await this.tenant.withTenantTx(async () => {
      const n = (await this.repo.maxSaleNumber()) + 1;
      const created = await this.repo.createSale(user.tenantId, {
        number: formatSaleNumber(n),
        customer_id: customerId,
        customer_name: customerName,
        status: 'active',
        total,
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
      items: resolved.length,
    });

    // Baixa de estoque (só produto vinculado) — FORA da tx (reconcile abre a própria).
    // best-effort por linha: falha de estoque não desfaz a venda (apenas loga).
    await this.applyStock(user, sale!.id, sale!.items, 'consume');

    return this.enrichOne(sale!, user.tenantId);
  }

  // ===================== Leitura =====================
  async listSales(user: AuthUser, query: ListSalesQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listSales({
        status: query.status,
        customerId: query.customerId,
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

  // ===================== Cancelamento (estorno lógico) =====================
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
}
