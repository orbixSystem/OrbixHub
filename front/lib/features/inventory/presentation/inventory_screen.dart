import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';
import 'item_detail_screen.dart';
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

/// Lista de produtos com busca, filtro de baixo estoque, criar e abrir detalhe.
/// Corpo apenas — a moldura é do shell.
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
    final canWrite = _canWrite();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Só estoque baixo'),
                avatar: Icon(
                  query.lowStock
                      ? Icons.warning_amber_rounded
                      : Icons.warning_amber_outlined,
                  size: 18,
                ),
                selected: query.lowStock,
                onSelected: (v) =>
                    ref.read(itemListQueryProvider.notifier).setLowStock(v),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar produto',
                  ),
                  onChanged: (v) =>
                      ref.read(itemListQueryProvider.notifier).setQuery(v),
                ),
              ),
              if (canWrite)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo item'),
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
                  itemBuilder: (_, i) {
                    final item = page.items[i];
                    return _ItemTile(
                      item: item,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ItemDetailScreen(itemId: item.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onOpen});

  final InventoryItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final low = isLowStock(item);
    final unit = item.unit == null || item.unit!.isEmpty ? '' : ' ${item.unit}';
    final subtitle =
        'Estoque: ${item.currentStock}$unit · ${money(item.salePrice)}';
    return ListTile(
      onTap: onOpen,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: AppColors.brandDeep,
          size: 22,
        ),
      ),
      title: Text(item.name),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (low)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.brandDeep,
              ),
              backgroundColor: AppColors.brandTint,
              side: const BorderSide(color: AppColors.brand),
              label: const Text(
                'Baixo',
                style: TextStyle(
                  color: AppColors.brandDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (!item.isActive) ...[
            const SizedBox(width: 6),
            Chip(
              visualDensity: VisualDensity.compact,
              label: const Text('Arquivado'),
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
