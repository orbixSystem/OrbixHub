import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../config/config.module';
import { Env } from '../config/env.schema';
import {
  AiTextGateway,
  Narrativa,
  ResultadoNarrativa,
  ResumoPayload,
} from './ai-text.gateway';
import { montarNarrativa } from './noop-ai.gateway';

/**
 * Resumo mensal escrito pelo Gemini.
 *
 * Três decisões que não são detalhe:
 *
 * 1. **O modelo não produz número.** Ele recebe os KPIs e os sinais já
 *    calculados e só escreve em cima deles. O prompt proíbe inventar cifra, e o
 *    schema de saída não tem campo numérico onde uma caberia.
 * 2. **Nunca lança.** Chave ausente, API fora, timeout, cota estourada,
 *    resposta imprestável — tudo cai no texto determinístico do
 *    `montarNarrativa`. O resumo mensal é leitura: ele não pode faltar porque
 *    um provedor teve um dia ruim.
 * 3. **O id do modelo vem do env.** O catálogo do Google muda de nome e de
 *    faixa gratuita sem avisar; fixar um id no código é garantir uma quebra
 *    futura difícil de diagnosticar.
 */
@Injectable()
export class GeminiTextGateway implements AiTextGateway {
  private readonly logger = new Logger(GeminiTextGateway.name);

  constructor(@Inject(ENV) private readonly env: Env) {}

  async gerarResumo(payload: ResumoPayload): Promise<ResultadoNarrativa> {
    const chave = this.env.GEMINI_API_KEY;
    const modelo = this.env.GEMINI_MODEL;
    if (!chave) {
      // Sem chave não é erro: é o estado normal até alguém configurar.
      return { narrativa: montarNarrativa(payload), status: 'fallback', modelo: 'resumo-automatico' };
    }

    try {
      const texto = await this.chamarComRetentativa(chave, modelo, payload);
      const narrativa = interpretar(texto, payload);
      if (!narrativa) {
        this.logger.warn('Resposta do modelo sem o formato esperado; usando o resumo automático.');
        return { narrativa: montarNarrativa(payload), status: 'fallback', modelo: 'resumo-automatico' };
      }
      return { narrativa, status: 'ok', modelo };
    } catch (e) {
      this.logger.warn(
        `Falha ao gerar o resumo com IA (${e instanceof Error ? e.message : String(e)}); usando o resumo automático.`,
      );
      return { narrativa: montarNarrativa(payload), status: 'fallback', modelo: 'resumo-automatico' };
    }
  }

  /**
   * Tenta até três vezes quando o erro é PASSAGEIRO.
   *
   * 503 ("alta demanda") e 429 (cota de minuto) acontecem de verdade — vi os
   * dois numa tarde de testes. Sem retentativa, um pico de dez segundos no
   * provedor custa o texto do mês inteiro de uma oficina, que só seria
   * reescrito no mês seguinte.
   *
   * Erro de verdade (chave errada, modelo inexistente) não é retentado: repetir
   * não vai consertar, e três chamadas erradas demoram três vezes mais para
   * chegar ao fallback.
   */
  private async chamarComRetentativa(
    chave: string,
    modelo: string,
    payload: ResumoPayload,
  ): Promise<string> {
    const esperas = [1500, 5000];
    for (let tentativa = 0; ; tentativa++) {
      try {
        return await this.chamar(chave, modelo, payload);
      } catch (e) {
        const passageiro = e instanceof HttpStatusError && e.passageiro;
        if (!passageiro || tentativa >= esperas.length) throw e;
        this.logger.log(
          `Modelo indisponível (HTTP ${(e as HttpStatusError).status}); nova tentativa em ${esperas[tentativa]}ms.`,
        );
        await new Promise((r) => setTimeout(r, esperas[tentativa]));
      }
    }
  }

  private async chamar(
    chave: string,
    modelo: string,
    payload: ResumoPayload,
  ): Promise<string> {
    const url =
      `${this.env.GEMINI_BASE_URL}/v1beta/models/${encodeURIComponent(modelo)}:generateContent`;
    // Timeout curto: isto roda num laço por tenant, de madrugada. Um provedor
    // lento não pode segurar a fila dos outros — o fallback já está pronto.
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.env.GEMINI_TIMEOUT_MS);
    try {
      const res = await fetch(url, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'content-type': 'application/json',
          // Header, nunca query string: chave em URL vaza em log de proxy.
          'x-goog-api-key': chave,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: INSTRUCAO }] },
          contents: [{ role: 'user', parts: [{ text: JSON.stringify(payload) }] }],
          generationConfig: {
            temperature: 0.4,
            responseMimeType: 'application/json',
            responseSchema: SCHEMA,
          },
        }),
      });
      if (!res.ok) {
        throw new HttpStatusError(res.status);
      }
      const json = (await res.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      return json.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    } finally {
      clearTimeout(timer);
    }
  }
}

/** Erro HTTP do provedor, com a informação de que vale ou não tentar de novo. */
class HttpStatusError extends Error {
  constructor(readonly status: number) {
    super(`HTTP ${status}`);
  }

  /** 429 = cota por minuto; 503 = alta demanda; 500/502/504 = tropeço do lado de lá. */
  get passageiro(): boolean {
    return [429, 500, 502, 503, 504].includes(this.status);
  }
}

const INSTRUCAO = `Você escreve o relatório mensal de uma oficina para o dono dela, em português do Brasil.

Receberá um JSON com os números do mês e os sinais já apurados pelo sistema.

NÚMEROS
- Todo valor já vem ESCRITO ("R$ 48.200,00", "subiu 12,1%", "80"). Copie exatamente como está.
- Nunca calcule, estime, arredonde nem reescreva um número. Não transforme "R$ 48.200,00" em "48200" nem em "48,2 mil".
- Não cite nenhum número que não esteja no JSON.

O TÍTULO
- Diz o que ACONTECEU no mês, numa frase curta (até 12 palavras), como a manchete de uma notícia.
- Quando houver uma tensão nos números — cresceu mas no fiado, vendeu mais e sobrou menos — é ela que vira título.
- Nunca use o formato de rótulo ("Resumo de setembro", "Relatório mensal", "Análise do mês").

A LEITURA
- De 2 a 4 frases, contando o mês: o que entrou, o que saiu, o que sobrou e o que chama atenção.
- Escreva como quem conversa com um dono de oficina: direto, sem jargão. Nada de "insights", "KPIs", "performance", "sinergia", "otimizar".

DESTAQUES
- De 2 a 4 números que valem um comentário, escolhidos entre os KPIs recebidos.
- Em "kpi" vá o RÓTULO EXATO do KPI, copiado do JSON ("Faturamento", "Ticket médio"). Rótulo que não exista é descartado.
- Em "comentario", uma frase curta dizendo o que aquele número significa para a oficina. NÃO repita o valor: ele já aparece ao lado.
- Prefira os números que mudaram, para melhor ou para pior, aos que ficaram parados.

O QUE FOI BEM
- De 1 a 3 pontos que sustentaram o mês. Se não houver nenhum, devolva lista vazia — não invente elogio.

O QUE PREOCUPA
- De 1 a 3 pontos que podem estragar o mês que vem. Baseie-se nos sinais e nos KPIs que pioraram.

ALERTAS
- Um por sinal recebido, explicando o que ele significa na prática. Não deduza problemas que não estão na lista.

RECOMENDAÇÕES
- De 2 a 3 ações concretas para o mês que começa, cada uma do tamanho de uma tarefa que cabe numa tarde.
- Comece cada uma por um verbo no infinitivo.

FECHAMENTO
- Uma ou duas frases olhando para o mês que começa. Sem promessa, sem previsão numérica: o que observar.

Se a lista de sinais vier vazia, diga que o mês correu bem — não procure problema.`;

/**
 * Saída estruturada. Só campos de texto: não existe aqui um lugar onde uma
 * cifra inventada pelo modelo pudesse se hospedar.
 */
const SCHEMA = {
  type: 'object',
  properties: {
    titulo: { type: 'string' },
    leitura: { type: 'string' },
    destaques: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          // `kpi` é um RÓTULO, não um valor: o modelo aponta qual número
          // comentar e o sistema busca a cifra. Um campo numérico aqui seria o
          // primeiro lugar onde uma alucinação se hospedaria.
          kpi: { type: 'string' },
          comentario: { type: 'string' },
        },
        required: ['kpi', 'comentario'],
      },
    },
    oQueFoiBem: { type: 'array', items: { type: 'string' } },
    oQuePreocupa: { type: 'array', items: { type: 'string' } },
    alertas: { type: 'array', items: { type: 'string' } },
    recomendacoes: { type: 'array', items: { type: 'string' } },
    fechamento: { type: 'string' },
  },
  required: [
    'titulo',
    'leitura',
    'destaques',
    'oQueFoiBem',
    'oQuePreocupa',
    'alertas',
    'recomendacoes',
    'fechamento',
  ],
} as const;

/**
 * Lê a resposta do modelo. Devolve `null` em qualquer formato inesperado — o
 * chamador então usa o resumo automático. Melhor um texto nosso que um texto
 * pela metade.
 */
export function interpretar(
  texto: string,
  payload?: ResumoPayload,
): Narrativa | null {
  if (!texto.trim()) return null;
  let bruto: unknown;
  try {
    bruto = JSON.parse(texto);
  } catch {
    return null;
  }
  if (typeof bruto !== 'object' || bruto === null) return null;
  const o = bruto as Record<string, unknown>;
  const str = (v: unknown): string => (typeof v === 'string' ? v.trim() : '');
  const lista = (v: unknown): string[] =>
    Array.isArray(v) ? v.map(str).filter((s) => s.length > 0) : [];

  const titulo = str(o.titulo);
  const leitura = str(o.leitura);
  // Título e leitura são o mínimo de um resumo; sem eles não há o que mostrar.
  if (!titulo || !leitura) return null;

  // Destaque só vale se apontar para um KPI que REALMENTE foi enviado. Sem
  // esta peneira, um rótulo inventado chegaria à tela como um número vazio —
  // ou, pior, como um número buscado por nome parecido.
  const rotulos = new Set((payload?.kpis ?? []).map((k) => k.rotulo));
  const destaques = Array.isArray(o.destaques)
    ? o.destaques
        .map((d) => {
          const item = (typeof d === 'object' && d !== null ? d : {}) as Record<
            string,
            unknown
          >;
          return { kpi: str(item.kpi), comentario: str(item.comentario) };
        })
        .filter(
          (d) =>
            d.kpi.length > 0 &&
            d.comentario.length > 0 &&
            (rotulos.size === 0 || rotulos.has(d.kpi)),
        )
    : [];

  return {
    titulo,
    leitura,
    destaques,
    oQueFoiBem: lista(o.oQueFoiBem),
    oQuePreocupa: lista(o.oQuePreocupa),
    alertas: lista(o.alertas),
    recomendacoes: lista(o.recomendacoes),
    fechamento: str(o.fechamento),
  };
}
