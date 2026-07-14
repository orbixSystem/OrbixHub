import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../os/presentation/os_status.dart' show money;
import '../domain/invoice_models.dart';
import 'invoice_providers.dart';
import 'invoice_status.dart';

/// Lista de Notas Fiscais — adaptativa: desktop = linhas densas + paginação
/// numerada; mobile = cards + pull-to-refresh + infinite scroll. Filtro de
/// status no topo. Corpo apenas — a moldura é do shell.
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
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
      ref.read(invoiceListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    // Fiscal é online-only (emissão/consulta acontecem no servidor fiscal).
    if (ref.watch(isOfflineProvider)) {
      return const RequiresConnectionView(
        message: 'As notas fiscais são emitidas e consultadas no servidor '
            'fiscal. Conecte-se à internet para acessá-las.',
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Notas Fiscais',
              style: TextStyle(
                color: context.neu.ink,
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            const _StatusFilterBar(),
            const SizedBox(height: 16),
            Expanded(child: _Body(scroll: _scroll)),
          ],
        ),
      ),
    );
  }
}

/// Barra de filtro de status: rolagem horizontal de chips (Todas/Emitidas/…).
class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(invoiceStatusFilterProvider);
    final notifier = ref.read(invoiceStatusFilterProvider.notifier);
    final neu = context.neu;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in InvoiceStatusFilter.values) ...[
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
  const _Body({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(invoiceListProvider);
    final isMobile = context.isMobile;

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e is AppException ? e.message : 'Erro ao carregar as notas.'),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(invoiceListProvider),
            ),
          ],
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const NeuEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nenhuma nota ainda',
            message:
                'Emita a partir de uma OS na tela da Ordem de Serviço para '
                'ver as notas fiscais aqui.',
          );
        }

        final list = ListView.separated(
          controller: scroll,
          padding: EdgeInsets.only(bottom: isMobile ? 24 : 8),
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
            final inv = page.items[i];
            return _InvoiceTile(
              invoice: inv,
              dense: !isMobile,
              onOpen: () => context.go('/m/invoice/${inv.id}'),
            );
          },
        );

        if (isMobile) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(invoiceListProvider),
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
                  ref.read(invoiceListProvider.notifier).goToPage(p),
            ),
          ],
        );
      },
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.dense,
    required this.onOpen,
  });

  final Invoice invoice;
  final bool dense;
  final VoidCallback onOpen;

  /// Título: "Nº 42 · Série 1" quando emitida; senão "Rascunho".
  String get _title {
    final n = invoice.number;
    if (n == null || n.isEmpty) {
      return invoice.status == 'draft'
          ? 'Rascunho'
          : invoiceDocumentTypeLabel(invoice.documentType);
    }
    final series = invoice.series;
    return series == null || series.isEmpty
        ? 'Nº $n'
        : 'Nº $n · Série $series';
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final date = _fmtDate(invoice.createdAt);
    final subtitleParts = <String>[
      if ((invoice.orderNumber ?? '').isNotEmpty) invoice.orderNumber!,
      if ((invoice.customerName ?? '').isNotEmpty) invoice.customerName!,
      if (date.isNotEmpty) date,
    ];

    return NeuListTile(
      dense: dense,
      onTap: onOpen,
      leading: Container(
        width: dense ? 40 : 44,
        height: dense ? 40 : 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: invoiceStatusColor(context, invoice.status)
              .withValues(alpha: .16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.receipt_long_outlined,
          size: 20,
          color: invoiceStatusColor(context, invoice.status),
        ),
      ),
      title: Text(_title),
      subtitle:
          subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((invoice.totalAmount ?? '').isNotEmpty) ...[
            Text(
              money(invoice.totalAmount),
              style: TextStyle(
                color: neu.ink,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(width: 10),
          ],
          InvoiceStatusChip(status: invoice.status),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: neu.inkFaint, size: 20),
        ],
      ),
    );
  }
}
