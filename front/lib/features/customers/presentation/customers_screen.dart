import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/customers_models.dart';
import 'customer_form_dialog.dart';
import 'customers_providers.dart';

/// Lista de clientes com busca, criar/editar e arquivar. Corpo apenas — a
/// moldura (sidebar/título) é do shell.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Dispara o carregamento do próximo lote ao chegar perto do fim do scroll
  /// (300px antes do fundo) — o notifier ignora chamadas redundantes.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(customersListProvider.notifier).loadMore();
    }
  }

  bool _canWrite(WidgetRef ref) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('customer.write');
  }

  Future<void> _create() async {
    final config =
        ref.read(customersConfigProvider).value ?? const CustomersConfig();
    final ok = await CustomerFormDialog.show(
      context,
      documentRequired: config.documentRequired,
    );
    if (ok == true) ref.invalidate(customersListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(customersListProvider);
    final query = ref.watch(customerListQueryProvider);
    final notifier = ref.read(customerListQueryProvider.notifier);
    final canWrite = _canWrite(ref);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de ações: filtros à esquerda; novo + busca à direita. Wrap com
          // spaceBetween reflui em telas estreitas sem Spacer.
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
                  // Toggle: mostra/oculta os arquivados (off = só ativos).
                  FilterChip(
                    label: const Text('Arquivados'),
                    avatar: Icon(
                      query.showArchived
                          ? Icons.archive
                          : Icons.archive_outlined,
                      size: 18,
                    ),
                    selected: query.showArchived,
                    onSelected: notifier.setShowArchived,
                  ),
                  _SortMenu(
                    value: query.sort,
                    onChanged: notifier.setSort,
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
                      // Global filled-button theme uses Size.fromHeight(50)
                      // (width = infinity); pin a finite min width when in a Row.
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Novo cliente'),
                    ),
                  // Busca compacta, à direita.
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Buscar cliente',
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
                child: Text(
                  e is AppException ? e.message : 'Erro ao carregar clientes.',
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(child: Text('Nenhum cliente encontrado.'));
                }
                // +1 slot para o rodapé (loader do próximo lote ou "fim da lista").
                return ListView.separated(
                  controller: _scroll,
                  itemCount: page.items.length + 1,
                  separatorBuilder: (_, i) => i >= page.items.length - 1
                      ? const SizedBox.shrink()
                      : const Divider(height: 1),
                  itemBuilder: (_, i) {
                    if (i >= page.items.length) {
                      return _ListFooter(
                        loadingMore: page.loadingMore,
                        hasMore: page.hasMore,
                        total: page.total,
                      );
                    }
                    final c = page.items[i];
                    return _CustomerTile(
                      customer: c,
                      canWrite: canWrite,
                      onOpen: () => context.go('/m/customers/${c.id}'),
                      onArchiveToggle: () async {
                        final repo = ref.read(customersRepositoryProvider);
                        if (c.status == 'archived') {
                          await repo.unarchiveCustomer(c.id);
                        } else {
                          await repo.archiveCustomer(c.id);
                        }
                        ref.invalidate(customersListProvider);
                      },
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

/// Menu de ordenação: gatilho estilo botão (ícone + rótulo atual) que abre a
/// lista de opções. Marca a opção selecionada com um check tangerina.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final CustomerSort value;
  final ValueChanged<CustomerSort> onChanged;

  static IconData _iconFor(CustomerSort s) => switch (s) {
        CustomerSort.recent => Icons.schedule,
        CustomerSort.oldest => Icons.history,
        CustomerSort.nameAsc => Icons.sort_by_alpha,
        CustomerSort.nameDesc => Icons.sort_by_alpha,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<CustomerSort>(
      tooltip: 'Ordenar',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final s in CustomerSort.values)
          PopupMenuItem<CustomerSort>(
            value: s,
            child: Row(
              children: [
                Icon(_iconFor(s), size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(s.label)),
                if (s == value)
                  const Icon(Icons.check, size: 18, color: AppColors.brand),
              ],
            ),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(value.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Rodapé da lista: spinner enquanto busca o próximo lote; convite a rolar quando
/// há mais; contagem total quando tudo foi carregado.
class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.loadingMore,
    required this.hasMore,
    required this.total,
  });

  final bool loadingMore;
  final bool hasMore;
  final int total;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
    );
    final Widget child;
    if (loadingMore) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (hasMore) {
      child = Text('Role para carregar mais', style: style);
    } else {
      child = Text(
        '$total ${total == 1 ? 'cliente' : 'clientes'} no total',
        style: style,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(child: child),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.canWrite,
    required this.onOpen,
    required this.onArchiveToggle,
  });

  final Customer customer;
  final bool canWrite;
  final VoidCallback onOpen;
  final Future<void> Function() onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (customer.document != null) customer.document!,
      if (customer.phone != null) customer.phone!,
    ].join(' · ');
    final archived = customer.status == 'archived';
    return ListTile(
      onTap: onOpen,
      leading: CircleAvatar(
        child: Text(customer.name.isNotEmpty
            ? customer.name.characters.first.toUpperCase()
            : '?'),
      ),
      title: Text(customer.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (archived)
            const Chip(label: Text('Arquivado'), visualDensity: VisualDensity.compact),
          if (canWrite)
            IconButton(
              tooltip: archived ? 'Desarquivar' : 'Arquivar',
              icon: Icon(archived ? Icons.unarchive_outlined : Icons.archive_outlined),
              onPressed: onArchiveToggle,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
