import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';
import 'item_form_dialog.dart';

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

/// Lista de produtos: barra de filtros (status + estoque baixo + busca + novo)
/// e linhas expansíveis com menu (editar/arquivar/excluir). Sem tela de detalhe
/// separada — a ficha do item abre inline. Corpo apenas — a moldura é do shell.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('inventory.write');
  }

  Future<void> _create() async {
    final ok = await ItemFormDialog.show(context);
    if (ok == true) ref.invalidate(itemListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(itemListProvider);
    final query = ref.watch(itemListQueryProvider);
    final notifier = ref.read(itemListQueryProvider.notifier);
    final canWrite = _canWrite();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de ações: filtros à esquerda; novo + busca à direita.
          // Dois clusters em um Wrap com spaceBetween — reflui em telas estreitas
          // sem Spacer (que exige um Flex, não cabe num Wrap).
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Todos')),
                      ButtonSegment(value: 'product', label: Text('Produtos')),
                      ButtonSegment(value: 'service', label: Text('Serviços')),
                    ],
                    selected: {query.kind ?? 'all'},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) => notifier
                        .setKind(sel.first == 'all' ? null : sel.first),
                  ),
                  FilterChip(
                    label: const Text('Só estoque baixo'),
                    avatar: Icon(
                      query.lowStock
                          ? Icons.warning_amber_rounded
                          : Icons.warning_amber_outlined,
                      size: 18,
                    ),
                    selected: query.lowStock,
                    onSelected: notifier.setLowStock,
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (canWrite)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Novo item'),
                    ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Buscar produto',
                      ),
                      onChanged: notifier.setQuery,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e is AppException
                          ? e.message
                          : 'Erro ao carregar itens.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40)),
                      onPressed: () => ref.invalidate(itemListProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(child: Text('Nenhum item encontrado.'));
                }
                return ListView.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _ItemTile(item: page.items[i], canWrite: canWrite),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha expansível de produto. O cabeçalho (menos o kebab) alterna a expansão;
/// o corpo expandido reusa a grade de fatos da antiga ficha de detalhe.
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onMenu(String action) async {
    switch (action) {
      case 'editar':
        final ok = await ItemFormDialog.show(context, existing: _item);
        if (ok == true) ref.invalidate(itemListProvider);
      case 'delete':
        await _delete();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir item'),
        content: Text(
          'Excluir "${_item.name}"? O item sai da lista '
          '(fica preservado no sistema).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isService
                        ? Icons.design_services_outlined
                        : Icons.inventory_2_outlined,
                    color: AppColors.brandDeep,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (low) ...[
                  const _LowChip(),
                  const SizedBox(width: 6),
                ],
                if (archived) ...[
                  _ArchivedChip(),
                  const SizedBox(width: 6),
                ],
                if (widget.canWrite)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline,
                              color: AppColors.danger),
                          title: Text(
                            'Excluir',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                    ],
                  ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.expand_more),
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
                  padding: const EdgeInsets.only(
                      left: 60, right: 4, bottom: 14, top: 2),
                  child: _FactsCard(item: item),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _LowChip extends StatelessWidget {
  const _LowChip();

  @override
  Widget build(BuildContext context) {
    return const Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.warning_amber_rounded,
          size: 16, color: AppColors.brandDeep),
      backgroundColor: AppColors.brandTint,
      side: BorderSide(color: AppColors.brand),
      label: Text(
        'Baixo',
        style: TextStyle(
          color: AppColors.brandDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ArchivedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: const Text('Arquivado'),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

/// Grade de fatos do item (preço, custo, margem, estoque, categoria, atributos
/// da vertical…). Reusa o visual tangerina da antiga ficha de detalhe.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
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
  const _FactTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
