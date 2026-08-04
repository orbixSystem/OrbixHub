/**
 * Config + tipos + helpers PUROS do módulo Caixa. Os VALORES de config ficam em
 * `tenant_module.settings['cashier']` — lidos/gravados via `BillingService`
 * ("aponta, não invade"). As funções de cálculo são puras (sem Nest) para serem
 * testadas isoladamente e reaproveitadas pelo service.
 */

export const CASHIER_MODULE_KEY = 'cashier';
export const CASHIER_CONFIG_KEY = 'cashier';

/** Formas de pagamento suportadas (espelha o CHECK da tabela `cash_entry`). */
export const PAYMENT_METHODS = [
  'pix',
  'dinheiro',
  'cartao_credito',
  'cartao_debito',
  'outro',
] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

/** Categorias de lançamento (espelha o CHECK da tabela `cash_entry`). */
export const ENTRY_CATEGORIES = [
  'os_payment', // recebimento de OS
  'venda_avulsa', // recebimento de venda avulsa (sem venda vinculada por ora)
  'despesa', // saída: despesa do caixa
  'sangria', // saída: retirada de dinheiro do caixa
  'suprimento', // entrada: aporte de dinheiro ao caixa
] as const;
export type EntryCategory = (typeof ENTRY_CATEGORIES)[number];

export type EntryDirection = 'in' | 'out';
export type SaleKind = 'os' | 'sale';
export type SessionStatus = 'open' | 'closed';

/**
 * Direção é DERIVADA da categoria (não confiamos no cliente): saídas são despesa
 * e sangria; o resto é entrada. Garante coerência do livro caixa.
 */
const OUT_CATEGORIES: ReadonlySet<EntryCategory> = new Set<EntryCategory>([
  'despesa',
  'sangria',
]);
export function directionForCategory(category: EntryCategory): EntryDirection {
  return OUT_CATEGORIES.has(category) ? 'out' : 'in';
}

export interface CashierConfig {
  /** Formas de pagamento oferecidas na UI (subconjunto de PAYMENT_METHODS). */
  paymentMethods: PaymentMethod[];
  /**
   * Exige uma sessão aberta para lançar no caixa.
   *
   * **SEMPRE `false`.** A cerimônia de abrir/fechar caixa foi REMOVIDA do
   * produto: ela serve para conferir gaveta de dinheiro, e na prática virou
   * atrito sem contrapartida — a oficina recebe por Pix/cartão ou opera com o
   * próprio dono no caixa, e o ritual só produzia telas de "abra o caixa"
   * bloqueando o lançamento.
   *
   * O campo continua no tipo (e no jsonb dos tenants antigos) para não quebrar
   * contrato nem exigir limpeza de dados, mas `mergeCashierConfig` o normaliza
   * para `false` — ler daqui nunca devolve `true`, mesmo que esteja gravado.
   *
   * A `cash_session` NÃO desapareceu do banco: `cash_entry.cash_session_id` é
   * NOT NULL, então a sessão segue como balde interno, criado sozinho. Ela
   * apenas deixou de ser um conceito que o usuário vê ou administra.
   */
  requireOpenSession: boolean;
  /** Conferência de fechamento considera só dinheiro (default true). */
  countCashOnly: boolean;
}

export const DEFAULT_CASHIER_CONFIG: CashierConfig = {
  paymentMethods: [...PAYMENT_METHODS],
  requireOpenSession: false,
  countCashOnly: true,
};

/** Merge raso e seguro de um patch parcial sobre os defaults/atual. */
export function mergeCashierConfig(
  current: Partial<CashierConfig> | null | undefined,
  patch: Partial<CashierConfig> = {},
): CashierConfig {
  const base = { ...DEFAULT_CASHIER_CONFIG, ...(current ?? {}) };
  const raw = patch.paymentMethods ?? base.paymentMethods;
  const filtered = Array.isArray(raw)
    ? raw.filter((m): m is PaymentMethod =>
        (PAYMENT_METHODS as readonly string[]).includes(m),
      )
    : [];
  return {
    // Lista vazia (ou só inválidos) ⇒ cai no default — nunca deixa o tenant sem forma.
    paymentMethods: filtered.length ? filtered : [...PAYMENT_METHODS],
    // Normaliza: ignora o que veio no patch E o que está gravado. Tenant antigo
    // com `true` no jsonb passa a operar sem cerimônia, e ninguém consegue
    // religá-la por API — a alternativa (confiar no valor salvo) deixaria a
    // oficina presa numa tela de "abra o caixa" que não existe mais.
    requireOpenSession: false,
    countCashOnly: patch.countCashOnly ?? base.countCashOnly,
  };
}

/** Arredonda a 2 casas (centavos) evitando ruído de ponto flutuante. */
export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Valor esperado em caixa no fechamento. countCashOnly ⇒ só dinheiro entra na
 * conta (pix/cartão são informativos). caso contrário, soma todas as entradas e
 * saídas independentemente do método.
 */
export function computeExpected(args: {
  opening: number;
  totalIn: number;
  totalOut: number;
}): number {
  return round2(args.opening + args.totalIn - args.totalOut);
}

/** Diferença de fechamento: contado − esperado (positivo = sobra; negativo = falta). */
export function computeDifference(counted: number, expected: number): number {
  return round2(counted - expected);
}
