import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
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

/// Localiza o campo editável cujo rótulo (Text visível) é [label]. Os campos do
/// design system (NeuTextField / _fieldShell) desenham o rótulo como um Text
/// irmão do campo, dentro do mesmo Column — subimos do rótulo até esse Column.
Finder _fieldByLabel(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(Column))
    .first;

/// Avança para o próximo passo do wizard.
Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(NeuButton, 'Próximo'));
  await tester.pumpAndSettle();
}

/// Seleciona o primeiro membro no dropdown "Responsável *" (obrigatório).
Future<void> _selectResponsavel(WidgetTester tester) async {
  final dd = find.text('— Selecione —');
  await tester.ensureVisible(dd);
  await tester.pumpAndSettle();
  await tester.tap(dd);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ana Mecânica').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cliente novo: nome habilita "Próximo" e cria a OS no fim',
      (tester) async {
    final fake = FakeOsRepository();
    await _openDialog(tester, fake);

    // Sem clientes não quebra: o dialog abre normalmente.
    expect(find.text('Nova ordem de serviço'), findsOneWidget);

    // "Próximo" começa desabilitado (nenhum cliente / nome).
    final nextBtn =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'));
    expect(nextBtn.onPressed, isNull);

    // Passo 1 — Cliente: troca para "Cliente novo" e preenche nome + telefone.
    await tester.tap(find.text('Cliente novo'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldByLabel('Nome *'), 'Maria Teste');
    await tester.pump();
    await tester.enterText(_fieldByLabel('Telefone (opcional)'), '11999998888');
    await tester.pump();

    // Nome preenchido habilita "Próximo".
    final enabledNext =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'));
    expect(enabledNext.onPressed, isNotNull);
    await _next(tester);

    // Passo 2 — Veículo (usaSubjects=true por default): campos dinâmicos da
    // config, incl. o picker de Marca e os campos Ano e Cor.
    expect(find.text('Marca (opcional)'), findsOneWidget);
    expect(find.text('Ano (opcional)'), findsOneWidget);
    expect(find.text('Cor (opcional)'), findsOneWidget);
    await tester.enterText(
        _fieldByLabel('Placa / Identificação *'), 'ABC1D23');
    await tester.enterText(_fieldByLabel('Cor (opcional)'), 'Prata');
    await tester.pump();
    await _next(tester);

    // Passo 3 — Detalhes: relato + responsável (obrigatórios).
    await tester.enterText(
        _fieldByLabel('Relato do cliente *'), 'Barulho no motor');
    await tester.pump();
    await _selectResponsavel(tester);

    final createBtn =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Criar OS'));
    expect(createBtn.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(NeuButton, 'Criar OS'));
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
    expect(find.text('Cliente *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente existente: preenche obrigatórios e cria', (tester) async {
    final fake = FakeOsRepository(
      customers: const [CustomerOption(id: 'c1', name: 'João da Silva')],
    );
    await _openDialog(tester, fake);

    // Passo 1 — Cliente: escolhe um cliente existente.
    await tester.enterText(_fieldByLabel('Cliente *'), 'João');
    await tester.pumpAndSettle();
    await tester.tap(find.text('João da Silva').last);
    await tester.pumpAndSettle();

    final enabledNext =
        tester.widget<NeuButton>(find.widgetWithText(NeuButton, 'Próximo'));
    expect(enabledNext.onPressed, isNotNull);
    await _next(tester);

    // Passo 2 — Veículo: cliente sem veículos cadastrados; segue direto.
    await _next(tester);

    // Passo 3 — Detalhes: relato e responsável são obrigatórios.
    await tester.enterText(
        _fieldByLabel('Relato do cliente *'), 'Revisão geral');
    await tester.pump();
    await _selectResponsavel(tester);

    await tester.tap(find.widgetWithText(NeuButton, 'Criar OS'));
    await tester.pumpAndSettle();

    final page = await fake.listOrders();
    expect(page.items, hasLength(1));
    expect(page.items.first.customerId, 'c1');
  });
}
