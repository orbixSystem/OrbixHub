import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/neu_chart.dart';

/// O cartão de gráfico tem de ACOMPANHAR o espaço disponível.
///
/// Antes a área do gráfico era fixa em 220px: num monitor largo o cartão
/// esticava mas o gráfico continuava uma tira no topo, com o resto do cartão
/// vazio; e dentro de um painel de altura definida ele nunca preenchia.
///
/// São dois modos e os dois importam:
///  - altura LIVRE (dentro de rolagem) → proporcional à largura, com piso/teto;
///  - altura LIMITADA (Expanded, painel fixo) → preenche o que sobrou.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Altura da área do gráfico = altura do widget-filho que passamos.
  Future<double> alturaDoGrafico(
    WidgetTester tester, {
    required Widget Function(Widget card) moldura,
    required Size tela,
  }) async {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const marcador = Key('grafico');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: moldura(
            const NeuChartCard(
              title: 'Faturamento',
              child: SizedBox.expand(child: ColoredBox(
                color: Color(0xFF000000),
                key: marcador,
              )),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return tester.getSize(find.byKey(marcador)).height;
  }

  testWidgets('altura livre: acompanha a largura (tela larga = gráfico maior)',
      (tester) async {
    final estreito = await alturaDoGrafico(
      tester,
      tela: const Size(600, 900),
      moldura: (card) => SingleChildScrollView(child: card),
    );
    final largo = await alturaDoGrafico(
      tester,
      tela: const Size(1600, 900),
      moldura: (card) => SingleChildScrollView(child: card),
    );
    expect(
      largo,
      greaterThan(estreito),
      reason: 'numa tela mais larga o gráfico tem de crescer, não ficar na '
          'mesma tira de 220px com o cartão vazio em volta',
    );
  });

  testWidgets('altura livre: respeita piso e teto', (tester) async {
    final minusculo = await alturaDoGrafico(
      tester,
      tela: const Size(320, 900),
      moldura: (card) => SingleChildScrollView(child: card),
    );
    expect(minusculo, greaterThanOrEqualTo(220),
        reason: 'abaixo do piso o gráfico fica ilegível');

    final gigante = await alturaDoGrafico(
      tester,
      tela: const Size(3000, 2000),
      moldura: (card) => SingleChildScrollView(child: card),
    );
    expect(gigante, lessThanOrEqualTo(460),
        reason: 'sem teto, num ultrawide o gráfico vira um paredão');
  });

  testWidgets('altura limitada: PREENCHE o espaço do painel', (tester) async {
    const alturaPainel = 700.0;
    final altura = await alturaDoGrafico(
      tester,
      tela: const Size(1400, 900),
      moldura: (card) => SizedBox(
        height: alturaPainel,
        child: Column(children: [Expanded(child: card)]),
      ),
    );
    // Sobra o título + espaçamentos + padding do cartão; o gráfico fica com o
    // grosso da altura. Antes ficava travado em 220 e o resto do painel vazio.
    expect(
      altura,
      greaterThan(alturaPainel * .7),
      reason: 'com altura definida o gráfico tem de ocupar o painel',
    );
  });
}
