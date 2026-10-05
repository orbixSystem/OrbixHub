import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/dashboard/data/fake_dashboard_repository.dart';
import 'package:orbixhub_front/features/dashboard/presentation/dashboard_providers.dart';
import 'package:orbixhub_front/features/report/data/fake_report_repository.dart';
import 'package:orbixhub_front/features/report/presentation/report_providers.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/caixa_tab.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/clientes_tab.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/despesas_tab.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/equipe_tab.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/estoque_tab.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/faturamento_tab.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/ordens_tab.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/painel.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';

/// Os painéis das sete abas de detalhamento.
///
/// O que estes testes protegem é a mesma promessa em todas: seis cards, dois
/// por linha no desktop, um por linha no celular, e NADA estourando. São telas
/// densas por desenho — e densidade é exatamente onde um layout quebra sem
/// ninguém perceber até o cliente abrir no pátio.

final _paineis = <String, Widget>{
  'Faturamento': const PainelDeFaturamento(),
  'Caixa': const PainelDeCaixa(),
  'Despesas': const PainelDeDespesas(),
  'Ordens': const PainelDeOrdens(),
  'Equipe': const PainelDeEquipe(),
  'Clientes': const PainelDeClientes(),
  'Estoque': const PainelDeEstoque(),
};

Future<void> _montar(WidgetTester t, Widget painel, Size tela) async {
  t.view.physicalSize = tela;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
      cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
      dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: painel)),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  for (final entrada in _paineis.entries) {
    testWidgets('${entrada.key}: a grade abre com seis cards, dois por linha',
        (t) async {
      await _montar(t, entrada.value, const Size(1400, 4000));

      expect(t.takeException(), isNull);
      expect(find.byType(CardDeGrafico), findsNWidgets(6));
      expect(find.byType(FaixaDeIndicadores), findsOneWidget);

      final cards = t.widgetList<CardDeGrafico>(find.byType(CardDeGrafico));
      final primeiro = t.getTopLeft(find.byWidget(cards.first));
      final segundo = t.getTopLeft(find.byWidget(cards.elementAt(1)));
      expect(segundo.dy, primeiro.dy, reason: 'os dois primeiros não alinham');
      expect(segundo.dx, greaterThan(primeiro.dx));
    });

    testWidgets('${entrada.key}: cada card diz o que mede e de onde vem',
        (t) async {
      await _montar(t, entrada.value, const Size(1400, 4000));

      // Sem o subtítulo e a explicação, o dono precisa perguntar a alguém o
      // que o gráfico soma — e a resposta some junto com quem sabia.
      for (final c in t.widgetList<CardDeGrafico>(find.byType(CardDeGrafico))) {
        expect(c.subtitulo, isNotNull, reason: '"${c.titulo}" sem subtítulo');
        expect(c.info, isNotNull, reason: '"${c.titulo}" sem explicação');
      }
    });

    testWidgets('${entrada.key}: cabe num celular de 360px', (t) async {
      await _montar(t, entrada.value, const Size(360, 8000));

      expect(t.takeException(), isNull,
          reason: 'nenhum overflow pode sobrar num celular de 360px');
      final cards = t.widgetList<CardDeGrafico>(find.byType(CardDeGrafico));
      final primeiro = t.getTopLeft(find.byWidget(cards.first));
      final segundo = t.getTopLeft(find.byWidget(cards.elementAt(1)));
      expect(segundo.dx, primeiro.dx, reason: 'deveria ser uma coluna só');
      expect(segundo.dy, greaterThan(primeiro.dy));
    });
  }
}
