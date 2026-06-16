import {
  BadRequestException, ConflictException,
  Injectable, NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditAction, AuditService } from '../../common/audit/audit.service';
import { BillingService } from '../billing/billing.service';
import { InventoryRepository } from './inventory.repository';
import {
  INVENTORY_CONFIG_KEY, INVENTORY_MODULE_KEY,
  InventoryConfig, mergeInventoryConfig, computeMovement, MovementType,
} from './inventory.config';
import { CreateItemDto, ListItemsQueryDto, UpdateItemDto } from './dto/item.dto';
import { CreateMovementDto } from './dto/movement.dto';
import { UpdateInventoryConfigDto } from './dto/config.dto';

const DEFAULT_PAGE_SIZE = 20;
const isUniqueViolation = (e: unknown) => (e as { code?: string })?.code === 'P2002';
const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

export interface ApplyMovementInput {
  itemId: string;
  type: MovementType;
  quantity: number;
  reason?: string;
  refType?: string;
  refId?: string;
  note?: string;
  actorUserId?: string;
}

@Injectable()
export class InventoryService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: InventoryRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
  ) {}

  // ============ Config ============
  async getConfig(tenantId: string): Promise<InventoryConfig> {
    const settings = await this.billing.getModuleSettings(tenantId, INVENTORY_MODULE_KEY);
    return mergeInventoryConfig(settings[INVENTORY_CONFIG_KEY] as Partial<InventoryConfig> | undefined);
  }

  async updateConfig(user: AuthUser, dto: UpdateInventoryConfigDto): Promise<InventoryConfig> {
    const settings = await this.billing.getModuleSettings(user.tenantId, INVENTORY_MODULE_KEY);
    const current = settings[INVENTORY_CONFIG_KEY] as Partial<InventoryConfig> | undefined;
    const merged = mergeInventoryConfig(current, dto as Partial<InventoryConfig>);
    await this.billing.setModuleSettings(user.tenantId, INVENTORY_MODULE_KEY, {
      ...settings,
      [INVENTORY_CONFIG_KEY]: merged,
    });
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'inventory.config');
    return merged;
  }

  // ============ Items ============
  async createItem(user: AuthUser, dto: CreateItemDto) {
    const isService = dto.kind === 'service';
    const config = await this.getConfig(user.tenantId);
    const data = {
      kind: dto.kind,
      name: dto.name.trim(),
      code: dto.code?.trim() || null,
      barcode: isService ? null : dto.barcode?.trim() || null,
      category: dto.category?.trim() || null,
      unit: dto.unit?.trim() || config.defaultUnit,
      sale_price_cents: dto.salePriceCents ?? 0,
      cost_price_cents: dto.costPriceCents ?? null,
      margin_percent: dto.marginPercent ?? null,
      sellable: dto.sellable ?? true,
      track_stock: isService ? false : (dto.trackStock ?? config.trackStockDefault),
      min_qty: isService ? null : dto.minQty ?? null,
      duration_minutes: isService ? dto.durationMinutes ?? null : null,
      brand: dto.brand?.trim() || null,
    };
    try {
      const item = await this.tenant.withTenantTx(() => this.repo.createItem(user.tenantId, data));
      await this.audit.log(user.tenantId, user.userId, 'inventory_item_create', item.id);
      return item;
    } catch (e) {
      if (isUniqueViolation(e)) throw new ConflictException('Já existe um item com este código.');
      throw e;
    }
  }

  async listItems(user: AuthUser, query: ListItemsQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listItems({
        q: query.q?.trim() || undefined,
        kind: query.kind,
        category: query.category?.trim() || undefined,
        status: query.status ?? 'active',
        lowStock: query.lowStock ?? false,
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  async getItemOrThrow(id: string) {
    const item = await this.tenant.withTenantTx(() => this.repo.findItemById(id));
    if (!item) throw new NotFoundException('Item não encontrado.');
    return item;
  }

  async updateItem(user: AuthUser, id: string, dto: UpdateItemDto) {
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing) throw new NotFoundException('Item não encontrado.');
      const isService = existing.kind === 'service';
      const data: Record<string, unknown> = {};
      if (dto.name !== undefined) data.name = dto.name.trim();
      if (dto.code !== undefined) data.code = dto.code.trim() || null;
      if (dto.barcode !== undefined) data.barcode = isService ? null : dto.barcode.trim() || null;
      if (dto.category !== undefined) data.category = dto.category.trim() || null;
      if (dto.unit !== undefined) data.unit = dto.unit.trim() || existing.unit;
      if (dto.salePriceCents !== undefined) data.sale_price_cents = dto.salePriceCents;
      if (dto.costPriceCents !== undefined) data.cost_price_cents = dto.costPriceCents;
      if (dto.marginPercent !== undefined) data.margin_percent = dto.marginPercent;
      if (dto.sellable !== undefined) data.sellable = dto.sellable;
      if (dto.trackStock !== undefined && !isService) data.track_stock = dto.trackStock;
      if (dto.minQty !== undefined && !isService) data.min_qty = dto.minQty;
      if (dto.durationMinutes !== undefined && isService) data.duration_minutes = dto.durationMinutes;
      if (dto.brand !== undefined) data.brand = dto.brand.trim() || null;
      try {
        const item = await this.repo.updateItem(id, data);
        await this.audit.log(user.tenantId, user.userId, 'inventory_item_update', id);
        return item;
      } catch (e) {
        if (isUniqueViolation(e)) throw new ConflictException('Já existe um item com este código.');
        throw e;
      }
    });
  }

  async archiveItem(user: AuthUser, id: string) {
    return this.setStatus(user, id, 'archived', 'inventory_item_archive');
  }
  async unarchiveItem(user: AuthUser, id: string) {
    return this.setStatus(user, id, 'active', 'inventory_item_unarchive');
  }
  private async setStatus(
    user: AuthUser,
    id: string,
    status: 'active' | 'archived',
    action: AuditAction,
  ) {
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing) throw new NotFoundException('Item não encontrado.');
      const item = await this.repo.setItemStatus(id, status);
      await this.audit.log(user.tenantId, user.userId, action, id);
      return item;
    });
  }

  // ============ Movements ============
  async registerMovement(user: AuthUser, itemId: string, dto: CreateMovementDto) {
    return this.tenant.withTenantTx(async () => {
      const item = await this.repo.findItemById(itemId);
      if (!item) throw new NotFoundException('Item não encontrado.');
      if (item.kind === 'service' || !item.track_stock) {
        throw new BadRequestException('Este item não controla estoque.');
      }
      let calc: { quantity: number; balanceAfter: number };
      try {
        calc = computeMovement(toNum(item.stock_qty), dto.type, dto.quantity);
      } catch (e) {
        throw new BadRequestException((e as Error).message);
      }
      const movement = await this.repo.createMovement(user.tenantId, itemId, {
        type: dto.type,
        quantity: calc.quantity,
        balance_after: calc.balanceAfter,
        reason: dto.reason?.trim() || 'manual',
        ref_type: null,
        ref_id: null,
        note: dto.note?.trim() || null,
        created_by: user.userId,
      });
      await this.audit.log(user.tenantId, user.userId, 'inventory_movement', itemId, {
        type: dto.type, quantity: calc.quantity, balanceAfter: calc.balanceAfter,
      });
      return movement;
    });
  }

  async listMovements(user: AuthUser, itemId: string) {
    return this.tenant.withTenantTx(async () => {
      const item = await this.repo.findItemById(itemId);
      if (!item) throw new NotFoundException('Item não encontrado.');
      return this.repo.listMovements(itemId);
    });
  }

  async lowStock(user: AuthUser) {
    const { items } = await this.tenant.withTenantTx(() =>
      this.repo.listItems({ status: 'active', lowStock: true, skip: 0, take: 100 }),
    );
    return items;
  }

  // ============ Public (consumed by OS — não pela UI deste módulo) ============
  /** Busca 1 item por id (para a OS montar a linha por snapshot). */
  getItem(user: AuthUser, id: string) {
    return this.getItemOrThrow(id);
  }

  /** Picker enxuto para a OS. */
  async searchForPicker(user: AuthUser, q: string, kind?: 'product' | 'service') {
    return this.tenant.withTenantTx(() => this.repo.searchForPicker(q?.trim() || undefined, kind));
  }

  /**
   * Baixa/entrada programática (ex.: consumo por OS). tenantId explícito
   * (padrão runWithTenant). Não chamar dentro de tx com I/O externo.
   */
  async applyMovement(tenantId: string, input: ApplyMovementInput) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const item = await this.repo.findItemById(input.itemId);
      if (!item) throw new NotFoundException('Item não encontrado.');
      if (item.kind === 'service' || !item.track_stock) {
        throw new BadRequestException('Este item não controla estoque.');
      }
      const calc = computeMovement(toNum(item.stock_qty), input.type, input.quantity);
      return this.repo.createMovement(tenantId, input.itemId, {
        type: input.type,
        quantity: calc.quantity,
        balance_after: calc.balanceAfter,
        reason: input.reason ?? 'os_consumption',
        ref_type: input.refType ?? null,
        ref_id: input.refId ?? null,
        note: input.note ?? null,
        created_by: input.actorUserId ?? null,
      });
    });
  }
}
