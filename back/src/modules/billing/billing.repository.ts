import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';

export type SubscriptionStatus = 'trialing' | 'active' | 'past_due' | 'canceled';

@Injectable()
export class BillingRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  // ---- global catalog reads (no RLS) ----
  listActivePlansWithModules() {
    return this.prisma.plan.findMany({
      include: { plan_module: { include: { module: true } } },
      orderBy: { price_cents: 'asc' },
    });
  }
  findPlanByKey(key: string) {
    return this.prisma.plan.findUnique({ where: { key } });
  }

  // ---- tenant-scoped (RLS) — caller MUST be inside a tenant tx ----
  getSubscription() {
    const db = this.tenant.getClient();
    return db.subscription.findFirst({ include: { plan: true } });
  }

  async upsertSubscription(
    tenantId: string,
    planId: string,
    data: {
      status: SubscriptionStatus;
      trial_ends_at?: Date | null;
      current_period_start?: Date | null;
      current_period_end?: Date | null;
      canceled_at?: Date | null;
      external_subscription_id?: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    return db.subscription.upsert({
      where: { tenant_id: tenantId },
      create: { tenant_id: tenantId, plan_id: planId, ...data },
      update: { plan_id: planId, updated_at: new Date(), ...data },
    });
  }

  async updateSubscriptionStatus(
    data: {
      status: SubscriptionStatus;
      current_period_start?: Date | null;
      current_period_end?: Date | null;
      canceled_at?: Date | null;
    },
  ) {
    const db = this.tenant.getClient();
    const sub = await db.subscription.findFirst();
    if (!sub) return null;
    return db.subscription.update({
      where: { id: sub.id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /**
   * Derive tenant_module from a plan. Idempotent. Assumes an active tenant tx.
   * - plan modules + is_core modules -> enabled=true (source 'plan' on create)
   * - existing source='addon'|'manual' rows are NEVER touched
   * - plan-sourced rows no longer in the plan (and not core) -> enabled=false
   *   (settings preserved — only the `enabled` flag changes)
   */
  async reconcile(tenantId: string, planId: string): Promise<void> {
    const db = this.tenant.getClient();

    const [planMods, coreMods, existing] = await Promise.all([
      db.plan_module.findMany({ where: { plan_id: planId } }),
      db.module.findMany({ where: { is_core: true } }),
      db.tenant_module.findMany(),
    ]);

    const target = new Set<string>([
      ...planMods.map((m) => m.module_id),
      ...coreMods.map((m) => m.id),
    ]);
    const bySource = new Map(
      existing.map((r) => [r.module_id, r.source] as const),
    );

    // Enable every target module (skip addon/manual rows — leave them as-is).
    for (const moduleId of target) {
      const src = bySource.get(moduleId);
      if (src && src !== 'plan') continue;
      await db.tenant_module.upsert({
        where: { tenant_id_module_id: { tenant_id: tenantId, module_id: moduleId } },
        create: { tenant_id: tenantId, module_id: moduleId, enabled: true, source: 'plan' },
        update: { enabled: true },
      });
    }

    // Disable plan-sourced modules that left the plan and aren't core.
    const toDisable = existing
      .filter((r) => r.source === 'plan' && !target.has(r.module_id))
      .map((r) => r.module_id);
    if (toDisable.length > 0) {
      await db.tenant_module.updateMany({
        where: { tenant_id: tenantId, module_id: { in: toDisable } },
        data: { enabled: false },
      });
    }
  }

  /**
   * Todos os módulos do catálogo com o estado no tenant — alimenta a tela
   * "Módulos e funcionalidades". Módulo nunca provisionado aparece como
   * desabilitado, e não some da lista: o dono precisa ver o que existe.
   *
   * APOSENTADO (`retired_at`) é a exceção: some. Toggle de um módulo sem rota
   * nem tela não é informação, é armadilha — quem clicasse religaria algo que
   * a 0046 desligou de propósito.
   */
  async listTenantModules(): Promise<
    Array<{ key: string; name: string; enabled: boolean; isCore: boolean; source: string | null }>
  > {
    const db = this.tenant.getClient();
    const [mods, tms] = await Promise.all([
      db.module.findMany({ where: { retired_at: null }, orderBy: { name: 'asc' } }),
      db.tenant_module.findMany(),
    ]);
    const byModuleId = new Map(tms.map((t) => [t.module_id, t] as const));
    return mods.map((m) => {
      const tm = byModuleId.get(m.id);
      return {
        key: m.key,
        name: m.name,
        enabled: m.is_core ? true : (tm?.enabled ?? false),
        isCore: m.is_core,
        source: tm?.source ?? null,
      };
    });
  }

  /**
   * Liga/desliga um módulo POR DECISÃO DO DONO — e grava `source='manual'`.
   *
   * Essa marca é o que faz a escolha SOBREVIVER: o `reconcile` acima pula
   * linhas com `source !== 'plan'`. Sem ela, a linha ficava como 'plan' e a
   * próxima troca de plano a religava (`update: { enabled: true }`) — era
   * exatamente o bug de "módulo desativado continua aparecendo na sidebar".
   *
   * Devolve false se a chave não existe no catálogo (o service vira 400).
   */
  async setModuleEnabled(
    tenantId: string,
    moduleKey: string,
    enabled: boolean,
  ): Promise<boolean> {
    const db = this.tenant.getClient();
    // Aposentado conta como inexistente para LIGAR — desligar continua valendo,
    // porque pode haver linha antiga ligada de antes da aposentadoria.
    const mod = await db.module.findFirst({
      where: enabled ? { key: moduleKey, retired_at: null } : { key: moduleKey },
    });
    if (!mod) return false;
    await db.tenant_module.upsert({
      where: { tenant_id_module_id: { tenant_id: tenantId, module_id: mod.id } },
      create: { tenant_id: tenantId, module_id: mod.id, enabled, source: 'manual' },
      update: { enabled, source: 'manual' },
    });
    return true;
  }

  // ---- platform table (no RLS) — webhook idempotency ----
  insertWebhookEvent(externalEventId: string, type: string, payload: Prisma.InputJsonValue) {
    return this.prisma.billing_webhook_event.create({
      data: { external_event_id: externalEventId, type, payload },
    });
  }
  markWebhookProcessed(id: string) {
    return this.prisma.billing_webhook_event.update({
      where: { id },
      data: { processed_at: new Date() },
    });
  }
  findWebhookEventByExternalId(externalEventId: string) {
    return this.prisma.billing_webhook_event.findUnique({
      where: { external_event_id: externalEventId },
    });
  }

  // ---- controlled SECURITY DEFINER resolvers (no JWT context) ----
  async resolveTenantBySubscription(externalSubscriptionId: string): Promise<string | null> {
    const rows = await this.prisma.$queryRaw<Array<{ tenant_id: string }>>`
      SELECT billing_resolve_tenant_by_subscription(${externalSubscriptionId}) AS tenant_id
    `;
    return rows[0]?.tenant_id ?? null;
  }
  findExpiredTrials() {
    return this.prisma.$queryRaw<Array<{ tenant_id: string; subscription_id: string }>>`
      SELECT tenant_id, subscription_id FROM billing_find_expired_trials()
    `;
  }
}
