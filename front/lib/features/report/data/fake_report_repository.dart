import 'dart:convert';
import 'dart:typed_data';

import '../domain/monthly_models.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';

/// [ReportRepository] falso com linhas realistas. Usado em testes/dev (sem rede).
class FakeReportRepository implements ReportRepository {
  static const _osRows = <OsReportRow>[
    OsReportRow(
      number: 'OS-0001',
      customerName: 'Maria Silva',
      status: 'concluida',
      assignedTo: 'João Mecânico',
      total: 450.90,
      openedAt: '2026-06-01T10:00:00.000Z',
      finishedAt: '2026-06-02T14:00:00.000Z',
      cycleMs: 100800000,
    ),
    OsReportRow(
      number: 'OS-0002',
      customerName: 'Auto Center LTDA',
      status: 'em_execucao',
      assignedTo: null,
      total: 1280.00,
      openedAt: '2026-06-05T09:30:00.000Z',
    ),
  ];

  @override
  Future<OsOperationalReport> osReport({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort = 'recent',
    int page = 1,
    int pageSize = 50,
  }) async {
    final filtered = (q == null || q.isEmpty)
        ? _osRows
        : _osRows
            .where((o) =>
                o.number.toLowerCase().contains(q.toLowerCase()) ||
                o.customerName.toLowerCase().contains(q.toLowerCase()))
            .toList();
    final start = (page - 1) * pageSize;
    final slice = start >= filtered.length
        ? const <OsReportRow>[]
        : filtered.sublist(
            start,
            (start + pageSize).clamp(0, filtered.length),
          );
    return OsOperationalReport(
      rows: slice,
      total: filtered.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Uint8List> osCsv({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort = 'recent',
  }) async =>
      Uint8List.fromList(
          utf8.encode('Número;Cliente\r\nOS-0001;Maria Silva\r\n'));

  @override
  Future<Uint8List> osPdf({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort = 'recent',
    ReportExportCompany? company,
  }) async =>
      Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]); // "%PDF"

  @override
  Future<CustomersRanking> customersRanking({required ReportRange range}) async =>
      const CustomersRanking();

  @override
  Future<ClienteRanqueado> customerLifetime(String customerId) async =>
      ClienteRanqueado(customerId: customerId);

  @override
  Future<ExpensesReport> expensesReport({required ReportRange range}) async =>
      const ExpensesReport(
        rows: [
          ExpenseCategoryReportRow(
            categoryId: 'c-aluguel',
            categoryName: 'Aluguel',
            categoryColor: '#F97316',
            count: 1,
            previsto: 2500,
            pago: 2500,
          ),
          ExpenseCategoryReportRow(
            categoryId: 'c-fornecedor',
            categoryName: 'Fornecedor',
            categoryColor: '#10B981',
            count: 2,
            previsto: 1180,
            pago: 400,
            emAberto: 780,
            vencido: 380,
          ),
          // Sem categoria entra como linha própria: é assim que o servidor
          // responde, e o rodapé precisa fechar com as linhas.
          ExpenseCategoryReportRow(
            categoryName: 'Sem categoria',
            count: 1,
            previsto: 90,
            emAberto: 90,
          ),
        ],
        totals: ExpensesReportTotals(
          count: 4,
          previsto: 3770,
          pago: 2900,
          emAberto: 870,
          vencido: 380,
        ),
      );

  @override
  Future<Uint8List> expensesCsv({required ReportRange range}) async =>
      Uint8List.fromList('Categoria;Previsto\r\nAluguel;R\$ 2.500,00'.codeUnits);

  @override
  Future<RevenueReport> revenue({required ReportRange range}) async =>
      const RevenueReport(
        total: 1730.90,
        avgTicket: 865.45,
        byDay: [
          RevenueByDay(day: '2026-06-01', revenue: 450.90, count: 1),
          RevenueByDay(day: '2026-06-02', revenue: 1280.00, count: 1),
        ],
        byStatus: {
          'concluida': CountRevenue(count: 1, revenue: 450.90),
          'entregue': CountRevenue(count: 1, revenue: 1280.00),
        },
      );

  @override
  Future<TeamReport> team({required ReportRange range}) async => const TeamReport(
        rows: [
          TeamReportRow(
            assignedTo: 'João Mecânico',
            orders: 4,
            completed: 3,
            revenue: 3200.00,
            avgTicket: 800.00,
            avgCycleMs: 86400000,
          ),
          TeamReportRow(
            assignedTo: null,
            orders: 2,
            completed: 1,
            revenue: 600.00,
            avgTicket: 300.00,
            avgCycleMs: null,
          ),
        ],
      );

  @override
  Future<TopItemsReport> topItems({
    required ReportRange range,
    String? kind,
    int? limit,
  }) async =>
      const TopItemsReport(
        kind: null,
        rows: [
          TopItemRow(
            name: 'Óleo 5W30',
            kind: 'product',
            qty: 24,
            revenue: 1200.00,
            orders: 12,
          ),
          TopItemRow(
            name: 'Troca de óleo',
            kind: 'service',
            qty: 12,
            revenue: 600.00,
            orders: 12,
          ),
        ],
      );

  static const _inventoryRows = <InventoryReportRow>[
    InventoryReportRow(
      name: 'Óleo 5W30',
      sku: 'OL-5W30',
      currentStock: 10,
      minStock: 5,
      costPrice: 25.00,
      salePrice: 50.00,
      stockValue: 250.00,
      belowMin: false,
    ),
    InventoryReportRow(
      name: 'Filtro de ar',
      sku: 'FA-001',
      currentStock: 2,
      minStock: 8,
      costPrice: 15.00,
      salePrice: 35.00,
      stockValue: 30.00,
      belowMin: true,
    ),
  ];

  @override
  Future<InventoryReport> inventory({
    int page = 1,
    int pageSize = 50,
    String? q,
  }) async {
    final start = (page - 1) * pageSize;
    final slice = start >= _inventoryRows.length
        ? const <InventoryReportRow>[]
        : _inventoryRows.sublist(
            start,
            (start + pageSize).clamp(0, _inventoryRows.length),
          );
    return InventoryReport(
      stockValue: 8500.00,
      rows: slice,
      total: _inventoryRows.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Uint8List> inventoryCsv({String? q}) async =>
      Uint8List.fromList(utf8.encode('Item;Valor\r\nÓleo 5W30;250,00\r\n'));

  @override
  Future<Uint8List> inventoryPdf({
    ReportExportCompany? company,
    String? q,
  }) async =>
      Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]); // "%PDF"

  static const _customerRows = <CustomerReportRow>[
    CustomerReportRow(
      id: 'c1',
      name: 'Maria Silva',
      type: 'pf',
      createdAt: '2026-06-03T12:00:00.000Z',
    ),
    CustomerReportRow(
      id: 'c2',
      name: 'Auto Center LTDA',
      type: 'pj',
      createdAt: '2026-06-10T08:00:00.000Z',
    ),
  ];

  @override
  Future<CustomersReport> customers({
    required ReportRange range,
    int page = 1,
    int pageSize = 50,
  }) async {
    final start = (page - 1) * pageSize;
    final slice = start >= _customerRows.length
        ? const <CustomerReportRow>[]
        : _customerRows.sublist(
            start,
            (start + pageSize).clamp(0, _customerRows.length),
          );
    return CustomersReport(
      active: 42,
      newInRange: _customerRows.length,
      rows: slice,
      total: _customerRows.length,
      page: page,
      pageSize: pageSize,
      series: const [
        CustomersSeriesPoint(day: '2026-06-03', type: 'pf', count: 1),
        CustomersSeriesPoint(day: '2026-06-10', type: 'pj', count: 1),
      ],
    );
  }

  @override
  Future<Uint8List> customersCsv({required ReportRange range}) async =>
      Uint8List.fromList(utf8.encode('Nome;Tipo\r\nMaria Silva;pf\r\n'));

  @override
  Future<Uint8List> customersPdf({
    required ReportRange range,
    ReportExportCompany? company,
  }) async =>
      Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]); // "%PDF"

  @override
  Future<SalesLedger> salesLedger({
    required ReportRange range,
    String? type,
    String? paymentStatus,
  }) async {
    const rows = [
      SalesLedgerRow(
        id: 'os-1',
        date: '2026-06-12T10:00:00.000Z',
        type: 'servico',
        origin: 'os',
        originNumber: 'OS-0001',
        customerName: 'Maria Silva',
        value: 320,
        paymentStatus: 'pago',
      ),
      SalesLedgerRow(
        id: 'sale-1',
        date: '2026-06-11T15:30:00.000Z',
        type: 'produto',
        origin: 'sale',
        originNumber: 'VND-0001',
        customerName: null,
        value: 80,
        paymentStatus: 'a_receber',
      ),
    ];
    final filtered = rows.where((r) {
      if (type != null && type.isNotEmpty && r.type != type) return false;
      if (paymentStatus != null &&
          paymentStatus.isNotEmpty &&
          r.paymentStatus != paymentStatus) {
        return false;
      }
      return true;
    }).toList();
    return SalesLedger(rows: filtered);
  }

  @override
  Future<List<ReportMemberOption>> members() async => const [
        ReportMemberOption(id: 'm1', name: 'João Mecânico'),
        ReportMemberOption(id: 'm2', name: 'Ana Atendente'),
      ];

  // --- Visão do mês e resumo ------------------------------------------------
  //
  // Um mês com HISTÓRIA, não números redondos: cresceu 12%, mas o crescimento
  // foi fiado e a despesa subiu mais que a receita. É o cenário que a tela
  // precisa saber mostrar — três setas verdes não provam nada sobre o layout,
  // nem sobre a honestidade das cores.

  static const _kpis = <KpiMensal>[
    KpiMensal(
      chave: 'faturado',
      rotulo: 'Faturamento',
      valor: 48200,
      formato: 'dinheiro',
      variacao: VariacaoMensal(anterior: 43000, pct: 12.1),
    ),
    KpiMensal(
      chave: 'recebido',
      rotulo: 'Entrou no caixa',
      valor: 41100,
      formato: 'dinheiro',
      variacao: VariacaoMensal(anterior: 38000, pct: 8.2),
    ),
    KpiMensal(
      chave: 'despesas',
      rotulo: 'Despesas',
      valor: 31300,
      formato: 'dinheiro',
      variacao: VariacaoMensal(anterior: 24100, pct: 29.9),
      maiorEhMelhor: false,
    ),
    KpiMensal(
      chave: 'resultado',
      rotulo: 'Resultado do caixa',
      valor: 9800,
      formato: 'dinheiro',
      variacao: VariacaoMensal(anterior: 13900, pct: -29.5),
    ),
    KpiMensal(
      chave: 'aReceber',
      rotulo: 'A receber',
      valor: 7100,
      formato: 'dinheiro',
      variacao: VariacaoMensal(anterior: 1730, pct: 310.4),
      maiorEhMelhor: false,
    ),
    KpiMensal(
      chave: 'ticket',
      rotulo: 'Ticket médio',
      valor: 602.5,
      formato: 'dinheiro',
      variacao: VariacaoMensal(anterior: 662, pct: -9),
    ),
    KpiMensal(
      chave: 'osConcluidas',
      rotulo: 'OS concluídas',
      valor: 80,
      variacao: VariacaoMensal(anterior: 65, pct: 23.1),
    ),
    KpiMensal(
      chave: 'clientesNovos',
      rotulo: 'Clientes novos',
      valor: 12,
      variacao: VariacaoMensal(anterior: 9, pct: 33.3),
    ),
  ];

  static const _sinais = <SinalMensal>[
    SinalMensal(
      chave: 'fiado_crescendo',
      severidade: 'alerta',
      titulo: 'O fiado cresceu mais que o faturamento',
      detalhe: 'Parte do crescimento do mês ainda não virou dinheiro em caixa.',
      numeros: {'aReceber': 7100, 'pctFiado': 310.4, 'pctFaturado': 12.1},
    ),
    SinalMensal(
      chave: 'despesa_subindo',
      severidade: 'alerta',
      titulo: 'As despesas subiram mais que o faturamento',
      detalhe: 'O custo de operar cresceu acima do que a oficina produziu.',
      numeros: {'despesas': 31300, 'pctDespesa': 29.9, 'pctFaturado': 12.1},
    ),
    SinalMensal(
      chave: 'estoque_abaixo_minimo',
      severidade: 'info',
      titulo: '4 itens abaixo do mínimo',
      detalhe: 'Peça que falta na hora do serviço vira OS parada.',
      numeros: {'itens': 4, 'valorEstoque': 22300},
    ),
  ];

  static const _periodo = PeriodoMensal(
    de: '2026-09-01',
    ate: '2026-09-30',
    rotulo: 'Setembro/2026',
  );

  /// Um mês com ritmo irregular de propósito: picos na segunda semana e um
  /// buraco no fim — é o que o gráfico de linha existe para mostrar.
  static const _graficos = GraficosDoMes(
    serieDiaria: [
      PontoDiario(dia: '2026-09-01', valor: 1850),
      PontoDiario(dia: '2026-09-02', valor: 2400),
      PontoDiario(dia: '2026-09-03', valor: 980),
      PontoDiario(dia: '2026-09-04', valor: 3100),
      PontoDiario(dia: '2026-09-05', valor: 2750),
      PontoDiario(dia: '2026-09-08', valor: 4200),
      PontoDiario(dia: '2026-09-09', valor: 3850),
      PontoDiario(dia: '2026-09-10', valor: 5100),
      PontoDiario(dia: '2026-09-11', valor: 2300),
      PontoDiario(dia: '2026-09-12', valor: 3400),
      PontoDiario(dia: '2026-09-15', valor: 2900),
      PontoDiario(dia: '2026-09-16', valor: 1750),
      PontoDiario(dia: '2026-09-17', valor: 2100),
      PontoDiario(dia: '2026-09-18', valor: 3650),
      PontoDiario(dia: '2026-09-19', valor: 2480),
      PontoDiario(dia: '2026-09-22', valor: 1200),
      PontoDiario(dia: '2026-09-23', valor: 890),
      PontoDiario(dia: '2026-09-24', valor: 1540),
      PontoDiario(dia: '2026-09-25', valor: 980),
      PontoDiario(dia: '2026-09-26', valor: 780),
    ],
    despesasPorCategoria: [
      FatiaCategoria(categoria: 'Peças', total: 16400),
      FatiaCategoria(categoria: 'Salários', total: 7200),
      FatiaCategoria(categoria: 'Aluguel', total: 3800),
      FatiaCategoria(categoria: 'Energia', total: 1900),
      FatiaCategoria(categoria: 'Ferramentas', total: 1200),
      FatiaCategoria(categoria: 'Impostos', total: 800),
    ],
  );

  @override
  Future<VisaoMensal> overview({String? mes}) async => const VisaoMensal(
        periodo: _periodo,
        kpis: _kpis,
        sinais: _sinais,
        graficos: _graficos,
      );

  @override
  Future<ResumoMensalPagina> resumoMensal({String? mes}) async =>
      const ResumoMensalPagina(
        resumo: ResumoMensal(
          period: '2026-09-01',
          periodo: _periodo,
          kpis: _kpis,
          sinais: _sinais,
          narrativa: NarrativaMensal(
            titulo: 'Setembro fechou 12% acima de agosto, mas no fiado',
            leitura:
                'A oficina faturou R\$ 48.200 em setembro, 12% a mais que em '
                'agosto, e concluiu 80 ordens. O dinheiro que entrou no caixa '
                'subiu menos (8%), porque boa parte das vendas do mês ficou '
                'anotada: o valor a receber passou de R\$ 1.730 para '
                'R\$ 7.100. As despesas cresceram 30%, bem acima do '
                'faturamento, e o resultado do caixa caiu para R\$ 9.800.',
            alertas: [
              'O fiado cresceu mais que o faturamento: parte do crescimento do '
                  'mês ainda não virou dinheiro em caixa.',
              'As despesas subiram 30% contra 12% do faturamento.',
              '4 itens de estoque estão abaixo do mínimo.',
            ],
            recomendacoes: [
              'Combine prazo de pagamento na hora de fiar: sem data, a dívida '
                  'não entra em nenhuma fila de cobrança.',
              'Abra as despesas por categoria e confira o que cresceu acima do '
                  'normal em setembro.',
              'Reponha os 4 itens abaixo do mínimo antes que uma OS pare '
                  'esperando peça.',
            ],
          ),
          aiModel: 'gemini-flash-latest',
          generatedAt: '2026-10-01T04:03:00.000Z',
        ),
        periodos: ['2026-09-01', '2026-08-01', '2026-07-01'],
      );
}
