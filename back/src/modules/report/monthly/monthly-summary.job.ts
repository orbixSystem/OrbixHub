import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../../common/database/prisma.service';
import { MonthlySummaryService, mesAnterior } from './monthly-summary.service';
import { MonthlySummaryNotifier } from './monthly-summary.notifier';

/**
 * O resumo do mês que acabou, no primeiro dia do mês que começa.
 *
 * Roda às 4h: depois do corte de trial (0h), da esteira de recorrência (2h) e
 * da limpeza (3h). Não é superstição — às 4h o mês anterior já está fechado
 * para todos eles, e um tenant cortado à meia-noite não recebe, no mesmo laço,
 * um e-mail animado sobre o mês passado.
 *
 * Um tenant problemático (dado estranho, módulo removido no meio do caminho)
 * não pode impedir os outros de receberem o seu — mesma regra do
 * `ExpenseRecurrenceJob`.
 */
@Injectable()
export class MonthlySummaryJob {
  private readonly logger = new Logger(MonthlySummaryJob.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly summary: MonthlySummaryService,
    private readonly notifier: MonthlySummaryNotifier,
  ) {}

  /** Dia 1º, 4h da manhã. */
  @Cron('0 4 1 * *')
  async run(): Promise<void> {
    await this.gerarParaTodos(new Date());
  }

  /**
   * Gera o resumo do mês ANTERIOR a [agora] para todos os tenants elegíveis.
   *
   * Separado do `@Cron` para que o gatilho administrativo e os testes possam
   * chamar o mesmo caminho — um job que só roda por relógio é um job que
   * ninguém consegue verificar.
   */
  async gerarParaTodos(agora: Date): Promise<{ gerados: number; falhas: number }> {
    const ref = mesAnterior(agora);
    // Varredura entre tenants via SECURITY DEFINER: aqui ainda não há tenant no
    // contexto, e a RLS bloquearia o `app_user`. Devolve só ponteiros.
    const tenants = await this.prisma.$queryRaw<
      Array<{ tenant_id: string; tenant_name: string }>
    >`SELECT tenant_id, tenant_name FROM report_find_tenants_for_monthly_summary()`;

    if (tenants.length === 0) return { gerados: 0, falhas: 0 };
    this.logger.log(`Gerando o resumo mensal de ${tenants.length} oficina(s).`);

    let gerados = 0;
    let falhas = 0;
    for (const t of tenants) {
      try {
        const resumo = await this.summary.gerarParaTenant(
          t.tenant_id,
          ref,
          t.tenant_name,
        );
        // Avisar é parte da entrega, mas não da geração: um e-mail que falha
        // não pode fazer o resumo (já gravado) contar como falha e ser
        // regerado — seria outra chamada paga pelo mesmo mês.
        await this.notifier.avisar(t.tenant_id, resumo).catch((e: unknown) => {
          this.logger.warn(
            `Resumo de ${t.tenant_id} gerado, mas o aviso falhou: ${msg(e)}`,
          );
        });
        gerados++;
      } catch (e) {
        falhas++;
        this.logger.warn(
          `Falha ao gerar o resumo de ${t.tenant_id}: ${msg(e)}`,
        );
      }
    }
    if (falhas > 0) {
      this.logger.warn(`${falhas} resumo(s) não puderam ser gerados.`);
    }
    return { gerados, falhas };
  }
}

const msg = (e: unknown): string => (e instanceof Error ? e.message : String(e));
