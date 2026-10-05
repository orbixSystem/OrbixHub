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
    /**
     * O valor JÁ ESCRITO em português ("R$ 48.200,00", "80"). O modelo copia
     * esta string; ele não formata.
     *
     * Formatar é calcular: separador de milhar, centavos e o "R$" são decisões
     * que um modelo erra em silêncio — e um relatório que diz "faturou 48200"
     * não é lido por ninguém que tenha oficina.
     */
    valor: string;
    /** "subiu 12,1%" / "caiu 29,5%" / null quando não há comparação. */
    variacao: string | null;
    /** A variação é boa para o negócio? Null quando não há comparação. */
    variacaoBoa: boolean | null;
  }>;
  sinais: Array<{
    chave: string;
    severidade: 'critico' | 'alerta' | 'info';
    titulo: string;
    detalhe: string;
    /** Também já escritos: {"A receber": "R$ 7.100,00", "Alta do fiado": "310%"}. */
    numeros: Record<string, string>;
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
  /**
   * Os números que o texto escolhe comentar.
   *
   * O modelo diz QUAL kpi destacar (pelo rótulo exato que recebeu) e escreve a
   * frase; o VALOR continua vindo do nosso lado. Um campo de número aqui seria
   * o primeiro lugar onde uma cifra alucinada se hospedaria — e um relatório
   * financeiro com cifra inventada queima o recurso na primeira leitura.
   */
  destaques: Array<{ kpi: string; comentario: string }>;
  /** O que sustentou o mês — 1 a 3 pontos. Vazio quando não houve. */
  oQueFoiBem: string[];
  /** O que pode estragar o próximo — 1 a 3 pontos. */
  oQuePreocupa: string[];
  /** O que merece atenção — um item por sinal relevante. */
  alertas: string[];
  /** 2-3 ações concretas para o mês que começa. */
  recomendacoes: string[];
  /** Uma ou duas frases de fechamento, olhando para o mês que começa. */
  fechamento: string;
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
