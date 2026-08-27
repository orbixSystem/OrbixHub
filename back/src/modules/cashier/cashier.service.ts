/**
 * Contrato público (porta) do módulo Caixa — consumido pela OS/vendas via
 * id + service público ("aponta, não invade"). Esta classe abstrata é o TOKEN de
 * injeção e o contrato congelado; a implementação real (`CashierServiceImpl`) o
 * binda via `useExisting` no `CashierModule`. A venda passa o PRÓPRIO total
 * (`fallbackTotal`) — o caixa só conhece o que recebeu, nunca toca a tabela da venda.
 *
 * O status de pagamento de uma venda é DERIVADO do caixa — a venda não guarda
 * valor pago próprio, ela pergunta aqui.
 */
import type { AuthUser } from '../../common/auth/auth.types';
import type { ChangedSincePage } from '../../common/database/changed-since';

export type PaymentStatus = 'a_receber' | 'parcial' | 'pago';

export interface PaymentSummary {
  /** Total da venda (espelha o total da OS no momento da consulta). */
  total: number;
  /**
   * Quanto da dívida foi QUITADO: dinheiro recebido + desconto concedido.
   *
   * Não é "quanto entrou em caixa" — desconto fecha dívida sem entrar dinheiro.
   * Confundir os dois é o erro que este comentário existe para evitar: o
   * fechamento do caixa soma só `amount`; o saldo do documento soma os dois.
   */
  paid: number;
  /** Dinheiro que de fato entrou (subconjunto de [paid]). */
  received: number;
  /** Desconto concedido na quitação (o resto de [paid]). */
  discount: number;
  /** Saldo a receber (>= 0). */
  balance: number;
  status: PaymentStatus;
}

/** Tolerância p/ comparação de decimais (1 centavo). */
const EPS = 0.005;

/**
 * Deriva o status de pagamento a partir de total e valor pago. Pura e
 * compartilhada (Noop e Caixa real usam a MESMA regra), garantindo consistência.
 */
export function derivePaymentStatus(total: number, paid: number): PaymentStatus {
  if (paid <= EPS) return 'a_receber';
  if (paid + EPS >= total) return 'pago';
  return 'parcial';
}

/**
 * Monta um resumo coerente a partir de total, dinheiro recebido e desconto
 * concedido (balance >= 0).
 *
 * `discount` é opcional para não quebrar chamador antigo: omitir equivale a
 * "nenhum desconto", que é a verdade sobre todo recebimento anterior à 0055.
 */
export function buildPaymentSummary(
  total: number,
  received: number,
  discount = 0,
): PaymentSummary {
  const safeTotal = total > 0 ? total : 0;
  const safeReceived = received > 0 ? received : 0;
  const safeDiscount = discount > 0 ? discount : 0;
  const paid = safeReceived + safeDiscount;
  return {
    total: safeTotal,
    paid,
    received: safeReceived,
    discount: safeDiscount,
    balance: Math.max(0, safeTotal - paid),
    status: derivePaymentStatus(safeTotal, paid),
  };
}

export abstract class CashierService {
  /**
   * Resumo de pagamento de uma venda (OS hoje; `sale` no futuro). `fallbackTotal`
   * é o total da venda conhecido pelo chamador (a OS sabe o seu próprio total) —
   * usado pelo Noop e como espelho do `total` no resumo.
   */
  abstract getPaymentSummary(
    tenantId: string,
    vendaId: string,
    fallbackTotal?: number,
  ): Promise<PaymentSummary>;

  /**
   * Versão batch para listagens (evita N+1). Recebe os pares id+total e devolve
   * um mapa id → resumo. Vendas sem recebimento devem vir como `a_receber`.
   */
  abstract getPaymentSummaryBatch(
    tenantId: string,
    vendas: Array<{ id: string; total: number }>,
  ): Promise<Map<string, PaymentSummary>>;

  /**
   * Página de mudanças de `cash_session`/`cash_entry` para o pull de sync
   * offline. Adicionado ao contrato (sem alterar os métodos existentes) para
   * o módulo `sync` — que só enxerga este token, nunca `CashierServiceImpl`
   * ("aponta, não invade") — conseguir chamá-lo.
   */
  /**
   * Σ do que ENTROU em dinheiro, agrupado por documento (`sale_id`), no
   * período. Não inclui desconto: desconto fecha dívida sem entrar dinheiro, e
   * quem pergunta "quanto este cliente já me pagou" quer o dinheiro.
   *
   * O caixa não sabe de CLIENTE — ele conhece `sale_id`. Quem cruza id →
   * cliente é o `report`, perguntando aos módulos donos. É a costura que
   * mantém a independência: nenhum dos três lê tabela do outro.
   */
  abstract receivedBySale(range?: {
    from?: Date;
    to?: Date;
  }): Promise<Map<string, { recebido: number; desconto: number }>>;

  abstract listChangedSince(
    entity: string,
    cursor: { ts: string; id: string } | null,
    limit: number,
  ): Promise<ChangedSincePage>;

  /**
   * Registra no livro caixa a SAÍDA de uma despesa que acabou de ser paga.
   *
   * Porta do módulo `expenses` ("aponta, não invade"): ele manda o valor, a
   * forma e uma descrição, e recebe de volta só o **id** do lançamento — que
   * guarda em `expense.cash_entry_id`. Nenhum dos dois lados lê a tabela do
   * outro, e o caixa não sabe o que é uma "despesa a pagar".
   *
   * Por que existe em vez de o `expenses` chamar `createEntry`:
   * - `createEntry` exige `cashier.manage` para a categoria `despesa`, porque lá
   *   é um lançamento MANUAL de quem opera a gaveta. Aqui o lançamento é
   *   CONSEQUÊNCIA de uma baixa já autorizada por `finance.write` — reexigir a
   *   permissão do caixa bloquearia quem tem todo o direito de pagar a conta.
   * - Uma porta estreita e nomeada documenta o acoplamento; injetar o Impl
   *   inteiro (como o `sync` faz, por precisar de replay genérico) daria ao
   *   módulo de despesas acesso a abrir/fechar caixa, que ele não deve ter.
   *
   * Recusa quando o tenant exige caixa aberto e não há sessão — a baixa NÃO deve
   * ser gravada sem o lançamento, senão a conferência de fechamento passa a não
   * bater sem que ninguém saiba por quê.
   */
  abstract registrarSaidaDeDespesa(
    user: AuthUser,
    input: {
      /** Valor efetivamente pago (pode divergir do previsto: juros/desconto). */
      amount: number;
      /** Forma de pagamento; o caixa valida contra as suas próprias. */
      method: string;
      /** Texto que identifica a despesa no extrato ("Aluguel do galpão"). */
      description: string;
      /** Ponto de caixa, quando houver mais de um. */
      deviceId?: string | null;
      /** Uuid do lançamento gerado no cliente (replay offline preserva o id). */
      entryId?: string;
      /**
       * Id da despesa que originou o pagamento. Gravado como origem
       * (`sale_kind='expense'`) para o clique no extrato abrir a conta a pagar.
       *
       * O caixa continua sem conhecer o módulo de despesas: guarda uma TAG e um
       * id opacos, exatamente como já faz com `'os'`. Ler a tabela alheia é que
       * seria violar a regra 1 — e ele não lê.
       */
      originId?: string;
    },
  ): Promise<{ id: string }>;

  /**
   * Estorna o lançamento de uma despesa cujo pagamento foi desfeito.
   *
   * Estorno, nunca delete (regra 6): apagar reescreveria um mês que a cliente
   * talvez já tenha conferido. Idempotente do ponto de vista do chamador —
   * lançamento já estornado não é erro, porque desfazer duas vezes (offline +
   * replay) não pode derrubar a operação.
   */
  abstract estornarSaidaDeDespesa(
    user: AuthUser,
    entryId: string,
  ): Promise<void>;
}
