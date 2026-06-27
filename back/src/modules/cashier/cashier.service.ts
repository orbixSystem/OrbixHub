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
export type PaymentStatus = 'a_receber' | 'parcial' | 'pago';

export interface PaymentSummary {
  /** Total da venda (espelha o total da OS no momento da consulta). */
  total: number;
  /** Soma recebida pelo caixa para esta venda. */
  paid: number;
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

/** Monta um resumo coerente a partir de total + pago (balance >= 0). */
export function buildPaymentSummary(total: number, paid: number): PaymentSummary {
  const safeTotal = total > 0 ? total : 0;
  const safePaid = paid > 0 ? paid : 0;
  return {
    total: safeTotal,
    paid: safePaid,
    balance: Math.max(0, safeTotal - safePaid),
    status: derivePaymentStatus(safeTotal, safePaid),
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
}
