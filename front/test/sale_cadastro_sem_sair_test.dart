import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/customers/presentation/customer_form_dialog.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/inventory/presentation/simple_item_form_dialog.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_create_dialog.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';

/// Pedido do balcão: cadastrar cliente e produto **sem sair da venda**.
///
/// O caso real: a peça foi comprada só para aquele cliente e nunca passou pelo
/// estoque; o cliente é novo e está na frente dela. Ter de abandonar a venda,
/// ir até Clientes/Estoque e recomeçar é o que estes testes impedem de voltar.
void main() {
  Widget app() {
    return ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
        saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
        inventoryRepositoryProvider
            .overrideWithValue(FakeInventoryRepository(items: const [])),
        customersRepositoryProvider
            .overrideWithValue(FakeCustomersRepository(customers: const [])),
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
  }

  /// Toca o "Salvar" DO diálogo indicado — há vários na pilha (a venda atrás
  /// tem o seu). O botão é `NeuButton`, do design system, não um botão do
  /// Material; por isso a busca é pelo texto dentro dele.
  Future<void> salvar(WidgetTester t, Finder dialogo) async {
    final botao = find.descendant(of: dialogo, matching: find.text('Salvar'));
    await t.ensureVisible(botao);
    await t.pumpAndSettle();
    await t.tap(botao);
    await t.pumpAndSettle();
  }

  Future<void> abrirVenda(WidgetTester t) async {
    t.view.physicalSize = const Size(1500, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  testWidgets('a venda oferece cadastrar produto sem fechar nada', (t) async {
    await abrirVenda(t);

    // O botão fica ao lado da busca — disponível antes mesmo de ela digitar.
    await t.tap(find.widgetWithText(OutlinedButton, 'Novo'));
    await t.pumpAndSettle();

    expect(find.byType(SimpleItemFormDialog), findsOneWidget);
    // A venda continua viva atrás: nada do que ela montou foi perdido.
    expect(find.text('Adicionar item avulso', skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('produto cadastrado na hora já entra como item da venda',
      (t) async {
    await abrirVenda(t);
    await t.tap(find.widgetWithText(OutlinedButton, 'Novo'));
    await t.pumpAndSettle();

    // Cadastro rápido: nome e preço de venda bastam.
    final campos = find.descendant(
      of: find.byType(SimpleItemFormDialog),
      matching: find.byType(TextFormField),
    );
    await t.enterText(campos.at(0), 'Correia comprada p/ o cliente');
    await t.enterText(campos.at(3), '250,00');
    await t.pumpAndSettle();
    await salvar(t, find.byType(SimpleItemFormDialog));

    // Voltou para a venda — e o produto já está na lista de itens.
    expect(find.byType(SimpleItemFormDialog), findsNothing);
    expect(find.text('Correia comprada p/ o cliente'), findsWidgets);
  });

  /// O campo de busca DO PICKER — a venda, atrás, tem o seu próprio campo de
  /// busca de produto, e ele vem antes na árvore.
  final buscaDoPicker = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets('a busca de cliente oferece cadastrar quem não existe',
      (t) async {
    await abrirVenda(t);
    await t.tap(find.widgetWithText(TextButton, 'Cliente'));
    await t.pumpAndSettle();

    // Base vazia: em vez de um beco sem saída ("Nenhum cliente."), a saída.
    await t.enterText(buscaDoPicker, 'Dona Marlene');
    await t.pumpAndSettle();
    expect(find.textContaining('Cadastrar “Dona Marlene”'), findsOneWidget);

    await t.tap(find.textContaining('Cadastrar “Dona Marlene”'));
    await t.pumpAndSettle();

    // Abre o cadastro JÁ com o nome digitado — ela não redigita.
    expect(find.byType(CustomerFormDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CustomerFormDialog, skipOffstage: false),
        matching: find.text('Dona Marlene', skipOffstage: false),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('cliente cadastrado na hora já sai selecionado na venda',
      (t) async {
    await abrirVenda(t);
    await t.tap(find.widgetWithText(TextButton, 'Cliente'));
    await t.pumpAndSettle();
    await t.enterText(buscaDoPicker, 'Dona Marlene');
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Cadastrar “Dona Marlene”'));
    await t.pumpAndSettle();

    // Telefone é obrigatório no cadastro de cliente — o nome já veio da busca.
    final campos = find.descendant(
      of: find.byType(CustomerFormDialog),
      matching: find.byType(TextFormField),
    );
    await t.enterText(campos.at(2), '11988887777');
    await t.pumpAndSettle();

    await salvar(t, find.byType(CustomerFormDialog));

    // Os DOIS diálogos fecharam e a venda voltou com o cliente no lugar do
    // "Sem cliente (balcão)" — sem uma segunda busca.
    expect(find.byType(CustomerFormDialog), findsNothing);
    expect(find.text('Sem cliente (balcão)'), findsNothing);
    expect(find.text('Dona Marlene'), findsWidgets);
  });
}
