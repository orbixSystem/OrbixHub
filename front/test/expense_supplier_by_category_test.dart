import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/expenses/data/fake_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/presentation/expense_form_dialog.dart';
import 'package:orbixhub_front/features/expenses/presentation/expenses_providers.dart';

/// "Adicionar fornecedor" só onde existe fornecedor.
///
/// O campo aparecia em TODA despesa, inclusive Aluguel e Energia, onde a pergunta
/// não faz sentido. Quem sabe é a CATEGORIA (`tracksSupplier`) — e vem do banco,
/// não de uma lista fixa no app, porque a cliente cria as próprias categorias.
void main() {
  Future<void> abrirFormulario(WidgetTester tester) async {
    final repo = FakeExpensesRepository(hoje: DateTime(2026, 8, 15));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [expensesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => showExpenseFormDialog(ctx, ref),
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
    // Etapa 1: escolhe "Uma vez" para chegar aos campos.
    await tester.tap(find.text('Uma vez'));
    await tester.pumpAndSettle();
  }

  /// O diálogo ROLA, e os chips de categoria ficam abaixo da dobra: `tap` num
  /// widget fora da viewport toca no vazio e não faz nada — silenciosamente.
  Future<void> escolherCategoria(WidgetTester t, String nome) async {
    final chip = find.text(nome);
    await t.ensureVisible(chip);
    await t.pumpAndSettle();
    await t.tap(chip);
    await t.pumpAndSettle();
  }

  testWidgets('sem categoria escolhida, não pergunta fornecedor', (t) async {
    await abrirFormulario(t);
    // Sem categoria a pergunta não tem contexto — e o formulário abre assim.
    expect(find.text('FORNECEDOR'), findsNothing);
  });

  testWidgets('categoria SEM fornecedor (Aluguel) não mostra a seção', (t) async {
    await abrirFormulario(t);
    await escolherCategoria(t, 'Aluguel');
    expect(find.text('FORNECEDOR'), findsNothing);
    expect(find.text('CNPJ'), findsNothing);
  });

  testWidgets('categoria COM fornecedor (Fornecedor) mostra CNPJ e nome',
      (t) async {
    await abrirFormulario(t);
    await escolherCategoria(t, 'Fornecedor');
    expect(find.text('FORNECEDOR'), findsOneWidget);
    expect(find.text('CNPJ'), findsOneWidget);
    expect(find.text('Nome do fornecedor'), findsOneWidget);
  });

  testWidgets('Manutenção também tem fornecedor (peça e serviço de terceiro)',
      (t) async {
    await abrirFormulario(t);
    await escolherCategoria(t, 'Manutenção');
    expect(find.text('CNPJ'), findsOneWidget);
  });

  testWidgets('trocar para categoria sem fornecedor esconde de novo', (t) async {
    await abrirFormulario(t);
    await escolherCategoria(t, 'Fornecedor');
    expect(find.text('CNPJ'), findsOneWidget);
    // Toca na selecionada para limpar a categoria.
    await escolherCategoria(t, 'Fornecedor');
    expect(find.text('CNPJ'), findsNothing);
  });
}
