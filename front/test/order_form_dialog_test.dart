import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/order_form_dialog.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';

/// Abre o dialog num app mínimo e devolve o id resolvido pelo Navigator.pop.
Future<String?> _openDialog(
  WidgetTester tester,
  FakeOsRepository fake,
) async {
  String? result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [osRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = (await OrderFormDialog.show(context)) as String?;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('cliente novo: nome habilita "Criar OS" e cria a OS',
      (tester) async {
    final fake = FakeOsRepository();
    await _openDialog(tester, fake);

    // Sem clientes não quebra: o dialog abre normalmente.
    expect(find.text('Nova ordem de serviço'), findsOneWidget);

    // "Criar OS" começa desabilitado (nenhum cliente / nome).
    final createBtn =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar OS'));
    expect(createBtn.onPressed, isNull);

    // Troca para "Cliente novo" e preenche o nome.
    await tester.tap(find.text('Cliente novo'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome *'), 'Maria Teste');
    await tester.pump();

    // Seção de veículo aparece (usaSubjects=true por default).
    expect(find.text('Veículo'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Marca'), 'Fiat');

    final enabled =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar OS'));
    expect(enabled.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Criar OS'));
    await tester.pumpAndSettle();

    // OS criada com o nome do cliente novo.
    final page = await fake.listOrders();
    expect(page.items, hasLength(1));
    expect(page.items.first.customerName, 'Maria Teste');
  });

  testWidgets('sem clientes cadastrados o dialog não quebra', (tester) async {
    final fake = FakeOsRepository(); // lista de clientes vazia
    await _openDialog(tester, fake);

    // Modo "existente" com busca vazia: campo presente, sem exceção.
    expect(find.widgetWithText(TextFormField, 'Cliente *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente existente: selecionar habilita criar', (tester) async {
    final fake = FakeOsRepository(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cliente *'), 'João');
    await tester.pumpAndSettle();
    await tester.tap(find.text('João da Silva').last);
    await tester.pumpAndSettle();

    final enabled =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Criar OS'));
    expect(enabled.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Criar OS'));
    await tester.pumpAndSettle();

    final page = await fake.listOrders();
    expect(page.items, hasLength(1));
    expect(page.items.first.customerId, 'c1');
  });
}
