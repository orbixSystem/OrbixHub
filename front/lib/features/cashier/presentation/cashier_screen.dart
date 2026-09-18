import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../../expenses/presentation/expense_detail_dialog.dart';
import '../../os/presentation/os_detail_dialog.dart';
import '../../os/presentation/os_providers.dart';
import '../../receivables/domain/receivables_models.dart';
import '../../receivables/presentation/receivables_providers.dart';
import '../../receivables/presentation/receive_title_dialog.dart';
import '../../os/presentation/payment_status.dart';
import '../../sale/domain/sale_models.dart';
import '../../sale/presentation/sale_create_dialog.dart';
import '../../sale/presentation/sale_detail_dialog.dart';
import 'cashier_providers.dart';
import 'entry_edit_dialogs.dart';
import 'receive_picker_dialog.dart';

/// Modulo Caixa: tres abas — "Caixa" (dashboard do dia com balanco, movimentacoes,
/// pendentes e acoes rapidas), "Fiado" (contas a receber, agrupadas por cliente)
/// e "Historico" (movimentos por periodo — o relatorio do caixa). Quais aparecem
/// depende do papel: Fiado exige `cashier.read`, Historico e de gestao.
///
/// Corpo apenas — a moldura e do shell. UI so fala com o repository (via
/// controller). Visual 100% no design system neumorfico (`core/ui`), responsivo.
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Força refresh ao entrar na tela (garante dados frescos após navegação).
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(cashierControllerProvider);
      ref.invalidate(_pendingTitlesProvider);
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      ref.invalidate(cashierControllerProvider);
      ref.invalidate(_pendingTitlesProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('cashier.write') ?? false;
  }

  bool _canManage() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('cashier.manage') ?? false;
  }

  bool _canSale() {
    final s = ref.read(sessionControllerProvider);
    final me = s.meOrNull;
    return me != null && me.hasModule('sale') && me.hasPermission('sale.write');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OfflineScreenNotice(
              message:
                  'Você está offline. Os lançamentos são guardados neste '
                  'aparelho e só serão efetivados no sistema quando a conexão '
                  'voltar.',
            ),
            Expanded(child: _dayBody()),
          ],
        ),
      ),
    );
  }

  Widget _dayBody() {
    final async = ref.watch(cashierControllerProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorBox(
        message: '$e',
        onRetry: () => ref.invalidate(cashierControllerProvider),
      ),
      data: (state) {
        return _DashboardBody(
          state: state,
          canWrite: _canWrite(),
          canManage: _canManage(),
          canSale: _canSale(),
        );
      },
    );
  }
}

/// Abre o fluxo unico de venda avulsa (venda + recebimento/a receber + nota). O
/// proprio dialogo cuida de tudo e mostra o resultado; aqui so o disparamos.
Future<void> _startSale(BuildContext context, WidgetRef ref) async {
  await showSaleCreateDialog(context);
}

/// Hora local "HH:MM" de um timestamp ISO (vazio se nulo/ invalido).
String _fmtHora(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

/// Metrica no padrao do dashboard (valor grande em cima, rotulo embaixo).
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: color ?? neu.ink),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 12.5)),
      ],
    );
  }
}

/// Glyph de direcao do movimento: circulo tintado com seta (entrada/saida).
class _DirectionGlyph extends StatelessWidget {
  const _DirectionGlyph({required this.color, required this.isIn});
  static const size = 40.0;
  final Color color;
  final bool isIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
        size: size * .5,
        color: color,
      ),
    );
  }
}

// ===================== Dashboard do Caixa (layout de 2 colunas) =====================

/// Tipo do filtro local de movimentacoes na aba Caixa.
enum _MovFilter { tudo, entradas, saidas, pendentes }

/// Dashboard single-panel: duas colunas no desktop, empilhadas no mobile.
/// Coluna esquerda (60%): Balanco do dia + Movimentacoes.
/// Coluna direita (40%): OS Pendentes + Acoes Rapidas.
class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({
    required this.state,
    required this.canWrite,
    required this.canManage,
    required this.canSale,
  });

  final CashierState state;
  final bool canWrite;
  final bool canManage;
  final bool canSale;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  _MovFilter _movFilter = _MovFilter.tudo;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Quando o cashierController muda (novo lançamento, estorno), invalida
    // os pendentes pra manter tudo sincronizado.
    ref.listenManual(cashierControllerProvider, (_, _) {
      ref.invalidate(_pendingTitlesProvider);
    });
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Filtra as entries localmente conforme o chip selecionado e a busca textual.
  /// Quando "Pendentes" ou "Tudo", inclui OS pendentes (do provider) como
  /// entries virtuais para aparecerem na lista.
  List<CashEntry> _filteredEntries(List<ReceivableTitle> pendingTitles) {
    final entries = widget.state.entries;
    final existingSaleIds = entries
        .map((e) => e.saleId)
        .whereType<String>()
        .toSet();
    final virtualEntries = pendingTitles
        .where((t) => !existingSaleIds.contains(t.id))
        .map((t) {
          final prefix = t.origin == 'os' ? 'OS' : 'Venda';
          final name = (t.customerName ?? '').isNotEmpty ? ' — ${t.customerName}' : '';
          return CashEntry(
            id: 'pending-${t.id}',
            direction: 'pending',
            amount: '${t.balance}',
            method: '',
            category: t.origin == 'os' ? 'os_payment' : 'venda_avulsa',
            saleKind: t.origin,
            saleId: t.id,
            description: '$prefix ${t.number}$name',
          );
        })
        .toList();

    final List<CashEntry> byChip = switch (_movFilter) {
      _MovFilter.tudo => [...virtualEntries, ...entries],
      _MovFilter.entradas => entries.where((e) => e.direction == 'in').toList(),
      _MovFilter.saidas => entries.where((e) => e.direction == 'out').toList(),
      _MovFilter.pendentes => virtualEntries,
    };

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return byChip;

    return byChip.where((e) {
      if ((e.description ?? '').toLowerCase().contains(q)) return true;
      if (categoryLabel(e.category).toLowerCase().contains(q)) return true;
      final sale = widget.state.salesById[e.saleId];
      if ((sale?.customerName ?? '').toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final pendingTitles = ref.watch(_pendingTitlesProvider).value?.items ?? const [];
    final filtered = _filteredEntries(pendingTitles);

    final leftColumn = [
      // Alvos do tutorial. O redesign trocou a tela inteira e levou os três
      // junto — o tour do Caixa ficou apontando para o nada (`CoachTargets.live`
      // devolvendo null nos três). Só um `_MovimentacoesCard` fica montado por
      // vez (o mobile descarta o `Expanded`), então a GlobalKey não duplica.
      CoachTarget('caixa.balanco', child: _BalanceCard(state: widget.state)),
      const SizedBox(height: 20),
      Expanded(
        child: CoachTarget(
          'caixa.movimentacoes',
          child: _MovimentacoesCard(
            entries: filtered,
            allEntries: widget.state.entries,
            canManage: widget.canManage,
            salesById: widget.state.salesById,
            filter: _movFilter,
            onFilterChanged: (f) => setState(() => _movFilter = f),
            searchCtrl: _searchCtrl,
          ),
        ),
      ),
    ];

    final rightColumn = [
      _PendentesCard(state: widget.state),
      const SizedBox(height: 20),
      CoachTarget(
        'caixa.acoes',
        child: _QuickActionsGrid(
          canWrite: widget.canWrite,
          canSale: widget.canSale,
          canManage: widget.canManage,
          config: widget.state.config,
        ),
      ),
    ];

    if (isMobile) {
      // Mobile: Balanço → Ações rápidas → OS pendentes → Movimentações
      return ListView(
        children: [
          CoachTarget('caixa.balanco', child: _BalanceCard(state: widget.state)),
          const SizedBox(height: 20),
          CoachTarget(
            'caixa.acoes',
            child: _QuickActionsGrid(
              canWrite: widget.canWrite,
              canSale: widget.canSale,
              canManage: widget.canManage,
              config: widget.state.config,
            ),
          ),
          const SizedBox(height: 20),
          _PendentesCard(state: widget.state),
          const SizedBox(height: 20),
          SizedBox(
            height: 420,
            child: CoachTarget(
              'caixa.movimentacoes',
              child: _MovimentacoesCard(
                entries: filtered,
                allEntries: widget.state.entries,
                canManage: widget.canManage,
                salesById: widget.state.salesById,
                filter: _movFilter,
                onFilterChanged: (f) => setState(() => _movFilter = f),
                searchCtrl: _searchCtrl,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    // Desktop: two columns.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column (60%).
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: leftColumn,
          ),
        ),
        const SizedBox(width: 20),
        // Right column (40%).
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rightColumn,
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== Balanco do dia =====================

class _BalanceCard extends ConsumerStatefulWidget {
  const _BalanceCard({required this.state});
  final CashierState state;

  @override
  ConsumerState<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<_BalanceCard> {
  /// Periodo customizado selecionado via filtro (null = hoje).
  _PeriodFilter? _period;

  /// Entries buscadas para o período selecionado (null = usa as de hoje do state).
  List<CashEntry>? _periodEntries;
  bool _loadingPeriod = false;

  ({String from, String to})? _rangeForPeriod(_PeriodFilter period) {
    final now = DateTime.now();
    return switch (period) {
      _PeriodFilter.hoje => null,
      _PeriodFilter.seteDias => (
          from: now
              .subtract(const Duration(days: 7))
              .toUtc()
              .toIso8601String(),
          to: now.toUtc().toIso8601String(),
        ),
      _PeriodFilter.trintaDias => (
          from: now
              .subtract(const Duration(days: 30))
              .toUtc()
              .toIso8601String(),
          to: now.toUtc().toIso8601String(),
        ),
      _PeriodFilter.esteMes => (
          from: DateTime(now.year, now.month, 1).toUtc().toIso8601String(),
          to: now.toUtc().toIso8601String(),
        ),
      _PeriodFilter.custom => null,
    };
  }

  Future<void> _applyPeriod(_PeriodFilter? period) async {
    if (period == null || period == _PeriodFilter.hoje) {
      if (mounted) setState(() { _periodEntries = null; _loadingPeriod = false; });
      return;
    }
    final range = _rangeForPeriod(period);
    if (range == null) {
      if (mounted) setState(() { _periodEntries = null; _loadingPeriod = false; });
      return;
    }
    if (mounted) setState(() => _loadingPeriod = true);
    try {
      final repo = ref.read(cashierRepositoryProvider);
      final page = await repo.listEntries(from: range.from, to: range.to);
      if (mounted) {
        setState(() {
          _periodEntries = page.items;
          _loadingPeriod = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _periodEntries = null; _loadingPeriod = false; });
    }
  }

  String get _title {
    if (_period == null) return 'Balanço do dia';
    return switch (_period!) {
      _PeriodFilter.hoje => 'Balanço do dia',
      _PeriodFilter.seteDias => 'Balanço dos últimos 7 dias',
      _PeriodFilter.trintaDias => 'Balanço dos últimos 30 dias',
      _PeriodFilter.esteMes => 'Balanço deste mês',
      _PeriodFilter.custom => 'Balanço do período',
    };
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final session = widget.state.session;
    final byMethod = session?.byMethod ?? const [];

    // Balanço calculado pela função pura testada (computeBalance).
    final pendingTitles = ref.watch(_pendingTitlesProvider).value?.items ?? const [];
    final isPeriodActive = _period != null && _period != _PeriodFilter.hoje;
    final effectiveEntries = _periodEntries ?? widget.state.entries;
    final balance = computeBalance(
      entries: effectiveEntries.map((e) => (
            category: e.category,
            reversedAt: e.reversedAt,
            amount: e.amount as Object?,
          )),
      // Pendente é estado atual — não faz sentido incluir em período histórico.
      pendingOsTotals: isPeriodActive ? const [] : pendingTitles.map((t) => t.balance),
    );

    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.rCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with filter button.
          Row(
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Stack(
                children: [
                  NeuIconButton(
                    icon: Icons.filter_list_rounded,
                    tooltip: 'Filtrar período',
                    size: 38,
                    onPressed: () async {
                      final result = await showDialog<_PeriodFilter?>(
                        context: context,
                        builder: (_) => _FilterPeriodDialog(current: _period),
                      );
                      if (result != null || _period != null) {
                        setState(() => _period = result);
                        _applyPeriod(result);
                      }
                    },
                  ),
                  if (_period != null && _period != _PeriodFilter.hoje)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: neu.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 5 metric blocks.
          if (_loadingPeriod)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Wrap(
              spacing: 28,
              runSpacing: 16,
              children: [
                _Metric(
                  label: 'Recebido',
                  value: formatMoney(balance.recebido),
                  color: neu.success,
                ),
                _Metric(
                  label: 'Saídas',
                  value: formatMoney(balance.saidas),
                  color: neu.danger,
                ),
                _Metric(
                  label: 'Saldo',
                  value: formatMoney(balance.saldo),
                  color: neu.navy,
                ),
                _Metric(
                  label: 'Depósitos',
                  value: formatMoney(balance.depositos),
                  color: neu.accent,
                ),
                _Metric(
                  label: 'Pendente',
                  value: formatMoney(balance.pendente),
                  color: neu.warning,
                ),
              ],
            ),
          // Method breakdown chips — omitido em períodos históricos (dado é da sessão atual).
          if (byMethod.isNotEmpty && !isPeriodActive) ...[
            const SizedBox(height: 16),
            Divider(color: neu.line, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in byMethod)
                  if (m.inAmount > 0 || m.outAmount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: neu.surfaceHi,
                        borderRadius: BorderRadius.circular(NeuTokens.rChip),
                      ),
                      child: Text(
                        '${methodLabel(m.method)}: ${formatMoney(m.inAmount)}',
                        style: TextStyle(
                          color: neu.inkMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== Movimentacoes =====================

class _MovimentacoesCard extends StatelessWidget {
  const _MovimentacoesCard({
    required this.entries,
    required this.allEntries,
    required this.canManage,
    required this.salesById,
    required this.filter,
    required this.onFilterChanged,
    required this.searchCtrl,
  });

  final List<CashEntry> entries;
  final List<CashEntry> allEntries;
  final bool canManage;
  final Map<String, Sale> salesById;
  final _MovFilter filter;
  final ValueChanged<_MovFilter> onFilterChanged;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.rCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movimentações',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          // Filter chips.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _MovFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ChoicePill(
                      label: switch (f) {
                        _MovFilter.tudo => 'Tudo',
                        _MovFilter.entradas => 'Entradas',
                        _MovFilter.saidas => 'Saídas',
                        _MovFilter.pendentes => 'Pendentes',
                      },
                      selected: filter == f,
                      onTap: () => onFilterChanged(f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Search field.
          NeuTextField(
            label: 'Buscar',
            controller: searchCtrl,
            hint: 'Cliente, número da OS ou venda...',
            prefixIcon: Icons.search_rounded,
            suffix: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchCtrl,
              builder: (_, val, _) => val.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: searchCtrl.clear,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: neu.inkMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          // Count indicator.
          if (allEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                entries.length == allEntries.length
                    ? '${allEntries.length} '
                          '${allEntries.length == 1 ? "registro" : "registros"}'
                    : '${entries.length} de ${allEntries.length}',
                style: TextStyle(color: neu.inkFaint, fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
          // Entries list.
          Expanded(
            child: entries.isEmpty
                ? const NeuEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nenhum movimento ainda',
                    message:
                        'Os recebimentos e lancamentos do dia aparecem aqui assim que forem registrados.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _EntryTile(
                      entry: entries[i],
                      canManage: canManage,
                      sale: entries[i].saleId == null
                          ? null
                          : salesById[entries[i].saleId],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ===================== Pagamentos Pendentes =====================

/// Provider que busca TODOS os pagamentos pendentes:
/// 1. OS com payment_status a_receber/parcial (qualquer status de workflow)
/// 2. Vendas avulsas em aberto (via receivables)
/// Combina as duas fontes num único `OpenTitlesPage`.
final _pendingTitlesProvider =
    FutureProvider.autoDispose<OpenTitlesPage>((ref) async {
  // 1. OS pendentes de pagamento (todas, incluindo em_execucao)
  final osRepo = ref.read(osRepositoryProvider);
  final osPage = await osRepo.listOrders(sort: 'recent', page: 1);
  final pendingOs = osPage.items
      .where((os) =>
          os.status != 'cancelada' &&
          (os.paymentStatus == 'a_receber' || os.paymentStatus == 'parcial'))
      .map((os) => ReceivableTitle(
            id: os.id,
            origin: 'os',
            number: os.number,
            total: moneyToDouble(os.total),
            paid: 0,
            balance: moneyToDouble(os.total),
            status: os.paymentStatus,
            customerName: os.customerName,
          ))
      .toList();

  // 2. Vendas avulsas pendentes (via receivables — traz fiados + vendas sem baixa)
  final recRepo = ref.read(receivablesRepositoryProvider);
  final recPage = await recRepo.listOpenTitles();
  // Filtra só vendas (as OS já vieram acima com dados mais completos)
  final pendingSales = recPage.items.where((t) => t.origin == 'sale').toList();

  // Combina: OS primeiro, vendas depois
  final allItems = [...pendingOs, ...pendingSales];
  num totalDue = 0;
  for (final t in allItems) {
    totalDue += t.balance;
  }

  return OpenTitlesPage(
    items: allItems,
    totalDue: totalDue,
    truncated: recPage.truncated,
  );
});

class _PendentesCard extends ConsumerWidget {
  const _PendentesCard({required this.state});
  final CashierState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final pendingAsync = ref.watch(_pendingTitlesProvider);

    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.rCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 20, color: neu.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pagamentos pendentes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (pendingAsync.value != null && pendingAsync.value!.items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: neu.warning.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pendingAsync.value!.items.length}',
                    style: TextStyle(
                      color: neu.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          pendingAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Erro ao carregar OS pendentes',
                style: TextStyle(color: neu.danger, fontSize: 13),
              ),
            ),
            data: (page) {
              final titles = page.items;
              if (titles.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 36,
                        color: neu.success,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nenhum pagamento pendente',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: neu.inkMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final t in titles) ...[
                    _PendingTitleTile(title: t, config: state.config),
                    if (t != titles.last)
                      Divider(color: neu.line, height: 20),
                  ],
                  if (page.truncated)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Há mais títulos — mostrando os mais recentes.',
                        style: TextStyle(color: neu.inkFaint, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tile de uma OS pendente de pagamento.
/// Tile de um título pendente (OS ou venda avulsa).
class _PendingTitleTile extends ConsumerWidget {
  const _PendingTitleTile({required this.title, required this.config});
  final ReceivableTitle title;
  final CashierConfig config;

  void _showActions(BuildContext outerContext, WidgetRef ref) {
    final neu = outerContext.neu;
    final isOs = title.origin == 'os';
    final label = isOs ? 'OS ${title.number}' : 'Venda ${title.number}';
    showDialog(
      context: outerContext,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NeuSurface(
            elevation: NeuElevation.raisedHigh,
            radius: NeuTokens.rPanel,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: neu.warning.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          isOs ? Icons.build_rounded : Icons.shopping_cart_rounded,
                          size: 22, color: neu.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(color: neu.navy, fontSize: 15, fontWeight: FontWeight.w800)),
                          if ((title.customerName ?? '').isNotEmpty)
                            Text(title.customerName!, style: TextStyle(color: neu.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text(formatMoney(title.balance), style: TextStyle(color: neu.ink, fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 20),
                _OsActionButton(
                  icon: Icons.payments_rounded,
                  iconColor: neu.success,
                  iconBg: neu.success.withValues(alpha: .14),
                  label: 'Receber pagamento',
                  subtitle: 'Registrar entrada no caixa',
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (!outerContext.mounted) return;
                    await showReceiveTitleDialog(
                      outerContext, ref,
                      config: config,
                      title: title,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _OsActionButton(
                  icon: Icons.visibility_rounded,
                  iconColor: neu.navy,
                  iconBg: neu.navy.withValues(alpha: .12),
                  label: 'Ver detalhes',
                  subtitle: isOs ? 'Itens, fotos, histórico' : 'Itens, cliente, valor',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (isOs) {
                      showOsDetailDialog(outerContext, orderId: title.id);
                    } else {
                      showSaleDetailDialog(outerContext, saleId: title.id);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: NeuButton(
                    label: 'Fechar',
                    kind: NeuButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final isOs = title.origin == 'os';
    final label = isOs ? 'OS ${title.number}' : 'VND ${title.number}';
    final cliente = title.customerName;

    return InkWell(
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      onTap: () => _showActions(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: neu.warning.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(NeuTokens.rChip),
              ),
              child: Center(
                child: Icon(
                  isOs ? Icons.assignment_outlined : Icons.shopping_bag_outlined,
                  size: 18, color: neu.warning,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: neu.ink, fontSize: 13.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (cliente != null && cliente.isNotEmpty)
                    Text(cliente, style: TextStyle(color: neu.inkMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatMoney(title.balance), style: TextStyle(color: neu.warning, fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 2),
                PaymentTag(status: title.status, dense: true),
              ],
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: neu.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Botão de ação no modal da OS pendente.
class _OsActionButton extends StatelessWidget {
  const _OsActionButton({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      onTap: onTap,
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, size: 18, color: iconColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: neu.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: TextStyle(color: neu.inkFaint, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: neu.inkFaint),
          ],
        ),
      ),
    );
  }
}

// ===================== Acoes Rapidas =====================

/// Grid 2x2 de acoes rapidas: Receber OS, Venda Avulsa, Deposito, Saque.
class _QuickActionsGrid extends ConsumerWidget {
  const _QuickActionsGrid({
    required this.canWrite,
    required this.canSale,
    required this.canManage,
    required this.config,
  });

  final bool canWrite;
  final bool canSale;
  final bool canManage;
  final CashierConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final acoes = <_QuickAction>[
      if (canWrite)
        _QuickAction(
          label: 'Receber OS',
          icon: Icons.payments_outlined,
          color: neu.success,
          onTap: () => showReceivePickerDialog(context, ref, config),
        ),
      if (canSale)
        _QuickAction(
          label: 'Venda Avulsa',
          icon: Icons.shopping_cart_checkout_outlined,
          color: neu.navy,
          requiresConnection: 'a venda avulsa é registrada no servidor',
          onTap: () => _startSale(context, ref),
        ),
      if (canManage)
        _QuickAction(
          label: 'Depósito',
          icon: Icons.arrow_upward,
          color: neu.info,
          requiresConnection: 'o depósito é registrado no servidor',
          onTap: () => _showDepositoSaqueDialog(
            context,
            ref,
            isDeposito: true,
            config: config,
          ),
        ),
      if (canManage)
        _QuickAction(
          label: 'Saque',
          icon: Icons.arrow_downward,
          color: neu.danger,
          requiresConnection: 'o saque é registrado no servidor',
          onTap: () => _showDepositoSaqueDialog(
            context,
            ref,
            isDeposito: false,
            config: config,
          ),
        ),
    ];

    if (acoes.isEmpty) return const SizedBox.shrink();

    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.rCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ações Rápidas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 300 ? 2 : 1;
              final spacing = 10.0;
              final itemWidth = cols == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final a in acoes)
                    SizedBox(
                      width: itemWidth,
                      child: _QuickActionCard(action: a),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.requiresConnection,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? requiresConnection;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final card = NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.rCard,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(NeuTokens.rChip),
                ),
                child: Center(
                  child: Icon(action.icon, size: 20, color: action.color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 2,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final reason = action.requiresConnection;
    return reason == null
        ? card
        : RequiresConnection(reason: reason, child: card);
  }
}

// ===================== Deposito / Saque Dialog =====================

Future<void> _showDepositoSaqueDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool isDeposito,
  required CashierConfig config,
}) async {
  await showDialog(
    context: context,
    builder: (_) => _DepositoSaqueDialog(
      isDeposito: isDeposito,
      paymentMethods: config.paymentMethods,
    ),
  );
}

class _DepositoSaqueDialog extends ConsumerStatefulWidget {
  const _DepositoSaqueDialog({
    required this.isDeposito,
    required this.paymentMethods,
  });

  final bool isDeposito;
  final List<String> paymentMethods;

  @override
  ConsumerState<_DepositoSaqueDialog> createState() =>
      _DepositoSaqueDialogState();
}

class _DepositoSaqueDialogState extends ConsumerState<_DepositoSaqueDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late String _method;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _method = widget.paymentMethods.isNotEmpty
        ? widget.paymentMethods.first
        : 'dinheiro';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showNeuErrorSnackBar(context, 'Informe um valor valido.');
      return;
    }

    setState(() => _loading = true);
    try {
      final category = widget.isDeposito ? 'suprimento' : 'sangria';
      final desc = _descCtrl.text.trim();
      final draft = EntryDraft(
        amount: amount,
        method: _method,
        category: category,
        description: desc.isNotEmpty ? desc : null,
      );
      await ref.read(cashierControllerProvider.notifier).addEntry(draft);
      if (mounted) {
        Navigator.of(context).pop();
        showNeuSuccessSnackBar(
          context,
          widget.isDeposito
              ? 'Depósito registrado com sucesso.'
              : 'Saque registrado com sucesso.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showNeuErrorSnackBar(context, 'Erro: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final title = widget.isDeposito
        ? 'Depósito (Suprimento)'
        : 'Saque (Sangria)';
    final iconColor = widget.isDeposito ? neu.info : neu.danger;
    final icon = widget.isDeposito ? Icons.arrow_upward : Icons.arrow_downward;

    return NeuDialog(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon header.
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
          ),
          const SizedBox(height: 20),
          NeuTextField(
            label: 'Valor',
            controller: _amountCtrl,
            prefixText: 'R\$ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [const DecimalInputFormatter()],
            autofocus: true,
          ),
          const SizedBox(height: 16),
          NeuTextField(
            label: 'Descrição',
            controller: _descCtrl,
            hint: widget.isDeposito
                ? 'Ex.: Troco inicial, reforco de caixa...'
                : 'Ex.: Pagamento de fornecedor, sangria de seguranca...',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // Method selector.
          Text(
            'Forma de pagamento',
            style: TextStyle(
              color: neu.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in widget.paymentMethods)
                _ChoicePill(
                  label: methodLabel(m),
                  selected: _method == m,
                  onTap: () => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: 24),
          NeuButton(
            label: widget.isDeposito ? 'Registrar depósito' : 'Registrar saque',
            icon: icon,
            expanded: true,
            loading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ===================== Filter Period Dialog =====================

enum _PeriodFilter { hoje, seteDias, trintaDias, esteMes, custom }

class _FilterPeriodDialog extends StatefulWidget {
  const _FilterPeriodDialog({this.current});
  final _PeriodFilter? current;

  @override
  State<_FilterPeriodDialog> createState() => _FilterPeriodDialogState();
}

class _FilterPeriodDialogState extends State<_FilterPeriodDialog> {
  late _PeriodFilter? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final presets = <(_PeriodFilter, String, IconData)>[
      (_PeriodFilter.hoje, 'Hoje', Icons.today_rounded),
      (_PeriodFilter.seteDias, 'Últimos 7 dias', Icons.date_range_rounded),
      (
        _PeriodFilter.trintaDias,
        'Últimos 30 dias',
        Icons.calendar_month_rounded,
      ),
      (_PeriodFilter.esteMes, 'Este mês', Icons.calendar_today_rounded),
    ];

    return NeuDialog(
      title: 'Filtrar período',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (filter, label, icon) in presets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(NeuTokens.rChip),
                onTap: () {
                  setState(() => _selected = filter);
                  Navigator.of(context).pop(filter);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _selected == filter
                        ? neu.navy.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(NeuTokens.rChip),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: _selected == filter ? neu.navy : neu.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: _selected == filter ? neu.navy : neu.ink,
                            fontWeight: _selected == filter
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_selected == filter)
                        Icon(Icons.check_rounded, size: 20, color: neu.navy),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Clear filter.
          if (_selected != null && _selected != _PeriodFilter.hoje)
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  'Limpar filtro',
                  style: TextStyle(color: neu.danger, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===================== Entry Tile (MANTIDO INTACTO) =====================

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.canManage, this.sale});
  final CashEntry entry;
  final bool canManage;

  /// Venda de origem, quando houver — e o que permite dizer PARA QUEM.
  final Sale? sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final isPending = entry.direction == 'pending';
    final isIn = entry.direction == 'in';
    final reversed = entry.reversedAt != null;
    final color = reversed
        ? neu.inkMuted
        : isPending
        ? neu.warning
        : isIn
        ? neu.success
        : neu.danger;
    // A descricao ja carrega o no da venda/OS (ex.: "OS-0001"/"VND-0001"); se vier
    // vazia (entries antigas), cai no rotulo generico da origem.
    final hasDesc = entry.description != null && entry.description!.isNotEmpty;
    final hora = _fmtHora(entry.createdAt);
    // Lancamento criado offline (ainda no outbox): selo "pendente de envio".
    final pending =
        (ref.watch(pendingIdsProvider('cash_entry')).value ?? const <String>{})
            .contains(entry.id);
    // Cliente antes da descricao (que ja traz o numero): "para quem" era a
    // informacao que faltava na linha do extrato.
    final cliente = sale?.customerName;
    final subtitleParts = <String>[
      if (hora.isNotEmpty) hora,
      methodLabel(entry.method),
      if (cliente != null && cliente.isNotEmpty) cliente,
      if (hasDesc)
        entry.description!
      else if (entry.saleKind == 'os')
        'OS'
      else if (entry.saleKind == 'sale')
        'Venda'
      else if (entry.saleKind == 'expense')
        'Despesa',
    ];
    // Lancamento que aponta para uma venda ou OS abre a ORIGEM dele.
    //
    // Venda abre em dialogo (da para editar itens e exportar sem sair do caixa);
    // OS NAVEGA para a tela dela, que e grande demais para caber num dialogo e
    // tem o proprio fluxo (itens, fotos, timeline, exportar PDF). Antes o
    // recebimento de OS era um beco sem saida: mostrava "OS" e nao levava a lugar
    // nenhum, obrigando a procurar a ordem a mao.
    final daVenda = entry.saleKind == 'sale' && entry.saleId != null;
    final daOs = entry.saleKind == 'os' && entry.saleId != null;
    // Saida de conta a pagar: abre a DESPESA em dialogo, como a venda. Antes a
    // baixa gravava origem nula e a linha do extrato dizia "Despesa . Aluguel"
    // sem levar a lugar nenhum — para achar a conta era preciso lembrar o mes e
    // procurar a mao. A ida (despesa -> lancamento) ja existia; faltava a volta.
    final daDespesa = entry.saleKind == 'expense' && entry.saleId != null;
    // Situacao da venda NA LINHA. Antes so dava para saber clicando: uma venda
    // cancelada tinha a mesma cara de uma normal, porque cancelar a venda NAO
    // mexe no lancamento do caixa (o dinheiro continua na gaveta ate alguem
    // estornar). Fiado e pagamento parcial tinham o mesmo problema.
    final selo = sale == null
        ? null
        : sale!.status == 'canceled'
        // Cancelada manda no rotulo: e a informacao que muda o que fazer,
        // e vem antes de qualquer coisa sobre pagamento.
        ? NeuStatusChip(
            label: 'Cancelada',
            color: neu.danger,
            tint: neu.danger.withValues(alpha: .14),
          )
        : PaymentTag(status: sale!.paymentStatus, dense: true);
    // So vira `Wrap` quando ha selo/badge: sem eles, o subtitulo continua uma
    // linha de texto simples, como sempre foi.
    final extras = <Widget>[
      ?selo,
      if (pending)
        SyncRowBadge(entity: 'cash_entry', id: entry.id, dense: true),
      // "Estornado" vive AQUI, junto dos outros selos, e não no trailing: lá
      // ele somava ~90px a uma coluna que já tem valor + menu + chevron, e a
      // linha estourava no celular (360px). O subtítulo é um Wrap — ele quebra.
      if (reversed)
        NeuStatusChip(
          label: 'Estornado',
          color: neu.inkMuted,
          tint: neu.inkMuted.withValues(alpha: .14),
        ),
    ];
    return NeuListTile(
      onTap: daVenda
          ? () => showSaleDetailDialog(context, saleId: entry.saleId!)
          : daOs
          ? () => showOsDetailDialog(context, orderId: entry.saleId!)
          : daDespesa
          ? () => showExpenseDetailDialog(context, ref, id: entry.saleId!)
          : null,
      leading: isPending
          ? Container(
              width: _DirectionGlyph.size,
              height: _DirectionGlyph.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: neu.warning.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule_rounded,
                size: _DirectionGlyph.size * .5,
                color: neu.warning,
              ),
            )
          : _DirectionGlyph(color: color, isIn: isIn),
      title: Text(
        isPending ? 'Pendente' : categoryLabel(entry.category),
        style: TextStyle(
          decoration: reversed ? TextDecoration.lineThrough : null,
          color: isPending
              ? neu.warning
              : reversed
              ? neu.inkMuted
              : neu.ink,
        ),
      ),
      subtitle: extras.isEmpty
          ? Text(subtitleParts.join(' · '))
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [Text(subtitleParts.join(' · ')), ...extras],
            ),
      // Teto de largura no PRÓPRIO trailing, e não no `NeuListTile`: o tile é
      // compartilhado por OS, clientes e estoque, e limitá-lo lá empurrava o
      // estouro para dentro do trailing daquelas telas (162px na lista de OS).
      // Aqui o problema é local — valor + menu + chevron chegavam a 231px numa
      // linha de 256 no celular, sobrando ZERO para o nome.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 168),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // `Flexible`: o valor é o que pode ceder. O menu de ações e o chevron
            // têm tamanho de alvo de toque e não encolhem — se algo tiver de
            // truncar num celular estreito, que seja o número, que o detalhe da
            // linha mostra por extenso.
            Flexible(
              child: Text(
                isPending
                    ? formatMoney(entry.amount)
                    : '${isIn ? '+' : '−'} ${formatMoney(entry.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: color,
                  decoration: reversed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            // Editar / Corrigir / Estornar num menu so: tres icones na linha nao
            // caberiam no celular, e as acoes sao raras (nao merecem o espaco).
            //
            // Nas linhas de VENDA o menu nao aparece: a linha abre o detalhe da
            // venda, que e onde se age sobre ela (itens, cliente, cancelar) E
            // sobre o recebimento. Dois caminhos para a mesma coisa, um deles
            // escondido atras de tres pontinhos, so confunde.
            if (canManage && !reversed && !daVenda) ...[
              const SizedBox(width: 6),
              EntryActionsMenu(entry: entry),
            ],
            // Afordancia: sem isto nada indica que a linha e clicavel (venda, OS
            // e despesa navegam no toque — so a venda mostrava o chevron).
            if (daVenda || daOs || daDespesa) ...[
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 18, color: neu.inkFaint),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: neu.danger, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: neu.inkMuted),
          ),
          const SizedBox(height: 12),
          NeuButton(
            label: 'Tentar de novo',
            kind: NeuButtonKind.secondary,
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Pilula de escolha (presets de periodo) — mesmo desenho dos chips de filtro
/// da lista de OS: selecionada = navy solido; demais = extrudadas.
class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
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
    return InkWell(
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
    );
  }
}
