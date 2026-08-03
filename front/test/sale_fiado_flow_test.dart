import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_create_dialog.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';

/// Venda de balcão: **o valor recebido decide** se a venda sai paga, parcial ou
/// fiada. Não há mais "Receber agora? sim/não".
///
/// O que estes testes protegem é um bug de dinheiro que existia: recebendo menos
/// que o total, o app lançava o TOTAL no caixa e só escrevia "Faltou X" na
/// descrição — a gaveta acusava dinheiro que não entrou e a dívida desaparecia
/// da carteira de fiado.

/// Caixa que registra o que foi lançado, para o teste inspecionar o VALOR.
class _SpyCashier extends FakeCashierRepository {
  final lancados = <EntryDraft>[];

  @override
  Future<CashEntry> createEntry(EntryDraft draft) {
    lancados.add(draft);
    return super.createEntry(draft);
  }
}

void main() {
  late _SpyCashier caixa;
  late FakeSaleRepository vendas;

  Widget app() {
    caixa = _SpyCashier();
    vendas = FakeSaleRepository();
    return ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(caixa),
        saleRepositoryProvider.overrideWithValue(vendas),
        inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
        customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            // O diálogo é privado: entra-se por `showSaleCreateDialog`, como a
            // tela do caixa faz.
            builder: (ctx) => TextButton(
              onPressed: () => showSaleCreateDialog(ctx),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
  }

  /// Abre o diálogo com uma tela grande (sem empilhar) e adiciona um item avulso
  /// de `preco`.
  Future<void> abrirComItem(WidgetTester tester, double preco) async {
    tester.view.physicalSize = const Size(1500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar item avulso'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição do item avulso'),
      'Palheta',
    );
    await tester.pumpAndSettle();
    // Preço unitário: é o ÚLTIMO stepper da linha do item (o 1º é a quantidade).
    // Os campos da linha são os únicos steppers da tela.
    final steppers = find.descendant(
      of: find.byType(NeuStepperField),
      matching: find.byType(TextFormField),
    );
    expect(steppers, findsNWidgets(2), reason: 'quantidade + preço');
    await tester.enterText(steppers.last, preco.toStringAsFixed(2));
    await tester.pumpAndSettle();
  }

  final campoRecebido = find.widgetWithText(TextFormField, 'Valor recebido');

  testWidgets('o toggle "Receber agora / A receber" não existe mais',
      (tester) async {
    await abrirComItem(tester, 150);
    expect(find.text('Receber agora'), findsNothing);
    expect(find.text('A receber'), findsNothing);
    expect(campoRecebido, findsOneWidget);
  });

  testWidgets('valor recebido vem preenchido com o total', (tester) async {
    await abrirComItem(tester, 150);
    final campo = tester.widget<TextFormField>(campoRecebido);
    // Vírgula: é o formato que o usuário digita e que o campo aceita (pt-BR).
    expect(campo.controller?.text, '150,00',
        reason: 'digitar um número que já está na tela é trabalho inútil');
  });

  testWidgets('recebendo o total: lança o total e não pede confirmação',
      (tester) async {
    await abrirComItem(tester, 150);

    expect(find.text('Vender e receber'), findsOneWidget);
    await tester.tap(find.text('Vender e receber'));
    await tester.pumpAndSettle();

    expect(caixa.lancados.single.amount, 150);
    expect(find.text('Registrar como fiado?'), findsNothing);
  });

  testWidgets('recebendo MENOS que o total: lança o recebido, não o total',
      (tester) async {
    await abrirComItem(tester, 200);
    await tester.enterText(campoRecebido, '120,00');
    await tester.pumpAndSettle();

    // O efeito aparece ANTES de confirmar.
    expect(find.textContaining('Fiado: ficam'), findsOneWidget);
    expect(find.text('Vender (fiado)'), findsOneWidget);

    await tester.tap(find.text('Vender (fiado)'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar como fiado?'), findsOneWidget);
    await tester.tap(find.text('Confirmar fiado'));
    await tester.pumpAndSettle();

    expect(
      caixa.lancados.single.amount,
      120,
      reason: 'o bug antigo lançava 200 e escondia a dívida de 80',
    );
  });

  testWidgets('voltar no modal NÃO cria a venda', (tester) async {
    await abrirComItem(tester, 200);
    await tester.enterText(campoRecebido, '120,00');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vender (fiado)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(caixa.lancados, isEmpty);
    expect((await vendas.listSales()).items, isEmpty);
  });

  testWidgets('recebendo zero: fiado integral, sem lançamento no caixa',
      (tester) async {
    await abrirComItem(tester, 90);
    await tester.enterText(campoRecebido, '0');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vender (fiado)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar fiado'));
    await tester.pumpAndSettle();

    // Nada entrou na gaveta — a venda inteira é dívida.
    expect(caixa.lancados, isEmpty);
    expect((await vendas.listSales()).items, hasLength(1));
  });

  testWidgets('recebendo MAIS que o total: troco, e o caixa recebe só o total',
      (tester) async {
    await abrirComItem(tester, 90);
    await tester.enterText(campoRecebido, '100,00');
    await tester.pumpAndSettle();

    expect(find.textContaining('Troco'), findsOneWidget);
    expect(find.text('Vender e receber'), findsOneWidget);

    await tester.tap(find.text('Vender e receber'));
    await tester.pumpAndSettle();

    expect(
      caixa.lancados.single.amount,
      90,
      reason: 'os R\$ 10 de troco voltam ao cliente, não são receita',
    );
  });

  testWidgets('sem cliente, o modal avisa que a dívida é difícil de cobrar',
      (tester) async {
    await abrirComItem(tester, 200);
    await tester.enterText(campoRecebido, '50,00');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vender (fiado)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem cliente identificado'), findsOneWidget);
  });
  group('editar venda existente', () {
    testWidgets('abre preenchida, sem recebimento, e salva os itens novos',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Uma venda já registrada, com dois itens.
      final existente = Sale(
        id: 's-9',
        number: 'VND-0009',
        total: '100.00',
        items: const [
          SaleItem(id: 'i1', name: 'Palheta', quantity: '2',
              unitPrice: '25.00', subtotal: '50.00'),
          SaleItem(id: 'i2', name: 'Óleo', quantity: '1',
              unitPrice: '50.00', subtotal: '50.00'),
        ],
      );
      caixa = _SpyCashier();
      vendas = FakeSaleRepository(sales: [existente]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          cashierRepositoryProvider.overrideWithValue(caixa),
          saleRepositoryProvider.overrideWithValue(vendas),
          inventoryRepositoryProvider
              .overrideWithValue(FakeInventoryRepository()),
          customersRepositoryProvider
              .overrideWithValue(FakeCustomersRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showSaleEditDialog(ctx, existente),
                child: const Text('editar'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('editar'));
      await tester.pumpAndSettle();

      // Abre já preenchida com os itens da venda...
      expect(find.text('Editar venda VND-0009'), findsOneWidget);
      expect(find.text('Palheta'), findsOneWidget);
      expect(find.text('Óleo'), findsOneWidget);
      // ...e SEM recebimento: o dinheiro dessa venda já passou pelo caixa.
      expect(campoRecebido, findsNothing);
      expect(find.text('Salvar venda'), findsOneWidget);

      // Muda a quantidade da 1ª linha de 2 → 3 e salva.
      final steppers = find.descendant(
        of: find.byType(NeuStepperField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(steppers.first, '3');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar venda'));
      await tester.pumpAndSettle();

      // O total foi recalculado (3×25 + 1×50) e NADA foi lançado no caixa.
      final salva = await vendas.getSale('s-9');
      expect(salva.total, '125.00');
      expect(caixa.lancados, isEmpty,
          reason: 'editar não recebe dinheiro de novo');
    });
  });
}
