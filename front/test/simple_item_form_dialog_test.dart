import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/domain/inventory_models.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/inventory/presentation/item_form_dialog.dart';
import 'package:orbixhub_front/features/inventory/presentation/simple_item_form_dialog.dart';

/// Cadastro RÁPIDO de produto: nome, marca, descrição, preços, estoque —
/// nada de código de barras, SKU ou campo fiscal. Esses continuam existindo,
/// só que num segundo diálogo, atrás do link "Cadastro completo".
void main() {
  Future<void> abrir(WidgetTester tester, FakeInventoryRepository fake) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inventoryRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => SimpleItemFormDialog.show(ctx),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('não pede código de barras, SKU nem campo fiscal', (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await abrir(t, fake);
    expect(find.text('Código de barras'), findsNothing);
    expect(find.text('SKU'), findsNothing);
    expect(find.text('NCM'), findsNothing);
  });

  testWidgets('pede exatamente os 6 campos do pedido', (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await abrir(t, fake);
    expect(find.text('Nome *'), findsOneWidget);
    expect(find.text('Marca'), findsOneWidget);
    expect(find.text('Descrição'), findsOneWidget);
    expect(find.text('Preço de venda *'), findsOneWidget);
    expect(find.text('Preço de compra'), findsOneWidget);
    expect(find.text('Quantidade em estoque'), findsOneWidget);
  });

  testWidgets('salva nome, marca, descrição, preços e estoque', (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await abrir(t, fake);

    await t.enterText(find.byType(TextFormField).at(0), 'Filtro de óleo');
    await t.enterText(find.byType(TextFormField).at(1), 'Bosch'); // marca
    await t.enterText(find.byType(TextFormField).at(2), 'Filtro compatível com linha 1.0');
    await t.enterText(find.byType(TextFormField).at(3), '35,90'); // venda
    await t.enterText(find.byType(TextFormField).at(4), '20'); // compra
    await t.enterText(find.byType(TextFormField).at(5), '8'); // estoque
    await t.pumpAndSettle();

    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();

    final criado = (await fake.listItems()).items.single;
    expect(criado.name, 'Filtro de óleo');
    expect(criado.brand, 'Bosch');
    expect(criado.description, 'Filtro compatível com linha 1.0');
    expect(double.parse(criado.salePrice!), 35.90);
    expect(double.parse(criado.costPrice!), 20);
    expect(double.parse(criado.currentStock), 8);
  });

  testWidgets('mostra o lucro por unidade assim que os dois preços existem',
      (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await abrir(t, fake);

    await t.enterText(find.byType(TextFormField).at(3), '35,90');
    await t.enterText(find.byType(TextFormField).at(4), '20');
    await t.pumpAndSettle();

    // (35,90 - 20) / 20 = 79,5% — é a mesma conta já usada no cadastro
    // completo (venda/custo/margem), só que aqui é só leitura.
    expect(find.textContaining('Lucro de'), findsOneWidget);
    expect(find.textContaining('79,5%'), findsOneWidget);
  });

  testWidgets('sem nome ou sem preço de venda, não salva', (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await abrir(t, fake);
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    expect((await fake.listItems()).items, isEmpty);
    expect(find.text('Informe o nome.'), findsOneWidget);
    expect(find.text('Informe o preço.'), findsOneWidget);
  });

  testWidgets('"Cadastro completo" abre o formulário cheio POR CIMA do simples',
      (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await abrir(t, fake);

    // O diálogo ROLA e o link fica abaixo da dobra num viewport de teste
    // pequeno (800x600) — `tap` direto tocaria fora da árvore visível.
    final link = find.textContaining('Cadastro completo');
    await t.ensureVisible(link);
    await t.pumpAndSettle();
    await t.tap(link);
    await t.pumpAndSettle();

    expect(find.byType(ItemFormDialog), findsOneWidget);
    // O simples CONTINUA montado atrás: é ele quem devolve o item a quem o
    // abriu (a venda). Fechá-lo aqui perderia esse retorno — e desistir do
    // completo jogaria fora o que já tinha sido digitado.
    expect(find.byType(SimpleItemFormDialog), findsOneWidget);
    // O completo ainda oferece Produto/Serviço — é ele quem cobre serviço.
    expect(find.text('Serviço'), findsOneWidget);
  });

  testWidgets('leva o nome já digitado para o cadastro completo', (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await abrir(t, fake);
    await t.enterText(find.byType(TextFormField).first, 'Correia dentada');
    await t.pumpAndSettle();

    final link = find.textContaining('Cadastro completo');
    await t.ensureVisible(link);
    await t.pumpAndSettle();
    await t.tap(link);
    await t.pumpAndSettle();

    // O que importa: o completo abriu com o nome já preenchido — ela não
    // redigita o que acabou de escrever.
    expect(
      // `skipOffstage: false` nos três: no viewport de teste (800x600) o campo
      // fica abaixo da dobra, e o padrão do finder o ignoraria.
      find.descendant(
        of: find.byType(ItemFormDialog, skipOffstage: false),
        matching: find.text('Correia dentada', skipOffstage: false),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('abre já preenchido com o nome vindo de fora (busca da venda)',
      (t) async {
    final fake = FakeInventoryRepository(items: const []);
    await t.pumpWidget(
      ProviderScope(
        overrides: [inventoryRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () =>
                    SimpleItemFormDialog.show(ctx, initialName: 'Filtro de óleo'),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    expect(find.text('Filtro de óleo'), findsOneWidget);
  });

  testWidgets('devolve o item criado a quem abriu (para a venda usar)',
      (t) async {
    final fake = FakeInventoryRepository(items: const []);
    InventoryItem? devolvido;
    await t.pumpWidget(
      ProviderScope(
        overrides: [inventoryRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async =>
                    devolvido = await SimpleItemFormDialog.show(ctx),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextFormField).at(0), 'Pastilha de freio');
    await t.enterText(find.byType(TextFormField).at(3), '120,00');
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();

    // Não é `true`: é o item, com id — sem isso a venda teria de buscá-lo de novo.
    expect(devolvido, isNotNull);
    expect(devolvido!.name, 'Pastilha de freio');
    expect(devolvido!.id, isNotEmpty);
  });
}
