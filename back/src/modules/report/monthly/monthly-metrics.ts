/**
 * Regra PURA da leitura de um período: os números e **o que merece atenção**.
 *
 * Nasceu mensal e continua servindo ao resumo escrito, que é de mês fechado.
 * Mas a tela passou a oferecer qualquer período — últimos 7 dias, um intervalo
 * do calendário —, e a régua de comparação virou "o período anterior de mesma
 * duração". Por isso os textos daqui falam em PERÍODO: dizer "mês anterior"
 * numa leitura de sete dias seria uma frase errada com ar de precisão.
 *
 * É aqui que mora a inteligência do recurso — não no prompt. O modelo de
 * linguagem recebe o resultado desta função e só escreve o texto; ele não
 * decide o que é problema nem produz cifra alguma. Duas razões:
 *
 * 1. um relatório financeiro com número alucinado queima o recurso na primeira
 *    leitura, e não há como recuperar a confiança depois;
 * 2. a decisão de "isto merece atenção" precisa ser a MESMA todo mês. Se
 *    morasse no texto, dois meses iguais sairiam com leituras diferentes e
 *    ninguém poderia conferir nada.
 *
 * Sem Nest, sem banco, sem rede: dá para cobrir caso a caso, inclusive os de
 * borda (oficina nova, mês parado) que são justamente os que produzem relatório
 * constrangedor quando ninguém olha.
 */

/** Os agregados de um mês, já calculados pelos módulos donos dos dados. */
export interface NumerosDoMes {
  /** OS faturadas + vendas avulsas no período. */
  faturado: number;
  /** Nº de OS + vendas — denominador do ticket médio. */
  transacoes: number;
  /** Entrou no caixa. */
  recebido: number;
  /** Saiu do caixa. */
  saiu: number;
  /** Despesas do mês, pelo VENCIMENTO. */
  despesas: number;
  despesasPorCategoria: Array<{ categoria: string; total: number }>;
  /**
   * Saldo em aberto AGORA — a foto do fiado, não um fato do mês.
   *
   * Por ser uma foto, não serve para comparar dois meses: o mês passado não
   * tem um "saldo de então" que a gente consiga reconstruir.
   */
  aReceber: number;
  /** Parte do `aReceber` já vencida. */
  aReceberVencido: number;
  /**
   * Quanto do que foi vendido NAQUELE mês continua em aberto.
   *
   * Este sim é um fato do mês, e é o que permite comparar: "em agosto ficaram
   * R$ 1.700 anotados; em setembro, R$ 7.100". Sem ele o alerta de fiado
   * crescendo nunca dispararia — o saldo do mês anterior chegaria sempre zero,
   * e a regra (corretamente) se recusa a calcular variação a partir de zero.
   */
  fiadoDoMes: number;
  osConcluidas: number;
  osCanceladas: number;
  osAbertas: number;
  clientesNovos: number;
  clientesAtendidos: number;
  estoqueValor: number;
  estoqueAbaixoMinimo: number;
}

export interface Periodo {
  de: string;
  ate: string;
  /** "Setembro/2026" — o rótulo que aparece na tela e no texto. */
  rotulo: string;
}

export interface Variacao {
  anterior: number;
  /** Diferença percentual, uma casa decimal. */
  pct: number;
}

export interface Kpi {
  chave: string;
  rotulo: string;
  valor: number;
  formato: 'dinheiro' | 'numero';
  /** `null` quando não há com o que comparar — nunca um número inventado. */
  variacao: Variacao | null;
  /**
   * Subir é bom? Receita subindo é verde; despesa e fiado subindo são
   * vermelhos. Sem isto toda seta vira enfeite — e a tela comemoraria
   * justamente o que o dono precisa cortar.
   */
  maiorEhMelhor: boolean;
}

export type Severidade = 'critico' | 'alerta' | 'info';

export interface Sinal {
  chave: string;
  severidade: Severidade;
  titulo: string;
  detalhe: string;
  /**
   * Os números que sustentam o sinal. O texto do modelo é escrito EM CIMA
   * deles; sinal sem número seria convite a inventar a cifra que falta.
   */
  numeros: Record<string, number>;
}

export interface MetricasMensais {
  periodo: Periodo;
  kpis: Kpi[];
  sinais: Sinal[];
}

export interface EntradaMensal {
  periodo: Periodo;
  mes: NumerosDoMes;
  /** `null` no primeiro mês de uso. */
  anterior: NumerosDoMes | null;
}

const umaCasa = (v: number): number => Math.round(v * 10) / 10;
const centavos = (v: number): number => Math.round(v * 100) / 100;

/**
 * Variação percentual entre dois valores.
 *
 * `null` quando não há base de comparação. Sair de zero não é "crescimento de
 * 100%" nem de infinito: é a primeira vez que o número existe, e dizer qualquer
 * percentual ali seria inventar.
 */
export function variacao(atual: number, anterior: number): Variacao | null {
  if (anterior === 0) return null;
  return { anterior, pct: umaCasa(((atual - anterior) / Math.abs(anterior)) * 100) };
}

const ticketDe = (n: NumerosDoMes): number =>
  n.transacoes > 0 ? centavos(n.faturado / n.transacoes) : 0;

/** O mês teve movimento de verdade? */
const houveMovimento = (n: NumerosDoMes): boolean =>
  n.faturado > 0 ||
  n.recebido > 0 ||
  n.despesas > 0 ||
  n.transacoes > 0 ||
  n.osConcluidas > 0 ||
  n.osAbertas > 0;

/**
 * Pisos de relevância. Existem para o resumo não gritar por troco: sem eles,
 * um fiado que foi de R$ 50 para R$ 200 vira "+300%" e o dono aprende, em dois
 * meses, a ignorar os alertas — que é o pior desfecho possível para a feature.
 */
const PISO_FIADO = 1000;
const QUEDA_TICKET = 10; // %
const CANCELAMENTO_ACEITAVEL = 0.15;
const VENCIDO_PREOCUPANTE = 0.4;

export function calcularMetricasMensais(e: EntradaMensal): MetricasMensais {
  const { mes, anterior, periodo } = e;

  const kpi = (
    chave: string,
    rotulo: string,
    valor: number,
    formato: Kpi['formato'],
    maiorEhMelhor: boolean,
    valorAnterior: number | null,
  ): Kpi => ({
    chave,
    rotulo,
    valor: centavos(valor),
    formato,
    maiorEhMelhor,
    variacao: valorAnterior === null ? null : variacao(centavos(valor), centavos(valorAnterior)),
  });

  const a = anterior;
  const kpis: Kpi[] = [
    kpi('faturado', 'Faturamento', mes.faturado, 'dinheiro', true, a?.faturado ?? null),
    kpi('recebido', 'Entrou no caixa', mes.recebido, 'dinheiro', true, a?.recebido ?? null),
    kpi('despesas', 'Despesas', mes.despesas, 'dinheiro', false, a?.despesas ?? null),
    kpi(
      'resultado',
      'Resultado do caixa',
      mes.recebido - mes.saiu,
      'dinheiro',
      true,
      a ? a.recebido - a.saiu : null,
    ),
    kpi('aReceber', 'A receber', mes.aReceber, 'dinheiro', false, a?.aReceber ?? null),
    kpi('ticket', 'Ticket médio', ticketDe(mes), 'dinheiro', true, a ? ticketDe(a) : null),
    kpi('osConcluidas', 'OS concluídas', mes.osConcluidas, 'numero', true, a?.osConcluidas ?? null),
    kpi('clientesNovos', 'Clientes novos', mes.clientesNovos, 'numero', true, a?.clientesNovos ?? null),
  ];

  return { periodo, kpis, sinais: detectarSinais(mes, anterior) };
}

/**
 * Os sinais do mês, do mais grave para o menos.
 *
 * Cada um é uma pergunta que o dono faria se tivesse tempo de olhar os números
 * — e que ninguém faz, porque olhar nove relatórios não cabe na semana.
 */
function detectarSinais(mes: NumerosDoMes, anterior: NumerosDoMes | null): Sinal[] {
  // Mês parado (férias, tenant que não usou o sistema) tem UMA coisa a dizer.
  // Sem este desvio, o resumo sairia narrando quedas de 100% em tudo —
  // tecnicamente certo e completamente inútil.
  if (!houveMovimento(mes)) {
    return [
      {
        chave: 'sem_movimento',
        severidade: 'info',
        titulo: 'Mês sem movimento registrado',
        detalhe:
          'Não houve faturamento, recebimento nem ordens de serviço no período. '
          + 'Se a oficina trabalhou, o registro não chegou ao sistema.',
        numeros: { faturado: 0, recebido: 0, osConcluidas: 0 },
      },
    ];
  }

  const sinais: Sinal[] = [];
  const resultado = centavos(mes.recebido - mes.saiu);

  if (resultado < 0) {
    sinais.push({
      chave: 'resultado_negativo',
      severidade: 'critico',
      titulo: 'Saiu mais dinheiro do que entrou',
      detalhe:
        'O caixa fechou o mês negativo: o que foi pago superou o que foi recebido.',
      numeros: { recebido: mes.recebido, saiu: mes.saiu, resultado },
    });
  }

  if (mes.aReceber > PISO_FIADO && mes.aReceberVencido / mes.aReceber > VENCIDO_PREOCUPANTE) {
    sinais.push({
      chave: 'vencido_alto',
      severidade: 'critico',
      titulo: 'A maior parte do que há para receber já venceu',
      detalhe:
        'Dívida vencida não envelhece bem: quanto mais tempo passa, menor a '
        + 'chance de entrar.',
      numeros: {
        aReceber: mes.aReceber,
        vencido: mes.aReceberVencido,
        pctVencido: umaCasa((mes.aReceberVencido / mes.aReceber) * 100),
      },
    });
  }

  if (anterior) {
    const cresceuFaturado = variacao(mes.faturado, anterior.faturado);
    // Compara o fiado GERADO em cada mês, não o saldo de hoje: o saldo é uma
    // foto do agora e o mês passado não tem uma foto própria.
    const cresceuFiado = variacao(mes.fiadoDoMes, anterior.fiadoDoMes);

    // Faturar sem receber é o jeito mais comum de uma oficina quebrar vendendo
    // bem — e é invisível num relatório de faturamento.
    if (
      cresceuFiado &&
      mes.fiadoDoMes > PISO_FIADO &&
      cresceuFiado.pct > (cresceuFaturado?.pct ?? 0) &&
      cresceuFiado.pct > 0
    ) {
      sinais.push({
        chave: 'fiado_crescendo',
        severidade: 'alerta',
        titulo: 'O fiado cresceu mais que o faturamento',
        detalhe:
          'Parte do crescimento do período ainda não virou dinheiro em caixa.',
        numeros: {
          fiadoDoMes: mes.fiadoDoMes,
          fiadoDoMesAnterior: anterior.fiadoDoMes,
          pctFiado: cresceuFiado.pct,
          pctFaturado: cresceuFaturado?.pct ?? 0,
        },
      });
    }

    const cresceuDespesa = variacao(mes.despesas, anterior.despesas);
    if (
      cresceuDespesa &&
      cresceuDespesa.pct > 0 &&
      cresceuDespesa.pct > (cresceuFaturado?.pct ?? 0)
    ) {
      sinais.push({
        chave: 'despesa_subindo',
        severidade: 'alerta',
        titulo: 'As despesas subiram mais que o faturamento',
        detalhe:
          'O custo de operar cresceu acima do que a oficina produziu no período.',
        numeros: {
          despesas: mes.despesas,
          despesasAnterior: anterior.despesas,
          pctDespesa: cresceuDespesa.pct,
          pctFaturado: cresceuFaturado?.pct ?? 0,
        },
      });
    }

    const ticket = ticketDe(mes);
    const ticketAnterior = ticketDe(anterior);
    const cresceuTicket = variacao(ticket, ticketAnterior);
    if (cresceuTicket && cresceuTicket.pct <= -QUEDA_TICKET) {
      sinais.push({
        chave: 'ticket_caindo',
        severidade: 'alerta',
        titulo: 'O ticket médio caiu',
        detalhe:
          'Cada atendimento rendeu menos que no período anterior — mesmo volume '
          + 'não significa mesma receita.',
        numeros: { ticket, ticketAnterior, pct: cresceuTicket.pct },
      });
    }
  }

  const encerradas = mes.osConcluidas + mes.osCanceladas;
  if (encerradas > 0 && mes.osCanceladas / encerradas > CANCELAMENTO_ACEITAVEL) {
    sinais.push({
      chave: 'cancelamento_alto',
      severidade: 'alerta',
      titulo: 'Muitas ordens canceladas',
      detalhe:
        'Serviço que começa e não termina consome tempo de bancada sem virar '
        + 'receita.',
      numeros: {
        canceladas: mes.osCanceladas,
        concluidas: mes.osConcluidas,
        pct: umaCasa((mes.osCanceladas / encerradas) * 100),
      },
    });
  }

  if (mes.estoqueAbaixoMinimo > 0) {
    sinais.push({
      chave: 'estoque_abaixo_minimo',
      severidade: 'info',
      titulo: `${mes.estoqueAbaixoMinimo} ${
        mes.estoqueAbaixoMinimo === 1 ? 'item abaixo' : 'itens abaixo'
      } do mínimo`,
      detalhe: 'Peça que falta na hora do serviço vira OS parada esperando compra.',
      numeros: { itens: mes.estoqueAbaixoMinimo, valorEstoque: mes.estoqueValor },
    });
  }

  const ordem: Record<Severidade, number> = { critico: 0, alerta: 1, info: 2 };
  return sinais.sort((x, y) => ordem[x.severidade] - ordem[y.severidade]);
}
