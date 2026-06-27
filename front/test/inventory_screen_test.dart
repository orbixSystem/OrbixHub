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

List<InventoryItem> _items(int n) => [
      for (var i = 0; i < n; i++)
        InventoryItem(
          id: 'id-${i.toString().padLeft(3, '0')}',
          name: 'Item ${i.toString().padLeft(3, '0')}',
          salePrice: (i + 1).toString(),
          currentStock: (n - i).toString(),
        ),
    ];

void main() {
  group('paginação (scroll infinito)', () {
    test('build traz só o 1º lote (20) e loadMore acumula até o fim', () async {
      final fake = FakeInventoryRepository(items: _items(45));
      final container = ProviderContainer(
        overrides: [inventoryRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      // 1º lote: 20 itens, há mais (total 45).
      final first = await container.read(itemListProvider.future);
      expect(first.items, hasLength(20));
      expect(first.total, 45);
      expect(first.hasMore, isTrue);

      // 2º lote → 40, ainda há mais.
      await container.read(itemListProvider.notifier).loadMore();
      final second = container.read(itemListProvider).requireValue;
      expect(second.items, hasLength(40));
      expect(second.hasMore, isTrue);

      // 3º lote → 45, acabou.
      await container.read(itemListProvider.notifier).loadMore();
      final third = container.read(itemListProvider).requireValue;
      expect(third.items, hasLength(45));
      expect(third.hasMore, isFalse);

      // loadMore além do fim é no-op.
      await container.read(itemListProvider.notifier).loadMore();
      expect(container.read(itemListProvider).requireValue.items, hasLength(45));
    });

    test('mudar ordenação reinicia da página 1 com a nova ordem', () async {
      final fake = FakeInventoryRepository(items: _items(45));
      final container = ProviderContainer(
        overrides: [inventoryRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      // Ordem padrão (nome A–Z): primeiro é Item 000.
      final asc = await container.read(itemListProvider.future);
      expect(asc.items.first.name, 'Item 000');

      // Maior preço: salePrice cresce com o índice → Item 044 primeiro.
      container.read(itemListQueryProvider.notifier).setSort(ItemSort.priceDesc);
      final desc = await container.read(itemListProvider.future);
      expect(desc.items.first.name, 'Item 044');
      expect(desc.items, hasLength(20)); // voltou ao 1º lote
    });
  });

  testWidgets('lista mostra produto e badge de estoque baixo', (tester) async {
    final fake = FakeInventoryRepository();
    // Produto com mínimo 5 e saldo 2 → estoque baixo.
    await fake.createItem(
      const ItemDraft(name: 'Pastilha', unit: 'un', minStock: 5, currentStock: 2),
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
