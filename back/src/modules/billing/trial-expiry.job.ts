import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingRepository } from './billing.repository';
import { CobrancaMailService } from './cobranca-mail.service';

/** O texto que o cliente lê quando foi o RELÓGIO que bloqueou, não uma pessoa. */
export const MOTIVO_VENCIMENTO =
  'Acesso vencido — pagamento não identificado.';
export const MOTIVO_CARENCIA =
  'Acesso vencido há mais de 3 dias — pagamento não identificado.';

/** Quantos dias antes do vencimento o aviso sai. */
export const DIAS_DE_AVISO = 15;

/**
 * O que vence, todo dia à meia-noite, em duas etapas.
 *
 * 1. Teste acabado ou acesso fora do prazo → `past_due`: continua vendo o que
 *    é dele, não escreve mais. Cancelar já no dia do vencimento tiraria do
 *    cliente até a consulta ao próprio histórico por causa de um boleto
 *    atrasado.
 * 2. Passada a carência (`BILLING_GRACE_DAYS`) sem pagar → `canceled`: fecha
 *    até o pagamento. Sem esta etapa, "somente leitura" virava um estado
 *    permanente e confortável para quem simplesmente parou de pagar.
 */
@Injectable()
export class TrialExpiryJob {
  private readonly logger = new Logger(TrialExpiryJob.name);

  constructor(
    private readonly repo: BillingRepository,
    private readonly tenant: TenantContext,
    private readonly audit: AuditService,
    private readonly correio: CobrancaMailService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async run(): Promise<void> {
    // Sem cobrança de verdade, marcar past_due só produz tenant travado e uma
    // entrada de auditoria por dia. O status volta a mudar quando o módulo de
    // assinatura existir e `BILLING_ENFORCE_SUBSCRIPTION` for ligado.
    if (!this.env.BILLING_ENFORCE_SUBSCRIPTION) return;

    // O AVISO vem antes de tudo: quem vence hoje precisa ter sido avisado há
    // duas semanas, e rodar isto depois dos cortes faria o aviso sair para
    // quem já foi cortado no mesmo laço.
    await this.avisarQuemVaiVencer();

    await this.vencer(await this.repo.findExpiredTrials(), 'trial_expired', 'trial(s)');
    await this.vencer(
      await this.repo.findExpiredAccess(),
      'access_expired',
      'acesso(s) fora do prazo',
      'past_due',
      MOTIVO_VENCIMENTO,
    );

    // Depois dos dois, para que quem venceu HOJE entre na carência agora e só
    // seja cortado quando ela acabar — e não no mesmo laço.
    await this.vencer(
      await this.repo.findGraceExpired(this.env.BILLING_GRACE_DAYS),
      'grace_expired',
      `acesso(s) com carência de ${this.env.BILLING_GRACE_DAYS} dia(s) esgotada`,
      'canceled',
      MOTIVO_CARENCIA,
    );
  }

  private async vencer(
    vencidos: Array<{ tenant_id: string; subscription_id: string }>,
    causa: 'trial_expired' | 'access_expired' | 'grace_expired',
    rotulo: string,
    novoStatus: 'past_due' | 'canceled' = 'past_due',
    motivo = MOTIVO_VENCIMENTO,
  ): Promise<void> {
    if (vencidos.length === 0) return;
    this.logger.log(`Expiring ${vencidos.length} ${rotulo}`);

    for (const { tenant_id, subscription_id } of vencidos) {
      await this.tenant.runWithTenant(tenant_id, () =>
        this.repo.updateSubscriptionStatus({
          status: novoStatus,
          block_reason: motivo,
          blocked_at: new Date(),
        }),
      );
      await this.audit.log(tenant_id, null, 'subscription_change', causa, {
        subscriptionId: subscription_id,
        motivo,
      });
      // O e-mail é o ÚLTIMO passo e não derruba o laço: um SMTP fora do ar não
      // pode impedir que os outros tenants sejam processados, nem fazer o job
      // reprocessar amanhã quem já foi cortado hoje.
      await this.avisar(tenant_id, novoStatus, motivo);
    }
  }

  /** Quem vence em até [DIAS_DE_AVISO] dias e ainda não soube. */
  private async avisarQuemVaiVencer(): Promise<void> {
    const proximos = await this.repo.findVencimentoProximo(DIAS_DE_AVISO);
    if (proximos.length === 0) return;
    this.logger.log(`Avisando ${proximos.length} vencimento(s) próximo(s)`);

    for (const { tenant_id, vence_em } of proximos) {
      const dias = Math.ceil((vence_em.getTime() - Date.now()) / 86_400_000);
      const enviou = await this.correio.avisoDeVencimento(tenant_id, dias);
      // Só marca depois de SAIR. Marcar antes trocaria "avisei uma vez" por
      // "tentei uma vez", e o cliente perderia o aviso por causa de um SMTP
      // que piscou.
      if (enviou) {
        await this.tenant.runWithTenant(tenant_id, () =>
          this.repo.marcarAvisoEnviado(vence_em),
        );
      }
    }
  }

  private avisar(
    tenantId: string,
    status: 'past_due' | 'canceled',
    motivo: string,
  ): Promise<boolean> {
    return status === 'canceled'
      ? this.correio.acessoBloqueado(tenantId, motivo)
      : this.correio.acessoVencido(tenantId);
  }
}
