import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_detail_dialog.dart';

/// Rodapé de ações do detalhe da venda.
///
/// Antes eram 5 botões num `Wrap` alinhado à direita: no telefone empilhavam de
/// forma imprevisível e "Cancelar venda" — a ação mais destrutiva — caía na
/// posição mais proeminente. Estes testes fixam a ORDEM e provam que não há
/// estouro de layout nos dois tamanhos.
void main() {
  const venda = Sale(
    id: 'v1',
    number: 'VND-1',
    customerId: 'c1',
    total: '100',
  );

  /// Monta só o rodapé de ações, no tamanho pedido.
  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    Sale sale = venda,
    bool cancelada = false,
    bool podeEditar = true,
    double? larguraDaCaixa,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    // Simula a largura do DIÁLOGO, que é o que decide o layout —
                    // não a da tela.
                    width: larguraDaCaixa,
                    child: acoesVendaParaTeste(
                      sale: sale,
                      cancelada: cancelada,
                      podeEditar: podeEditar,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Posição vertical de um rótulo — usada para provar a ORDEM na tela.
  double topoDe(WidgetTester tester, String label) =>
      tester.getTopLeft(find.text(label)).dy;

  group('mobile (390x844) — empilhado por frequência de uso', () {
    testWidgets('sem estouro de layout', (tester) async {
      await pump(tester, size: const Size(390, 844));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ordem: editar, trocar cliente, exportar, depois destrutivas',
        (tester) async {
      await pump(tester, size: const Size(390, 844));
      final editar = topoDe(tester, 'Editar itens');
      final trocar = topoDe(tester, 'Trocar cliente');
      final exportar = topoDe(tester, 'Exportar PDF');
      final cancelar = topoDe(tester, 'Cancelar venda');
      final refazer = topoDe(tester, 'Cancelar e refazer');

      expect(editar, lessThan(trocar));
      expect(trocar, lessThan(exportar));
      // As destrutivas ficam DEPOIS de tudo, isoladas pelo divisor.
      expect(exportar, lessThan(cancelar));
      expect(cancelar, lessThan(refazer));
    });

    testWidgets('há um divisor separando as destrutivas', (tester) async {
      await pump(tester, size: const Size(390, 844));
      // O divisor é o que evita o clique acidental — não a ocultação.
      expect(find.byType(Divider), findsOneWidget);
      final divisor = tester.getTopLeft(find.byType(Divider)).dy;
      expect(divisor, lessThan(topoDe(tester, 'Cancelar venda')));
      expect(divisor, greaterThan(topoDe(tester, 'Exportar PDF')));
    });
  });

  group('desktop (1400x900) — construtivas à direita, primária por último', () {
    testWidgets('sem estouro de layout', (tester) async {
      await pump(tester, size: const Size(1400, 900));
      expect(tester.takeException(), isNull);
    });

    testWidgets('exportar à esquerda; editar itens é o mais à direita',
        (tester) async {
      await pump(tester, size: const Size(1400, 900));
      final exportarX = tester.getTopLeft(find.text('Exportar PDF')).dx;
      final trocarX = tester.getTopLeft(find.text('Trocar cliente')).dx;
      final editarX = tester.getTopLeft(find.text('Editar itens')).dx;

      expect(exportarX, lessThan(trocarX));
      // Primária no canto onde o olho termina a linha.
      expect(trocarX, lessThan(editarX));
    });

    testWidgets('destrutivas ficam ABAIXO, nunca ao lado da primária',
        (tester) async {
      await pump(tester, size: const Size(1400, 900));
      expect(
        topoDe(tester, 'Editar itens'),
        lessThan(topoDe(tester, 'Cancelar venda')),
      );
    });
  });

  group('venda cancelada / sem permissão', () {
    testWidgets('só exporta — nada de cancelar de novo nem editar',
        (tester) async {
      await pump(
        tester,
        size: const Size(390, 844),
        cancelada: true,
        podeEditar: false,
      );
      expect(find.text('Exportar PDF'), findsOneWidget);
      expect(find.text('Cancelar venda'), findsNothing);
      expect(find.text('Editar itens'), findsNothing);
      // Sem ações destrutivas não há o que separar.
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('REGRESSÃO: diálogo estreito em tela larga', () {
    testWidgets('não estoura — o layout segue a caixa, não a tela',
        (tester) async {
      // Foi o bug: medindo `MediaQuery` da tela (800px), o rodapé escolhia o
      // layout de desktop dentro de um diálogo de ~420px e transbordava 358px.
      // Um `Row` não encolhe botões, ele estoura.
      await pump(
        tester,
        size: const Size(1400, 900),
        larguraDaCaixa: 420,
      );
      expect(tester.takeException(), isNull);
      // Nessa largura tem de empilhar, como no telefone.
      expect(
        topoDe(tester, 'Editar itens'),
        lessThan(topoDe(tester, 'Exportar PDF')),
      );
    });

    testWidgets('caixa larga dentro da mesma tela usa a linha única',
        (tester) async {
      await pump(tester, size: const Size(1400, 900), larguraDaCaixa: 900);
      expect(tester.takeException(), isNull);
      // Contrato = ORDEM horizontal (exportar à esquerda, primária à direita).
      // Não comparo baseline: a altura de cada botão é detalhe do design system
      // e um teste preso nela quebraria a cada ajuste de padding.
      final exportarX = tester.getTopLeft(find.text('Exportar PDF')).dx;
      final trocarX = tester.getTopLeft(find.text('Trocar cliente')).dx;
      final editarX = tester.getTopLeft(find.text('Editar itens')).dx;
      expect(exportarX, lessThan(trocarX));
      expect(trocarX, lessThan(editarX));
    });
  });

  group('rótulo do cliente', () {
    testWidgets('venda sem cliente convida a IDENTIFICAR', (tester) async {
      await pump(
        tester,
        size: const Size(1400, 900),
        sale: const Sale(id: 'v2', number: 'VND-2', total: '10'),
      );
      // É a ação que resolve o fiado preso em "Sem cliente".
      expect(find.text('Identificar cliente'), findsOneWidget);
      expect(find.text('Trocar cliente'), findsNothing);
    });
  });
}
