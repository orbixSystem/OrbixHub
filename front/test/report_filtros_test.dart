import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/report/presentation/report_providers.dart';
import 'package:orbixhub_front/features/report/presentation/report_tabs.dart';
import 'package:orbixhub_front/features/report/data/fake_report_repository.dart';
import 'package:orbixhub_front/features/report/domain/report_models.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/filtros_da_aba.dart';

/// A linha de filtros das abas.
///
/// O que estes testes protegem é o contrato da barra: ela é UMA, ela mostra o
/// mês primeiro, ela conta só os filtros da aba em que está, e o "Limpar" não
/// atravessa de uma aba para a outra apagando o recorte que o usuário montou
/// noutro lugar e ainda não conferiu.

Future<void> _montar(WidgetTester t, ReportTab aba) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: FiltrosDaAba(aba: aba)),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('o período abre a barra em toda aba que o tem', (t) async {
    for (final aba in [
      ReportTab.visao,
      ReportTab.faturamento,
      ReportTab.caixa,
      ReportTab.despesas,
      ReportTab.ordens,
      ReportTab.equipe,
      ReportTab.clientes,
    ]) {
      await _montar(t, aba);
      expect(find.text('Este mês'), findsOneWidget,
          reason: 'a aba $aba abriu sem o seletor de período');
    }
  });

  testWidgets('estoque não oferece período — é uma foto do agora', (t) async {
    await _montar(t, ReportTab.estoque);

    // Quantidade em prateleira não tem período; um seletor ali prometeria uma
    // viagem no tempo que o dado não permite.
    expect(find.text('Este mês'), findsNothing);
    expect(find.text('Situação'), findsOneWidget);
  });

  testWidgets('cada aba mostra os recortes do próprio assunto', (t) async {
    await _montar(t, ReportTab.faturamento);
    expect(find.text('Tipo'), findsOneWidget);
    expect(find.text('Pagamento'), findsOneWidget);
    // E não os de outra aba: um filtro que não muda nada ensina a ignorar a
    // barra inteira.
    expect(find.text('Forma de pagamento'), findsNothing);

    await _montar(t, ReportTab.caixa);
    expect(find.text('Forma de pagamento'), findsOneWidget);
    expect(find.text('Tipo'), findsNothing);
  });

  testWidgets('sem filtro aplicado não há badge nem "limpar"', (t) async {
    await _montar(t, ReportTab.faturamento);

    expect(find.text('Limpar filtros'), findsNothing);
    expect(find.textContaining('ativo'), findsNothing);
  });

  testWidgets('escolher um recorte acende o badge e o "limpar"', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final container = ProviderContainer(overrides: [
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(reportFiltersProvider.notifier).setSaleType('servico');

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: FiltrosDaAba(aba: ReportTab.faturamento),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.text('1 ativo'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
    // O chip passa a mostrar o VALOR no lugar do rótulo: a barra parada tem de
    // dizer o recorte inteiro sem ninguém abrir nada.
    expect(find.text('Serviço'), findsOneWidget);
    expect(find.text('Tipo'), findsNothing);

    await t.tap(find.text('Limpar filtros'));
    await t.pumpAndSettle();
    expect(container.read(reportFiltersProvider).saleType, isNull);
  });

  test('o "limpar" de uma aba não apaga o recorte de outra', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(reportFiltersProvider.notifier);

    n.setSaleType('servico'); // aba Faturamento
    n.setAssignedTo('u1'); // aba Ordens

    // O usuário está em Faturamento e aperta "limpar": ele vê um chip e espera
    // limpar aquele — não o recorte que montou em Ordens e ainda não conferiu.
    n.limpar(filtrosDaAba[ReportTab.faturamento]!);

    expect(container.read(reportFiltersProvider).saleType, isNull);
    expect(container.read(reportFiltersProvider).assignedTo, 'u1');
  });

  _testesDeAplicacao();

  test('o período não entra na contagem de filtros ativos', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(periodoSelecionadoProvider.notifier)
        .usarPreset(PresetDePeriodo.ultimos7);

    // Não existe relatório sem "quando": o período é sempre um valor, nunca um
    // recorte opcional, e contá-lo deixaria o badge preso em "1 ativo".
    final f = container.read(reportFiltersProvider);
    expect(f.ativosEntre(filtrosDaAba[ReportTab.visao]!), 0);
  });
}

/// Os filtros aplicados — a metade que a barra sozinha não garante.
///
/// Uma barra bonita que não recorta nada é pior do que nenhuma: ela promete um
/// controle que a página não tem, e o dono só descobre quando o número da tela
/// discorda do que ele esperava.
void _testesDeAplicacao() {
  test('o tipo e o pagamento vão ao servidor, e valem para a página toda', () {
    final repo = _LedgerEspiao();
    final container = ProviderContainer(overrides: [
      reportRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    container.read(reportFiltersProvider.notifier).setSaleType('produto');
    container
        .read(reportFiltersProvider.notifier)
        .setSalePaymentStatus('a_receber');
    container.read(salesLedgerReportProvider);

    expect(repo.ultimoType, 'produto');
    expect(repo.ultimoPaymentStatus, 'a_receber');
  });

  test('a busca do estoque vai ao servidor nas duas consultas', () {
    final repo = _EstoqueEspiao();
    final container = ProviderContainer(overrides: [
      reportRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    container.read(reportFiltersProvider.notifier).setEstoqueQ('  filtro  ');
    // O painel e a tabela têm de olhar para a mesma prateleira.
    container.read(painelEstoqueProvider);
    container.read(inventoryReportProvider);

    expect(repo.buscas, ['filtro', 'filtro']);
  });
}

class _LedgerEspiao extends FakeReportRepository {
  String? ultimoType;
  String? ultimoPaymentStatus;

  @override
  Future<SalesLedger> salesLedger({
    required ReportRange range,
    String? type,
    String? paymentStatus,
  }) {
    ultimoType = type;
    ultimoPaymentStatus = paymentStatus;
    return super.salesLedger(
      range: range,
      type: type,
      paymentStatus: paymentStatus,
    );
  }
}

class _EstoqueEspiao extends FakeReportRepository {
  final buscas = <String?>[];

  @override
  Future<InventoryReport> inventory({
    int page = 1,
    int pageSize = 50,
    String? q,
  }) {
    buscas.add(q);
    return super.inventory(page: page, pageSize: pageSize, q: q);
  }
}
