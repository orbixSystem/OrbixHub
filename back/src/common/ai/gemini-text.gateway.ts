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
      const texto = await this.chamar(chave, modelo, payload);
      const narrativa = interpretar(texto);
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
        throw new Error(`HTTP ${res.status}`);
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

const INSTRUCAO = `Você escreve o relatório mensal de uma oficina para o dono dela, em português do Brasil.

Receberá um JSON com os números do mês e os sinais já apurados pelo sistema.

Regras invioláveis:
- NUNCA invente, estime ou calcule números. Use apenas os valores do JSON, exatamente como estão.
- Não cite nenhum número que não esteja no JSON.
- Comente apenas os sinais presentes em "sinais". Não deduza problemas que não estão lá.
- Escreva como quem conversa com um dono de oficina: direto, sem jargão de consultoria, sem "insights", "KPIs" ou "sinergia".
- Cada recomendação precisa ser uma ação que caiba na semana dele.
- Se não houver sinais, diga que o mês correu bem — não procure problema.`;

/**
 * Saída estruturada. Só campos de texto: não existe aqui um lugar onde uma
 * cifra inventada pelo modelo pudesse se hospedar.
 */
const SCHEMA = {
  type: 'object',
  properties: {
    titulo: { type: 'string' },
    leitura: { type: 'string' },
    alertas: { type: 'array', items: { type: 'string' } },
    recomendacoes: { type: 'array', items: { type: 'string' } },
  },
  required: ['titulo', 'leitura', 'alertas', 'recomendacoes'],
} as const;

/**
 * Lê a resposta do modelo. Devolve `null` em qualquer formato inesperado — o
 * chamador então usa o resumo automático. Melhor um texto nosso que um texto
 * pela metade.
 */
export function interpretar(texto: string): Narrativa | null {
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
  return {
    titulo,
    leitura,
    alertas: lista(o.alertas),
    recomendacoes: lista(o.recomendacoes),
  };
}
