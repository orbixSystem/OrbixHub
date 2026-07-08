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
import { NotificationsService } from '../notifications/notifications.service';
import { crossedIntoLowStock } from './low-stock';
import { computeReconcile } from './stock-reconcile';
import { InventoryRepository } from './inventory.repository';
import {
  INVENTORY_CONFIG_KEY,
  INVENTORY_MODULE_KEY,
  InventoryConfig,
  mergeInventoryConfig,
  skuBaseFromName,
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
import {
  isIdUniqueViolation,
  isUniqueViolation,
} from '../../common/database/prisma-errors';

const DEFAULT_PAGE_SIZE = 20;

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

const toNumOrNull = (d: Prisma.Decimal | number | null | undefined): number | null =>
  d == null ? null : typeof d === 'number' ? d : d.toNumber();

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
    private readonly notifications: NotificationsService,
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

    const isService = dto.kind === 'service';
    const data = {
      id: dto.id,
      name: dto.name.trim(),
      kind: dto.kind ?? 'product',
      // Serviço não controla estoque: sem barcode/código do fabricante/estoque.
      sku: trimOrNull(dto.sku),
      manufacturer_code: isService ? null : trimOrNull(dto.manufacturerCode),
      barcode: isService ? null : trimOrNull(dto.barcode),
      category: trimOrNull(dto.category),
      brand: trimOrNull(dto.brand),
      unit: trimOrNull(dto.unit),
      sale_price: dto.salePrice ?? null,
      cost_price: dto.costPrice ?? null,
      margin_pct: dto.marginPct ?? null,
      current_stock: isService ? 0 : (dto.currentStock ?? 0),
      min_stock: isService ? null : (dto.minStock ?? null),
      duration_minutes: isService ? (dto.durationMinutes ?? null) : null,
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
      if (!isUniqueViolation(e)) throw e;
      // PK duplicada (replay offline com id) ≠ SKU/barcode duplicado. Sob RLS o
      // meta.target vem null — quando o detalhe não aponta a PK, confirmamos
      // com uma leitura por id em nova tx (id existe no tenant ⇒ conflito de id).
      if (dto.id) {
        const idTaken =
          isIdUniqueViolation(e) ||
          (await this.tenant.withTenantTx(() =>
            this.repo.findItemById(dto.id as string),
          )) != null;
        if (idTaken) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
      }
      throw new ConflictException('Já existe um item com este código.');
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
        kind: query.kind,
        category: query.category?.trim() || undefined,
        active,
        lowStock: query.lowStock ?? false,
        sort: query.sort ?? 'name_asc',
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  async getItemOrThrow(id: string) {
    const item = await this.tenant.withTenantTx(() => this.repo.findItemById(id));
    if (!item || item.deleted_at) throw new NotFoundException('Item não encontrado.');
    return item;
  }

  async deleteItem(user: AuthUser, id: string) {
    // audit FORA do withTenantTx: audit.log abre sua própria transação, e aninhar
    // transações esgota o pool ("Unable to start a transaction"). Mesmo padrão do createItem.
    const item = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('Item não encontrado.');
      return this.repo.softDelete(id);
    });
    await this.audit.log(user.tenantId, user.userId, 'inventory_item_delete', id);
    return item;
  }

  async updateItem(user: AuthUser, id: string, dto: UpdateInventoryItemDto) {
    if (dto.attributes !== undefined) {
      const config = await this.getConfig(user.tenantId);
      const errs = validateAttributes(dto.attributes, config.itemFields);
      if (errs.length) throw new BadRequestException(errs.join(' '));
    }
    const { item, prev, prevMin, next, nextMin, isService } =
      await this.tenant.withTenantTx(async () => {
        const existing = await this.repo.findItemById(id);
        if (!existing || existing.deleted_at)
          throw new NotFoundException('Item não encontrado.');
        // kind nunca muda; serviço não controla estoque (ignora campos de estoque).
        const isService = existing.kind === 'service';
        const data: Record<string, unknown> = {};
        if (dto.name !== undefined) data.name = dto.name.trim();
        if (dto.sku !== undefined) data.sku = trimOrNull(dto.sku);
        if (!isService && dto.manufacturerCode !== undefined)
          data.manufacturer_code = trimOrNull(dto.manufacturerCode);
        if (!isService && dto.barcode !== undefined)
          data.barcode = trimOrNull(dto.barcode);
        if (dto.category !== undefined) data.category = trimOrNull(dto.category);
        if (dto.brand !== undefined) data.brand = trimOrNull(dto.brand);
        if (dto.unit !== undefined) data.unit = trimOrNull(dto.unit);
        if (dto.salePrice !== undefined) data.sale_price = dto.salePrice;
        if (dto.costPrice !== undefined) data.cost_price = dto.costPrice;
        if (dto.marginPct !== undefined) data.margin_pct = dto.marginPct;
        if (!isService && dto.currentStock !== undefined)
          data.current_stock = dto.currentStock;
        if (!isService && dto.minStock !== undefined) data.min_stock = dto.minStock;
        if (dto.durationMinutes !== undefined)
          data.duration_minutes = dto.durationMinutes;
        if (dto.attributes !== undefined)
          data.attributes = dto.attributes as Prisma.InputJsonValue;
        try {
          const updated = await this.repo.updateItem(id, data);
          return {
            item: updated,
            prev: toNum(existing.current_stock),
            prevMin: toNumOrNull(existing.min_stock),
            next: toNum(updated.current_stock),
            nextMin: toNumOrNull(updated.min_stock),
            isService,
          };
        } catch (e) {
          if (isUniqueViolation(e))
            throw new ConflictException('Já existe um item com este código.');
          throw e;
        }
      });
    // audit FORA do tx (evita transação aninhada — ver deleteItem).
    await this.audit.log(user.tenantId, user.userId, 'inventory_item_update', id);
    if (!isService)
      await this.maybeNotifyLowStock(
        user.tenantId, item, prev, prevMin, next, nextMin,
      );
    return item;
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
    const item = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('Item não encontrado.');
      return this.repo.setActive(id, isActive);
    });
    // audit FORA do tx (evita transação aninhada — ver deleteItem).
    await this.audit.log(user.tenantId, user.userId, action, id);
    return item;
  }

  /**
   * Sugere um SKU de 8 caracteres único por tenant: 4 letras (abreviação do nome)
   * + 4 dígitos sequenciais (ex.: CAFE0001, CAFE0002…).
   */
  async suggestSku(_user: AuthUser, name: string): Promise<{ sku: string }> {
    const abbr = skuBaseFromName(name); // 4 letras
    return this.tenant.withTenantTx(async () => {
      for (let n = 1; n < 10000; n++) {
        const candidate = `${abbr}${String(n).padStart(4, '0')}`;
        if (!(await this.repo.skuExists(candidate))) return { sku: candidate };
      }
      return { sku: `${abbr}0000` }; // fallback defensivo (improvável)
    });
  }

  async lowStock(_user: AuthUser) {
    const { items } = await this.tenant.withTenantTx(() =>
      this.repo.listItems({
        active: 'active',
        kind: 'product',
        lowStock: true,
        skip: 0,
        take: 100,
      }),
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

  /**
   * Busca itens vivos por id, em lote (tenant via CLS). Itens ausentes/deletados
   * simplesmente não voltam — o chamador decide o fallback. Abre a própria tx, então
   * NÃO chame de dentro de outra `withTenantTx` (aninhar esgota o pool).
   */
  getItemsByIds(ids: string[]) {
    if (!ids.length) return Promise.resolve([]);
    return this.tenant.withTenantTx(() => this.repo.findItemsByIds(ids));
  }

  /** Entrada de estoque programática (tenant explícito — padrão runWithTenant). */
  async incrementStock(tenantId: string, id: string, qty: number) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const item = await this.repo.findItemById(id);
      if (!item) throw new NotFoundException('Item não encontrado.');
      if (item.kind === 'service')
        throw new BadRequestException('Serviço não controla estoque.');
      const next = toNum(item.current_stock) + qty;
      return this.repo.adjustStock(id, next);
    });
  }

  /** Baixa de estoque programática; valida saldo ≥ 0. Notifica na virada (fora da tx). */
  async decrementStock(tenantId: string, id: string, qty: number) {
    const { item, prev, next, min } = await this.tenant.runWithTenant(
      tenantId,
      async () => {
        const item = await this.repo.findItemById(id);
        if (!item) throw new NotFoundException('Item não encontrado.');
        if (item.kind === 'service')
          throw new BadRequestException('Serviço não controla estoque.');
        const prev = toNum(item.current_stock);
        const next = prev - qty;
        if (next < 0) throw new BadRequestException('Estoque insuficiente.');
        const updated = await this.repo.adjustStock(id, next);
        return { item: updated, prev, next, min: toNumOrNull(item.min_stock) };
      },
    );
    // min não muda nesta operação → prevMin === nextMin === min.
    await this.maybeNotifyLowStock(tenantId, item, prev, min, next, min);
    return item;
  }

  /**
   * Reconcilia o consumo de UMA linha de origem (ex.: item de OS) para a
   * quantidade-alvo. Idempotente: se o consumo já registrado == alvo, não faz
   * nada. Grava o movimento e ajusta o saldo na MESMA tx; notifica estoque baixo
   * na virada (fora da tx). Abre a própria tx (runWithTenant) — NÃO chamar de
   * dentro de outra withTenantTx/runWithTenant.
   */
  async reconcileConsumption(
    tenantId: string,
    args: {
      inventoryItemId: string;
      refType: 'service_order' | 'sale';
      refId: string;
      refItemId: string;
      targetQty: number;
      createdBy?: string | null;
    },
  ): Promise<void> {
    const result = await this.tenant.runWithTenant(tenantId, async () => {
      const item = await this.repo.findItemById(args.inventoryItemId);
      // Item sumiu/deletado, ou é serviço → nada a reconciliar.
      if (!item || item.kind === 'service') return null;

      const prevConsumed = await this.repo.sumConsumedByRefItem(args.refItemId);
      const plan = computeReconcile(
        prevConsumed,
        args.targetQty,
        args.refType === 'sale' ? 'sale' : 'os',
      );
      if (!plan) return null; // sem mudança

      const prev = toNum(item.current_stock);
      const next = prev + plan.stockDelta;
      if (next < 0) throw new BadRequestException('Estoque insuficiente.');

      await this.repo.createStockMovement(tenantId, {
        inventory_item_id: args.inventoryItemId,
        stock_delta: plan.stockDelta,
        reason: plan.reason,
        ref_type: args.refType,
        ref_id: args.refId,
        ref_item_id: args.refItemId,
        created_by: args.createdBy ?? null,
      });
      const updated = await this.repo.adjustStock(args.inventoryItemId, next);
      return { item: updated, prev, next, min: toNumOrNull(item.min_stock) };
    });

    // Notifica "estoque baixo" só na virada (consumo que cruza o mínimo).
    if (result) {
      await this.maybeNotifyLowStock(
        tenantId,
        result.item,
        result.prev,
        result.min,
        result.next,
        result.min,
      );
    }
  }

  /**
   * Best-effort: notifica "estoque baixo" só na virada (NÃO-baixo → baixo). Chamar
   * SEMPRE fora de withTenantTx/runWithTenant (notify abre a própria tx). Falha de
   * notificação nunca quebra a baixa de estoque.
   */
  private async maybeNotifyLowStock(
    tenantId: string,
    item: { id: string; name: string; unit: string | null },
    prevStock: number,
    prevMin: number | null,
    nextStock: number,
    nextMin: number | null,
  ): Promise<void> {
    if (!crossedIntoLowStock(prevStock, prevMin, nextStock, nextMin)) return;
    try {
      const unidade = item.unit?.trim() ? ` ${item.unit.trim()}` : '';
      await this.notifications.notify(tenantId, {
        type: 'inventory_low_stock',
        title: `Estoque baixo: ${item.name}`,
        body: `Restam ${nextStock}${unidade} (mínimo ${nextMin})`,
        refType: 'inventory_item',
        refId: item.id,
      });
    } catch {
      // best-effort — não quebra o fluxo de estoque
    }
  }
}
