import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';
import 'item_form_dialog.dart';
import 'simple_item_form_dialog.dart';

/// Formata um preço decimal serializado ("45.90") em "R$ 45,90". Null → "—".
String money(String? decimal) {
  if (decimal == null || decimal.trim().isEmpty) return '—';
  final v = double.tryParse(decimal);
  if (v == null) return '—';
  return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

/// Item está com estoque no/abaixo do mínimo.
bool isLowStock(InventoryItem i) {
  if (i.minStock == null) return false;
  final qty = double.tryParse(i.currentStock);
  final min = double.tryParse(i.minStock!);
  if (qty == null || min == null) return false;
  return qty <= min;
}

/// Lista de itens — adaptativa (spec 2026-07-04): desktop = linhas densas +
/// paginação numerada; mobile = cards + pull-to-refresh + infinite scroll +
/// FAB "Novo item". Linhas expansíveis com a ficha do item inline.
/// Corpo apenas — a moldura é do shell.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // `itemListQueryProvider` não é autoDispose: os filtros sobrevivem à saída
    // da tela (de propósito — voltar do detalhe mantém o contexto). Só que este
    // controller nasce vazio a cada montagem, e sem a linha abaixo a lista volta
    // filtrada por um termo que a caixa de busca não mostra. Foi assim que uma
    // cliente com 84 itens viu a tela vazia e achou que tinha perdido o estoque.
    final q = ref.read(itemListQueryProvider).q;
    if (q != null && q.isNotEmpty) {
      _search.value = TextEditingValue(
        text: q,
        selection: TextSelection.collapsed(offset: q.length),
      );
    }
  }

  /// Limpa busca e filtros de uma vez. Precisa mexer nos dois lados: o
  /// controller (o que ela vê) e o provider (o que a query usa) — limpar só um
  /// recria justamente a divergência que este conserto elimina.
  void _clearFilters() {
    _search.clear();
    ref.read(itemListQueryProvider.notifier).clearFilters();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Infinite scroll (mobile): dispara o próximo lote perto do fim.
  void _onScroll() {
    if (!_scroll.hasClients || !mounted || !context.isMobile) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(itemListProvider.notifier).loadMore();
    }
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('inventory.write') ?? false;
  }

  Future<void> _create() async {
    // Simples por padrão (nome, marca, descrição, preços, estoque) — o
    // completo (código de barras, fiscal, serviço) fica a um toque, dentro
    // dele ("Cadastro completo").
    final ok = await SimpleItemFormDialog.show(context);
    if (ok != null) ref.invalidate(itemListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _canWrite();
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isMobile && canWrite)
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: context.neu.navy,
              foregroundColor: context.neu.onNavy,
              icon: const Icon(Icons.add),
              label: const Text('Novo item'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoachTarget(
              'estoque.filtros',
              child: _Toolbar(
              search: _search,
              canWrite: canWrite,
              onCreate: _create,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CoachTarget(
                'estoque.lista',
                child: _Body(
                  scroll: _scroll,
                  canWrite: canWrite,
                  onClearFilters: _clearFilters,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.search,
    required this.canWrite,
    required this.onCreate,
  });

  final TextEditingController search;
  final bool canWrite;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final query = ref.watch(itemListQueryProvider);
    final notifier = ref.read(itemListQueryProvider.notifier);
    final isMobile = context.isMobile;

    final kindSegmented = NeuSegmented<String>(
      segments: const {
        'all': 'Todos',
        'product': 'Produtos',
        'service': 'Serviços',
      },
      selected: query.kind ?? 'all',
      onChanged: (v) => notifier.setKind(v == 'all' ? null : v),
    );

    final lowStockToggle = InkWell(
      onTap: () => notifier.setLowStock(!query.lowStock),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: query.lowStock ? neu.warning : neu.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: query.lowStock ? null : neu.raised(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              query.lowStock
                  ? Icons.warning_amber_rounded
                  : Icons.warning_amber_outlined,
              size: 16,
              color: query.lowStock ? Colors.white : neu.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Estoque baixo',
              style: TextStyle(
                color: query.lowStock ? Colors.white : neu.inkMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    final sortMenu = _SortMenu(value: query.sort, onChanged: notifier.setSort);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeuSearchBar(
            hint: 'Buscar produto ou serviço',
            controller: search,
            onChanged: notifier.setQuery,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                kindSegmented,
                const SizedBox(width: 8),
                lowStockToggle,
                const SizedBox(width: 8),
                sortMenu,
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: NeuSearchBar(
                  hint: 'Buscar produto ou serviço',
                  controller: search,
                  onChanged: notifier.setQuery,
                ),
              ),
            ),
            const SizedBox(width: 12),
            sortMenu,
            if (canWrite) ...[
              const SizedBox(width: 12),
              NeuButton(
                label: 'Novo item',
                icon: Icons.add_rounded,
                onPressed: onCreate,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            kindSegmented,
            const SizedBox(width: 12),
            lowStockToggle,
          ],
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.scroll,
    required this.canWrite,
    required this.onClearFilters,
  });

  final ScrollController scroll;
  final bool canWrite;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(itemListProvider);
    final hasHidingFilters = ref.watch(itemListQueryProvider).hasHidingFilters;
    final isMobile = context.isMobile;

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e is AppException ? e.message : 'Erro ao carregar itens.'),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(itemListProvider),
            ),
          ],
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          // Vazio por filtro e vazio de verdade são situações opostas: uma pede
          // para limpar a busca, a outra para cadastrar. Dizer "cadastre
          // produtos" a quem tem 84 itens escondidos por um filtro é o que faz
          // a pessoa achar que o sistema perdeu o trabalho dela.
          if (hasHidingFilters) {
            return NeuEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Nenhum item com os filtros ativos',
              message:
                  'Seus itens continuam cadastrados — a busca ou os filtros desta tela estão escondendo todos.',
              actionLabel: 'Limpar filtros',
              onAction: onClearFilters,
            );
          }
          return const NeuEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Nenhum item encontrado',
            message:
                'Cadastre produtos e serviços para usá-los nas ordens de serviço e controlar o estoque.',
          );
        }

        final list = ListView.separated(
          controller: scroll,
          padding: EdgeInsets.only(bottom: isMobile ? 88 : 8),
          itemCount: page.items.length + (isMobile ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (isMobile && i >= page.items.length) {
              return NeuListFooter(
                loading: page.loadingMore,
                hasMore: page.hasMore,
                total: page.total,
              );
            }
            return _ItemTile(item: page.items[i], canWrite: canWrite);
          },
        );

        if (isMobile) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(itemListProvider),
            child: list,
          );
        }

        return Column(
          children: [
            Expanded(child: list),
            const SizedBox(height: 12),
            NeuPageControls(
              page: page.page,
              pageSize: page.pageSize,
              total: page.total,
              onPage: (p) => ref.read(itemListProvider.notifier).goToPage(p),
            ),
          ],
        );
      },
    );
  }
}

/// Menu de ordenação neumórfico.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final ItemSort value;
  final ValueChanged<ItemSort> onChanged;

  static IconData _iconFor(ItemSort s) => switch (s) {
        ItemSort.nameAsc => Icons.sort_by_alpha,
        ItemSort.nameDesc => Icons.sort_by_alpha,
        ItemSort.priceDesc => Icons.trending_up,
        ItemSort.priceAsc => Icons.trending_down,
        ItemSort.stockDesc => Icons.expand_less,
        ItemSort.stockAsc => Icons.expand_more,
        ItemSort.recent => Icons.schedule,
      };

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return PopupMenuButton<ItemSort>(
      tooltip: 'Ordenar',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final s in ItemSort.values)
          PopupMenuItem<ItemSort>(
            value: s,
            child: Row(
              children: [
                Icon(_iconFor(s), size: 18, color: neu.inkMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(s.label)),
                if (s == value)
                  Icon(Icons.check, size: 18, color: neu.accent),
              ],
            ),
          ),
      ],
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: neu.inkMuted),
            if (!context.isMobile) ...[
              const SizedBox(width: 8),
              Text(
                value.label,
                style: TextStyle(
                  color: neu.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Icon(Icons.arrow_drop_down, color: neu.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Linha expansível de item. O cabeçalho (menos o kebab) alterna a expansão;
/// o corpo expandido mostra a grade de fatos do item.
class _ItemTile extends ConsumerStatefulWidget {
  const _ItemTile({required this.item, required this.canWrite});

  final InventoryItem item;
  final bool canWrite;

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  bool _expanded = false;

  InventoryItem get _item => widget.item;

  void _snack(String msg) {
    if (!mounted) return;
    showNeuErrorSnackBar(context, msg);
  }

  Future<void> _onMenu(String action) async {
    switch (action) {
      case 'editar':
        final ok = await ItemFormDialog.show(context, existing: _item);
        if (ok != null) ref.invalidate(itemListProvider);
      case 'delete':
        await _delete();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showNeuConfirm(
      context,
      title: 'Excluir item?',
      message:
          'Excluir "${_item.name}"? Ele sai da lista (fica preservado no '
          'sistema para histórico).',
      confirmLabel: 'Excluir',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(inventoryRepositoryProvider).deleteItem(_item.id);
      ref.invalidate(itemListProvider);
      _snack('Item excluído');
    } on AppException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final item = _item;
    final isService = item.kind == 'service';
    final low = isService ? false : isLowStock(item);
    final unit = item.unit == null || item.unit!.isEmpty ? '' : ' ${item.unit}';
    final duration = item.durationMinutes;
    final subtitle = isService
        ? 'Serviço · ${money(item.salePrice)}'
            '${duration != null ? ' · $duration min' : ''}'
        : 'Estoque: ${item.currentStock}$unit · ${money(item.salePrice)}';
    final archived = !item.isActive;

    return NeuCard(
      padding: EdgeInsets.zero,
      radius: NeuTokens.rField,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(NeuTokens.rField),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  NeuIconChip.glyph(
                    context,
                    icon: isService
                        ? Icons.design_services_outlined
                        : Icons.inventory_2_outlined,
                    index: isService ? 5 : 2,
                    size: 42,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: neu.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: neu.inkMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (low) ...[
                    NeuStatusChip(
                      label: 'Baixo',
                      color: neu.warning,
                      tint: neu.warningTint,
                      icon: Icons.warning_amber_rounded,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (archived) ...[
                    NeuStatusChip(
                      label: 'Arquivado',
                      color: neu.inkMuted,
                      tint: neu.inkMuted.withValues(alpha: .14),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (widget.canWrite)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: neu.inkMuted),
                      tooltip: 'Mais ações',
                      onSelected: _onMenu,
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading:
                                Icon(Icons.delete_outline, color: neu.danger),
                            title: Text(
                              'Excluir',
                              style: TextStyle(color: neu.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more, color: neu.inkFaint),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: _FactsCard(item: item),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Grade de fatos do item (preço, custo, margem, estoque, categoria, atributos
/// da vertical…) — cavada dentro do cartão expandido.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final isService = item.kind == 'service';
    final unit = item.unit == null || item.unit!.isEmpty ? '' : ' ${item.unit}';
    final facts = <(IconData, String, String?)>[
      (Icons.sell_outlined, 'Preço de venda', money(item.salePrice)),
      if (item.costPrice != null)
        (Icons.payments_outlined, 'Custo', money(item.costPrice)),
      if (item.marginPct != null)
        (Icons.percent, 'Margem', '${item.marginPct}%'),
      if (isService && item.durationMinutes != null)
        (Icons.schedule_outlined, 'Duração', '${item.durationMinutes} min'),
      if (!isService)
        (Icons.inventory_outlined, 'Estoque', '${item.currentStock}$unit'),
      if (!isService && item.minStock != null)
        (Icons.warning_amber_outlined, 'Mínimo', item.minStock),
      if (item.unit != null) (Icons.straighten, 'Unidade', item.unit),
      if (item.category != null)
        (Icons.category_outlined, 'Categoria', item.category),
      if (item.brand != null) (Icons.business_outlined, 'Marca', item.brand),
      if (item.sku != null) (Icons.tag, 'SKU', item.sku),
      if (!isService && item.manufacturerCode != null)
        (Icons.precision_manufacturing_outlined, 'Cód. fabricante',
            item.manufacturerCode),
      if (!isService && item.barcode != null)
        (Icons.qr_code_2, 'Cód. de barras', item.barcode),
      for (final entry in item.attributes.entries)
        (
          Icons.label_important_outline,
          entry.key,
          entry.value is List
              ? (entry.value as List).join(', ')
              : entry.value?.toString()
        ),
    ];
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (icon, label, value) in facts)
            if (value != null && value.isNotEmpty)
              _FactTile(icon: icon, label: label, value: value),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neu.surfaceHi,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: neu.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: neu.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: neu.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
