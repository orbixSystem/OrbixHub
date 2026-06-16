import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/domain/inventory_models.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_screen.dart';

/// Session controller fixo (autenticado) para isolar o teste de canais de
/// plataforma (secure storage) que o controller real toca no bootstrap.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'A'),
          role: 'owner',
          permissions: ['inventory.write'],
          modules: ['inventory'],
        ),
      );
}

void main() {
  testWidgets('lista mostra item e badge de estoque baixo', (tester) async {
    final fake = FakeInventoryRepository();
    // Produto com mínimo 5 e saldo 0 → estoque baixo.
    await fake.createItem(
      const ItemDraft(kind: 'product', name: 'Pastilha', unit: 'un', minQty: 5),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryRepositoryProvider.overrideWithValue(fake),
          sessionControllerProvider.overrideWith(_FakeSession.new),
        ],
        child: const MaterialApp(home: Scaffold(body: InventoryScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pastilha'), findsOneWidget);
    expect(find.text('Baixo'), findsOneWidget);
  });
}
