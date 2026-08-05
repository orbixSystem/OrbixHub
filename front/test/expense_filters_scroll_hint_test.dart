import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/expenses/data/fake_expenses_repository.dart';
import 'package:orbixhub_front/features/expenses/presentation/expenses_providers.dart';
import 'package:orbixhub_front/features/expenses/presentation/expenses_screen.dart';

/// Os filtros de despesa rolam para o lado no mobile ("Vencidas" e "Pagas"
/// ficam fora da tela), mas nada indicava isso — o usuário só descobria por
/// acidente. Uma seta na borda direita avisa; ela some perto do fim da lista
/// (não há mais nada para descobrir) e reaparece se o usuário voltar.
void main() {
  Future<void> montar(WidgetTester tester, {double largura = 360}) async {
    final repo = FakeExpensesRepository(hoje: DateTime(2026, 8, 15));
    tester.view.physicalSize = Size(largura, 800);
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

  testWidgets('mostra a seta quando há filtro escondido fora da tela',
      (tester) async {
    await montar(tester);
    expect(find.byIcon(Icons.keyboard_double_arrow_right_rounded), findsOneWidget);
  });

  testWidgets('some ao rolar até o fim da lista de filtros', (tester) async {
    await montar(tester);
    expect(find.byIcon(Icons.keyboard_double_arrow_right_rounded), findsOneWidget);

    // Arrasta bem além do necessário — o fim da lista chega antes.
    // "Todas" vem com contagem ("Todas (10)"), daí `textContaining`.
    await tester.drag(
      find.textContaining('Todas').first,
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_double_arrow_right_rounded), findsNothing);
  });

  testWidgets('tela larga o bastante para caber tudo não mostra a seta',
      (tester) async {
    await montar(tester, largura: 1200);
    expect(find.byIcon(Icons.keyboard_double_arrow_right_rounded), findsNothing);
  });
}
