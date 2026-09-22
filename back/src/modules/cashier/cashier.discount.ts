import { round2 } from './cashier.config';

/**
 * Alçada de desconto na quitação — regra pura, sem banco e sem Nest.
 *
 * Está separada do service de propósito: é a regra que decide se alguém pode
 * perdoar dívida, e quanto. Isolada, ela é testável sem subir infraestrutura e
 * tem um lugar só onde a verdade mora — o service, o replay offline e (no
 * futuro) qualquer outro caminho de recebimento chamam a MESMA função, em vez
 * de cada um reimplementar o limite com uma comparação ligeiramente diferente.
 */

/** Teto por tenant. `null` em qualquer um dos dois = sem limite naquele eixo. */
export interface TetoDesconto {
  maxPercentual: number | null;
  maxValor: number | null;
}

export const SEM_TETO: TetoDesconto = { maxPercentual: null, maxValor: null };

export type ResultadoDesconto =
  | { ok: true; desconto: number }
  | { ok: false; motivo: string };

export interface EntradaDesconto {
  /** Desconto pedido, em reais. */
  desconto: number;
  /** Saldo que está sendo quitado nesta operação. */
  saldo: number;
  /** Valor que entra em dinheiro nesta operação. */
  amount: number;
  /** Quem opera tem a permissão `cashier.discount`? */
  podeConceder: boolean;
  /** Teto do tenant. Owner passa [SEM_TETO]. */
  teto: TetoDesconto;
}

/**
 * Decide se o desconto pedido é aceitável. Devolve o valor já arredondado a
 * centavos, para o chamador não reintroduzir ruído de ponto flutuante.
 *
 * A ordem das checagens é intencional: permissão primeiro, porque negar por
 * "acima do teto" a quem nem podia conceder vazaria qual é o teto.
 */
export function validarDesconto(e: EntradaDesconto): ResultadoDesconto {
  const desconto = round2(e.desconto ?? 0);

  if (desconto === 0) return { ok: true, desconto: 0 };

  if (desconto < 0) {
    return { ok: false, motivo: 'Desconto não pode ser negativo.' };
  }

  if (!e.podeConceder) {
    return {
      ok: false,
      motivo: 'Seu cargo não permite conceder desconto.',
    };
  }

  // Lançamento precisa significar alguma coisa: nem dinheiro, nem desconto, é
  // registro vazio. O banco também barra (cash_entry_amount_chk), mas errar
  // aqui devolve mensagem em vez de erro de constraint.
  if (round2(e.amount) === 0 && desconto === 0) {
    return { ok: false, motivo: 'Lançamento sem valor e sem desconto.' };
  }

  const saldo = round2(e.saldo);
  if (desconto > saldo) {
    return {
      ok: false,
      motivo:
        'Desconto maior que o saldo — não dá para perdoar mais do que se deve.',
    };
  }

  if (e.teto.maxValor !== null && desconto > round2(e.teto.maxValor)) {
    return {
      ok: false,
      motivo: `Desconto acima da sua alçada (máximo R$ ${round2(
        e.teto.maxValor,
      ).toFixed(2)}).`,
    };
  }

  if (e.teto.maxPercentual !== null && saldo > 0) {
    const percentual = (desconto / saldo) * 100;
    // Tolerância de meio centésimo: 10% de R$ 33,33 dá 3,333 e arredondar para
    // 3,33 vira 9,99...% — recusar isso seria recusar o próprio limite.
    if (percentual > e.teto.maxPercentual + 0.005) {
      return {
        ok: false,
        motivo: `Desconto acima da sua alçada (máximo ${e.teto.maxPercentual}% do saldo).`,
      };
    }
  }

  return { ok: true, desconto };
}
