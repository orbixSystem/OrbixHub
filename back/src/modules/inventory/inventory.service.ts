import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditAction, AuditService } from '../../common/audit/audit.service';
import { BillingService } from '../billing/billing.service';
import { InventoryRepository } from './inventory.repository';
import {
  INVENTORY_CONFIG_KEY,
  INVENTORY_MODULE_KEY,
  InventoryConfig,
  mergeInventoryConfig,
  validateAttributes,
} from './inventory.config';
import {
  CreateInventoryItemDto,
  ItemQueryDto,
  UpdateInventoryItemDto,
} from './dto/item.dto';
import { UpdateInventoryConfigDto } from './dto/config.dto';
import {
  CATALOG_PROVIDER,
  CatalogHit,
  CatalogProvider,
} from './catalog/catalog.provider';
import { CatalogProductStore } from './catalog/catalog-product.store';
import { isValidGtin } from './catalog/gtin';

const DEFAULT_PAGE_SIZE = 20;

const isUniqueViolation = (e: unknown): boolean =>
  (e as { code?: string })?.code === 'P2002';

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

/** Trim → null quando vazio (mesmo padrão do customers). */
const trimOrNull = (v: string | undefined): string | null | undefined =>
  v === undefined ? undefined : v.trim() || null;

export type LookupResult =
  | { source: 'internal'; item: unknown }
  | { source: 'catalog'; suggestion: CatalogHit }
  | { source: 'none' };

@Injectable()
export class InventoryService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: InventoryRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
    private readonly catalogStore: CatalogProductStore,
    @Inject(CATALOG_PROVIDER) private readonly catalog: CatalogProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  // ===================== Config =====================
  async getConfig(tenantId: string): Promise<InventoryConfig> {
    const settings = await this.billing.getModuleSettings(
      tenantId,
      INVENTORY_MODULE_KEY,
    );
    return mergeInventoryConfig(
      settings[INVENTORY_CONFIG_KEY] as Partial<InventoryConfig> | undefined,
    );
  }

  async updateConfig(
    user: AuthUser,
    dto: UpdateInventoryConfigDto,
  ): Promise<InventoryConfig> {
    const settings = await this.billing.getModuleSettings(
      user.tenantId,
      INVENTORY_MODULE_KEY,
    );
    const current = settings[INVENTORY_CONFIG_KEY] as
      | Partial<InventoryConfig>
      | undefined;
    const merged = mergeInventoryConfig(current, dto as Partial<InventoryConfig>);
    await this.billing.setModuleSettings(user.tenantId, INVENTORY_MODULE_KEY, {
      ...settings,
      [INVENTORY_CONFIG_KEY]: merged,
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'settings_change',
      'inventory.config',
    );
    return merged;
  }

  // ===================== Items =====================
  async createItem(user: AuthUser, dto: CreateInventoryItemDto) {
    const config = await this.getConfig(user.tenantId);
    const errs = validateAttributes(dto.attributes, config.itemFields);
    if (errs.length) throw new BadRequestException(errs.join(' '));

    const data = {
      name: dto.name.trim(),
      sku: trimOrNull(dto.sku),
      manufacturer_code: trimOrNull(dto.manufacturerCode),
      barcode: trimOrNull(dto.barcode),
      category: trimOrNull(dto.category),
      brand: trimOrNull(dto.brand),
      unit: trimOrNull(dto.unit),
      sale_price: dto.salePrice ?? null,
      cost_price: dto.costPrice ?? null,
      margin_pct: dto.marginPct ?? null,
      current_stock: dto.currentStock ?? 0,
      min_stock: dto.minStock ?? null,
      attributes: (dto.attributes ?? {}) as Prisma.InputJsonValue,
    };
    try {
      const item = await this.tenant.withTenantTx(() =>
        this.repo.createItem(user.tenantId, data),
      );
      await this.audit.log(
        user.tenantId,
        user.userId,
        'inventory_item_create',
        item.id,
      );
      return item;
    } catch (e) {
      if (isUniqueViolation(e))
        throw new ConflictException('Já existe um item com este código.');
      throw e;
    }
  }

  async listItems(user: AuthUser, query: ItemQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const active =
      query.active === 'false'
        ? 'archived'
        : query.active === 'all'
          ? 'all'
          : 'active';
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listItems({
        q: query.q?.trim() || undefined,
        category: query.category?.trim() || undefined,
        active,
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

  async updateItem(user: AuthUser, id: string, dto: UpdateInventoryItemDto) {
    if (dto.attributes !== undefined) {
      const config = await this.getConfig(user.tenantId);
      const errs = validateAttributes(dto.attributes, config.itemFields);
      if (errs.length) throw new BadRequestException(errs.join(' '));
    }
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing) throw new NotFoundException('Item não encontrado.');
      const data: Record<string, unknown> = {};
      if (dto.name !== undefined) data.name = dto.name.trim();
      if (dto.sku !== undefined) data.sku = trimOrNull(dto.sku);
      if (dto.manufacturerCode !== undefined)
        data.manufacturer_code = trimOrNull(dto.manufacturerCode);
      if (dto.barcode !== undefined) data.barcode = trimOrNull(dto.barcode);
      if (dto.category !== undefined) data.category = trimOrNull(dto.category);
      if (dto.brand !== undefined) data.brand = trimOrNull(dto.brand);
      if (dto.unit !== undefined) data.unit = trimOrNull(dto.unit);
      if (dto.salePrice !== undefined) data.sale_price = dto.salePrice;
      if (dto.costPrice !== undefined) data.cost_price = dto.costPrice;
      if (dto.marginPct !== undefined) data.margin_pct = dto.marginPct;
      if (dto.currentStock !== undefined) data.current_stock = dto.currentStock;
      if (dto.minStock !== undefined) data.min_stock = dto.minStock;
      if (dto.attributes !== undefined)
        data.attributes = dto.attributes as Prisma.InputJsonValue;
      try {
        const item = await this.repo.updateItem(id, data);
        await this.audit.log(
          user.tenantId,
          user.userId,
          'inventory_item_update',
          id,
        );
        return item;
      } catch (e) {
        if (isUniqueViolation(e))
          throw new ConflictException('Já existe um item com este código.');
        throw e;
      }
    });
  }

  async archiveItem(user: AuthUser, id: string) {
    return this.setActive(user, id, false, 'inventory_item_archive');
  }
  async unarchiveItem(user: AuthUser, id: string) {
    return this.setActive(user, id, true, 'inventory_item_unarchive');
  }
  private async setActive(
    user: AuthUser,
    id: string,
    isActive: boolean,
    action: AuditAction,
  ) {
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing) throw new NotFoundException('Item não encontrado.');
      const item = await this.repo.setActive(id, isActive);
      await this.audit.log(user.tenantId, user.userId, action, id);
      return item;
    });
  }

  async lowStock(_user: AuthUser) {
    const { items } = await this.tenant.withTenantTx(() =>
      this.repo.listItems({ active: 'active', lowStock: true, skip: 0, take: 100 }),
    );
    return items;
  }

  // ===================== Código-first (lookup) =====================
  /**
   * Cascata: 1) interno (barcode|manufacturer_code|sku); 2) catálogo por GTIN (só
   * se válido + CATALOG_ENABLED) servido do nosso `catalog_product` durável quando
   * fresco (≤60d, zero chamada externa); no miss/obsoleto chama o provider FORA de
   * tx e faz upsert; 3) nada. Token/credenciais nunca vão ao front.
   */
  async lookup(_user: AuthUser, code: string): Promise<LookupResult> {
    const trimmed = code.trim();

    const internal = await this.tenant.withTenantTx(() =>
      this.repo.findByCode(trimmed),
    );
    if (internal) return { source: 'internal', item: internal };

    if (isValidGtin(trimmed) && this.env.CATALOG_ENABLED) {
      const cached = await this.catalogStore.get(trimmed);
      if (cached) return { source: 'catalog', suggestion: cached };

      // Miss/obsoleto: chamada externa fora de qualquer transação de banco.
      const hit = await this.catalog.lookupByGtin(trimmed);
      if (hit) {
        await this.catalogStore.upsert(trimmed, hit, this.env.CATALOG_PROVIDER);
        return { source: 'catalog', suggestion: hit };
      }
    }

    return { source: 'none' };
  }

  // ===================== Seam público (consumido pela OS) =====================
  /** Busca 1 item por id (tenant via CLS — chamado dentro de request autenticado). */
  getItem(id: string) {
    return this.getItemOrThrow(id);
  }

  /** Entrada de estoque programática (tenant explícito — padrão runWithTenant). */
  async incrementStock(tenantId: string, id: string, qty: number) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const item = await this.repo.findItemById(id);
      if (!item) throw new NotFoundException('Item não encontrado.');
      const next = toNum(item.current_stock) + qty;
      return this.repo.adjustStock(id, next);
    });
  }

  /** Baixa de estoque programática; valida saldo ≥ 0. */
  async decrementStock(tenantId: string, id: string, qty: number) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const item = await this.repo.findItemById(id);
      if (!item) throw new NotFoundException('Item não encontrado.');
      const next = toNum(item.current_stock) - qty;
      if (next < 0) throw new BadRequestException('Estoque insuficiente.');
      return this.repo.adjustStock(id, next);
    });
  }
}
