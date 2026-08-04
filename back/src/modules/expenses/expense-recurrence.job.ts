import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { TenantContext } from '../../common/database/tenant-context';
import { ExpensesRepository } from './expenses.repository';
import { ExpensesService } from './expenses.service';

/**
 * Faz a esteira de recorrência andar.
 *
 * A criação de uma regra já materializa 12 meses; sem este job a janela ficaria
 * parada e, um ano depois, o aluguel simplesmente sumiria do calendário. Aqui a
 * janela caminha um pouco por dia.
 *
 * Roda às 2h — depois da meia-noite do `TrialExpiryJob`, para que um tenant que
 * acabou de cair em `past_due` não tenha contas geradas no mesmo instante em que
 * perdeu o acesso de escrita.
 */
@Injectable()
export class ExpenseRecurrenceJob {
  private readonly logger = new Logger(ExpenseRecurrenceJob.name);

  constructor(
    private readonly repo: ExpensesRepository,
    private readonly service: ExpensesService,
    private readonly tenant: TenantContext,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_2AM)
  async run(): Promise<void> {
    const horizonte = ExpensesService.horizonteDaEsteira();
    // Varredura entre tenants via SECURITY DEFINER (a RLS bloquearia o app_user
    // sem tenant no CLS); devolve só ponteiros.
    const pendentes = await this.repo.findRecurrencesToExtendGlobal(horizonte);
    if (pendentes.length === 0) return;

    this.logger.log(`Estendendo ${pendentes.length} recorrência(s) de despesa`);
    let falhas = 0;
    for (const { tenant_id, recurrence_id } of pendentes) {
      try {
        // A partir daqui tudo volta a passar pela RLS: `runWithTenant` põe o
        // tenant no contexto e a policy vale normalmente.
        await this.tenant.runWithTenant(tenant_id, () =>
          this.service.estenderRegra(tenant_id, recurrence_id),
        );
      } catch (e) {
        // Uma regra problemática (categoria removida, dados estranhos) não pode
        // impedir os outros tenants de terem as contas geradas.
        falhas++;
        this.logger.warn(
          `Falha ao estender a recorrência ${recurrence_id}: ${
            e instanceof Error ? e.message : String(e)
          }`,
        );
      }
    }
    if (falhas > 0) {
      this.logger.warn(`${falhas} recorrência(s) não puderam ser estendidas`);
    }
  }
}
