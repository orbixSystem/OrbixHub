import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { AuditService } from '../../common/audit/audit.service';
import { TenantContext } from '../../common/database/tenant-context';
import { CustomersService } from '../customers/customers.service';
import { InventoryService } from '../inventory/inventory.service';
import {
  CancelSaleDto,
  CreateSaleDto,
  ListSalesQueryDto,
  SaleItemInputDto,
} from './dto/sale.dto';
import { SaleLineData, SalesRepository } from './sales.repository';

const DEFAULT_PAGE_SIZE = 20;

function toNum(v: Prisma.Decimal | number | null | undefined): number {
  if (v == null) return 0;
  return typeof v === 'number' ? v : Number(v.toString());
}

function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Vendas avulsas de produto (caixa). Venda criada já CONCLUÍDA (paga). Regra
 * "aponta não invade": lê cliente (CustomersService) e itens (InventoryService)
 * por service público; guarda só ids + snapshots. A baixa de estoque reusa o
 * seam do inventory (`reconcileConsumption`, ref_type='sale'); cancelar estorna.
 * Nenhuma chamada externa dentro de transação de banco.
 */
@Injectable()
export class SalesService {
  private readonly logger = new Logger(SalesService.name);

  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: SalesRepository,
    private readonly inventory: InventoryService,
    private readonly customers: CustomersService,
    private readonly audit: AuditService,
  ) {}

  /** Monta a linha (snapshot) de um item do carrinho. getItem abre a própria tx
   * (CLS) — chamar FORA da tx de criação. */
  private async buildLine(
    user: AuthUser,
    input: SaleItemInputDto,
  ): Promise<SaleLineData> {
    let name = input.name?.trim() ?? '';
    let unitPrice = input.unitPrice;
    let kind: 'product' | 'service' = input.kind ?? 'product';
    let invId: string | null = input.inventoryItemId ?? null;

    if (invId) {
      try {
        const item = await this.inventory.getItem(invId);
        if (!name) name = item.name;
        if (input.unitPrice == null) unitPrice = toNum(item.sale_price);
        kind = item.kind === 'service' ? 'service' : 'product';
      } catch {
        invId = null; // item sumiu → vira avulso
      }
    }
    if (!name) name = 'Item';
    const qty = input.quantity;
    const discount = input.discount ?? 0;
    const total = Math.max(0, round2(qty * unitPrice - discount));
    return {
      inventory_item_id: invId,
      kind,
      name,
      quantity: qty,
      unit_price: unitPrice,
      discount,
      total,
    };
  }

  async checkout(user: AuthUser, dto: CreateSaleDto) {
    // Snapshot do cliente (opcional). getCustomer abre a própria tx.
    let customerName: string | null = null;
    if (dto.customerId) {
      try {
        const c = await this.customers.getCustomer(user, dto.customerId);
        customerName = c.name;
      } catch {
        customerName = null;
      }
    }

    // Snapshot das linhas (FORA da tx de criação — getItem abre tx própria).
    const lines: SaleLineData[] = [];
    for (const it of dto.items) {
      lines.push(await this.buildLine(user, it));
    }
    const subtotal = round2(lines.reduce((a, l) => a + l.total, 0));
    const saleDiscount = dto.discount ?? 0;
    const total = Math.max(0, round2(subtotal - saleDiscount));

    // Tx curta: número + venda + itens.
    const sale = await this.tenant.withTenantTx(async () => {
      const number = await this.repo.nextNumber();
      return this.repo.createWithItems(user.tenantId, {
        number,
        customerId: dto.customerId ?? null,
        customerName,
        paymentMethod: dto.paymentMethod,
        discount: saleDiscount,
        subtotal,
        total,
        soldBy: user.userId,
        lines,
      });
    });

    // Baixa de estoque FORA da tx (reconcileConsumption abre a própria via
    // runWithTenant). Best-effort por item — erro num item não derruba a venda.
    let stockApplied = false;
    for (const li of sale.items) {
      if (li.kind !== 'product' || !li.inventory_item_id) continue;
      try {
        await this.inventory.reconcileConsumption(user.tenantId, {
          inventoryItemId: li.inventory_item_id,
          refType: 'sale',
          refId: sale.id,
          refItemId: li.id,
          targetQty: toNum(li.quantity),
          createdBy: user.userId,
        });
        stockApplied = true;
      } catch (e) {
        this.logger.warn(
          `Baixa de estoque falhou (venda ${sale.id}, item ${li.id}): ${
            (e as Error).message
          }`,
        );
      }
    }
    if (stockApplied) {
      await this.tenant.withTenantTx(() =>
        this.repo.updateSale(sale.id, { stock_applied: true }),
      );
    }

    await this.audit.log(user.tenantId, user.userId, 'sale_create', sale.id, {
      total,
      items: sale.items.length,
    });
    return this.getOne(sale.id);
  }

  async list(query: ListSalesQueryDto) {
    const page = query.page && query.page > 0 ? query.page : 1;
    const [items, total] = await this.tenant.withTenantTx(() =>
      this.repo.listSales({
        status: query.status,
        customerId: query.customerId,
        skip: (page - 1) * DEFAULT_PAGE_SIZE,
        take: DEFAULT_PAGE_SIZE,
      }),
    );
    return { items, total, page, pageSize: DEFAULT_PAGE_SIZE };
  }

  async getOne(id: string) {
    const sale = await this.tenant.withTenantTx(() =>
      this.repo.findByIdWithItems(id),
    );
    if (!sale) throw new NotFoundException('Venda não encontrada.');
    return sale;
  }

  async cancel(user: AuthUser, id: string, dto: CancelSaleDto) {
    const sale = await this.tenant.withTenantTx(async () => {
      const s = await this.repo.findByIdWithItems(id);
      if (!s) throw new NotFoundException('Venda não encontrada.');
      if (s.status === 'cancelada') {
        throw new BadRequestException('Venda já cancelada.');
      }
      return s;
    });

    // Estorna o estoque (targetQty=0) FORA da tx.
    for (const li of sale.items) {
      if (li.kind !== 'product' || !li.inventory_item_id) continue;
      try {
        await this.inventory.reconcileConsumption(user.tenantId, {
          inventoryItemId: li.inventory_item_id,
          refType: 'sale',
          refId: sale.id,
          refItemId: li.id,
          targetQty: 0,
          createdBy: user.userId,
        });
      } catch (e) {
        this.logger.warn(
          `Estorno de estoque falhou (venda ${sale.id}, item ${li.id}): ${
            (e as Error).message
          }`,
        );
      }
    }

    await this.tenant.withTenantTx(() =>
      this.repo.updateSale(id, {
        status: 'cancelada',
        canceled_at: new Date(),
      }),
    );
    await this.audit.log(user.tenantId, user.userId, 'sale_cancel', id, {
      reason: dto.reason,
    });
    return this.getOne(id);
  }
}
