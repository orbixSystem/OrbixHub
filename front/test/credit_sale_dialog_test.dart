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

/// "Venda a prazo" é `showSaleCreateDialog(ctx, modoPrazo: true)` — o MESMO
/// diálogo da venda avulsa, só que sem recebimento e com parcelamento opcional.
/// Harness copiado de `sale_fiado_flow_test.dart` (item avulso direto na linha,
/// sem passar pelo estoque).
void main() {
  Widget app({
    required FakeCashierRepository cashier,
    required FakeSaleRepository sale,
  }) {
    return ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(cashier),
        saleRepositoryProvider.overrideWithValue(sale),
        inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
        customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showSaleCreateDialog(ctx, modoPrazo: true),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> abrir(
    WidgetTester t, {
    FakeCashierRepository? cashier,
    FakeSaleRepository? sale,
  }) async {
    t.view.physicalSize = const Size(1500, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(
      cashier: cashier ?? FakeCashierRepository(),
      sale: sale ?? FakeSaleRepository(),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  /// Item avulso direto na linha (sem estoque): nome + preço unitário. Mesmo
  /// caminho de `sale_fiado_flow_test.dart`.
  Future<void> adicionarItemAvulso(WidgetTester t, {double preco = 100}) async {
    await t.tap(find.text('Adicionar item avulso'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextFormField, 'Descrição do item avulso'),
      'Peça balcão',
    );
    await t.pumpAndSettle();
    // Preço unitário: o ÚLTIMO stepper da linha do item (o 1º é quantidade).
    final steppers = find.descendant(
      of: find.byType(NeuStepperField),
      matching: find.byType(TextFormField),
    );
    await t.enterText(steppers.last, preco.toStringAsFixed(2));
    await t.pumpAndSettle();
  }

  /// A venda nasce sempre fiada em modo prazo (recebido = 0 < total) — o rótulo
  /// do botão único é "Vender (fiado)", igual ao fluxo normal quando falta algo.
  Future<void> salvarVenda(WidgetTester t) async {
    final botao = find.text('Vender (fiado)');
    await t.ensureVisible(botao);
    await t.pumpAndSettle();
    await t.tap(botao);
    await t.pumpAndSettle();
  }

  /// Escolhe um dos modos do bloco "Prazo de pagamento".
  Future<void> escolherPrazo(WidgetTester t, String modo) async {
    final chip = find.text(modo);
    await t.ensureVisible(chip);
    await t.pumpAndSettle();
    await t.tap(chip);
    await t.pumpAndSettle();
  }

  /// Um toque no "+" do campo de Parcelas: 2 (padrão) → 3.
  Future<void> incrementarParcelas(WidgetTester t) async {
    final maisParcelas = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is NeuStepperField && w.semanticLabel == 'Parcelas',
      ),
      matching: find.byIcon(Icons.add_rounded),
    );
    await t.ensureVisible(maisParcelas);
    await t.pumpAndSettle();
    await t.tap(maisParcelas);
    await t.pumpAndSettle();
  }

  testWidgets('modo prazo: sem bloco de recebimento e com parcelamento',
      (t) async {
    await abrir(t);
    // "Valor recebido" é o rótulo real do campo de `_PaymentSection` — em modo
    // prazo ele nem monta, porque a venda nasce fiada por decisão, não por
    // valor digitado.
    expect(find.text('Valor recebido'), findsNothing);
    // Prazo NÃO é sinônimo de parcelamento: os três modos ficam à vista.
    expect(find.text('Prazo de pagamento'), findsOneWidget);
    expect(find.text('Sem prazo'), findsOneWidget);
    expect(find.text('Data única'), findsOneWidget);
    expect(find.text('Parcelado'), findsOneWidget);
  });

  testWidgets('os seletores de prazo têm rótulo VISÍVEL', (t) async {
    // `semanticLabel` sozinho só existe para o leitor de tela: na tela ficavam
    // dois campos numéricos lado a lado ("2" e "10") sem dizer qual era qual.
    await abrir(t);

    await escolherPrazo(t, 'Data única');
    expect(find.text('Data combinada'), findsOneWidget);

    await escolherPrazo(t, 'Parcelado');
    expect(find.text('Parcelas'), findsOneWidget);
    expect(find.text('Dia do vencimento'), findsOneWidget);
  });

  testWidgets('sem prazo combinado: venda fiada e NENHUM plano', (t) async {
    final cashier = FakeCashierRepository();
    final sale = FakeSaleRepository();
    await abrir(t, cashier: cashier, sale: sale);
    await adicionarItemAvulso(t);
    await salvarVenda(t); // "Sem prazo" é o padrão

    expect(sale.criadas.single.fiado, isTrue);
    expect(cashier.planos, isEmpty,
        reason: 'sem data combinada não há o que programar');
  });

  testWidgets('data única vira um plano de UMA parcela na data escolhida',
      (t) async {
    final cashier = FakeCashierRepository();
    final sale = FakeSaleRepository();
    await abrir(t, cashier: cashier, sale: sale);
    await adicionarItemAvulso(t);
    await escolherPrazo(t, 'Data única');
    await salvarVenda(t);

    // "Me paga dia X" é uma parcela só — o modelo de parcelas já existia, e
    // reusá-lo evita um segundo caminho para a mesma coisa.
    expect(cashier.planos, hasLength(1));
    expect(cashier.planos.single.installmentCount, 1);
    expect(cashier.planos.single.firstDueDate, isNotNull);
    // Padrão: 30 dias à frente — uma data futura, nunca "hoje" (que nasceria
    // vencida no dia seguinte, o bug que a regra nova corrige).
    final combinada = DateTime.parse(cashier.planos.single.firstDueDate!);
    expect(combinada.isAfter(DateTime.now()), isTrue);
  });

  testWidgets('sem cliente cadastrado avisa que apelido não tem telefone',
      (t) async {
    await abrir(t);
    expect(find.textContaining('sem telefone'), findsOneWidget);
  });

  testWidgets('salvar com 3 parcelas cria a venda fiada E o plano', (t) async {
    final cashier = FakeCashierRepository();
    final sale = FakeSaleRepository();
    await abrir(t, cashier: cashier, sale: sale);
    await adicionarItemAvulso(t);
    await escolherPrazo(t, 'Parcelado');
    await incrementarParcelas(t);
    await salvarVenda(t);

    expect(sale.criadas, hasLength(1));
    expect(sale.criadas.last.fiado, isTrue);
    expect(cashier.planos, hasLength(1));
    expect(cashier.planos.single.installmentCount, 3);
  });

  testWidgets('falha no plano NÃO desfaz a venda e avisa', (t) async {
    final cashier = FakeCashierRepository()
      ..planoDeveFalharCom = Exception('offline');
    final sale = FakeSaleRepository();
    await abrir(t, cashier: cashier, sale: sale);
    await adicionarItemAvulso(t);
    await escolherPrazo(t, 'Parcelado');
    await salvarVenda(t);

    // A venda foi gravada — o dinheiro não mudou de mão, só o plano faltou.
    expect(sale.criadas, hasLength(1));
    expect(sale.criadas.last.fiado, isTrue);
    expect(cashier.planos, isEmpty);
    // O aviso do plano é o SEGUNDO snackbar — fica na fila atrás do de sucesso
    // (duração padrão de 4s) até este sumir. Avança o relógio simulado para
    // o segundo assumir o lugar antes de procurar o texto.
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.textContaining('prazo não foi gravado'), findsOneWidget);
  });
}
