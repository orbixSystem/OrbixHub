import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';
import 'inventory_screen.dart' show money, isLowStock;
import 'item_form_dialog.dart';

const _maxContentWidth = 720.0;

/// Ficha do produto: cabeçalho + fatos (incl. campos da vertical). Empilhada via
/// Navigator.push. Sem histórico/movimentos — estoque é ajustado direto na edição.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  bool _canWrite(WidgetRef ref) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('inventory.write');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemProvider(itemId));

    return Scaffold(
      appBar: AppBar(title: const Text('Item')),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e is AppException ? e.message : 'Erro ao carregar item.',
          ),
        ),
        data: (item) {
          final canWrite = _canWrite(ref);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  _Header(
                    item: item,
                    canWrite: canWrite,
                    onEdit: () async {
                      final ok =
                          await ItemFormDialog.show(context, existing: item);
                      if (ok == true) ref.invalidate(itemProvider(itemId));
                    },
                    onArchiveToggle: () async {
                      final repo = ref.read(inventoryRepositoryProvider);
                      if (item.isActive) {
                        await repo.archiveItem(item.id);
                      } else {
                        await repo.unarchiveItem(item.id);
                      }
                      ref.invalidate(itemProvider(itemId));
                      ref.invalidate(itemListProvider);
                    },
                  ),
                  const SizedBox(height: 20),
                  _FactsCard(item: item),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.canWrite,
    required this.onEdit,
    required this.onArchiveToggle,
  });

  final InventoryItem item;
  final bool canWrite;
  final VoidCallback onEdit;
  final Future<void> Function() onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final archived = !item.isActive;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.brandDeep,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Produto',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isLowStock(item))
            const Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.brandDeep),
              backgroundColor: AppColors.brandTint,
              side: BorderSide(color: AppColors.brand),
              label: Text('Baixo',
                  style: TextStyle(
                      color: AppColors.brandDeep,
                      fontWeight: FontWeight.w700)),
            ),
          if (archived) ...[
            const SizedBox(width: 6),
            Chip(
              visualDensity: VisualDensity.compact,
              label: const Text('Arquivado'),
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ],
          if (canWrite) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: archived ? 'Desarquivar' : 'Arquivar',
              icon: Icon(archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined),
              onPressed: onArchiveToggle,
            ),
          ],
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = item.unit == null || item.unit!.isEmpty ? '' : ' ${item.unit}';
    final facts = <(IconData, String, String?)>[
      (Icons.sell_outlined, 'Preço de venda', money(item.salePrice)),
      if (item.costPrice != null)
        (Icons.payments_outlined, 'Custo', money(item.costPrice)),
      if (item.marginPct != null)
        (Icons.percent, 'Margem', '${item.marginPct}%'),
      (Icons.inventory_outlined, 'Estoque', '${item.currentStock}$unit'),
      if (item.minStock != null)
        (Icons.warning_amber_outlined, 'Mínimo', item.minStock),
      if (item.unit != null) (Icons.straighten, 'Unidade', item.unit),
      if (item.category != null)
        (Icons.category_outlined, 'Categoria', item.category),
      if (item.brand != null) (Icons.business_outlined, 'Marca', item.brand),
      if (item.sku != null) (Icons.tag, 'SKU', item.sku),
      if (item.manufacturerCode != null)
        (Icons.precision_manufacturing_outlined, 'Cód. fabricante',
            item.manufacturerCode),
      if (item.barcode != null)
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
