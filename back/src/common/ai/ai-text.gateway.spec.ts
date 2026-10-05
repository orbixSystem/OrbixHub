import { ResumoPayload } from './ai-text.gateway';
import { interpretar } from './gemini-text.gateway';
import { NoopAiGateway, montarNarrativa } from './noop-ai.gateway';

/**
 * O resumo mensal não pode depender de um provedor estar de pé.
 *
 * Estes testes fixam as duas pontas disso: o texto determinístico é bom o
 * bastante para ser o piso do produto, e qualquer resposta estranha do modelo
 * cai nele em vez de virar relatório pela metade.
 */

const payload: ResumoPayload = {
  empresa: 'Oficina do Zé',
  periodo: 'Setembro/2026',
  objeto: 'Veículo',
  // Já escritos: é assim que chegam ao modelo, porque formatar é calcular.
  kpis: [
    {
      rotulo: 'Faturamento',
      valor: 'R\$ 55.000,00',
      variacao: 'subiu 12%',
      variacaoBoa: true,
    },
    {
      rotulo: 'Entrou no caixa',
      valor: 'R\$ 41.000,00',
      variacao: 'subiu 8%',
      variacaoBoa: true,
    },
    {
      rotulo: 'Resultado do caixa',
      valor: 'R\$ 9.800,00',
      variacao: 'caiu 4%',
      variacaoBoa: false,
    },
  ],
  sinais: [
    {
      chave: 'fiado_crescendo',
      severidade: 'alerta',
      titulo: 'O fiado cresceu mais que o faturamento',
      detalhe: 'Parte do crescimento do mês ainda não virou dinheiro em caixa.',
      numeros: {
        'A receber': 'R\$ 15.000,00',
        'Alta do fiado': '200%',
        'Alta do faturamento': '12%',
      },
    },
  ],
};

describe('resumo sem IA (o piso do produto)', () => {
  it('escreve um texto completo a partir dos sinais', async () => {
    const { narrativa, status, modelo } = await new NoopAiGateway().gerarResumo(
      payload,
    );

    expect(status).toBe('fallback');
    expect(modelo).toBe('resumo-automatico');
    expect(narrativa.titulo).toContain('Setembro/2026');
    expect(narrativa.leitura).toContain('R$');
    // Um alerta por sinal e uma ação concreta — não "acompanhe seus
    // indicadores", que ensina o leitor a pular a seção.
    expect(narrativa.alertas).toHaveLength(1);
    expect(narrativa.recomendacoes[0]).toContain('Combine prazo');
  });

  it('usa apenas números que vieram no payload', () => {
    // A mesma trava que vale para o modelo vale aqui: o texto é montado EM CIMA
    // dos valores recebidos, nunca de uma conta feita na hora.
    const n = montarNarrativa(payload);
    const texto = [n.titulo, n.leitura, ...n.alertas].join(' ');
    expect(texto).toContain('R\$ 55.000,00');
    expect(texto).toContain('subiu 12%');
  });

  it('mês sem movimento tem um texto próprio, não uma lista de quedas', async () => {
    const parado: ResumoPayload = {
      ...payload,
      kpis: payload.kpis.map((k) => ({
        ...k,
        valor: 'R\$ 0,00',
        variacao: 'caiu 100%',
      })),
      sinais: [
        {
          chave: 'sem_movimento',
          severidade: 'info',
          titulo: 'Mês sem movimento registrado',
          detalhe: 'Não houve faturamento no período.',
          numeros: { Faturamento: 'R\$ 0,00' },
        },
      ],
    };
    const { narrativa } = await new NoopAiGateway().gerarResumo(parado);

    expect(narrativa.titulo).toContain('sem movimento');
    expect(narrativa.recomendacoes[0]).toContain('Confira');
  });

  it('mês saudável não inventa alerta nem recomendação vazia', () => {
    const n = montarNarrativa({ ...payload, sinais: [] });
    expect(n.alertas).toHaveLength(0);
    expect(n.leitura).toContain('sem sinais de alerta');
    expect(n.recomendacoes).toHaveLength(1);
  });
});

describe('leitura da resposta do modelo', () => {
  it('aceita a resposta no formato esperado', () => {
    const n = interpretar(
      JSON.stringify({
        titulo: 'Setembro fechou acima de agosto',
        leitura: 'O mês cresceu, mas o crescimento foi fiado.',
        alertas: ['O fiado cresceu mais que o faturamento.'],
        recomendacoes: ['Combine prazo na hora de fiar.'],
      }),
    );
    expect(n?.titulo).toBe('Setembro fechou acima de agosto');
    expect(n?.alertas).toHaveLength(1);
  });

  it('recusa JSON quebrado', () => {
    expect(interpretar('{"titulo": "oi"')).toBeNull();
  });

  it('recusa resposta vazia', () => {
    expect(interpretar('')).toBeNull();
    expect(interpretar('   ')).toBeNull();
  });

  it('recusa resposta sem título ou sem leitura', () => {
    // Meio resumo é pior que o resumo automático: o leitor não sabe que falta
    // alguma coisa.
    expect(interpretar(JSON.stringify({ titulo: 'x' }))).toBeNull();
    expect(interpretar(JSON.stringify({ leitura: 'x' }))).toBeNull();
  });

  it('limpa itens vazios das listas em vez de mostrar marcador em branco', () => {
    const n = interpretar(
      JSON.stringify({
        titulo: 't',
        leitura: 'l',
        alertas: ['um', '', '   ', 'dois'],
        recomendacoes: [],
      }),
    );
    expect(n?.alertas).toEqual(['um', 'dois']);
    expect(n?.recomendacoes).toEqual([]);
  });

  it('não explode com tipos estranhos no lugar das listas', () => {
    const n = interpretar(
      JSON.stringify({ titulo: 't', leitura: 'l', alertas: 'nao e lista' }),
    );
    expect(n?.alertas).toEqual([]);
  });
});

/**
 * As seções que tornam o resumo um RELATÓRIO, e não um parágrafo.
 *
 * Elas existem porque um texto corrido é lido uma vez e esquecido: o dono
 * precisa conseguir voltar à página e achar, sem reler, qual número mudou, o
 * que sustentou o mês e o que pode estragar o próximo.
 */
describe('as seções do relatório', () => {
  it('destaca os números que MUDARAM, começando pelos que pioraram', () => {
    const { destaques } = montarNarrativa(payload);

    expect(destaques.length).toBeGreaterThanOrEqual(2);
    // "Resultado do caixa" caiu: é o que custa dinheiro, e vem primeiro.
    expect(destaques[0].kpi).toBe('Resultado do caixa');
    // O comentário NÃO repete a cifra: ela aparece ao lado, vinda do KPI.
    expect(destaques.every((d) => !d.comentario.includes('R$'))).toBe(true);
  });

  it('separa o que foi bem do que preocupa', () => {
    const n = montarNarrativa(payload);

    expect(n.oQueFoiBem.join(' ')).toContain('Faturamento');
    expect(n.oQuePreocupa).toContain('O fiado cresceu mais que o faturamento');
    expect(n.fechamento).not.toBe('');
  });

  it('mês sem nada a elogiar não inventa elogio', () => {
    const ruim: ResumoPayload = {
      ...payload,
      kpis: payload.kpis.map((k) => ({ ...k, variacaoBoa: false })),
    };

    expect(montarNarrativa(ruim).oQueFoiBem).toEqual([]);
  });

  it('destaque que aponta para um KPI inexistente é descartado', () => {
    // A trava que impede o modelo de produzir número também impede que ele
    // aponte para um número que não existe: sem a peneira, um rótulo inventado
    // chegaria à tela como um destaque vazio.
    const resposta = JSON.stringify({
      titulo: 'Setembro fechou acima',
      leitura: 'O mês foi bom.',
      destaques: [
        { kpi: 'Faturamento', comentario: 'Cresceu com consistência.' },
        { kpi: 'Lucro operacional', comentario: 'Número que ninguém enviou.' },
      ],
      oQueFoiBem: ['Faturamento em alta'],
      oQuePreocupa: [],
      alertas: [],
      recomendacoes: ['Cobrar os atrasados'],
      fechamento: 'Seguir no ritmo.',
    });

    const n = interpretar(resposta, payload);

    expect(n?.destaques).toEqual([
      { kpi: 'Faturamento', comentario: 'Cresceu com consistência.' },
    ]);
  });

  it('sem o payload para conferir, os destaques passam como vieram', () => {
    // O parser é usado em teste e em produção; sem payload ele não tem como
    // peneirar, e recusar tudo seria pior do que confiar.
    const resposta = JSON.stringify({
      titulo: 'T',
      leitura: 'L',
      destaques: [{ kpi: 'Qualquer', comentario: 'C' }],
      alertas: [],
      recomendacoes: [],
    });

    expect(interpretar(resposta)?.destaques).toHaveLength(1);
  });
});
