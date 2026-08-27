import {
  Controller,
  Param,
  ParseUUIDPipe,
  Get,
  Header,
  Query,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { resolveRange } from '../../common/metrics/range';
import { ReportService } from './report.service';
import {
  ReportCustomersExportQueryDto,
  ReportCustomersQueryDto,
  ReportInventoryExportQueryDto,
  ReportInventoryQueryDto,
  ReportOsExportQueryDto,
  ReportOsQueryDto,
  ReportRangeQueryDto,
  ReportSalesQueryDto,
  ReportTopItemsQueryDto,
} from './dto/report-query.dto';

/**
 * Módulo `report` — relatórios gated (contratável; habilitado em trial+pro hoje).
 * Todas as rotas: JWT (global) + @RequiresModule('report') + @Permissions('report.read').
 * O controller é fino: resolve o range e delega ao service (que compõe via os
 * services públicos de cada módulo). Leitura → sem audit.
 */
@Controller('report')
@UseGuards(ModuleAccessGuard)
@RequiresModule('report')
@Permissions('report.read')
export class ReportController {
  constructor(private readonly report: ReportService) {}

  /**
   * Despesas por categoria no período — "para onde vai o dinheiro".
   *
   * Gated pelo módulo `expenses` dentro do service: quem não contratou despesas
   * recebe 404, e não uma tabela vazia que pareceria "não gastei nada".
   */
  @Get('expenses')
  expenses(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportRangeQueryDto,
  ) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.expensesReport(user.tenantId, { from, to });
  }

  @Get('expenses.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="despesas.csv"')
  async expensesCsv(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportRangeQueryDto,
  ): Promise<StreamableFile> {
    const { from, to } = resolveRange(query.from, query.to);
    const buf = await this.report.expensesCsv(user.tenantId, { from, to });
    return new StreamableFile(buf);
  }

  /** OS operacional: linhas PAGINADAS (scroll infinito) + busca + ordenação. */
  @Get('os')
  os(@CurrentUser() user: AuthUser, @Query() query: ReportOsQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.osReport(user.tenantId, {
      from,
      to,
      assignedTo: query.assignedTo,
      status: query.status,
      q: query.q,
      sort: query.sort,
      page: query.page ?? 1,
      pageSize: query.pageSize ?? 50,
    });
  }

  /** OS — export CSV (relatório completo, respeitando os filtros ativos). */
  @Get('os.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="os-operacional.csv"')
  async osCsv(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportOsExportQueryDto,
  ): Promise<StreamableFile> {
    const { from, to } = resolveRange(query.from, query.to);
    const buf = await this.report.osCsv(user.tenantId, {
      from,
      to,
      assignedTo: query.assignedTo,
      status: query.status,
      q: query.q,
      sort: query.sort,
    });
    return new StreamableFile(buf);
  }

  /** OS — export PDF (relatório completo, respeitando os filtros ativos). */
  @Get('os.pdf')
  @Header('Content-Type', 'application/pdf')
  @Header('Content-Disposition', 'attachment; filename="os-operacional.pdf"')
  async osPdf(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportOsExportQueryDto,
  ): Promise<StreamableFile> {
    const { from, to } = resolveRange(query.from, query.to);
    const buf = await this.report.osPdf(
      user.tenantId,
      {
        from,
        to,
        assignedTo: query.assignedTo,
        status: query.status,
        q: query.q,
        sort: query.sort,
      },
      {
        name: query.companyName,
        legalName: query.companyLegalName,
        cnpj: query.companyCnpj,
      },
    );
    return new StreamableFile(buf);
  }

  /** Faturamento: total, ticket médio, série por dia, quebra por status. */
  /**
   * Melhores clientes do período, por dinheiro RECEBIDO e por recorrência.
   *
   * Duas listas em vez de uma "nota" combinada: quem traz mais dinheiro nem
   * sempre é quem volta mais, e a oficina trata os dois de jeitos diferentes.
   */
  @Get('customers-ranking')
  @Permissions('report.read')
  customersRanking(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportRangeQueryDto,
  ) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.customersRanking({ from, to });
  }

  /** Ciclo de vida de um cliente — sem período, é o "desde sempre". */
  @Get('customers/:id/lifetime')
  @Permissions('report.read')
  customerLifetime(@Param('id', ParseUUIDPipe) id: string) {
    return this.report.customerLifetime(id);
  }

  @Get('revenue')
  revenue(@CurrentUser() user: AuthUser, @Query() query: ReportRangeQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.revenue(user.tenantId, { from, to });
  }

  /**
   * Lente "Vendas": histórico unificado (OS serviço + venda avulsa produto) em
   * ordem de tempo. Read-only, composto via services. Filtros: período, tipo,
   * status de pagamento.
   */
  @Get('sales')
  sales(@CurrentUser() user: AuthUser, @Query() query: ReportSalesQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.salesLedger(user.tenantId, {
      from,
      to,
      type: query.type,
      paymentStatus: query.paymentStatus,
    });
  }

  /** Rendimento da equipe: agregado por responsável. */
  @Get('team')
  team(@CurrentUser() user: AuthUser, @Query() query: ReportRangeQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.team(user.tenantId, { from, to });
  }

  /** Top produtos/serviços por receita nas OS do range. */
  @Get('top-items')
  topItems(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportTopItemsQueryDto,
  ) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.topItems(user.tenantId, {
      from,
      to,
      kind: query.kind,
      limit: query.limit,
    });
  }

  /** Estoque (posição atual) PAGINADO: linhas da página + total + valor global. */
  @Get('inventory')
  inventory(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportInventoryQueryDto,
  ) {
    return this.report.inventoryPage(user.tenantId, {
      page: query.page ?? 1,
      pageSize: query.pageSize ?? 50,
      q: query.q,
    });
  }

  /** Estoque — export CSV (relatório completo, baixado pelo browser). */
  @Get('inventory.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header(
    'Content-Disposition',
    'attachment; filename="posicao-de-estoque.csv"',
  )
  async inventoryCsv(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportInventoryExportQueryDto,
  ): Promise<StreamableFile> {
    const buf = await this.report.inventoryCsv(user.tenantId, query.q);
    return new StreamableFile(buf);
  }

  /** Estoque — export PDF (relatório completo, baixado pelo browser). */
  @Get('inventory.pdf')
  @Header('Content-Type', 'application/pdf')
  @Header(
    'Content-Disposition',
    'attachment; filename="posicao-de-estoque.pdf"',
  )
  async inventoryPdf(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportInventoryExportQueryDto,
  ): Promise<StreamableFile> {
    const buf = await this.report.inventoryPdf(
      user.tenantId,
      {
        name: query.companyName,
        legalName: query.companyLegalName,
        cnpj: query.companyCnpj,
      },
      query.q,
    );
    return new StreamableFile(buf);
  }

  /**
   * Clientes: novos no range PAGINADOS (scroll infinito) + total ativo + série
   * por dia/tipo para o gráfico (independente da página).
   */
  @Get('customers')
  customers(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportCustomersQueryDto,
  ) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.customersReport(user.tenantId, {
      from,
      to,
      page: query.page ?? 1,
      pageSize: query.pageSize ?? 50,
    });
  }

  /** Clientes — export CSV (relatório completo do período). */
  @Get('customers.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="clientes.csv"')
  async customersCsv(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportCustomersExportQueryDto,
  ): Promise<StreamableFile> {
    const { from, to } = resolveRange(query.from, query.to);
    const buf = await this.report.customersCsv(user.tenantId, { from, to });
    return new StreamableFile(buf);
  }

  /** Clientes — export PDF (relatório completo do período). */
  @Get('customers.pdf')
  @Header('Content-Type', 'application/pdf')
  @Header('Content-Disposition', 'attachment; filename="clientes.pdf"')
  async customersPdf(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportCustomersExportQueryDto,
  ): Promise<StreamableFile> {
    const { from, to } = resolveRange(query.from, query.to);
    const buf = await this.report.customersPdf(
      user.tenantId,
      { from, to },
      {
        name: query.companyName,
        legalName: query.companyLegalName,
        cnpj: query.companyCnpj,
      },
    );
    return new StreamableFile(buf);
  }
}
