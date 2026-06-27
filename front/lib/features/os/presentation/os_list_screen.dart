import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import 'order_form_dialog.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Lista de ordens de serviço: barra com filtro de status + busca + "Nova OS"
/// (gated `os.write`); linhas com nº, cliente, veículo, status (chip colorido)
/// e total. Toca → detalhe. Corpo apenas — a moldura é do shell.
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

  /// Dispara o carregamento do próximo lote ao chegar perto do fim do scroll
  /// (300px antes do fundo) — o notifier ignora chamadas redundantes.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(orderListProvider.notifier).loadMore();
    }
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('os.write');
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
    final listAsync = ref.watch(orderListProvider);
    final query = ref.watch(orderListQueryProvider);
    final notifier = ref.read(orderListQueryProvider.notifier);
    final canWrite = _canWrite();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Filtro de status: "Todas" + os 7 status, como chips.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: query.status == null,
                    onSelected: (_) => notifier.setStatus(null),
                  ),
                  for (final s in osStatuses)
                    ChoiceChip(
                      label: Text(osStatusLabel(s)),
                      selected: query.status == s,
                      onSelected: (_) => notifier.setStatus(s),
                    ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _SortMenu(
                    value: query.sort,
                    onChanged: notifier.setSort,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48)),
                    onPressed: () => context.go('/m/os/templates'),
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('Templates'),
                  ),
                  if (canWrite)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Nova OS'),
                    ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Buscar nº ou cliente',
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
                          : 'Erro ao carregar ordens de serviço.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40)),
                      onPressed: () => ref.invalidate(orderListProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(
                      child: Text('Nenhuma ordem de serviço encontrada.'));
                }
                // +1 slot para o rodapé (loader do próximo lote ou "fim da lista").
                return ListView.separated(
                  controller: _scroll,
                  itemCount: page.items.length + 1,
                  separatorBuilder: (_, i) => i >= page.items.length - 1
                      ? const SizedBox.shrink()
                      : const Divider(height: 1),
                  itemBuilder: (_, i) {
                    if (i < page.items.length) {
                      final o = page.items[i];
                      return _OrderTile(
                        number: o.number,
                        customerName: o.customerName,
                        subjectLabel: o.subjectLabel,
                        status: o.status,
                        total: o.total,
                        onTap: () => context.go('/m/os/${o.id}'),
                      );
                    }
                    return _ListFooter(
                      loadingMore: page.loadingMore,
                      hasMore: page.hasMore,
                      shown: page.items.length,
                      total: page.total,
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

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.number,
    required this.customerName,
    required this.subjectLabel,
    required this.status,
    required this.total,
    required this.onTap,
  });

  final String number;
  final String? customerName;
  final String? subjectLabel;
  final String status;
  final String? total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (customerName != null && customerName!.isNotEmpty) customerName!,
      if (subjectLabel != null && subjectLabel!.isNotEmpty) subjectLabel!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
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
              child: const Icon(Icons.build_outlined,
                  color: AppColors.brandDeep, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            OsStatusChip(status: status),
            const SizedBox(width: 16),
            Text(
              money(total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Menu de ordenação: gatilho estilo botão (ícone + rótulo atual) que abre a
/// lista de opções. Marca a opção selecionada com um check tangerina.
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
    final scheme = Theme.of(context).colorScheme;
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
    required this.shown,
    required this.total,
  });

  final bool loadingMore;
  final bool hasMore;
  final int shown;
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
      child = Text('$total OS no total', style: style);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(child: child),
    );
  }
}
