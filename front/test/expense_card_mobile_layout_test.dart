import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/expenses/data/fake_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/presentation/expenses_providers.dart';
import 'package:orbixhub_front/features/expenses/presentation/expenses_screen.dart';

/// O card de despesa no MOBILE não pode cortar (nem esconder) o nome.
///
/// A causa raiz, achada medindo o widget de verdade (não adivinhando): a coluna
/// do valor é filha DIRETA de uma `Row` (sem `Expanded`), então ela recebe
/// largura NÃO LIMITADA para se medir. "R$ 2.500,00" em negrito 15,5pt mede
/// ~170px sozinho — quase o card inteiro num celular de 360px. Sem um teto, a
/// coluna da descrição ficava com 0px (o nome ficava INVISÍVEL, não só cortado)
/// e a `Row` ainda estourava por conta própria. **Não era um bug só de
/// parcela** — qualquer despesa com valor alto sofria, com ou sem parcelamento.
void main() {
  Future<void> montar(WidgetTester tester) async {
    final repo = FakeExpensesRepository(hoje: DateTime(2026, 8, 15));
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [expensesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ExpensesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nenhum card overflow em tela estreita (360px)', (tester) async {
    await montar(tester);
    // A régua do bug: nenhuma exceção de RenderFlex overflow, em NENHUM card
    // visível (a fake semeia valores de R$ 149 a R$ 8.400 — inclusive contas
    // sem parcelamento, que também sofriam com o valor grande sozinho).
    expect(tester.takeException(), isNull);
  });

  testWidgets('nome da despesa continua VISÍVEL (largura > 0), não só sem crash',
      (tester) async {
    await montar(tester);
    // "Aluguel do galpão" tem um valor alto (R$ 2.500,00) — era exatamente o
    // caso que zerava a largura da coluna do nome antes da correção. O piso de
    // 40px (não só ">0") guarda contra uma futura regressão que devolva SÓ
    // alguns pixels — visível tecnicamente, mas ilegível na prática.
    final nome = find.text('Aluguel do galpão');
    expect(nome, findsOneWidget);
    expect(tester.getSize(nome).width, greaterThan(40));
  });

  testWidgets('card parcelado (o caso relatado originalmente) também não corta',
      (tester) async {
    await montar(tester);
    // "Compressor de ar" só fica visível rolando até ele (mais abaixo na
    // fila de urgência) — é exatamente por isso que o bug geral só apareceu
    // ao rolar a lista de verdade, e não nos primeiros cards.
    await tester.dragUntilVisible(
      find.text('Compressor de ar').first,
      find.byType(ListView),
      const Offset(0, -80),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.text('Compressor de ar').first).width,
      greaterThan(40),
    );
    expect(find.text('2/6'), findsOneWidget);
  });
}
