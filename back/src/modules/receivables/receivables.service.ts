import { Injectable } from '@nestjs/common';
import type { AuthUser } from '../../common/auth/auth.types';
import { OsService } from '../os/os.service';
import { SaleService } from '../sale/sale.service';

/**
 * Controle de FIADO (contas a receber) — módulo ORQUESTRADOR, sem tabela própria.
 *
 * "Fiado" não é um estado novo no banco: uma venda ou OS que ninguém pagou já é
 * exatamente isso. `payment` (total/pago/saldo) é DERIVADO do caixa pelos
 * próprios donos da venda — OS e Vendas perguntam ao `CashierService` quanto
 * entrou, em batch. Este service só COMPÕE esses services públicos e agrupa por
 * cliente; nunca toca a tabela de outro módulo ("aponta, não invade").
 *
 * Não pode morar no `cashier`: OS e Vendas já dependem dele, e inverter criaria
 * ciclo. Mesmo padrão do módulo `sync`, que orquestra vários services.
 *
 * LIMITES CONHECIDOS (aceitos no design):
 * - Sem data de vencimento não há aging; o que se mostra é "deve desde quando".
 * - `payment_status` é derivado em leitura, então o banco não sabe filtrar nem
 *   paginar por dívida: a varredura lê páginas e filtra em memória, com teto de
 *   [MAX_PAGINAS]. Se o teto for atingido o retorno traz `truncated: true` — a
 *   UI avisa em vez de omitir dívida em silêncio. Se a escala passar disso, o
 *   próximo passo é um título a receber com tabela própria.
 */

/** Um item do que foi vendido — responde "quais serviços e quanto de cada". */
export interface ReceivableItem {
  name: string;
  kind: string | null;
  quantity: number;
  unitPrice: number;
  total: number;
}

/** Um título em aberto: a venda ou OS que gerou a dívida. */
export interface ReceivableTitle {
  /** Módulo dono — decide qual tela abrir no drill-down. */
  origin: 'os' | 'sale';
  id: string;
  /** Número visível ao usuário (OS-0042, venda 15). */
  number: string;
  createdAt: string | null;
  total: number;
  paid: number;
  balance: number;
  status: 'a_receber' | 'parcial';
  items: ReceivableItem[];
}

/** Um título em aberto já com o dono — a forma achatada, sem agrupar. */
export interface ReceivableOpenTitle extends ReceivableTitle {
  customerId: string | null;
  customerName: string;
}

/**
 * Títulos FINALIZADOS com saldo que nunca passaram pelo caixa. Não são fiado
 * (ninguém decidiu fiar), mas também não podem sumir da vista: serviço entregue
 * e não cobrado é dinheiro esquecido. A aba Fiado mostra isto como aviso.
 */
export interface PendingSettlement {
  count: number;
  total: number;
}

/** Um cliente devedor e o que ele deve. */
export interface ReceivableCustomer {
  /** `null` = venda de balcão sem cliente identificado. */
  customerId: string | null;
  customerName: string;
  totalDue: number;
  titleCount: number;
  /** Título mais antigo em aberto — "deve desde quando". */
  oldestAt: string | null;
}

const n = (v: unknown): number => {
  const x = Number(v);
  return Number.isFinite(x) ? x : 0;
};
const round2 = (v: number): number => Math.round(v * 100) / 100;

/** Resumo (contagem + total) da lista de pendentes de acerto. */
function resumoPendentes(pendentes: TituloComDono[]): PendingSettlement {
  return {
    count: pendentes.length,
    total: round2(pendentes.reduce((acc, p) => acc + p.title.balance, 0)),
  };
}

/** Um centavo de tolerância: resíduo de arredondamento não é dívida. */
const EPS = 0.005;

/** Status de OS em que o serviço já foi entregue ao cliente. */
const FINALIZADAS = new Set(['concluida', 'entregue']);

/**
 * O título passou pelo caixa? É o que separa DÍVIDA de trabalho em andamento.
 *
 * Antes, fiado era puramente derivado (saldo > 0) e por isso uma OS entrava na
 * carteira de cobrança no instante em que era aberta — antes do serviço, antes
 * de qualquer conversa sobre pagamento.
 *
 * Duas provas, ambas já no banco:
 *  - `paid > 0`: existe lançamento de caixa ligado ao título (recebimento
 *    parcial). Quem recebeu alguma coisa, por definição passou pelo caixa.
 *  - `fiado_at`: o operador recebeu ZERO e declarou fiado — o único caso que
 *    não deixa lançamento, e a razão de a coluna existir.
 *
 * Plano de parcelas não é consultado aqui de propósito: quem parcela pelo
 * diálogo ou lançou no caixa, ou ganhou `fiado_at` na mesma ação. Para os
 * títulos ANTIGOS, o backfill da migration 0049 já resolveu.
 */
function passouPeloCaixa(row: LinhaVendavel, paid: number): boolean {
  return paid > EPS || row.fiado_at != null;
}

/** Cap de `pageSize` dos DTOs de listagem (não burlar chamando o service direto). */
const PAGE_SIZE = 100;

/** Teto da varredura. Atingido ⇒ `truncated: true` (nunca cap silencioso). */
const MAX_PAGINAS = 10;

type TituloComDono = {
  title: ReceivableTitle;
  customerId: string | null;
  customerName: string;
};

/**
 * Porta de LEITURA: só o que o fiado consome de uma linha de OS/venda. Declarar
 * o subconjunto (em vez de importar o tipo inteiro dos outros módulos) mantém o
 * acoplamento no mínimo e documenta de que shape este módulo depende.
 */
interface ItemBruto {
  name?: unknown;
  kind?: unknown;
  // Valores monetários/quantidade chegam como Prisma.Decimal (não number nem
  // string), por isso `unknown`: `n()` normaliza qualquer um deles.
  quantity?: unknown;
  unit_price?: unknown;
  unitPrice?: unknown;
  total?: unknown;
}

interface LinhaVendavel {
  id: string;
  number?: string | number | null;
  status?: string | null;
  customer_id?: string | null;
  customer_name?: string | null;
  created_at?: Date | string | null;
  /** Resumo derivado do caixa; `null` quando o caixa está Noop/desligado. */
  payment?: { total?: unknown; paid?: unknown; balance?: unknown } | null;
  /**
   * Quando o operador DECLAROU o título como fiado recebendo zero. É a prova de
   * passagem pelo caixa do único caso que não deixa lançamento — ver
   * [passouPeloCaixa].
   */
  fiado_at?: Date | string | null;
  items?: ItemBruto[] | null;
}

interface PaginaLista {
  items: unknown[];
  total: number;
}

@Injectable()
export class ReceivablesService {
  constructor(
    private readonly os: OsService,
    private readonly sales: SaleService,
  ) {}

  /** Devedores e quanto cada um deve, do maior saldo para o menor. */
  async listCustomers(user: AuthUser): Promise<{
    items: ReceivableCustomer[];
    totalDue: number;
    pendingSettlement: PendingSettlement;
    truncated: boolean;
  }> {
    const { titulos, pendentes, truncated } = await this.openTitles(user);
    const porCliente = new Map<string, ReceivableCustomer>();

    for (const { title, customerId, customerName } of titulos) {
      const chave = customerId ?? `nome:${customerName}`;
      const atual = porCliente.get(chave);
      if (atual) {
        atual.totalDue = round2(atual.totalDue + title.balance);
        atual.titleCount += 1;
        if (ehAnterior(title.createdAt, atual.oldestAt)) {
          atual.oldestAt = title.createdAt;
        }
        continue;
      }
      porCliente.set(chave, {
        customerId,
        customerName,
        totalDue: round2(title.balance),
        titleCount: 1,
        oldestAt: title.createdAt,
      });
    }

    const items = [...porCliente.values()].sort((a, b) => b.totalDue - a.totalDue);
    return {
      items,
      totalDue: round2(items.reduce((acc, c) => acc + c.totalDue, 0)),
      // Vai junto de propósito: a aba Fiado já faz esta chamada, então o aviso
      // de "entregue e não acertado" não custa uma segunda varredura.
      pendingSettlement: resumoPendentes(pendentes),
      truncated,
    };
  }

  /**
   * QUAIS são os títulos finalizados que nunca passaram pelo caixa.
   *
   * O resumo (contagem/total) vem junto de [listCustomers] e serve para o aviso;
   * esta lista é o drill-down — sem ela o operador sabe que existem 3 OS
   * esquecidas mas não consegue descobrir QUAIS, e o aviso vira um beco sem
   * saída. Mesma forma de [listOpenTitles], para a tela reusar o mesmo widget.
   */
  async listPendingSettlement(user: AuthUser): Promise<{
    items: ReceivableOpenTitle[];
    totalDue: number;
    truncated: boolean;
  }> {
    const { pendentes, truncated } = await this.openTitles(user);
    const items = pendentes
      .map(({ title, customerId, customerName }) => ({
        ...title,
        customerId,
        customerName,
      }))
      // Mais antigo primeiro: é a ordem em que se cobra.
      .sort((a, b) => (a.createdAt ?? '').localeCompare(b.createdAt ?? ''));
    return {
      items,
      totalDue: round2(items.reduce((acc, t) => acc + t.balance, 0)),
      truncated,
    };
  }

  /**
   * TODOS os títulos em aberto, achatados (sem agrupar por cliente) e do mais
   * recente para o mais antigo.
   *
   * Existe para o **histórico do caixa** poder mostrar a OS que ficou fiada.
   * Sem isto o histórico listava venda em fiado mas não OS em fiado — o mesmo
   * fato ("ficou devendo") aparecia num lugar e sumia no outro, e quem ia
   * receber tinha de procurar em duas telas.
   *
   * Não traz os itens da OS (só os da venda, que já vêm na listagem): quem
   * precisa do detalhamento é a aba Fiado, via [listTitles]. Aqui o que
   * importa é "quem, quanto e quando".
   */
  async listOpenTitles(user: AuthUser): Promise<{
    items: ReceivableOpenTitle[];
    totalDue: number;
    truncated: boolean;
  }> {
    const { titulos, truncated } = await this.openTitles(user);
    const items = titulos
      .map(({ title, customerId, customerName }) => ({
        ...title,
        customerId,
        customerName,
      }))
      .sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''));
    return {
      items,
      totalDue: round2(items.reduce((acc, t) => acc + t.balance, 0)),
      truncated,
    };
  }

  /**
   * Títulos em aberto de UM cliente, separados e com os itens de cada — é o
   * "quais serviços e qual valor" do controle de fiado. `customerId: null`
   * devolve as vendas de balcão sem cliente identificado.
   *
   * Os itens da OS não vêm na listagem (só no detalhe), então são buscados aqui
   * — o N é o número de títulos DAQUELE cliente (tipicamente poucos), não a
   * carteira toda.
   */
  async listTitles(
    user: AuthUser,
    customerId: string | null,
  ): Promise<{ customerName: string; totalDue: number; items: ReceivableTitle[] }> {
    const { titulos } = await this.openTitles(user);
    const doCliente = titulos.filter((t) => t.customerId === customerId);

    await Promise.all(
      doCliente
        .filter((t) => t.title.origin === 'os' && t.title.items.length === 0)
        .map(async (t) => {
          try {
            const detalhe = (await this.os.getOrderOrThrow(
              t.title.id,
              user.tenantId,
            )) as { items?: ItemBruto[] | null };
            t.title.items = mapItems(detalhe?.items);
          } catch {
            // Título segue válido sem o detalhamento — o saldo é o que importa.
          }
        }),
    );

    // Mais antigo primeiro: é a ordem em que se cobra.
    const items = doCliente
      .map((t) => t.title)
      .sort((a, b) => (a.createdAt ?? '').localeCompare(b.createdAt ?? ''));

    return {
      customerName: doCliente[0]?.customerName ?? 'Sem cliente',
      totalDue: round2(items.reduce((acc, t) => acc + t.balance, 0)),
      items,
    };
  }

  /**
   * Todo título em aberto (OS + vendas), com saldo. As duas listagens devolvem
   * `payment` derivado do caixa em batch, então não há N+1 nem segunda ida ao
   * caixa aqui. Vendas já trazem os itens; OS não (ver [listTitles]).
   */
  private async openTitles(
    user: AuthUser,
  ): Promise<{
    titulos: TituloComDono[];
    pendentes: TituloComDono[];
    truncated: boolean;
  }> {
    const [os, vendas] = await Promise.all([
      this.varrer((page) =>
        this.os.listOrders(user, { page, pageSize: PAGE_SIZE } as never),
      ),
      this.varrer((page) =>
        this.sales.listSales(user, {
          status: 'active',
          page,
          pageSize: PAGE_SIZE,
        } as never),
      ),
    ]);

    const titulos: TituloComDono[] = [];
    const pendentes: TituloComDono[] = [];

    for (const o of os.linhas) {
      // OS cancelada não é dívida.
      if (o.status === 'cancelada') continue;
      const title = this.toTitle('os', o);
      if (!title) continue;
      if (passouPeloCaixa(o, title.paid)) {
        titulos.push({
          title,
          customerId: o.customer_id ?? null,
          customerName: o.customer_name ?? 'Sem cliente',
        });
        continue;
      }
      // Não passou pelo caixa: ainda não é fiado. Só entra no aviso quando o
      // serviço já FOI ENTREGUE — OS em andamento não é dívida esquecida, é
      // trabalho acontecendo.
      if (FINALIZADAS.has(String(o.status ?? ''))) {
        pendentes.push({
          title,
          customerId: o.customer_id ?? null,
          customerName: o.customer_name ?? 'Sem cliente',
        });
      }
    }

    for (const s of vendas.linhas) {
      if (s.status !== 'active') continue;
      const title = this.toTitle('sale', s);
      if (!title) continue;
      if (passouPeloCaixa(s, title.paid)) {
        titulos.push({
          title,
          customerId: s.customer_id ?? null,
          customerName: s.customer_name ?? 'Sem cliente',
        });
        continue;
      }
      // Venda de balcão é sempre entregue no ato: se tem saldo e ninguém
      // acertou, é pendente de acerto.
      pendentes.push({
        title,
        customerId: s.customer_id ?? null,
        customerName: s.customer_name ?? 'Sem cliente',
      });
    }

    return {
      titulos,
      pendentes,
      truncated: os.truncated || vendas.truncated,
    };
  }

  /** Pagina até esgotar (ou até o teto), acumulando as linhas. */
  private async varrer(
    buscar: (page: number) => Promise<PaginaLista>,
  ): Promise<{ linhas: LinhaVendavel[]; truncated: boolean }> {
    const linhas: LinhaVendavel[] = [];
    for (let page = 1; page <= MAX_PAGINAS; page++) {
      const res = await buscar(page);
      linhas.push(...(res.items as LinhaVendavel[]));
      if (linhas.length >= res.total || res.items.length === 0) {
        return { linhas, truncated: false };
      }
    }
    return { linhas, truncated: true };
  }

  /** Converte uma linha de OS/venda em título — `null` quando não há dívida. */
  private toTitle(origin: 'os' | 'sale', row: LinhaVendavel): ReceivableTitle | null {
    const balance = round2(n(row.payment?.balance));
    if (balance <= EPS) return null; // pago (ou resíduo de centavo) não é fiado
    const paid = round2(n(row.payment?.paid));
    return {
      origin,
      id: String(row.id),
      number: String(row.number ?? ''),
      createdAt: isoOrNull(row.created_at),
      total: round2(n(row.payment?.total)),
      paid,
      balance,
      // Já sabemos que há saldo: nada recebido ⇒ a_receber; algo recebido ⇒ parcial.
      // Mesma régua do `derivePaymentStatus` do caixa.
      status: paid > EPS ? 'parcial' : 'a_receber',
      items: mapItems(row.items),
    };
  }
}

function mapItems(items: ItemBruto[] | null | undefined): ReceivableItem[] {
  if (!Array.isArray(items)) return [];
  return items.map((i) => ({
    name: String(i?.name ?? ''),
    kind: i?.kind == null ? null : String(i.kind),
    quantity: n(i?.quantity),
    unitPrice: n(i?.unit_price ?? i?.unitPrice),
    total: n(i?.total),
  }));
}

/** Data em ISO, ou null — aceita Date (Prisma) e string. */
function isoOrNull(v: unknown): string | null {
  if (!v) return null;
  if (v instanceof Date) return v.toISOString();
  return String(v);
}

/** `a` é anterior a `b`? (null nunca ganha de uma data real) */
function ehAnterior(a: string | null, b: string | null): boolean {
  if (!a) return false;
  if (!b) return true;
  return a < b;
}
