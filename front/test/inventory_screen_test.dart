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

/// Filtros já "sujos" na montagem da tela — reproduz o cenário real: o provider
/// de filtros não é autoDispose, então quem volta para o Estoque reencontra a
/// busca de antes.
class _PresetQuery extends ItemListQueryNotifier {
  _PresetQuery(this._initial);
  final ItemListQuery _initial;
  @override
  ItemListQuery build() => _initial;
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

  group('filtro invisível', () {
    test('hasHidingFilters ignora o padrão da tela e a ordenação', () {
      expect(const ItemListQuery().hasHidingFilters, isFalse);
      expect(
        const ItemListQuery(sort: ItemSort.priceDesc).hasHidingFilters,
        isFalse,
      );
      expect(const ItemListQuery(q: 'gás').hasHidingFilters, isTrue);
      expect(const ItemListQuery(lowStock: true).hasHidingFilters, isTrue);
      expect(const ItemListQuery(kind: 'product').hasHidingFilters, isTrue);
      expect(const ItemListQuery(active: 'false').hasHidingFilters, isTrue);
    });

    test('clearFilters zera o que esconde e preserva a ordenação', () {
      final container = ProviderContainer(
        overrides: [
          inventoryRepositoryProvider
              .overrideWithValue(FakeInventoryRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(itemListQueryProvider.notifier);
      notifier.setQuery('gás');
      notifier.setLowStock(true);
      notifier.setKind('product');
      notifier.setSort(ItemSort.priceDesc);
      expect(container.read(itemListQueryProvider).hasHidingFilters, isTrue);

      notifier.clearFilters();
      final q = container.read(itemListQueryProvider);
      expect(q.hasHidingFilters, isFalse);
      expect(q.q, isNull);
      expect(q.lowStock, isFalse);
      expect(q.kind, isNull);
      expect(q.sort, ItemSort.priceDesc); // ordenar não esconde nada
    });

    testWidgets('busca retida do provider aparece na caixa ao montar a tela',
        (tester) async {
      final fake = FakeInventoryRepository();
      await fake.createItem(const ItemDraft(name: 'Pastilha', unit: 'un'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fake),
            sessionControllerProvider.overrideWith(_FakeSession.new),
            itemListQueryProvider.overrideWith(
              () => _PresetQuery(const ItemListQuery(q: 'ZZZ')),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: InventoryScreen())),
        ),
      );
      await tester.pumpAndSettle();

      // O termo que está filtrando precisa estar VISÍVEL na caixa de busca.
      expect(find.widgetWithText(TextField, 'ZZZ'), findsOneWidget);
    });

    testWidgets('lista vazia por filtro avisa e o botão devolve os itens',
        (tester) async {
      final fake = FakeInventoryRepository();
      await fake.createItem(const ItemDraft(name: 'Pastilha', unit: 'un'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider.overrideWithValue(fake),
            sessionControllerProvider.overrideWith(_FakeSession.new),
            itemListQueryProvider.overrideWith(
              () => _PresetQuery(const ItemListQuery(q: 'ZZZ')),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: InventoryScreen())),
        ),
      );
      await tester.pumpAndSettle();

      // Nada casa com "ZZZ": a tela precisa culpar o filtro, não a cliente.
      expect(find.text('Nenhum item com os filtros ativos'), findsOneWidget);
      expect(find.text('Nenhum item encontrado'), findsNothing);
      expect(find.text('Pastilha'), findsNothing);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Pastilha'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'ZZZ'), findsNothing);
    });

    testWidgets('estoque realmente vazio mantém o convite a cadastrar',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryRepositoryProvider
                .overrideWithValue(FakeInventoryRepository()),
            sessionControllerProvider.overrideWith(_FakeSession.new),
          ],
          child: const MaterialApp(home: Scaffold(body: InventoryScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum item encontrado'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsNothing);
    });
  });
}
