import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import 'order_form_dialog.dart';
import 'os_providers.dart';
import 'os_status.dart';
import 'payment_status.dart';

/// Lista de ordens de serviço — adaptativa (spec 2026-07-04):
/// desktop = linhas densas + paginação numerada; mobile = cards grandes +
/// pull-to-refresh + infinite scroll + FAB "Nova OS".
/// Corpo apenas — a moldura é do shell.
class OsListScreen extends ConsumerStatefulWidget {
  const OsListScreen({super.key});

  @override
  ConsumerState<OsListScreen> createState() => _OsListScreenState();
}

class _OsListScreenState extends ConsumerState<OsListScreen> {
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
      ref.read(orderListProvider.notifier).loadMore();
    }
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('os.write') ?? false;
  }

  Future<void> _create() async {
    final ok = await OrderFormDialog.show(context);
    if (ok is String) {
      ref.invalidate(orderListProvider);
      if (mounted) context.go('/m/os/$ok');
    }
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
              label: const Text('Nova OS'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              search: _search,
              canWrite: canWrite,
              onCreate: _create,
            ),
            const SizedBox(height: 16),
            Expanded(child: _Body(scroll: _scroll, onCreate: _create)),
          ],
        ),
      ),
    );
  }
}

/// Barra de filtros/ações: busca cavada + status + ordenar + templates +
/// "Nova OS" (desktop; no mobile a criação vira FAB).
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
    final query = ref.watch(orderListQueryProvider);
    final notifier = ref.read(orderListQueryProvider.notifier);
    final isMobile = context.isMobile;

    final statusChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _StatusChip(
            label: 'Todas',
            selected: query.status == null,
            onTap: () => notifier.setStatus(null),
          ),
          for (final s in osStatuses)
            _StatusChip(
              label: osStatusLabel(s),
              selected: query.status == s,
              onTap: () => notifier.setStatus(s),
            ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: NeuSearchBar(
                  hint: 'Buscar nº ou cliente',
                  controller: search,
                  onChanged: notifier.setQuery,
                ),
              ),
              const SizedBox(width: 10),
              _SortMenu(value: query.sort, onChanged: notifier.setSort),
            ],
          ),
          const SizedBox(height: 10),
          statusChips,
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
                  hint: 'Buscar nº ou cliente',
                  controller: search,
                  onChanged: notifier.setQuery,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _SortMenu(value: query.sort, onChanged: notifier.setSort),
            const SizedBox(width: 12),
            NeuButton(
              label: 'Templates',
              kind: NeuButtonKind.secondary,
              icon: Icons.dashboard_customize_outlined,
              onPressed: () => context.go('/m/os/templates'),
            ),
            if (canWrite) ...[
              const SizedBox(width: 12),
              NeuButton(
                label: 'Nova OS',
                icon: Icons.add_rounded,
                onPressed: onCreate,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        statusChips,
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? neu.navy : neu.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? null : neu.raised(),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? neu.onNavy : neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.scroll, required this.onCreate});

  final ScrollController scroll;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(orderListProvider);
    final isMobile = context.isMobile;

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e is AppException
                  ? e.message
                  : 'Erro ao carregar ordens de serviço.',
            ),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(orderListProvider),
            ),
          ],
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return NeuEmptyState(
            icon: Icons.build_outlined,
            title: 'Nenhuma OS encontrada',
            message:
                'Crie uma ordem de serviço para registrar o trabalho de um veículo — orçamento, peças e progresso ficam todos aqui.',
            actionLabel: 'Criar primeira OS',
            onAction: onCreate,
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
            final o = page.items[i];
            return _OrderTile(
              number: o.number,
              customerName: o.customerName,
              subjectLabel: o.subjectLabel,
              status: o.status,
              paymentStatus: o.paymentStatus,
              total: o.total,
              dense: !isMobile,
              onTap: () => context.go('/m/os/${o.id}'),
            );
          },
        );

        if (isMobile) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orderListProvider),
            child: list,
          );
        }

        // Desktop: lista + controles de página numerados.
        return Column(
          children: [
            Expanded(child: list),
            const SizedBox(height: 12),
            NeuPageControls(
              page: page.page,
              pageSize: page.pageSize,
              total: page.total,
              onPage: (p) =>
                  ref.read(orderListProvider.notifier).goToPage(p),
            ),
          ],
        );
      },
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.number,
    required this.customerName,
    required this.subjectLabel,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.dense,
    required this.onTap,
  });

  final String number;
  final String? customerName;
  final String? subjectLabel;
  final String status;
  final String paymentStatus;
  final String? total;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final subtitle = [
      if (customerName != null && customerName!.isNotEmpty) customerName!,
      if (subjectLabel != null && subjectLabel!.isNotEmpty) subjectLabel!,
    ].join(' · ');
    return NeuListTile(
      dense: dense,
      onTap: onTap,
      leading: NeuIconChip.glyph(
        context,
        icon: Icons.build_outlined,
        index: 1,
        size: dense ? 40 : 44,
      ),
      // OS criada offline (número provisório OS-P…) ganha o selo "pendente de
      // envio" — Wrap para não estourar o tile no mobile.
      title: isPendingOsNumber(number)
          ? Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(number),
                const PendingSyncBadge(dense: true),
              ],
            )
          : Text(number),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaymentTag(status: paymentStatus, dense: true),
          const SizedBox(width: 8),
          OsStatusChip(status: status),
          const SizedBox(width: 14),
          Text(
            money(total),
            style: TextStyle(
              color: neu.ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: neu.inkFaint, size: 20),
        ],
      ),
    );
  }
}

/// Menu de ordenação: gatilho neumórfico que abre a lista de opções.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final OsSort value;
  final ValueChanged<OsSort> onChanged;

  static IconData _iconFor(OsSort s) => switch (s) {
        OsSort.recent => Icons.schedule,
        OsSort.oldest => Icons.history,
        OsSort.numberAsc => Icons.sort,
        OsSort.numberDesc => Icons.sort,
        OsSort.customerAsc => Icons.sort_by_alpha,
        OsSort.customerDesc => Icons.sort_by_alpha,
        OsSort.totalDesc => Icons.trending_up,
        OsSort.totalAsc => Icons.trending_down,
        OsSort.status => Icons.flag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return PopupMenuButton<OsSort>(
      tooltip: 'Ordenar',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final s in OsSort.values)
          PopupMenuItem<OsSort>(
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
