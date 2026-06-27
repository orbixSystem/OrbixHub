import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/widgets/charts/chart_common.dart';
import 'package:orbixhub_front/core/widgets/charts/orbix_bar_chart.dart';
import 'package:orbixhub_front/core/widgets/charts/orbix_donut_chart.dart';
import 'package:orbixhub_front/core/widgets/charts/orbix_line_chart.dart';

void main() {
  group('formatação pt-BR dos eixos', () {
    test('compactMoney abrevia milhares e milhões', () {
      expect(compactMoney(950), 'R\$ 950');
      expect(compactMoney(1500), 'R\$ 1,5 mil');
      expect(compactMoney(12000), 'R\$ 12 mil');
      expect(compactMoney(2500000), 'R\$ 2,5 mi');
    });

    test('compactNumber abrevia sem moeda', () {
      expect(compactNumber(5), '5');
      expect(compactNumber(3400), '3,4 mil');
      expect(compactNumber(1000000), '1 mi');
    });

    test('axisDayMonth e tooltipDate formatam em pt-BR', () {
      final d = DateTime(2026, 3, 7);
      expect(axisDayMonth(d), '07/03');
      expect(tooltipDate(d), '07/03/2026');
    });
  });

  // Renderiza cada componente nos dois temas (claro/escuro) e confirma que não
  // lança — guarda contra cores hardcoded / APIs do fl_chart que quebrem.
  Future<void> pump(WidgetTester tester, Widget child,
      {Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      home: Scaffold(
        body: SizedBox(width: 600, height: 360, child: child),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final points = [
    OrbixTimePoint(date: DateTime(2026, 6, 1), value: 100),
    OrbixTimePoint(date: DateTime(2026, 6, 2), value: 250),
    OrbixTimePoint(date: DateTime(2026, 6, 3), value: 180),
  ];

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('OrbixLineChart renderiza ($b)', (tester) async {
      await pump(tester,
          ChartCard(title: 'Faturamento', child: OrbixLineChart(points: points)),
          brightness: b);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OrbixBarChart renderiza ($b)', (tester) async {
      await pump(
          tester,
          const ChartCard(
            title: 'Top',
            child: OrbixBarChart(bars: [
              OrbixBar(label: 'Filtro de óleo', value: 1200),
              OrbixBar(label: 'Pastilha de freio', value: 800),
            ]),
          ),
          brightness: b);
      expect(tester.takeException(), isNull);
      expect(find.text('Filtro de óleo'), findsOneWidget);
    });

    testWidgets('OrbixDonutChart renderiza ($b)', (tester) async {
      await pump(
          tester,
          const ChartCard(
            title: 'Status',
            child: OrbixDonutChart(
              centerValue: '3',
              centerLabel: 'OS',
              slices: [
                OrbixDonutSlice(label: 'Aberta', value: 2, color: Colors.blue),
                OrbixDonutSlice(label: 'Pronta', value: 1, color: Colors.green),
              ],
            ),
          ),
          brightness: b);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('estado de ponto único mostra o valor, não uma linha solta',
      (tester) async {
    await pump(
        tester,
        ChartCard(
          title: 'Faturamento',
          child: ChartSinglePoint(
              value: 'R\$ 100,00', caption: 'em 01/06/2026'),
        ));
    expect(find.text('R\$ 100,00'), findsOneWidget);
    expect(find.textContaining('Apenas um ponto'), findsOneWidget);
  });

  testWidgets('estado vazio mostra a mensagem', (tester) async {
    await pump(tester,
        const ChartCard(title: 'Faturamento', child: ChartEmptyState()));
    expect(find.text('Sem dados no período.'), findsOneWidget);
  });
}
