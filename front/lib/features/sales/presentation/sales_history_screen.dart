import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../os/presentation/os_status.dart' show money;
import '../domain/sale_models.dart';
import 'sale_providers.dart';
import 'sale_status.dart';

/// Histórico de vendas — adaptativo: desktop = linhas densas + paginação
/// numerada; mobile = cards + pull-to-refresh + infinite scroll. Filtro de
/// status no topo e botão grande "Nova venda". Corpo apenas — a moldura é do
/// shell.
class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
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
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || !mounted || !context.isMobile) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(saleListProvider.notifier).loadMore();
    }
  }

  bool _canSell(WidgetRef ref) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('cashier.write');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final canSell = _canSell(ref);

    return Scaffold(
      backgroundColor: Colors.transparent,
      // FAB grande no mobile: caminho de 1 toque para a venda.
      floatingActionButton: (canSell && isMobile)
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/m/sales/nova'),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Nova venda'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vendas',
                    style: TextStyle(
                      color: context.neu.ink,
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                // No desktop, o botão fica no cabeçalho (sem FAB flutuante).
                if (canSell && !isMobile)
                  NeuButton(
                    label: 'Nova venda',
                    icon: Icons.add_shopping_cart_rounded,
                    onPressed: () => context.go('/m/sales/nova'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _StatusFilterBar(),
            const SizedBox(height: 16),
            Expanded(child: _Body(scroll: _scroll, canSell: canSell)),
          ],
        ),
      ),
    );
  }
}

/// Barra de filtro de status: rolagem horizontal de chips (Todas/Concluídas/…).
class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(saleStatusFilterProvider);
    final notifier = ref.read(saleStatusFilterProvider.notifier);
    final neu = context.neu;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in SaleStatusFilter.values) ...[
            if (f.index > 0) const SizedBox(width: 8),
            InkWell(
              onTap: () => notifier.set(f),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: f == selected ? neu.navy : neu.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: f == selected ? null : neu.raised(),
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    color: f == selected ? neu.onNavy : neu.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.scroll, required this.canSell});

  final ScrollController scroll;
  final bool canSell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(saleListProvider);
    final isMobile = context.isMobile;

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e is AppException ? e.message : 'Erro ao carregar as vendas.',
            ),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(saleListProvider),
            ),
          ],
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return NeuEmptyState(
            icon: Icons.point_of_sale_outlined,
            title: 'Nenhuma venda ainda',
            message: canSell
                ? 'Toque em "Nova venda" para registrar a primeira venda no '
                    'balcão. É rápido: busque o produto, escolha o pagamento e '
                    'pronto.'
                : 'Quando alguém do caixa registrar uma venda, ela aparece aqui.',
            actionLabel: canSell ? 'Nova venda' : null,
            onAction: canSell ? () => context.go('/m/sales/nova') : null,
          );
        }

        final list = ListView.separated(
          controller: scroll,
          padding: EdgeInsets.only(bottom: isMobile ? 90 : 8),
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
            final sale = page.items[i];
            return _SaleTile(
              sale: sale,
              dense: !isMobile,
              onOpen: () => context.go('/m/sales/${sale.id}'),
            );
          },
        );

        if (isMobile) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(saleListProvider),
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
              onPage: (p) => ref.read(saleListProvider.notifier).goToPage(p),
            ),
          ],
        );
      },
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.dense,
    required this.onOpen,
  });

  final Sale sale;
  final bool dense;
  final VoidCallback onOpen;

  String get _title {
    final n = sale.number;
    return (n == null || n.isEmpty) ? 'Venda' : 'Venda nº $n';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final date = saleFmtDate(sale.createdAt);
    final customer = (sale.customerName ?? '').isNotEmpty
        ? sale.customerName!
        : 'Consumidor final';
    final subtitleParts = <String>[
      customer,
      if (date.isNotEmpty) date,
      paymentMethodLabel(sale.paymentMethod),
    ];
    final color = saleStatusColor(context, sale.status);

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
        child: Icon(
          paymentMethodIcon(sale.paymentMethod),
          size: 20,
          color: color,
        ),
      ),
      title: Text(_title),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money(sale.total),
            style: TextStyle(
              color: neu.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 10),
          SaleStatusChip(status: sale.status),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: neu.inkFaint, size: 20),
        ],
      ),
    );
  }
}
