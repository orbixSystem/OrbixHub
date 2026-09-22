import { Injectable, NotFoundException } from '@nestjs/common';
import { BillingService } from '../billing/billing.service';
import { OsMetricsService } from '../os/os-metrics.service';
import { InventoryMetricsService } from '../inventory/inventory-metrics.service';
import { CustomersMetricsService } from '../customers/customers-metrics.service';
import { EmployeesService } from '../iam/employees.service';
import { SaleService } from '../sale/sale.service';
import { CashierService } from '../cashier/cashier.service';
import { ExpensesService } from '../expenses/expenses.service';
import type {
  RevenueSeries,
  TeamPerformance,
  TopItems,
  OsReportAllParams,
  OsReportPage,
  OsReportPageParams,
} from '../os/dto/metrics.dto';
import type { InventoryMetricsReportPage } from '../inventory/dto/metrics.dto';
import {
  buildInventoryCsv,
  buildInventoryPdf,
  type ExportCompany,
} from './export/inventory-export';
import { buildOsCsv, buildOsPdf } from './export/os-export';
import { buildExpensesCsv } from './export/expenses-export';
import {
  buildCustomersCsv,
  buildCustomersPdf,
} from './export/customers-export';
import {
  ClienteRanqueado,
  porReceita,
  porRecorrencia,
  ranquearClientes,
} from './customers-ranking';
import type {
  CustomersMetricsParams,
  CustomersMetricsReportPage,
  CustomersReportPageParams,
} from '../customers/dto/metrics.dto';

interface Range {
  from: Date;
  to: Date;
}

/** Uma linha da lente "Vendas" (histórico unificado OS + venda avulsa). */
export interface SalesLedgerRow {
  id: string;
  date: string; // ISO — opened_at (OS) / created_at (venda)
  type: 'servico' | 'produto';
  origin: 'os' | 'sale';
  originNumber: string; // OS-0001 / VND-0001
  customerName: string | null;
  value: number;
  paymentStatus: 'a_receber' | 'parcial' | 'pago';
}

export interface SalesLedger {
  range: { from: string; to: string };
  rows: SalesLedgerRow[];
}

/**
 * Serviço do módulo `report` — COMPÕE relatórios chamando apenas os métodos
 * públicos das camadas de métrica de cada módulo (`OsMetricsService`,
 * `InventoryMetricsService`, `CustomersMetricsService`). Regra "aponta, não
 * invade": NUNCA injeta repository/PrismaService nem toca tabela alheia. Cada
 * relatório só é servido se o módulo-fonte estiver habilitado no tenant
 * (via `BillingService.getEnabledModules`); senão → 404 (recurso indisponível).
 * Leitura: sem audit, sem I/O externo.
 */
@Injectable()
export class ReportService {
  constructor(
    private readonly billing: BillingService,
    private readonly os: OsMetricsService,
    private readonly inventory: InventoryMetricsService,
    private readonly customers: CustomersMetricsService,
    private readonly employees: EmployeesService,
    private readonly sales: SaleService,
    private readonly cashier: CashierService,
    private readonly expenses: ExpensesService,
  ) {}

  /**
   * Mapa {userId → nome} dos membros ativos (mesma fonte do dropdown "Técnico" e
   * do front), para resolver o `assigned_to` (uuid) no export de OS. "aponta, não
   * invade": via service público do IAM, nunca a tabela. Membro inativo/removido
   * fica fora do mapa → o export rotula "—" (igual ao front).
   */
  private async memberNameMap(): Promise<Map<string, string>> {
    const members = await this.employees.listAssignableMembers();
    const map = new Map<string, string>();
    for (const m of members) if (m.fullName) map.set(m.userId, m.fullName);
    return map;
  }

  /** Rótulo "dd/mm/aaaa – dd/mm/aaaa" do período (cabeçalho do PDF). */
  private periodLabel(from: Date, to: Date): string {
    const fmt = (d: Date): string =>
      d.toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' });
    return `${fmt(from)} – ${fmt(to)}`;
  }

  /** Garante que o módulo-fonte do relatório está habilitado para o tenant. */
  private async assertModuleEnabled(
    tenantId: string,
    moduleKey: string,
  ): Promise<void> {
    const enabled = await this.billing.getEnabledModules(tenantId);
    if (!enabled.includes(moduleKey)) {
      throw new NotFoundException(
        `Relatório indisponível: módulo '${moduleKey}' não habilitado`,
      );
    }
  }

  /**
   * Despesas do período por categoria — "para onde vai o dinheiro".
   *
   * COMPÕE chamando o service público do módulo dono (regra 1): o `report` não
   * conhece as tabelas `expense*`. Gated pelo módulo `expenses`, não por
   * `report`: quem não contratou despesas não tem o relatório delas.
   */
  async expensesReport(tenantId: string, range: Range) {
    await this.assertModuleEnabled(tenantId, 'expenses');
    return this.expenses.summaryByCategory(range);
  }

  /** CSV do relatório de despesas (é o que vai para o contador). */
  async expensesCsv(tenantId: string, range: Range): Promise<Buffer> {
    const report = await this.expensesReport(tenantId, range);
    return buildExpensesCsv(report);
  }

  /** OS operacional PAGINADA (scroll infinito na tela): linhas da página + total. */
  async osReport(
    tenantId: string,
    p: OsReportPageParams,
  ): Promise<OsReportPage> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.metricsReportPage(p);
  }

  /** CSV do relatório COMPLETO de OS (respeita os filtros ativos). Buffer pronto. */
  async osCsv(tenantId: string, p: OsReportAllParams): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'os');
    const [rows, names] = await Promise.all([
      this.os.metricsReportAll(p),
      this.memberNameMap(),
    ]);
    return buildOsCsv(rows, names);
  }

  /** PDF do relatório COMPLETO de OS (respeita os filtros ativos). Buffer pronto. */
  async osPdf(
    tenantId: string,
    p: OsReportAllParams,
    company?: ExportCompany,
  ): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'os');
    const [rows, names] = await Promise.all([
      this.os.metricsReportAll(p),
      this.memberNameMap(),
    ]);
    return buildOsPdf(rows, names, {
      company,
      periodLabel: this.periodLabel(p.from, p.to),
    });
  }

  /**
   * Faturamento = OS (concluídas/entregues) + venda avulsa, no range. Compõe via
   * services públicos: OS é dono da própria série; somamos a receita de vendas
   * (`SaleService.revenueByDay`) ao total e à série por dia. "inicialmente igual
   * ao caixa; separa quando houver canal sem caixa (ex.: e-commerce)". Cada fonte
   * só entra se seu módulo estiver habilitado.
   */
  /**
   * Clientes cruzados com o que ENTROU em dinheiro. Três consultas agregadas —
   * uma por módulo dono — e o cruzamento aqui, que é o papel do `report`.
   *
   * Sem varredura paginada e sem teto: OS e venda têm `customer_id` e o caixa
   * agrupa por `sale_id`, então dá para perguntar direto. (O fiado varre em
   * memória porque não tem tabela própria — aqui não é o caso, e herdar aquele
   * limite seria escolher um problema que não temos.)
   */
  private async clientesComRecebido(range: {
    from?: Date;
    to?: Date;
  }): Promise<ClienteRanqueado[]> {
    const [os, vendas, recebido] = await Promise.all([
      this.os.documentosPorCliente(range),
      this.sales.documentosPorCliente(range),
      this.cashier.receivedBySale(range),
    ]);
    return ranquearClientes(os, vendas, recebido);
  }

  /** Melhores clientes por dinheiro e por recorrência, no período. */
  async customersRanking(
    range: { from: Date; to: Date },
    limit = 10,
  ): Promise<{
    range: { from: string; to: string };
    porReceita: ClienteRanqueado[];
    porRecorrencia: ClienteRanqueado[];
    totalClientes: number;
  }> {
    const todos = await this.clientesComRecebido(range);
    return {
      range: { from: range.from.toISOString(), to: range.to.toISOString() },
      porReceita: [...todos].sort(porReceita).slice(0, limit),
      porRecorrencia: [...todos].sort(porRecorrencia).slice(0, limit),
      totalClientes: todos.length,
    };
  }

  /**
   * Ciclo de vida de UM cliente: sem range, porque a pergunta é "quanto este
   * cliente já me deixou desde sempre".
   */
  async customerLifetime(customerId: string): Promise<ClienteRanqueado> {
    const todos = await this.clientesComRecebido({});
    return (
      todos.find((c) => c.customerId === customerId) ?? {
        customerId,
        customerName: 'Cliente',
        recebido: 0,
        desconto: 0,
        atendimentos: 0,
        osCount: 0,
        saleCount: 0,
        ticketMedio: 0,
        primeiroEm: '',
        ultimoEm: '',
      }
    );
  }

  async revenue(tenantId: string, range: Range): Promise<RevenueSeries> {
    const enabled = await this.billing.getEnabledModules(tenantId);
    const hasOs = enabled.includes('os');
    const hasSale = enabled.includes('sale');
    if (!hasOs && !hasSale) {
      throw new NotFoundException(
        "Relatório indisponível: nenhum módulo de venda ('os'/'sale') habilitado",
      );
    }

    const base: RevenueSeries = hasOs
      ? await this.os.revenueSeries(range)
      : {
          range: { from: range.from.toISOString(), to: range.to.toISOString() },
          total: 0,
          avgTicket: 0,
          byDay: [],
          byStatus: {},
        };
    if (!hasSale) return base;

    const saleDays = await this.sales.revenueByDay(tenantId, range);
    if (!saleDays.length) return base;

    // Merge da série por dia (OS + venda), recomputa total/ticket/contagem.
    const byDayMap = new Map(base.byDay.map((d) => [d.day, { ...d }]));
    let saleTotal = 0;
    let saleCount = 0;
    for (const s of saleDays) {
      saleTotal += s.revenue;
      saleCount += s.count;
      const cur = byDayMap.get(s.day);
      if (cur) {
        cur.revenue = Math.round((cur.revenue + s.revenue) * 100) / 100;
        cur.count += s.count;
      } else {
        byDayMap.set(s.day, { day: s.day, revenue: s.revenue, count: s.count });
      }
    }
    const byDay = [...byDayMap.values()].sort((a, b) =>
      a.day.localeCompare(b.day),
    );
    const total = Math.round((base.total + saleTotal) * 100) / 100;
    // Contagem total = nº de "transações" (OS faturadas + vendas) p/ o ticket médio.
    const osCount = Object.values(base.byStatus).reduce(
      (acc, s) => acc + s.count,
      0,
    );
    const count = osCount + saleCount;
    const avgTicket = count > 0 ? Math.round((total / count) * 100) / 100 : 0;

    return {
      ...base,
      total,
      avgTicket,
      byDay,
      // Quebra por origem (não some no byStatus de OS): expõe a fatia de vendas.
      byStatus: {
        ...base.byStatus,
        venda: { count: saleCount, revenue: Math.round(saleTotal * 100) / 100 },
      },
    };
  }

  /**
   * Lente "Vendas": histórico unificado do que foi vendido — **OS (serviço)** +
   * **venda avulsa (produto)** — em ordem de tempo (mais recente no topo).
   * READ-ONLY e COMPOSTA via services públicos (`OsMetricsService` +
   * `SaleService`); o status de pagamento é DERIVADO do Caixa em batch
   * (`CashierService.getPaymentSummaryBatch`). Nenhuma tabela alheia é tocada
   * ("aponta, não invade"). Cada fonte só entra se seu módulo estiver habilitado
   * e se o filtro `type` permitir. Filtros: período, tipo, status de pagamento.
   */
  async salesLedger(
    tenantId: string,
    p: Range & {
      type?: 'servico' | 'produto';
      paymentStatus?: 'a_receber' | 'parcial' | 'pago';
    },
  ): Promise<SalesLedger> {
    const enabled = await this.billing.getEnabledModules(tenantId);
    const wantOs = (!p.type || p.type === 'servico') && enabled.includes('os');
    const wantSale =
      (!p.type || p.type === 'produto') && enabled.includes('sale');

    const rows: SalesLedgerRow[] = [];

    if (wantOs) {
      // OS no range; exclui canceladas (não são vendas). `metricsReportAll` já é
      // o seam público de listagem da OS (nunca tocamos a tabela aqui).
      const os = await this.os.metricsReportAll({ from: p.from, to: p.to });
      for (const o of os) {
        if (o.status === 'cancelada') continue;
        rows.push({
          id: o.id,
          date: o.opened_at,
          type: 'servico',
          origin: 'os',
          originNumber: o.number,
          customerName: o.customer_name,
          value: o.total,
          paymentStatus: 'a_receber',
        });
      }
    }

    if (wantSale) {
      const sales = await this.sales.listForReport(tenantId, {
        from: p.from,
        to: p.to,
      });
      for (const s of sales) {
        rows.push({
          id: s.id,
          date: s.created_at,
          type: 'produto',
          origin: 'sale',
          originNumber: s.number,
          customerName: s.customer_name,
          value: s.total,
          paymentStatus: 'a_receber',
        });
      }
    }

    // Status de pagamento derivado do Caixa em UMA chamada batch (OS e venda
    // compartilham o resolvedor — chaveado por id; UUIDs distintos não colidem).
    if (rows.length) {
      const summaries = await this.cashier.getPaymentSummaryBatch(
        tenantId,
        rows.map((r) => ({ id: r.id, total: r.value })),
      );
      for (const r of rows) {
        r.paymentStatus = (summaries.get(r.id)?.status ??
          'a_receber') as SalesLedgerRow['paymentStatus'];
      }
    }

    let out = rows;
    if (p.paymentStatus) {
      out = out.filter((r) => r.paymentStatus === p.paymentStatus);
    }
    // Ordem de tempo (mais recente no topo), unificando as duas origens.
    out.sort((a, b) => b.date.localeCompare(a.date));

    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      rows: out,
    };
  }

  async team(tenantId: string, range: Range): Promise<TeamPerformance> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.teamPerformance(range);
  }

  async topItems(
    tenantId: string,
    p: Range & { kind?: 'product' | 'service'; limit?: number },
  ): Promise<TopItems> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.topItems(p);
  }

  /** Posição de estoque PAGINADA (tela). stockValue é o total global. */
  async inventoryPage(
    tenantId: string,
    p: { page: number; pageSize: number; q?: string },
  ): Promise<InventoryMetricsReportPage> {
    await this.assertModuleEnabled(tenantId, 'inventory');
    return this.inventory.metricsReportPage(p);
  }

  /** CSV do relatório completo de estoque (Buffer pronto p/ download). */
  async inventoryCsv(tenantId: string, q?: string): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'inventory');
    const report = await this.inventory.metricsReport(q);
    return buildInventoryCsv(report);
  }

  /** PDF do relatório completo de estoque (Buffer pronto p/ download). */
  async inventoryPdf(
    tenantId: string,
    company?: ExportCompany,
    q?: string,
  ): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'inventory');
    const report = await this.inventory.metricsReport(q);
    return buildInventoryPdf(report, company);
  }

  /**
   * Clientes PAGINADO (scroll infinito na tela): linhas da página + total +
   * total ativo + série por dia/tipo (gráfico independe da paginação).
   */
  async customersReport(
    tenantId: string,
    p: CustomersReportPageParams,
  ): Promise<CustomersMetricsReportPage> {
    await this.assertModuleEnabled(tenantId, 'customers');
    return this.customers.metricsReportPage(p);
  }

  /** CSV do relatório COMPLETO de clientes (novos no período). Buffer pronto. */
  async customersCsv(
    tenantId: string,
    p: CustomersMetricsParams,
  ): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'customers');
    const report = await this.customers.metricsReport(p);
    return buildCustomersCsv(report);
  }

  /** PDF do relatório COMPLETO de clientes (novos no período). Buffer pronto. */
  async customersPdf(
    tenantId: string,
    p: CustomersMetricsParams,
    company?: ExportCompany,
  ): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'customers');
    const report = await this.customers.metricsReport(p);
    return buildCustomersPdf(report, {
      company,
      periodLabel: this.periodLabel(p.from, p.to),
    });
  }
}
