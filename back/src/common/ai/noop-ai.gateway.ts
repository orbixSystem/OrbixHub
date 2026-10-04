import { Injectable } from '@nestjs/common';
import {
  AiTextGateway,
  Narrativa,
  ResultadoNarrativa,
  ResumoPayload,
} from './ai-text.gateway';

// Os valores já chegam escritos ("R$ 48.200,00"): aqui só se costura frase.
/**
 * O resumo SEM IA — e é ele que roda quando não há chave, quando a API está
 * fora, quando estoura o timeout ou quando a resposta volta imprestável.
 *
 * Não é um placeholder: é o piso do produto. A regra pura já decidiu o que
 * aconteceu e o que merece atenção; aqui esse material só é costurado em
 * frases. Um dono que nunca souber que existe IA no meio ainda recebe um
 * relatório que se lê.
 *
 * É também o que impede o recurso de virar refém de um provedor: se amanhã o
 * Gemini sair do ar ou ficar caro, o resumo mensal continua chegando.
 */
@Injectable()
export class NoopAiGateway implements AiTextGateway {
  gerarResumo(payload: ResumoPayload): Promise<ResultadoNarrativa> {
    return Promise.resolve({
      narrativa: montarNarrativa(payload),
      status: 'fallback',
      modelo: 'resumo-automatico',
    });
  }
}

/** Exportada porque o gateway do Gemini a usa como rede de segurança. */
export function montarNarrativa(payload: ResumoPayload): Narrativa {
  const porRotulo = new Map(payload.kpis.map((k) => [k.rotulo, k]));
  const faturado = porRotulo.get('Faturamento');
  const recebido = porRotulo.get('Entrou no caixa');
  const resultado = porRotulo.get('Resultado do caixa');

  const parado = payload.sinais.some((s) => s.chave === 'sem_movimento');
  if (parado) {
    return {
      titulo: `${payload.periodo} sem movimento registrado`,
      leitura:
        'Não houve faturamento, recebimento nem ordens de serviço no período. '
        + 'Se a oficina trabalhou neste mês, os registros não chegaram ao sistema.',
      alertas: ['Nenhum lançamento no período.'],
      recomendacoes: [
        'Confira se as ordens de serviço e os recebimentos do mês foram registrados.',
      ],
    };
  }

  const frases: string[] = [];
  if (faturado) {
    frases.push(
      faturado.variacao
        ? `O faturamento de ${payload.periodo} foi de ${faturado.valor}, e ${faturado.variacao} em relação ao mês anterior.`
        : `O faturamento de ${payload.periodo} foi de ${faturado.valor}.`,
    );
  }
  if (recebido && resultado) {
    frases.push(
      `Entraram ${recebido.valor} no caixa e o resultado do mês ficou em ${resultado.valor}.`,
    );
  }
  const criticos = payload.sinais.filter((s) => s.severidade === 'critico');
  frases.push(
    criticos.length > 0
      ? 'Há pontos que pedem atenção imediata, listados abaixo.'
      : payload.sinais.length > 0
        ? 'O mês não registrou problemas graves, mas alguns pontos merecem olhada.'
        : 'O mês transcorreu sem sinais de alerta nos números.',
  );

  return {
    titulo: tituloDoMes(payload, faturado),
    leitura: frases.join(' '),
    alertas: payload.sinais.map((s) => `${s.titulo}. ${s.detalhe}`),
    recomendacoes: recomendacoesPara(payload),
  };
}

function tituloDoMes(
  payload: ResumoPayload,
  faturado: ResumoPayload['kpis'][number] | undefined,
): string {
  const v = faturado?.variacao;
  if (!v) return `Resumo de ${payload.periodo}`;
  if (v.startsWith('subiu')) {
    return `${payload.periodo} fechou acima do mês anterior: o faturamento ${v}`;
  }
  if (v.startsWith('caiu')) {
    return `${payload.periodo} fechou abaixo do mês anterior: o faturamento ${v}`;
  }
  return `${payload.periodo} repetiu o mês anterior`;
}

/**
 * Uma recomendação por sinal — a ação que aquele sinal pede. São fixas de
 * propósito: recomendação genérica ("acompanhe seus indicadores") é pior que
 * nenhuma, porque ensina o leitor a pular a seção.
 */
const ACOES: Record<string, string> = {
  resultado_negativo:
    'Reveja as despesas do mês e priorize a cobrança do que está em aberto — o caixa fechou negativo.',
  vencido_alto:
    'Separe uma tarde para cobrar os títulos vencidos, começando pelos mais antigos.',
  fiado_crescendo:
    'Combine prazo de pagamento na hora de fiar: sem data, a dívida não entra em nenhuma fila de cobrança.',
  despesa_subindo:
    'Abra as despesas por categoria e confira o que cresceu acima do normal.',
  ticket_caindo:
    'Verifique se serviços estão saindo sem peças ou com desconto maior que o habitual.',
  cancelamento_alto:
    'Olhe as ordens canceladas do mês e identifique o motivo mais comum.',
  estoque_abaixo_minimo:
    'Reponha os itens abaixo do mínimo antes que uma OS pare esperando peça.',
};

function recomendacoesPara(payload: ResumoPayload): string[] {
  const acoes = payload.sinais
    .map((s) => ACOES[s.chave])
    .filter((a): a is string => Boolean(a))
    .slice(0, 3);
  if (acoes.length > 0) return acoes;
  return [
    'Mantenha o registro das ordens e dos recebimentos em dia — é o que faz este relatório valer.',
  ];
}
