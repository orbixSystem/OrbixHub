import { Inject, Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  AI_TEXT_GATEWAY,
  AiTextGateway,
  ResumoPayload,
} from '../../../common/ai/ai-text.gateway';
import { TenantContext } from '../../../common/database/tenant-context';
import {
  GraficosDoMes,
  MonthlyAggregatesService,
} from './monthly-aggregates.service';
import { MonthlySummaryRepository, ResumoMensal } from './monthly-summary.repository';
import { calcularMetricasMensais, MetricasMensais } from './monthly-metrics';

const MESES = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/** Primeiro instante do mês de [ref], em UTC. */
export function inicioDoMes(ref: Date): Date {
  return new Date(Date.UTC(ref.getUTCFullYear(), ref.getUTCMonth(), 1));
}

/** A janela fechada do mês que contém [ref]: [1º 00:00, último dia 23:59:59.999]. */
export function janelaDoMes(ref: Date): { from: Date; to: Date; rotulo: string } {
  const from = inicioDoMes(ref);
  const to = new Date(
    Date.UTC(from.getUTCFullYear(), from.getUTCMonth() + 1, 0, 23, 59, 59, 999),
  );
  return {
    from,
    to,
    rotulo: `${MESES[from.getUTCMonth()]}/${from.getUTCFullYear()}`,
  };
}

/** O mês anterior ao de [ref]. */
export function mesAnterior(ref: Date): Date {
  const i = inicioDoMes(ref);
  return new Date(Date.UTC(i.getUTCFullYear(), i.getUTCMonth() - 1, 1));
}

/**
 * Monta o resumo de um mês: coleta → regra → texto → grava.
 *
 * A ordem importa e não é acidental: a chamada ao modelo acontece DEPOIS de
 * tudo que é banco e ANTES da escrita — nunca dentro de uma transação. Uma API
 * externa dentro de transação prende conexão do pool pelo tempo que o provedor
 * quiser demorar, e esta roda num laço por tenant.
 */
@Injectable()
export class MonthlySummaryService {
  private readonly logger = new Logger(MonthlySummaryService.name);

  constructor(
    private readonly agregados: MonthlyAggregatesService,
    private readonly repo: MonthlySummaryRepository,
    private readonly tenant: TenantContext,
    @Inject(AI_TEXT_GATEWAY) private readonly ia: AiTextGateway,
  ) {}

  /**
   * Gera (ou regera) o resumo do mês que contém [ref] para um tenant.
   *
   * Roda sob `runWithTenant`: a varredura entre tenants acontece fora da RLS,
   * mas tudo que lê ou escreve dado do cliente volta a passar por ela.
   */
  async gerarParaTenant(
    tenantId: string,
    ref: Date,
    empresa: string,
  ): Promise<ResumoMensal> {
    const metricas = await this.calcular(tenantId, ref);
    // FORA de qualquer transação: ver o comentário da classe.
    const { narrativa, status, modelo } = await this.ia.gerarResumo(
      paraPayload(empresa, metricas),
    );

    await this.tenant.runWithTenant(tenantId, () =>
      this.repo.salvar(tenantId, inicioDoMes(ref), {
        metrics: {
          periodo: metricas.periodo,
          kpis: metricas.kpis,
        } as unknown as Prisma.InputJsonValue,
        signals: metricas.sinais as unknown as Prisma.InputJsonValue,
        narrative: narrativa as unknown as Prisma.InputJsonValue,
        aiModel: modelo,
        aiStatus: status,
      }),
    );
    this.logger.log(
      `Resumo de ${metricas.periodo.rotulo} gerado para ${tenantId} (${status}).`,
    );

    return {
      period: inicioDoMes(ref).toISOString().slice(0, 10),
      periodo: metricas.periodo,
      kpis: metricas.kpis,
      sinais: metricas.sinais,
      narrativa,
      aiModel: modelo,
      aiStatus: status,
      generatedAt: new Date().toISOString(),
    };
  }

  /**
   * Os números do mês, sem IA e sem gravar — é o que a TELA consome.
   *
   * A mesma função alimenta a tela e o resumo de propósito: dois caminhos
   * calculando "o faturamento do mês" divergiriam no primeiro ajuste, e o
   * relatório passaria a discordar do texto que o acompanha.
   */
  async calcular(tenantId: string, ref: Date): Promise<MetricasMensais> {
    return (await this.calcularComGraficos(tenantId, ref)).metricas;
  }

  /** A visão completa da TELA: números, sinais e os dados dos gráficos. */
  async calcularComGraficos(
    tenantId: string,
    ref: Date,
  ): Promise<{ metricas: MetricasMensais; graficos: GraficosDoMes }> {
    const atual = janelaDoMes(ref);
    const anterior = janelaDoMes(mesAnterior(ref));

    const [doMes, mesAnteriorNumeros] = await this.tenant.runWithTenant(
      tenantId,
      async () => [
        await this.agregados.coletarComGraficos(tenantId, atual),
        // Sem o saldo de fiado: "a receber" é foto do agora, não do mês
        // passado. Comparar a foto de hoje com ela mesma daria variação zero e
        // esconderia justamente o sinal de fiado crescendo.
        await this.agregados.coletar(tenantId, anterior, {
          incluirSaldoAtual: false,
        }),
      ],
    );

    const metricas = calcularMetricasMensais({
      periodo: {
        de: atual.from.toISOString().slice(0, 10),
        ate: atual.to.toISOString().slice(0, 10),
        rotulo: atual.rotulo,
      },
      mes: doMes.numeros,
      anterior: mesAnteriorNumeros,
    });
    return { metricas, graficos: doMes.graficos };
  }
}

/** O que vai para o modelo: rótulos e números, sem nada que ele possa somar. */
export function paraPayload(
  empresa: string,
  m: MetricasMensais,
  objeto = 'Veículo',
): ResumoPayload {
  return {
    empresa,
    periodo: m.periodo.rotulo,
    objeto,
    kpis: m.kpis.map((k) => ({
      rotulo: k.rotulo,
      valor: k.valor,
      formato: k.formato,
      variacaoPct: k.variacao?.pct ?? null,
      maiorEhMelhor: k.maiorEhMelhor,
    })),
    sinais: m.sinais.map((s) => ({
      chave: s.chave,
      severidade: s.severidade,
      titulo: s.titulo,
      detalhe: s.detalhe,
      numeros: s.numeros,
    })),
  };
}
