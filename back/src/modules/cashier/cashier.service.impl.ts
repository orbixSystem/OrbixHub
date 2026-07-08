import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingService } from '../billing/billing.service';
import { CashierRepository, CashierSyncEntity } from './cashier.repository';
import { clampChangedSinceLimit } from '../../common/database/changed-since';
import {
  buildPaymentSummary,
  CashierService,
  PaymentSummary,
} from './cashier.service';
import {
  CASHIER_CONFIG_KEY,
  CASHIER_MODULE_KEY,
  CashierConfig,
  computeDifference,
  computeExpected,
  directionForCategory,
  EntryCategory,
  mergeCashierConfig,
  PaymentMethod,
  round2,
  SaleKind,
} from './cashier.config';
import { CreateEntryDto, ReverseEntryDto } from './dto/entry.dto';
import { CloseSessionDto, OpenSessionDto } from './dto/session.dto';
import { EntryQueryDto, SummaryQueryDto } from './dto/query.dto';
import { UpdateCashierConfigDto } from './dto/config.dto';
import {
  isIdUniqueViolation,
  isUniqueViolation,
} from '../../common/database/prisma-errors';

const DEFAULT_PAGE_SIZE = 20;

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

const parseDate = (v: string | undefined): Date | undefined =>
  v ? new Date(v) : undefined;

/** Totais de uma sessão por método/direção (informativo no fechamento/atual). */
export interface MethodTotals {
  method: string;
  in: number;
  out: number;
}

/**
 * Implementação REAL do Caixa. Estende o contrato congelado `CashierService`
 * (os 2 métodos que a OS/vendas consomem) e adiciona a operação do módulo
 * (sessões, lançamentos, extrato, resumo, config). Tudo tenant-scoped por RLS:
 * endpoints do controller usam `withTenantTx` (tenant do CLS/JWT); os métodos do
 * contrato usam `runWithTenant` (tenant explícito vindo do chamador, p. ex. a OS).
 */
@Injectable()
export class CashierServiceImpl extends CashierService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: CashierRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
  ) {
    super();
  }

  // ============== Contrato público (consumido pela OS/vendas) ==============
  async getPaymentSummary(
    tenantId: string,
    vendaId: string,
    fallbackTotal = 0,
  ): Promise<PaymentSummary> {
    const paid = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.sumPaidForSale(vendaId),
    );
    return buildPaymentSummary(fallbackTotal, paid);
  }

  async getPaymentSummaryBatch(
    tenantId: string,
    vendas: Array<{ id: string; total: number }>,
  ): Promise<Map<string, PaymentSummary>> {
    const map = new Map<string, PaymentSummary>();
    if (!vendas.length) return map;
    const paidById = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.sumPaidForSales(vendas.map((v) => v.id)),
    );
    for (const v of vendas) {
      map.set(v.id, buildPaymentSummary(v.total, paidById.get(v.id) ?? 0));
    }
    return map;
  }

  private static readonly SYNC_ENTITIES = new Set<CashierSyncEntity>([
    'cash_session',
    'cash_entry',
  ]);

  /**
   * Página de mudanças de `cash_session`/`cash_entry` para o pull de sync
   * offline ("aponta, não invade": o módulo `sync` só chama este service
   * público via o token `CashierService`). Mesma shape JSON dos endpoints de
   * leitura (linhas cruas do Prisma — `listSessions`/`listEntries` também
   * devolvem a linha crua).
   */
  async listChangedSince(
    entity: string,
    cursor: { ts: string; id: string } | null,
    limit: number,
  ): Promise<{ rows: unknown[]; nextCursor: { ts: string; id: string } | null }> {
    if (!CashierServiceImpl.SYNC_ENTITIES.has(entity as CashierSyncEntity)) {
      throw new BadRequestException(
        `Entidade não pertence ao módulo cashier: ${entity}`,
      );
    }
    const clamped = clampChangedSinceLimit(limit);
    return this.tenant.withTenantTx(() =>
      this.repo.listChangedSince(entity as CashierSyncEntity, cursor, clamped),
    );
  }

  // ===================== Config =====================
  async getConfig(tenantId: string): Promise<CashierConfig> {
    const settings = await this.billing.getModuleSettings(
      tenantId,
      CASHIER_MODULE_KEY,
    );
    return mergeCashierConfig(
      settings[CASHIER_CONFIG_KEY] as Partial<CashierConfig> | undefined,
    );
  }

  async updateConfig(
    user: AuthUser,
    dto: UpdateCashierConfigDto,
  ): Promise<CashierConfig> {
    const settings = await this.billing.getModuleSettings(
      user.tenantId,
      CASHIER_MODULE_KEY,
    );
    const current = settings[CASHIER_CONFIG_KEY] as
      | Partial<CashierConfig>
      | undefined;
    const merged = mergeCashierConfig(current, dto as Partial<CashierConfig>);
    await this.billing.setModuleSettings(user.tenantId, CASHIER_MODULE_KEY, {
      ...settings,
      [CASHIER_CONFIG_KEY]: merged,
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'settings_change',
      'cashier.config',
    );
    return merged;
  }

  // ===================== Sessões =====================
  async openSession(user: AuthUser, dto: OpenSessionDto) {
    try {
      const session = await this.tenant.withTenantTx(async () => {
        const open = await this.repo.findOpenSession(dto.deviceId);
        if (open)
          throw new ConflictException(
            'Já existe um caixa aberto neste ponto de caixa.',
          );
        return this.repo.createSession(user.tenantId, {
          id: dto.id,
          opened_by: user.userId,
          opening_amount: dto.openingAmount ?? 0,
          notes: dto.notes?.trim() || null,
          device_id: dto.deviceId ?? null,
        });
      });
      await this.audit.log(
        user.tenantId,
        user.userId,
        'cashier_session_open',
        session.id,
      );
      return session;
    } catch (e) {
      if (!isUniqueViolation(e)) throw e;
      // PK duplicada (replay offline com id) ≠ "caixa já aberto" (corrida do
      // índice parcial uq_cash_session_open_device). Sob RLS o meta.target vem
      // null — quando o detalhe não aponta a PK, confirmamos com uma leitura
      // por id em nova tx (id existe no tenant ⇒ conflito de id).
      if (dto.id) {
        const idTaken =
          isIdUniqueViolation(e) ||
          (await this.tenant.withTenantTx(() =>
            this.repo.findSessionById(dto.id as string),
          )) != null;
        if (idTaken) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
      }
      // Índice parcial único protege contra corrida (2 aberturas simultâneas no mesmo ponto).
      throw new ConflictException(
        'Já existe um caixa aberto neste ponto de caixa.',
      );
    }
  }

  async closeSession(user: AuthUser, dto: CloseSessionDto) {
    const config = await this.getConfig(user.tenantId);
    const { session, expected, difference, byMethod } =
      await this.tenant.withTenantTx(async () => {
        const open = await this.repo.findOpenSession(dto.deviceId);
        if (!open)
          throw new BadRequestException(
            'Não há caixa aberto neste ponto de caixa.',
          );
        const rows = await this.repo.sessionTotalsByMethod(open.id);
        const byMethod = shapeMethodTotals(rows);
        const cash = pickCash(byMethod);
        const all = pickAll(byMethod);
        const opening = toNum(open.opening_amount);
        // countCashOnly ⇒ só dinheiro entra na conta do esperado.
        const expected = config.countCashOnly
          ? computeExpected({
              opening,
              totalIn: cash.in,
              totalOut: cash.out,
            })
          : computeExpected({ opening, totalIn: all.in, totalOut: all.out });
        const counted = round2(dto.countedAmount);
        const difference = computeDifference(counted, expected);
        const session = await this.repo.closeSession(open.id, {
          closed_by: user.userId,
          closing_amount_counted: counted,
          closing_amount_expected: expected,
          difference,
          notes: dto.notes?.trim() || null,
        });
        return { session, expected, difference, byMethod };
      });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_session_close',
      session.id,
      { expected, difference },
    );
    return { ...session, byMethod };
  }

  /** Sessão aberta atual + totais correntes (para a tela do caixa do dia). */
  async getCurrentSession(user: AuthUser, deviceId?: string) {
    return this.tenant.withTenantTx(async () => {
      const open = await this.repo.findOpenSession(deviceId);
      if (!open) return null;
      const rows = await this.repo.sessionTotalsByMethod(open.id);
      const byMethod = shapeMethodTotals(rows);
      const all = pickAll(byMethod);
      const cash = pickCash(byMethod);
      const config = mergeCashierConfig(
        (await this.billing.getModuleSettings(user.tenantId, CASHIER_MODULE_KEY))[
          CASHIER_CONFIG_KEY
        ] as Partial<CashierConfig> | undefined,
      );
      const expected = config.countCashOnly
        ? computeExpected({
            opening: toNum(open.opening_amount),
            totalIn: cash.in,
            totalOut: cash.out,
          })
        : computeExpected({
            opening: toNum(open.opening_amount),
            totalIn: all.in,
            totalOut: all.out,
          });
      return {
        ...open,
        byMethod,
        totals: { in: all.in, out: all.out, expected },
      };
    });
  }

  async listSessions(_user: AuthUser, page = 1, pageSize = DEFAULT_PAGE_SIZE) {
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listSessions({
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  // ===================== Lançamentos =====================
  async createEntry(user: AuthUser, dto: CreateEntryDto) {
    const category = dto.category as EntryCategory;
    // Despesa/sangria/suprimento (ajustes da gaveta) são privilégio de gestão.
    // Recebimento (os_payment/venda_avulsa) o atendente faz com `cashier.write`.
    if (
      (category === 'despesa' ||
        category === 'sangria' ||
        category === 'suprimento') &&
      !(await this.hasPermission(user.role, 'cashier.manage'))
    ) {
      throw new ForbiddenException(
        'Apenas dono/gerente podem lançar despesa, sangria ou suprimento.',
      );
    }
    const direction = directionForCategory(category);
    const { saleKind, saleId } = this.resolveSale(category, dto);
    const config = await this.getConfig(user.tenantId);

    const entry = await this.tenant.withTenantTx(async () => {
      let open = await this.repo.findOpenSession(dto.deviceId);
      if (!open) {
        if (config.requireOpenSession)
          throw new BadRequestException(
            'Não há caixa aberto neste ponto de caixa.',
          );
        // requireOpenSession=false ⇒ abre uma sessão implícita (valor inicial 0) no mesmo ponto.
        open = await this.repo.createSession(user.tenantId, {
          opened_by: user.userId,
          opening_amount: 0,
          notes: null,
          device_id: dto.deviceId ?? null,
        });
      }
      try {
        return await this.repo.createEntry(user.tenantId, {
          id: dto.id,
          cash_session_id: open.id,
          direction,
          amount: round2(dto.amount),
          method: dto.method as PaymentMethod,
          category,
          sale_kind: saleKind,
          sale_id: saleId,
          description: dto.description?.trim() || null,
          created_by: user.userId,
        });
      } catch (e) {
        // `cash_entry` não tem unique além da PK: P2002 com id do cliente
        // presente SÓ pode ser o id duplicado (replay repetido).
        if (dto.id && isUniqueViolation(e)) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
        throw e;
      }
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_entry_create',
      entry.id,
      { category, direction, amount: toNum(entry.amount), saleKind, saleId },
    );
    return entry;
  }

  /**
   * Valida e resolve o vínculo com a venda. `os_payment` exige (saleKind='os',
   * saleId). Saídas (despesa/sangria) e suprimento nunca apontam venda. `venda_avulsa`
   * é forward-compatible: aceita um vínculo, mas hoje (sem módulo `sale`) fica solto.
   */
  private resolveSale(
    category: EntryCategory,
    dto: CreateEntryDto,
  ): { saleKind: SaleKind | null; saleId: string | null } {
    if (category === 'os_payment') {
      if (dto.saleKind !== 'os' || !dto.saleId)
        throw new BadRequestException(
          'Recebimento de OS exige saleKind="os" e saleId.',
        );
      return { saleKind: 'os', saleId: dto.saleId };
    }
    if (category === 'venda_avulsa') {
      // Aceita vínculo opcional; sem módulo `sale` ainda, normalmente vem solto.
      if (dto.saleId) return { saleKind: (dto.saleKind ?? 'sale') as SaleKind, saleId: dto.saleId };
      return { saleKind: null, saleId: null };
    }
    // despesa / sangria / suprimento: nunca apontam venda.
    return { saleKind: null, saleId: null };
  }

  async reverseEntry(user: AuthUser, id: string, dto: ReverseEntryDto) {
    const entry = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findEntryById(id);
      if (!existing) throw new NotFoundException('Lançamento não encontrado.');
      if (existing.reversed_at)
        throw new ConflictException('Lançamento já estornado.');
      return this.repo.markReversed(id, {
        reversed_by: user.userId,
        reversal_reason: dto.reason.trim(),
      });
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'cashier_entry_reverse',
      id,
      { reason: dto.reason.trim() },
    );
    return entry;
  }

  // ===================== Extrato & resumo =====================
  async listEntries(_user: AuthUser, query: EntryQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listEntries({
        sessionId: query.sessionId,
        direction: query.direction,
        method: query.method,
        category: query.category,
        saleKind: query.saleKind,
        saleId: query.saleId,
        from: parseDate(query.from),
        to: parseDate(query.to),
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  /** Totais por método/categoria/origem no período — base dos relatórios (recebido). */
  async getCashSummary(_user: AuthUser, query: SummaryQueryDto) {
    const p = { from: parseDate(query.from), to: parseDate(query.to) };
    const [methodRows, categoryRows, originRows] = await this.tenant.withTenantTx(
      () =>
        Promise.all([
          this.repo.summaryByMethod(p),
          this.repo.summaryByCategory(p),
          this.repo.summaryByOrigin(p),
        ]),
    );
    const byMethod = shapeMethodTotals(methodRows);
    const all = pickAll(byMethod);
    return {
      byMethod,
      byCategory: shapeKeyedTotals(categoryRows, 'category'),
      byOrigin: shapeKeyedTotals(originRows, 'sale_kind', 'nenhum'),
      totalIn: all.in,
      totalOut: all.out,
      net: round2(all.in - all.out),
    };
  }

  /**
   * Resumo de pagamento para o endpoint HTTP do caixa. `total` é OPCIONAL e vem do
   * dono da venda (a OS sabe seu total) — o caixa não toca a tabela da venda. Sem
   * `total`, reflete só o recebido (total=0). Acompanha as entries da venda.
   */
  async getSalePaymentDetail(
    _user: AuthUser,
    saleId: string,
    total?: number,
  ) {
    const { paid, entries } = await this.tenant.withTenantTx(async () => {
      const [paid, entries] = await Promise.all([
        this.repo.sumPaidForSale(saleId),
        this.repo.listEntriesForSale(saleId),
      ]);
      return { paid, entries };
    });
    return { ...buildPaymentSummary(total ?? 0, paid), entries };
  }

  /**
   * Cargo tem a permissão? (role/role_permission/permission são globais, sem RLS —
   * mesma consulta do PermissionsGuard). Usado para o gate fino de categorias
   * sensíveis dentro de `createEntry`.
   */
  private async hasPermission(role: string, perm: string): Promise<boolean> {
    const db = this.tenant.getClient();
    const rows = await db.$queryRaw<Array<{ key: string }>>`
      SELECT p.key FROM role r
      JOIN role_permission rp ON rp.role_id = r.id
      JOIN permission p ON p.id = rp.permission_id
      WHERE r.key = ${role} AND p.key = ${perm}
      LIMIT 1
    `;
    return rows.length > 0;
  }
}

// ===================== Helpers de forma (puros) =====================
type GroupRow = { direction: string; _sum: { amount: Prisma.Decimal | null } };

/** Agrupa linhas (method, direction) → [{ method, in, out }]. */
function shapeMethodTotals(
  rows: Array<GroupRow & { method: string }>,
): MethodTotals[] {
  const map = new Map<string, MethodTotals>();
  for (const r of rows) {
    const cur = map.get(r.method) ?? { method: r.method, in: 0, out: 0 };
    if (r.direction === 'in') cur.in = round2(cur.in + toNum(r._sum.amount));
    else cur.out = round2(cur.out + toNum(r._sum.amount));
    map.set(r.method, cur);
  }
  return [...map.values()];
}

/** Agrupa linhas (<key>, direction) → [{ key, in, out }] genérico. */
function shapeKeyedTotals<K extends string>(
  rows: Array<GroupRow & Record<K, string | null>>,
  key: K,
  nullLabel = 'nenhum',
): Array<{ key: string; in: number; out: number }> {
  const map = new Map<string, { key: string; in: number; out: number }>();
  for (const r of rows) {
    const k = (r[key] as string | null) ?? nullLabel;
    const cur = map.get(k) ?? { key: k, in: 0, out: 0 };
    if (r.direction === 'in') cur.in = round2(cur.in + toNum(r._sum.amount));
    else cur.out = round2(cur.out + toNum(r._sum.amount));
    map.set(k, cur);
  }
  return [...map.values()];
}

const pickCash = (rows: MethodTotals[]): { in: number; out: number } => {
  const cash = rows.find((r) => r.method === 'dinheiro');
  return { in: cash?.in ?? 0, out: cash?.out ?? 0 };
};

const pickAll = (rows: MethodTotals[]): { in: number; out: number } => {
  let i = 0;
  let o = 0;
  for (const r of rows) {
    i += r.in;
    o += r.out;
  }
  return { in: round2(i), out: round2(o) };
};
