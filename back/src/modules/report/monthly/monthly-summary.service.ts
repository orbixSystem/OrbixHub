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

/** Uma janela qualquer, com o dia inteiro nas duas pontas. */
export interface Janela {
  from: Date;
  to: Date;
  rotulo: string;
}

/**
 * A janela de um intervalo livre escolhido na tela.
 *
 * Quando o intervalo é exatamente um mês do calendário, o rótulo volta a ser
 * "Setembro/2026": é como o dono chama aquele período, e trocar por
 * "01/09 a 30/09" só porque o caminho até ali foi outro tornaria o mesmo mês
 * irreconhecível de uma tela para a outra.
 */
export function janelaDoIntervalo(de: Date, ate: Date): Janela {
  const from = new Date(
    Date.UTC(de.getUTCFullYear(), de.getUTCMonth(), de.getUTCDate()),
  );
  const to = new Date(
    Date.UTC(
      ate.getUTCFullYear(),
      ate.getUTCMonth(),
      ate.getUTCDate(),
      23,
      59,
      59,
      999,
    ),
  );
  const mes = janelaDoMes(from);
  const ehMesInteiro =
    from.getTime() === mes.from.getTime() && to.getTime() === mes.to.getTime();
  return {
    from,
    to,
    rotulo: ehMesInteiro ? mes.rotulo : `${diaMes(from)} a ${diaMes(to)}`,
  };
}

/**
 * O período de comparação: o intervalo imediatamente anterior, de mesma
 * duração.
 *
 * Para um mês do calendário isso é o mês anterior — e é por isso que o caminho
 * especial existe: fevereiro comparado com "os 28 dias anteriores" pegaria
 * três dias de dezembro, e a frase "contra o mês anterior" deixaria de ser
 * verdade sem nada na tela avisando.
 */
export function janelaAnterior(janela: Janela): Janela {
  const mes = janelaDoMes(janela.from);
  if (
    janela.from.getTime() === mes.from.getTime() &&
    janela.to.getTime() === mes.to.getTime()
  ) {
    return janelaDoMes(mesAnterior(janela.from));
  }
  const duracao = janela.to.getTime() - janela.from.getTime();
  const to = new Date(janela.from.getTime() - 1);
  const from = new Date(to.getTime() - duracao);
  return { from, to, rotulo: `${diaMes(from)} a ${diaMes(to)}` };
}

const diaMes = (d: Date): string =>
  `${String(d.getUTCDate()).padStart(2, '0')}/${String(d.getUTCMonth() + 1).padStart(2, '0')}`;

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
    return this.calcularDaJanela(tenantId, janelaDoMes(ref));
  }

  /**
   * A mesma visão, para um período QUALQUER escolhido na tela.
   *
   * A régua de comparação é o período imediatamente anterior de mesma duração
   * — e, quando o período é um mês do calendário, o mês anterior. Sem isso,
   * "subiu 17%" ficaria comparando sete dias com trinta e a tela mentiria com
   * ar de precisão.
   */
  async calcularDaJanela(
    tenantId: string,
    atual: Janela,
  ): Promise<{ metricas: MetricasMensais; graficos: GraficosDoMes }> {
    const anterior = janelaAnterior(atual);

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

/**
 * O que vai para o modelo: tudo JÁ ESCRITO em português.
 *
 * Formatar é calcular — separador de milhar, centavos, o "R$", "subiu" ou
 * "caiu" são decisões que um modelo erra em silêncio. Com o texto pronto, ele
 * copia; e um relatório que diria "faturou 48200" passa a dizer
 * "faturou R$ 48.200,00", que é como alguém com oficina escreve.
 */
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
      valor: k.formato === 'dinheiro' ? dinheiro(k.valor) : inteiro(k.valor),
      variacao: k.variacao === null ? null : movimento(k.variacao.pct),
      variacaoBoa:
        k.variacao === null || k.variacao.pct === 0
          ? null
          : k.variacao.pct > 0
            ? k.maiorEhMelhor
            : !k.maiorEhMelhor,
    })),
    sinais: m.sinais.map((s) => ({
      chave: s.chave,
      severidade: s.severidade,
      titulo: s.titulo,
      detalhe: s.detalhe,
      numeros: numerosEscritos(s.numeros),
    })),
  };
}

const dinheiro = (v: number): string =>
  v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });

const inteiro = (v: number): string => v.toLocaleString('pt-BR');

const porcento = (v: number): string =>
  `${Math.abs(v).toLocaleString('pt-BR', { maximumFractionDigits: 1 })}%`;

const movimento = (pct: number): string =>
  pct === 0 ? 'ficou igual' : `${pct > 0 ? 'subiu' : 'caiu'} ${porcento(pct)}`;

/**
 * Os números do sinal, escritos — e com rótulo em português.
 *
 * As chaves cruas (`pctFiado`, `aReceberAnterior`) são nomes de programador: o
 * modelo acabaria repetindo-as no texto, e "o pctFiado foi de 310" não é
 * português.
 */
function numerosEscritos(n: Record<string, number>): Record<string, string> {
  const rotulos: Record<string, [string, 'dinheiro' | 'pct' | 'inteiro']> = {
    recebido: ['Entrou no caixa', 'dinheiro'],
    saiu: ['Saiu do caixa', 'dinheiro'],
    resultado: ['Resultado do caixa', 'dinheiro'],
    aReceber: ['A receber', 'dinheiro'],
    aReceberAnterior: ['A receber no mês anterior', 'dinheiro'],
    vencido: ['Já vencido', 'dinheiro'],
    pctVencido: ['Parte vencida', 'pct'],
    despesas: ['Despesas', 'dinheiro'],
    despesasAnterior: ['Despesas no mês anterior', 'dinheiro'],
    pctDespesa: ['Alta das despesas', 'pct'],
    pctFiado: ['Alta do fiado', 'pct'],
    pctFaturado: ['Alta do faturamento', 'pct'],
    ticket: ['Ticket médio', 'dinheiro'],
    ticketAnterior: ['Ticket médio anterior', 'dinheiro'],
    pct: ['Variação', 'pct'],
    canceladas: ['Ordens canceladas', 'inteiro'],
    concluidas: ['Ordens concluídas', 'inteiro'],
    itens: ['Itens', 'inteiro'],
    valorEstoque: ['Valor em estoque', 'dinheiro'],
    faturado: ['Faturamento', 'dinheiro'],
    osConcluidas: ['Ordens concluídas', 'inteiro'],
  };
  const out: Record<string, string> = {};
  for (const [chave, valor] of Object.entries(n)) {
    const [rotulo, tipo] = rotulos[chave] ?? [chave, 'inteiro'];
    out[rotulo] =
      tipo === 'dinheiro'
        ? dinheiro(valor)
        : tipo === 'pct'
          ? porcento(valor)
          : inteiro(valor);
  }
  return out;
}
