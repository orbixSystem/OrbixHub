import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_create_dialog.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';

/// Layout da linha do item na venda de balcão.
///
/// Dois defeitos que estes testes travam, os dois vistos em tela:
///  - os botões −/+ ficavam FORA do campo e comiam ~80px, cortando o número
///    ("4.000" aparecia como "4.", "2.00" como "2.");
///  - a quantidade aparecia como float ("4,000") quando ninguém escreve
///    "4,000 palhetas".
///
/// Overflow de layout faz o teste de widget FALHAR sozinho (o Flutter lança na
/// fase de layout), então rodar a linha em largura de celular e de desktop já é a
/// verificação de "encaixa nos dois".

Widget _app() => ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
        saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
        inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
        customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showSaleCreateDialog(ctx),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

/// Abre o diálogo numa tela de tamanho [size] e adiciona um item avulso.
Future<void> abrirComItem(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Adicionar item avulso'));
  await tester.pumpAndSettle();
}

/// Campos dos steppers da linha (quantidade e preço, nessa ordem).
Finder get _stepperFields => find.descendant(
      of: find.byType(NeuStepperField),
      matching: find.byType(TextFormField),
    );

String _textoDe(WidgetTester tester, Finder f) =>
    tester.widget<TextFormField>(f).controller!.text;

void main() {
  group('desktop (1400×1200)', () {
    const desktop = Size(1400, 1200);

    testWidgets('a linha do item cabe sem overflow', (tester) async {
      await abrirComItem(tester, desktop);
      // Chegar aqui sem exceção já prova que nada estourou na fase de layout.
      expect(_stepperFields, findsNWidgets(2));
    });

    testWidgets('quantidade mostra "1", não "1,000"', (tester) async {
      await abrirComItem(tester, desktop);
      expect(_textoDe(tester, _stepperFields.first), '1');
    });

    testWidgets('preço mantém as 2 casas de dinheiro', (tester) async {
      await abrirComItem(tester, desktop);
      expect(_textoDe(tester, _stepperFields.last), '0,00');
    });

    testWidgets('os botões −/+ ficam DENTRO do campo', (tester) async {
      await abrirComItem(tester, desktop);
      // Por fora, eles eram irmãos do campo na Row; por dentro, são descendentes
      // dele (prefixIcon/suffixIcon) — é isso que devolve a largura ao número.
      final dentro = find.descendant(
        of: _stepperFields.first,
        matching: find.byIcon(Icons.add_rounded),
      );
      expect(dentro, findsOneWidget);
    });

    testWidgets('o número não fica truncado no espaço disponível',
        (tester) async {
      await abrirComItem(tester, desktop);
      // "1.234,56" é o pior caso realista de preço no balcão.
      await tester.enterText(_stepperFields.last, '1234,56');
      await tester.pumpAndSettle();

      final campo = _stepperFields.last;
      final render = tester.renderObject<RenderBox>(campo);
      final textos = find.descendant(of: campo, matching: find.byType(EditableText));
      final pintado = tester.renderObject<RenderBox>(textos.first);
      expect(
        pintado.size.width,
        lessThanOrEqualTo(render.size.width),
        reason: 'o texto tem de caber na moldura do campo',
      );
    });
  });

  group('celular (390×844 — iPhone)', () {
    const celular = Size(390, 844);

    testWidgets('a linha empilha e cabe sem overflow', (tester) async {
      await abrirComItem(tester, celular);
      expect(_stepperFields, findsNWidgets(2));
    });

    testWidgets('quantidade e preço continuam legíveis', (tester) async {
      await abrirComItem(tester, celular);
      await tester.enterText(_stepperFields.first, '2');
      await tester.enterText(_stepperFields.last, '1234,56');
      await tester.pumpAndSettle();

      expect(_textoDe(tester, _stepperFields.first), '2');
      expect(_textoDe(tester, _stepperFields.last), '1234,56');
    });

    testWidgets('somar pelo + funciona e mantém a formatação inteira',
        (tester) async {
      await abrirComItem(tester, celular);
      final mais = find.descendant(
        of: _stepperFields.first,
        matching: find.byIcon(Icons.add_rounded),
      );
      await tester.tap(mais);
      await tester.pumpAndSettle();
      expect(_textoDe(tester, _stepperFields.first), '2');
    });

    testWidgets('o − trava em zero (não cria quantidade negativa)',
        (tester) async {
      await abrirComItem(tester, celular);
      final menos = find.descendant(
        of: _stepperFields.first,
        matching: find.byIcon(Icons.remove_rounded),
      );
      await tester.tap(menos); // 1 → 0
      await tester.pumpAndSettle();
      expect(_textoDe(tester, _stepperFields.first), '0');

      await tester.tap(menos); // já no piso: nada acontece
      await tester.pumpAndSettle();
      expect(_textoDe(tester, _stepperFields.first), '0');
    });

    testWidgets('fração continua digitável (0,5 h de mão de obra)',
        (tester) async {
      await abrirComItem(tester, celular);
      await tester.enterText(_stepperFields.first, '0,5');
      await tester.pumpAndSettle();
      expect(_textoDe(tester, _stepperFields.first), '0,5');
    });
  });
}
