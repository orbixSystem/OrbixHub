export const AI_TEXT_GATEWAY = Symbol('AI_TEXT_GATEWAY');

/**
 * O que o modelo recebe: números e sinais JÁ CALCULADOS. Nada aqui é opinião —
 * é o retrato do mês fechado por `calcularMetricasMensais`.
 */
export interface ResumoPayload {
  empresa: string;
  /** "Setembro/2026". */
  periodo: string;
  /** Vocabulário do nicho ("Veículo", "Equipamento") — o texto fala a língua do cliente. */
  objeto: string;
  kpis: Array<{
    rotulo: string;
    valor: number;
    formato: 'dinheiro' | 'numero';
    variacaoPct: number | null;
    maiorEhMelhor: boolean;
  }>;
  sinais: Array<{
    chave: string;
    severidade: 'critico' | 'alerta' | 'info';
    titulo: string;
    detalhe: string;
    numeros: Record<string, number>;
  }>;
}

/**
 * O texto do resumo, em blocos. Estruturado (e não um parágrafo só) porque a
 * tela monta cada bloco de um jeito e o e-mail de outro — e porque bloco vazio
 * é detectável, enquanto um texto corrido que "esqueceu" as recomendações passa.
 */
export interface Narrativa {
  /** Uma linha que resume o mês. */
  titulo: string;
  /** 2-4 frases sobre o que aconteceu. */
  leitura: string;
  /** O que merece atenção — um item por sinal relevante. */
  alertas: string[];
  /** 2-3 ações concretas para o mês que começa. */
  recomendacoes: string[];
}

export interface ResultadoNarrativa {
  narrativa: Narrativa;
  /** 'ok' = veio do modelo; 'fallback' = montada aqui, sem IA. */
  status: 'ok' | 'fallback';
  /** Identificação do modelo, para o registro saber o que gerou aquele texto. */
  modelo: string;
}

/**
 * Contrato agnóstico ao provedor de IA — nenhum tipo específico (Gemini,
 * OpenAI, o que vier) vaza além desta fronteira. Mesmo padrão do
 * `FiscalGateway` e do `PaymentGateway`.
 *
 * **Nunca produz número.** O modelo recebe o payload fechado e só escreve; a
 * decisão sobre o que é problema já foi tomada pela regra pura. Um relatório
 * financeiro com cifra alucinada queima o recurso na primeira leitura.
 *
 * **Nunca lança.** Resumo é um serviço de leitura: se a API está fora, demora
 * demais ou devolve lixo, a implementação cai no texto determinístico. O resumo
 * sempre existe — a IA só o deixa melhor escrito.
 *
 * **DEVE ser chamado FORA de qualquer transação de banco.**
 */
export interface AiTextGateway {
  gerarResumo(payload: ResumoPayload): Promise<ResultadoNarrativa>;
}
