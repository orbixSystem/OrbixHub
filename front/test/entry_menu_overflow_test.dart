import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/cashier/presentation/entry_edit_dialogs.dart';

/// O menu de ações do lançamento tem de CABER: `PopupMenuItem` impõe altura de
/// 48px, e um item com título + subtítulo precisa de mais — daí o overflow.
/// Overflow faz o teste falhar sozinho, então abrir o menu já é a verificação.
void main() {
  testWidgets('menu de ações abre sem overflow no celular', (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: EntryActionsMenu(
              entry: CashEntry(
                id: 'e1',
                direction: 'out',
                amount: '50.00',
                method: 'pix',
                category: 'despesa',
                createdAt: '2026-08-03T12:00:00Z',
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Corrigir valor'), findsOneWidget);
    expect(find.text('Estornar'), findsOneWidget);
  });
}
