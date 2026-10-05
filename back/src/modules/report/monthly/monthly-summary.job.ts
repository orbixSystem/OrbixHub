import {
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ENV } from '../../../common/config/config.module';
import { Env } from '../../../common/config/env.schema';
import { PrismaService } from '../../../common/database/prisma.service';
import {
  MonthlySummaryService,
  inicioDoMes,
  mesAnterior,
} from './monthly-summary.service';
import { MonthlySummaryNotifier } from './monthly-summary.notifier';

/**
 * O resumo do mês que acabou, entregue nos primeiros dias do mês que começa.
 *
 * **É uma esteira, não um disparo único.** A faixa gratuita do provedor de IA
 * é de 20 requisições por DIA: numa base com 31 oficinas, um job que gerasse
 * tudo no dia 1º deixaria as 11 últimas com o texto automático para sempre — e
 * ninguém notaria, porque o resumo chegaria assim mesmo. Então ele roda do dia
 * 1 ao 7, atende só quem ainda não tem o resumo daquele mês e para quando
 * gasta o orçamento do dia. Em dois ou três dias todo mundo tem o texto
 * escrito, dentro da cota.
 *
 * O efeito colateral bom: a esteira é auto-reparável. Tenant que falhou hoje
 * entra amanhã sem ninguém mexer em nada.
 *
 * Quem já tem resumo — inclusive o automático — NÃO é refeito. Reescrever
 * amanhã o texto que o dono pode ter lido hoje faria o relatório mudar
 * sozinho, que é exatamente o que a gravação existe para impedir.
 *
 * Roda às 4h: depois do corte de trial (0h), da esteira de recorrência (2h) e
 * da limpeza (3h). Às 4h o mês anterior já está fechado para todos eles, e um
 * tenant cortado à meia-noite não recebe no mesmo laço um e-mail animado sobre
 * o mês passado.
 *
 * Um tenant problemático não impede os outros — mesma regra do
 * `ExpenseRecurrenceJob`.
 */
@Injectable()
export class MonthlySummaryJob {
  private readonly logger = new Logger(MonthlySummaryJob.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly summary: MonthlySummaryService,
    private readonly notifier: MonthlySummaryNotifier,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Do dia 1 ao 7, às 4h — a esteira roda até todo mundo ser atendido. */
  @Cron('0 4 1-7 * *')
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
    const periodo = inicioDoMes(ref);
    // Varredura entre tenants via SECURITY DEFINER: aqui ainda não há tenant no
    // contexto, e a RLS bloquearia o `app_user`. Devolve só ponteiros, e só de
    // quem AINDA não tem o resumo deste mês.
    const pendentes = await this.prisma.$queryRaw<
      Array<{ tenant_id: string; tenant_name: string }>
    >`SELECT tenant_id, tenant_name FROM report_find_tenants_missing_monthly_summary(${periodo}::date)`;

    if (pendentes.length === 0) return { gerados: 0, falhas: 0 };

    // O orçamento do dia. O que sobrar fica para amanhã — a esteira roda de
    // novo e pega de onde parou.
    const tenants = pendentes.slice(0, this.env.GEMINI_ORCAMENTO_DIARIO);
    const adiados = pendentes.length - tenants.length;
    this.logger.log(
      `Gerando o resumo mensal de ${tenants.length} oficina(s)` +
        (adiados > 0 ? ` — ${adiados} ficam para amanhã (orçamento do dia).` : '.'),
    );

    let gerados = 0;
    let falhas = 0;
    for (const [indice, t] of tenants.entries()) {
      // Respiro entre oficinas. A cota do provedor é por MINUTO e este laço
      // dispara uma chamada por tenant: sem pausa, da décima em diante tudo
      // vira 429 e todo mundo recebe o texto automático — foi exatamente o que
      // aconteceu no primeiro teste com 31 oficinas.
      //
      // Roda às 4h da manhã: gastar alguns minutos aqui não custa nada a
      // ninguém, e é a diferença entre um texto escrito e um texto montado.
      if (indice > 0 && this.env.GEMINI_INTERVALO_MS > 0) {
        await new Promise((r) => setTimeout(r, this.env.GEMINI_INTERVALO_MS));
      }
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

  /**
   * Gera o resumo do mês anterior a [agora] para UMA oficina.
   *
   * A esteira atende por ordem alfabética e com orçamento diário: numa base
   * com mil tenants, uma oficina específica pode levar semanas para ser
   * alcançada — e não há como verificar o texto dela antes disso. Este caminho
   * existe para isso, atrás do token administrativo, e passa exatamente pelos
   * mesmos passos (gerar, gravar, avisar) para não virar um segundo caminho
   * que diverge do primeiro no primeiro ajuste.
   */
  async gerarParaUm(
    tenantId: string,
    agora: Date,
  ): Promise<{ gerados: number; falhas: number }> {
    const ref = mesAnterior(agora);
    const [tenant] = await this.prisma.$queryRaw<Array<{ name: string }>>`
      SELECT name FROM tenant WHERE id = ${tenantId}::uuid
    `;
    if (!tenant) throw new NotFoundException('Oficina não encontrada.');

    try {
      const resumo = await this.summary.gerarParaTenant(tenantId, ref, tenant.name);
      await this.notifier.avisar(tenantId, resumo).catch((e: unknown) => {
        this.logger.warn(
          `Resumo de ${tenantId} gerado, mas o aviso falhou: ${msg(e)}`,
        );
      });
      return { gerados: 1, falhas: 0 };
    } catch (e) {
      this.logger.warn(`Falha ao gerar o resumo de ${tenantId}: ${msg(e)}`);
      return { gerados: 0, falhas: 1 };
    }
  }
}

const msg = (e: unknown): string => (e instanceof Error ? e.message : String(e));
