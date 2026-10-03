import { Injectable } from '@nestjs/common';
import { AuthUser } from '../../../common/auth/auth.types';
import { BillingService } from '../../billing/billing.service';
import { CashierService } from '../../cashier/cashier.service';
import { CustomersMetricsService } from '../../customers/customers-metrics.service';
import { ExpensesService } from '../../expenses/expenses.service';
import { InventoryMetricsService } from '../../inventory/inventory-metrics.service';
import { OsMetricsService } from '../../os/os-metrics.service';
import { EM_ANDAMENTO, FATURAVEIS, OsStatus } from '../../os/os-status';
import { ReceivablesService } from '../../receivables/receivables.service';
import { SaleService } from '../../sale/sale.service';
import { NumerosDoMes } from './monthly-metrics';

export interface Janela {
  from: Date;
  to: Date;
}

/**
 * Junta os números de UM mês perguntando a cada módulo dono dos seus.
 *
 * Nenhuma query aqui: tudo vem de service público ("aponta, não invade"). É a
 * mesma costura que o resto do `report` já faz — a diferença é que o resultado
 * sai no formato que a regra pura consome, e não no formato de uma tela.
 *
 * **Módulo desligado não é zero.** Se a oficina não contratou estoque, o
 * resumo não pode dizer "nenhum item abaixo do mínimo" — ela não tem estoque
 * no sistema. Por isso cada fonte só é consultada quando o módulo existe, e o
 * que falta fica em zero sabendo que a regra não gera sinal sobre fonte
 * ausente (um sinal precisa de número que o sustente).
 */
@Injectable()
export class MonthlyAggregatesService {
  constructor(
    private readonly billing: BillingService,
    private readonly os: OsMetricsService,
    private readonly sales: SaleService,
    private readonly cashier: CashierService,
    private readonly expenses: ExpensesService,
    private readonly customers: CustomersMetricsService,
    private readonly inventory: InventoryMetricsService,
    private readonly receivables: ReceivablesService,
  ) {}

  /**
   * [incluirSaldoAtual] — o "a receber" é uma FOTO do agora, não do período:
   * não existe saldo de fiado "em setembro", existe o que está em aberto hoje.
   * Por isso só o mês corrente/recém-fechado o recebe; o mês de comparação vem
   * sem ele, e a regra então não inventa variação de fiado.
   */
  async coletar(
    tenantId: string,
    janela: Janela,
    opcoes: { incluirSaldoAtual: boolean } = { incluirSaldoAtual: true },
  ): Promise<NumerosDoMes> {
    const modulos = await this.billing.getEnabledModules(tenantId);
    const tem = (k: string) => modulos.includes(k);

    const [receita, vendas, caixa, despesas, clientes, estoque, fiado] =
      await Promise.all([
        tem('os')
          ? this.os.revenueSeries(janela)
          : Promise.resolve(null),
        tem('sale')
          ? this.sales.revenueByDay(tenantId, janela)
          : Promise.resolve([]),
        tem('cashier')
          ? this.cashier.totaisDoPeriodo(janela)
          : Promise.resolve({ entrou: 0, saiu: 0 }),
        tem('expenses')
          ? this.expenses.summaryByCategory(janela)
          : Promise.resolve(null),
        tem('customers')
          ? this.customers.metricsSummary({ from: janela.from, to: janela.to })
          : Promise.resolve(null),
        tem('inventory')
          ? this.inventory.metricsSummary()
          : Promise.resolve(null),
        tem('cashier') && opcoes.incluirSaldoAtual
          ? this.saldoAReceber(tenantId)
          : Promise.resolve({ aReceber: 0, vencido: 0 }),
      ]);

    const faturadoOs = receita?.total ?? 0;
    const faturadoVendas = vendas.reduce((acc, d) => acc + d.revenue, 0);
    // Transações = documentos faturados, de qualquer origem. É o denominador
    // do ticket médio: dividir receita de OS + venda pelo nº de OS daria um
    // ticket inflado toda vez que o balcão vender uma peça.
    const transacoesOs = Object.values(receita?.byStatus ?? {}).reduce(
      (acc, s) => acc + s.count,
      0,
    );
    const transacoesVendas = vendas.reduce((acc, d) => acc + d.count, 0);

    const osResumo = tem('os')
      ? await this.os.metricsSummary({ from: janela.from, to: janela.to })
      : null;

    return {
      faturado: round2(faturadoOs + faturadoVendas),
      transacoes: transacoesOs + transacoesVendas,
      recebido: caixa.entrou,
      saiu: caixa.saiu,
      despesas: round2(despesas?.totals?.previsto ?? 0),
      despesasPorCategoria: (despesas?.rows ?? []).map((r) => ({
        categoria: r.categoryName,
        total: round2(r.previsto),
      })),
      aReceber: fiado.aReceber,
      aReceberVencido: fiado.vencido,
      // Contagem pelos GRUPOS de status (fonte única em `os-status.ts`), nunca
      // por uma lista repetida aqui: o workflow já foi de 7 para 11 estados, e
      // uma cópia desatualizada faria o resumo contar errado em silêncio.
      osConcluidas: somarStatus(osResumo?.byStatus, FATURAVEIS),
      osCanceladas: osResumo?.byStatus?.cancelada ?? 0,
      osAbertas: somarStatus(osResumo?.byStatus, EM_ANDAMENTO),
      clientesNovos: clientes?.newInRange ?? 0,
      clientesAtendidos: clientes?.active ?? 0,
      estoqueValor: estoque?.stockValue ?? 0,
      estoqueAbaixoMinimo: estoque?.belowMin ?? 0,
    };
  }

  /**
   * Saldo de fiado e quanto dele já venceu.
   *
   * `listCustomers` usa apenas `tenantId` do usuário — o id do ator não
   * participa de nenhuma decisão aqui, e por isso o job pode montar um ator
   * mínimo em vez de carregar a sessão de alguém que não está logado.
   */
  private async saldoAReceber(
    tenantId: string,
  ): Promise<{ aReceber: number; vencido: number }> {
    const ator = { tenantId, userId: 'job', role: 'owner', jti: 'job' } as AuthUser;
    const r = await this.receivables.listCustomers(ator, { pageSize: 1 });
    return { aReceber: round2(r.totalDue), vencido: round2(r.overdueTotal) };
  }
}

const round2 = (v: number): number => Math.round(v * 100) / 100;

/** Soma as contagens dos status que pertencem ao grupo. */
function somarStatus(
  byStatus: Record<string, number> | undefined,
  grupo: ReadonlySet<OsStatus>,
): number {
  if (!byStatus) return 0;
  let total = 0;
  for (const [status, n] of Object.entries(byStatus)) {
    if (grupo.has(status as OsStatus)) total += n;
  }
  return total;
}
