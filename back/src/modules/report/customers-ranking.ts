/**
 * Cruzamento de clientes × recebido — regra pura, sem banco e sem Nest.
 *
 * Existe separada porque é a única parte com decisão de negócio ("o que conta
 * como atendimento", "o que fazer com venda sem cliente") e porque testá-la
 * exigiria, de outro modo, subir três módulos.
 *
 * O CRUZAMENTO em si é o motivo de o `report` existir: o caixa conhece o
 * recebido por `sale_id` e não sabe de cliente; a OS e a venda sabem de cliente
 * e não sabem de recebido. Nenhum dos três lê a tabela do outro — quem junta é
 * este módulo, com os dados que cada um entrega pela sua costura pública.
 */

/** Documento (OS ou venda) com o dono, como os módulos donos entregam. */
export interface DocumentoDeCliente {
  id: string;
  customer_id: string | null;
  customer_name: string | null;
  created_at: Date;
}

/** Quanto entrou e quanto foi perdoado, por documento (vem do caixa). */
export interface RecebidoPorDocumento {
  recebido: number;
  desconto: number;
}

export interface ClienteRanqueado {
  customerId: string;
  customerName: string;
  /** Dinheiro que de fato entrou — a definição escolhida de "receita". */
  recebido: number;
  /** Perdoado na quitação. Fora do [recebido], mostrado à parte. */
  desconto: number;
  /** Nº de documentos (OS + vendas) — a recorrência. */
  atendimentos: number;
  osCount: number;
  saleCount: number;
  /** Média por atendimento. Zero quando não houve atendimento. */
  ticketMedio: number;
  primeiroEm: string;
  ultimoEm: string;
}

function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Agrega documentos + recebido em uma linha por CLIENTE CADASTRADO.
 *
 * Venda de balcão sem cliente (`customer_id` nulo) fica de fora: ela não é uma
 * pessoa que se possa fidelizar, e somada viraria o "cliente" campeão de
 * qualquer oficina — liderando a lista com um nome que não existe.
 */
export function ranquearClientes(
  os: DocumentoDeCliente[],
  vendas: DocumentoDeCliente[],
  recebidoPorDoc: Map<string, RecebidoPorDocumento>,
): ClienteRanqueado[] {
  const porCliente = new Map<string, ClienteRanqueado>();

  const acumular = (d: DocumentoDeCliente, ehOs: boolean) => {
    if (!d.customer_id) return;
    const pago = recebidoPorDoc.get(d.id);
    const quando = d.created_at.toISOString();

    const atual = porCliente.get(d.customer_id);
    if (!atual) {
      porCliente.set(d.customer_id, {
        customerId: d.customer_id,
        customerName: d.customer_name ?? 'Cliente',
        recebido: pago?.recebido ?? 0,
        desconto: pago?.desconto ?? 0,
        atendimentos: 1,
        osCount: ehOs ? 1 : 0,
        saleCount: ehOs ? 0 : 1,
        ticketMedio: 0,
        primeiroEm: quando,
        ultimoEm: quando,
      });
      return;
    }
    atual.recebido += pago?.recebido ?? 0;
    atual.desconto += pago?.desconto ?? 0;
    atual.atendimentos += 1;
    if (ehOs) atual.osCount += 1;
    else atual.saleCount += 1;
    if (quando < atual.primeiroEm) atual.primeiroEm = quando;
    if (quando > atual.ultimoEm) atual.ultimoEm = quando;
    // O nome mais RECENTE ganha: cliente que trocou de razão social deve
    // aparecer com o nome de hoje, não com o do primeiro atendimento.
    if (quando === atual.ultimoEm && d.customer_name) {
      atual.customerName = d.customer_name;
    }
  };

  for (const d of os) acumular(d, true);
  for (const d of vendas) acumular(d, false);

  for (const c of porCliente.values()) {
    c.recebido = round2(c.recebido);
    c.desconto = round2(c.desconto);
    c.ticketMedio =
      c.atendimentos > 0 ? round2(c.recebido / c.atendimentos) : 0;
  }
  return [...porCliente.values()];
}

/** Ordena por dinheiro; empate desempata por recorrência. */
export function porReceita(a: ClienteRanqueado, b: ClienteRanqueado): number {
  return b.recebido - a.recebido || b.atendimentos - a.atendimentos;
}

/**
 * Ordena por recorrência; empate desempata por dinheiro.
 *
 * As duas listas existem porque respondem a perguntas diferentes: quem traz
 * mais dinheiro nem sempre é quem volta mais, e a oficina trata os dois de
 * jeitos diferentes.
 */
export function porRecorrencia(
  a: ClienteRanqueado,
  b: ClienteRanqueado,
): number {
  return b.atendimentos - a.atendimentos || b.recebido - a.recebido;
}
