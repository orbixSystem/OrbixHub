import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/customers_models.dart';
import 'customer_form_dialog.dart';
import 'customers_providers.dart';

/// Lista de clientes — adaptativa (spec 2026-07-04): desktop = linhas densas +
/// paginação numerada; mobile = cards + pull-to-refresh + infinite scroll +
/// FAB "Novo cliente". Corpo apenas — a moldura é do shell.
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

  /// Infinite scroll (mobile): dispara o próximo lote perto do fim.
  void _onScroll() {
    if (!_scroll.hasClients || !mounted || !context.isMobile) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(customersListProvider.notifier).loadMore();
    }
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('customer.write') ?? false;
  }

  Future<void> _create() async {
    final config =
        ref.read(customersConfigProvider).value ?? const CustomersConfig();
    final ok = await CustomerFormDialog.show(
      context,
      documentRequired: config.documentRequired,
    );
    if (ok != null) ref.invalidate(customersListProvider);
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
              label: const Text('Novo cliente'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // _Toolbar e _Body montam o próprio layout por dentro, então marcar
            // os dois inteiros dá holofote válido em desktop E mobile.
            CoachTarget(
              'clientes.filtros',
              child: _Toolbar(
                search: _search,
                canWrite: canWrite,
                onCreate: _create,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CoachTarget(
                'clientes.lista',
                child: _Body(
                  scroll: _scroll,
                  canWrite: canWrite,
                  onCreate: _create,
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
    final query = ref.watch(customerListQueryProvider);
    final notifier = ref.read(customerListQueryProvider.notifier);
    final isMobile = context.isMobile;

    final archivedToggle = InkWell(
      onTap: () => notifier.setShowArchived(!query.showArchived),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: query.showArchived ? neu.navy : neu.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: query.showArchived ? null : neu.raised(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              query.showArchived ? Icons.archive : Icons.archive_outlined,
              size: 16,
              color: query.showArchived ? neu.onNavy : neu.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Arquivados',
              style: TextStyle(
                color: query.showArchived ? neu.onNavy : neu.inkMuted,
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
            hint: 'Buscar cliente',
            controller: search,
            onChanged: notifier.setQuery,
          ),
          const SizedBox(height: 10),
          Row(children: [archivedToggle, const Spacer(), sortMenu]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: NeuSearchBar(
              hint: 'Buscar cliente',
              controller: search,
              onChanged: notifier.setQuery,
            ),
          ),
        ),
        const SizedBox(width: 12),
        archivedToggle,
        const SizedBox(width: 12),
        sortMenu,
        if (canWrite) ...[
          const SizedBox(width: 12),
          NeuButton(
            label: 'Novo cliente',
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
        ],
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.scroll,
    required this.canWrite,
    required this.onCreate,
  });

  final ScrollController scroll;
  final bool canWrite;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(customersListProvider);
    final isMobile = context.isMobile;

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e is AppException ? e.message : 'Erro ao carregar clientes.'),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(customersListProvider),
            ),
          ],
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return NeuEmptyState(
            icon: Icons.group_outlined,
            title: 'Nenhum cliente encontrado',
            message:
                'Cadastre seu primeiro cliente para poder abrir ordens de serviço e acompanhar o histórico dele.',
            actionLabel: canWrite ? 'Cadastrar cliente' : null,
            onAction: canWrite ? onCreate : null,
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
            final c = page.items[i];
            return _CustomerTile(
              customer: c,
              canWrite: canWrite,
              dense: !isMobile,
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

        if (isMobile) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customersListProvider),
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
              onPage: (p) =>
                  ref.read(customersListProvider.notifier).goToPage(p),
            ),
          ],
        );
      },
    );
  }
}

class _CustomerTile extends ConsumerWidget {
  const _CustomerTile({
    required this.customer,
    required this.canWrite,
    required this.dense,
    required this.onOpen,
    required this.onArchiveToggle,
  });

  final Customer customer;
  final bool canWrite;
  final bool dense;
  final VoidCallback onOpen;
  final Future<void> Function() onArchiveToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final subtitle = [
      if (customer.document != null) customer.document!,
      if (customer.phone != null) customer.phone!,
    ].join(' · ');
    final archived = customer.status == 'archived';
    final initial = customer.name.isNotEmpty
        ? customer.name.characters.first.toUpperCase()
        : '?';
    // Cor estável por cliente (primeira letra) — avatares coloridos e
    // consistentes entre sessões.
    final color = neu.glyphs[initial.codeUnitAt(0) % neu.glyphs.length];

    return NeuListTile(
      dense: dense,
      onTap: onOpen,
      leading: Container(
        width: dense ? 40 : 44,
        height: dense ? 40 : 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(customer.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (archived)
            NeuStatusChip(
              label: 'Arquivado',
              color: neu.inkMuted,
              tint: neu.inkMuted.withValues(alpha: .14),
            ),
          if (canWrite) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: archived ? 'Desarquivar' : 'Arquivar',
              icon: Icon(
                archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                size: 20,
                color: neu.inkMuted,
              ),
              onPressed: onArchiveToggle,
            ),
          ],
          Icon(Icons.chevron_right, color: neu.inkFaint, size: 20),
        ],
      ),
    );
  }
}

/// Menu de ordenação neumórfico.
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
    final neu = context.neu;
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
