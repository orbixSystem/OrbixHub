import { isUniqueViolation } from './prisma-errors';

/**
 * Tenta criar um documento numerado (OS, venda) reexecutando quando o número
 * escolhido já foi tomado por outro usuário no mesmo instante.
 *
 * O número sai de `SELECT MAX(number)+1` e só então é inserido. Entre a leitura
 * e a gravação cabe outra criação: dois atendentes abrindo OS ao mesmo tempo
 * calculam o MESMO próximo número. O índice único
 * (`uq_service_order_tenant_number`, `uq_sale_tenant_number`) impede a
 * duplicata — que é o importante —, mas sem repetir a tentativa o segundo
 * usuário recebe um erro cru e a OS simplesmente não é criada. Numa oficina
 * movimentada isso acontece no balcão, na frente do cliente.
 *
 * Repetir é seguro porque a tentativa perdedora não deixou nada para trás: a
 * transação inteira (número + documento + evento) foi desfeita pelo próprio
 * unique violation. A nova tentativa relê o MAX e pega o número seguinte.
 *
 * [ehConflitoDeId] existe porque nem todo P2002 é colisão de número: o replay
 * de uma criação offline manda o `id` do aparelho junto, e repetir aí só
 * repetiria o mesmo conflito para sempre. Sob RLS o Postgres suprime qual
 * constraint falhou (ver `prisma-errors.ts`), então quem chama é que sabe
 * distinguir — normalmente lendo o id.
 */
export async function criarComNumeroSequencial<T>(
  criar: () => Promise<T>,
  opts: {
    ehConflitoDeId: (erro: unknown) => Promise<boolean> | boolean;
    /** Tentativas totais. 5 cobre com folga a concorrência de um balcão. */
    tentativas?: number;
  },
): Promise<T> {
  const total = opts.tentativas ?? 5;
  for (let tentativa = 1; ; tentativa++) {
    try {
      return await criar();
    } catch (e) {
      if (!isUniqueViolation(e) || tentativa >= total) throw e;
      if (await opts.ehConflitoDeId(e)) throw e;
      // Colisão de número: o próximo laço relê o MAX e tenta o seguinte.
    }
  }
}
