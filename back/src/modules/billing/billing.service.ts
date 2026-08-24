import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingRepository, type SubscriptionStatus } from './billing.repository';
import { PAYMENT_GATEWAY, PaymentGateway } from './payment/payment-gateway';

export interface PlanView {
  key: string;
  name: string;
  priceCents: number;
  billingPeriod: string;
  modules: string[];
}
/** Acesso a um módulo para um tenant: entitlement + status da assinatura. */
export interface ModuleAccessView {
  /** Status da assinatura (`trialing`/`active`/`past_due`/`canceled`). */
  status: string;
  /** O módulo está habilitado para o tenant (`tenant_module.enabled`). */
  enabled: boolean;
  /** Módulo de núcleo: ignora o flag `enabled` (mas respeita o status). */
  isCore: boolean;
}
/** A mesma assinatura, com o que o painel administrativo precisa mostrar. */
export interface AssinaturaDetalhada extends SubscriptionView {
  planName: string;
  planPriceCents: number;
  billingPeriod: string;
}

export interface SubscriptionView {
  planKey: string;
  status: string;
  trialEndsAt: Date | null;
  currentPeriodStart: Date | null;
  currentPeriodEnd: Date | null;
  canceledAt: Date | null;
}

@Injectable()
export class BillingService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: BillingRepository,
    @Inject(ENV) private readonly env: Env,
    private readonly audit: AuditService,
    @Inject(PAYMENT_GATEWAY) private readonly gateway: PaymentGateway,
  ) {}

  /**
   * Trial bootstrap called by register INSIDE its tx (caller wraps via
   * tenant.bindTx). Uses getClient() so the insert + reconcile are atomic with
   * tenant/user/membership creation.
   */
  async createTrial(tenantId: string): Promise<void> {
    const plan = await this.repo.findPlanByKey(this.env.TRIAL_PLAN_KEY);
    if (!plan) throw new Error(`TRIAL_PLAN_KEY "${this.env.TRIAL_PLAN_KEY}" not found`);
    const db = this.tenant.getClient();
    await db.subscription.create({
      data: {
        tenant_id: tenantId,
        plan_id: plan.id,
        status: 'trialing',
        trial_ends_at: new Date(Date.now() + this.env.TRIAL_DAYS * 86_400_000),
      },
    });
    await this.repo.reconcile(tenantId, plan.id);
  }

  /** Plans for the catalog endpoint (excludes the internal trial plan). */
  async getPlans(): Promise<PlanView[]> {
    const plans = await this.repo.listActivePlansWithModules();
    return plans
      .filter((p) => p.key !== this.env.TRIAL_PLAN_KEY)
      .map((p) => ({
        key: p.key,
        name: p.name,
        priceCents: p.price_cents,
        billingPeriod: p.billing_period,
        modules: p.plan_module.map((pm) => pm.module.key),
      }));
  }

  async getSubscription(): Promise<SubscriptionView | null> {
    return this.tenant.withTenantTx(async () => {
      const sub = await this.repo.getSubscription();
      if (!sub) return null;
      return {
        planKey: sub.plan.key,
        status: sub.status,
        trialEndsAt: sub.trial_ends_at,
        currentPeriodStart: sub.current_period_start,
        currentPeriodEnd: sub.current_period_end,
        canceledAt: sub.canceled_at,
      };
    });
  }

  /**
   * Assinatura de UM tenant, por id — para o painel da Orbix, que não tem
   * contexto de request de tenant. Traz o plano junto porque a pergunta do
   * atendente é sempre "qual plano, quanto custa e até quando está pago".
   */
  async assinaturaDoTenant(tenantId: string): Promise<AssinaturaDetalhada | null> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const sub = await this.repo.getSubscription();
      if (!sub) return null;
      return {
        planKey: sub.plan.key,
        planName: sub.plan.name,
        planPriceCents: sub.plan.price_cents,
        billingPeriod: sub.plan.billing_period,
        status: sub.status,
        trialEndsAt: sub.trial_ends_at,
        currentPeriodStart: sub.current_period_start,
        currentPeriodEnd: sub.current_period_end,
        canceledAt: sub.canceled_at,
      };
    });
  }

  /**
   * Ajuste manual da assinatura, feito pela Orbix no painel administrativo.
   *
   * Existe para o que a cobrança automática ainda não cobre: estender um teste
   * que acabou, dar prazo a quem prometeu pagar amanhã, encerrar um contrato.
   * Enquanto o Mercado Pago não estiver integrado, é o único jeito de mexer
   * nessas datas sem SQL na mão em produção.
   *
   * A situação se ajusta sozinha quando a data volta a fazer sentido: estender
   * o teste de quem já tinha caído devolve `trialing`, e dar prazo novo a um
   * inadimplente devolve `active`. Sem isso, editar a data não destravava nada
   * — o acesso é decidido pelo STATUS, e ele tinha ficado para trás.
   */
  async ajustarAssinatura(
    tenantId: string,
    ajuste: {
      trialEndsAt?: Date | null;
      accessEndsAt?: Date | null;
      status?: SubscriptionStatus;
    },
  ): Promise<AssinaturaDetalhada | null> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const atual = await this.repo.getSubscription();
      if (!atual) throw new NotFoundException('Este ambiente não tem assinatura.');

      const agora = new Date();
      const futuro = (d?: Date | null) => d instanceof Date && d > agora;

      let status = ajuste.status ?? (atual.status as SubscriptionStatus);
      if (!ajuste.status) {
        if (futuro(ajuste.trialEndsAt)) status = 'trialing';
        else if (futuro(ajuste.accessEndsAt) && atual.status === 'past_due') {
          status = 'active';
        }
      }

      const salvo = await this.repo.ajustarAssinatura({
        status,
        ...(ajuste.trialEndsAt !== undefined ? { trial_ends_at: ajuste.trialEndsAt } : {}),
        ...(ajuste.accessEndsAt !== undefined
          ? { current_period_end: ajuste.accessEndsAt }
          : {}),
      });
      if (!salvo) return null;

      await this.audit.log(tenantId, null, 'subscription_change', 'ajuste_manual', {
        por: 'orbix-admin',
        de: {
          status: atual.status,
          trialEndsAt: atual.trial_ends_at,
          accessEndsAt: atual.current_period_end,
        },
        para: {
          status: salvo.status,
          trialEndsAt: salvo.trial_ends_at,
          accessEndsAt: salvo.current_period_end,
        },
      });

      return {
        planKey: salvo.plan.key,
        planName: salvo.plan.name,
        planPriceCents: salvo.plan.price_cents,
        billingPeriod: salvo.plan.billing_period,
        status: salvo.status,
        trialEndsAt: salvo.trial_ends_at,
        currentPeriodStart: salvo.current_period_start,
        currentPeriodEnd: salvo.current_period_end,
        canceledAt: salvo.canceled_at,
      };
    });
  }

  /** Enabled module keys for a server-resolved tenant. Used by /me and the guard path. */
  async getEnabledModules(tenantId: string): Promise<string[]> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const tms = await db.tenant_module.findMany({
        where: { enabled: true },
        include: { module: true },
      });
      return tms.map((tm) => tm.module.key);
    });
  }

  /**
   * Acesso a UM módulo (mesma régua do `ModuleAccessGuard`), resolvido pelo dono
   * da tabela `tenant_module` — quem não é o billing pergunta AQUI, nunca lê a
   * tabela ("aponta, não invade"). Usado pelo `/sync/*`, que não pode usar o
   * `@RequiresModule` (uma rota, N entidades de módulos diferentes).
   */
  async getModuleAccess(
    tenantId: string,
    moduleKey: string,
  ): Promise<ModuleAccessView> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const sub = await db.subscription.findFirst();
      const tm = await db.tenant_module.findFirst({
        where: { module: { key: moduleKey } },
        include: { module: true },
      });
      return {
        status: sub?.status ?? 'canceled',
        enabled: tm?.enabled ?? false,
        isCore: tm?.module?.is_core ?? false,
      };
    });
  }

  /**
   * Status da assinatura de um tenant explícito. Billing é dono de
   * `subscription`; quem precisa do status (a API administrativa, por exemplo)
   * pergunta por aqui em vez de ler a tabela.
   */
  async getSubscriptionStatus(tenantId: string): Promise<string | null> {
    const sub = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.getSubscription(),
    );
    return sub?.status ?? null;
  }

  /** Catálogo de módulos com o estado do tenant (para a tela de configuração). */
  listTenantModules(tenantId: string) {
    return this.tenant.runWithTenant(tenantId, () => this.repo.listTenantModules());
  }

  /**
   * Liga/desliga um módulo por decisão do dono. Grava `source='manual'`, que é
   * o que faz a escolha sobreviver à próxima troca de plano — ver o comentário
   * no repositório. Núcleo (`is_core`) não é desligável: ele sustenta o resto.
   */
  async setModuleEnabled(
    tenantId: string,
    // `null` quando quem mexeu não é usuário DESTE tenant (painel da Orbix).
    // `audit_log.actor_user_id` referencia `users`: passar o id do tenant aqui
    // violava a FK e o toggle gravava e devolvia 500 — meio aplicado.
    actorUserId: string | null,
    moduleKey: string,
    enabled: boolean,
  ): Promise<void> {
    const info = await this.getModuleAccess(tenantId, moduleKey);
    if (info.isCore && !enabled) {
      throw new BadRequestException('Módulo de núcleo não pode ser desativado.');
    }
    const ok = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.setModuleEnabled(tenantId, moduleKey, enabled),
    );
    if (!ok) throw new BadRequestException(`Módulo desconhecido: ${moduleKey}`);
    await this.audit.log(tenantId, actorUserId, 'module_toggle', moduleKey, {
      enabled,
    });
  }

  /**
   * Settings JSONB de um módulo (em `tenant_module.settings`). Billing é dono da
   * tabela `tenant_module` — outros módulos leem/escrevem a própria config por
   * aqui, nunca tocando a tabela ("aponta, não invade"). Retorna {} se o módulo
   * não estiver provisionado para o tenant.
   */
  async getModuleSettings(
    tenantId: string,
    moduleKey: string,
  ): Promise<Record<string, unknown>> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const tm = await db.tenant_module.findFirst({
        where: { module: { key: moduleKey } },
      });
      return (tm?.settings as Record<string, unknown> | null) ?? {};
    });
  }

  /**
   * Persiste o JSONB de settings de um módulo. Só atualiza linhas existentes
   * (provisionadas pelo reconcile do plano) — não cria entitlement por aqui.
   */
  async setModuleSettings(
    tenantId: string,
    moduleKey: string,
    settings: Record<string, unknown>,
  ): Promise<void> {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const tm = await db.tenant_module.findFirst({
        where: { module: { key: moduleKey } },
      });
      if (!tm) return;
      await db.tenant_module.update({
        where: {
          tenant_id_module_id: {
            tenant_id: tm.tenant_id,
            module_id: tm.module_id,
          },
        },
        data: { settings: settings as never },
      });
    });
  }

  async subscribe(tenantId: string, actorUserId: string, planKey: string): Promise<SubscriptionView> {
    const plan = await this.assertSubscribablePlan(planKey);

    if (this.env.BILLING_REQUIRE_PAYMENT) {
      // Gateway call FIRST, OUTSIDE any DB tx. Status stays authoritative via webhook.
      const checkout = await this.gateway.createCheckout({
        tenantId,
        planKey: plan.key,
        priceCents: plan.price_cents,
      });
      await this.tenant.runWithTenant(tenantId, () =>
        this.repo.upsertSubscription(tenantId, plan.id, {
          status: 'trialing', // pending until webhook confirms 'active'
          external_subscription_id: checkout.externalSubscriptionId,
        }),
      );
      // Module enablement (reconcile) is deferred to the webhook that confirms 'active'.
    } else {
      const now = new Date();
      await this.tenant.runWithTenant(tenantId, async () => {
        await this.repo.upsertSubscription(tenantId, plan.id, {
          status: 'active',
          current_period_start: now,
          current_period_end: new Date(now.getTime() + 30 * 86_400_000),
          canceled_at: null,
        });
        await this.repo.reconcile(tenantId, plan.id);
      });
    }
    await this.audit.log(tenantId, actorUserId, 'subscription_change', 'subscribe', {
      planKey: plan.key,
    });
    return this.subscriptionView(tenantId);
  }

  async changePlan(tenantId: string, actorUserId: string, planKey: string): Promise<SubscriptionView> {
    const plan = await this.assertSubscribablePlan(planKey);
    await this.tenant.runWithTenant(tenantId, async () => {
      await this.repo.upsertSubscription(tenantId, plan.id, { status: 'active' });
      await this.repo.reconcile(tenantId, plan.id);
    });
    await this.audit.log(tenantId, actorUserId, 'subscription_change', 'change-plan', {
      planKey: plan.key,
    });
    return this.subscriptionView(tenantId);
  }

  /**
   * Idempotent, signature-verified webhook handler.
   * Order: verify sig -> dedupe -> resolve tenant by external id -> update under
   * that tenant's context -> audit -> mark processed. NEVER trusts a tenant id
   * from the payload.
   */
  async processWebhook(rawBody: Buffer | string, signature: string | undefined): Promise<void> {
    if (!this.gateway.verifySignature(rawBody, signature)) {
      throw new BadRequestException('Invalid webhook signature');
    }
    const payload = JSON.parse(rawBody.toString()) as {
      id: string;
      type: string;
      data?: { subscriptionId?: string; currentPeriodStart?: string; currentPeriodEnd?: string };
    };

    let eventRow: { id: string };
    try {
      eventRow = await this.repo.insertWebhookEvent(payload.id, payload.type, payload as never);
    } catch (e) {
      if ((e as { code?: string }).code !== 'P2002') throw e;
      // Duplicate delivery. If a prior attempt inserted the row but failed before
      // finishing (processed_at still null), re-drive processing so the update is
      // not lost. If it was already processed, this is a true no-op.
      const existing = await this.repo.findWebhookEventByExternalId(payload.id);
      if (!existing || existing.processed_at) return;
      eventRow = { id: existing.id };
    }

    const externalSubId = payload.data?.subscriptionId;
    const status = this.statusFromEventType(payload.type);
    if (externalSubId && status) {
      const tenantId = await this.repo.resolveTenantBySubscription(externalSubId);
      if (tenantId) {
        await this.tenant.runWithTenant(tenantId, () =>
          this.repo.updateSubscriptionStatus({
            status,
            current_period_start: payload.data?.currentPeriodStart
              ? new Date(payload.data.currentPeriodStart)
              : undefined,
            current_period_end: payload.data?.currentPeriodEnd
              ? new Date(payload.data.currentPeriodEnd)
              : undefined,
            canceled_at: status === 'canceled' ? new Date() : null,
          }),
        );
        await this.audit.log(tenantId, null, 'subscription_change', 'webhook', {
          type: payload.type,
          externalSubscriptionId: externalSubId,
        });
      }
    }
    await this.repo.markWebhookProcessed(eventRow.id);
  }

  private statusFromEventType(
    type: string,
  ): 'trialing' | 'active' | 'past_due' | 'canceled' | null {
    switch (type) {
      case 'subscription.active':
        return 'active';
      case 'subscription.past_due':
        return 'past_due';
      case 'subscription.canceled':
        return 'canceled';
      case 'subscription.trialing':
        return 'trialing';
      default:
        return null;
    }
  }

  private async assertSubscribablePlan(planKey: string) {
    const plan = await this.repo.findPlanByKey(planKey);
    if (!plan || plan.key === this.env.TRIAL_PLAN_KEY) {
      throw new BadRequestException(`Invalid plan: ${planKey}`);
    }
    return plan;
  }

  private async subscriptionView(tenantId: string): Promise<SubscriptionView> {
    const sub = await this.tenant.runWithTenant(tenantId, () => this.repo.getSubscription());
    if (!sub) throw new Error('subscription not found immediately after write');
    return {
      planKey: sub.plan.key,
      status: sub.status,
      trialEndsAt: sub.trial_ends_at,
      currentPeriodStart: sub.current_period_start,
      currentPeriodEnd: sub.current_period_end,
      canceledAt: sub.canceled_at,
    };
  }
}
