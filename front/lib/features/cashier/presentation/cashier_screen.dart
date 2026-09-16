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
import '../../../core/error/app_exception.dart';
import '../../os/domain/os_models.dart';
import '../../receivables/domain/receivables_models.dart';
import '../../receivables/presentation/receive_title_dialog.dart';
import '../../os/presentation/os_detail_dialog.dart';
import '../../os/presentation/os_providers.dart';
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
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(cashierControllerProvider);
      ref.invalidate(_pendingOsProvider);
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

  /// Filtra as entries localmente conforme o chip selecionado.
  /// Quando "Pendentes" ou "Tudo", inclui OS pendentes (do provider) como
  /// entries virtuais para aparecerem na lista.
  List<CashEntry> _filteredEntries(List<ServiceOrder> pendingOs) {
    final entries = widget.state.entries;
    // Cria entries virtuais para OS pendentes que NÃO têm entry no caixa.
    final existingSaleIds = entries
        .map((e) => e.saleId)
        .whereType<String>()
        .toSet();
    final virtualEntries = pendingOs
        .where((os) => !existingSaleIds.contains(os.id))
        .map(
          (os) => CashEntry(
            id: 'pending-${os.id}',
            direction: 'pending',
            amount: os.total ?? '0',
            method: '',
            category: 'os_payment',
            saleKind: 'os',
            saleId: os.id,
            description: 'OS ${os.number} — ${os.customerName ?? ''}',
          ),
        )
        .toList();

    switch (_movFilter) {
      case _MovFilter.tudo:
        return [...virtualEntries, ...entries];
      case _MovFilter.entradas:
        return entries.where((e) => e.direction == 'in').toList();
      case _MovFilter.saidas:
        return entries.where((e) => e.direction == 'out').toList();
      case _MovFilter.pendentes:
        return virtualEntries;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final pendingOs = ref.watch(_pendingOsProvider).value ?? const [];
    final filtered = _filteredEntries(pendingOs);

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
    final pendingOs = ref.watch(_pendingOsProvider).value ?? const [];
    final balance = computeBalance(
      entries: widget.state.entries.map((e) => (
            category: e.category,
            reversedAt: e.reversedAt,
            amount: e.amount as Object?,
          )),
      pendingOsTotals: pendingOs.map((os) => os.total),
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
          // Method breakdown chips.
          if (byMethod.isNotEmpty) ...[
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
  });

  final List<CashEntry> entries;
  final List<CashEntry> allEntries;
  final bool canManage;
  final Map<String, Sale> salesById;
  final _MovFilter filter;
  final ValueChanged<_MovFilter> onFilterChanged;

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

// ===================== OS Pendentes =====================

/// Provider que busca OS finalizadas com pagamento pendente diretamente do
/// módulo de OS — não depende de entries no caixa (uma OS que nunca recebeu
/// nada também aparece).
final _pendingOsProvider = FutureProvider.autoDispose<List<ServiceOrder>>((
  ref,
) async {
  final repo = ref.read(osRepositoryProvider);
  // Busca todas as OS (sem filtro de status workflow) e filtra pelo
  // payment_status derivado do caixa. O backend enriquece cada OS com
  // payment_status na listagem.
  final page = await repo.listOrders(sort: 'recent', page: 1);
  return page.items
      .where(
        (os) =>
            os.status != 'cancelada' &&
            (os.paymentStatus == 'a_receber' || os.paymentStatus == 'parcial'),
      )
      .toList();
});

class _PendentesCard extends ConsumerWidget {
  const _PendentesCard({required this.state});
  final CashierState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final pendingAsync = ref.watch(_pendingOsProvider);

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
                  'OS Pendentes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (pendingAsync.value != null && pendingAsync.value!.isNotEmpty)
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
                    '${pendingAsync.value!.length}',
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
            data: (pendingOs) {
              if (pendingOs.isEmpty) {
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
                        'Nenhuma OS pendente de pagamento',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: neu.inkMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      NeuButton(
                        label: 'Receber OS',
                        icon: Icons.payments_outlined,
                        kind: NeuButtonKind.secondary,
                        onPressed: () =>
                            showReceivePickerDialog(context, ref, state.config),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final os in pendingOs) ...[
                    _PendingOsTile(order: os, config: state.config),
                    if (os != pendingOs.last)
                      Divider(color: neu.line, height: 20),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: NeuButton(
                      label: 'Receber OS',
                      icon: Icons.payments_outlined,
                      kind: NeuButtonKind.secondary,
                      onPressed: () =>
                          showReceivePickerDialog(context, ref, state.config),
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
class _PendingOsTile extends ConsumerWidget {
  const _PendingOsTile({required this.order, required this.config});
  final ServiceOrder order;
  final CashierConfig config;

  void _showActions(BuildContext outerContext, WidgetRef ref) {
    final neu = outerContext.neu;
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
                // Header com info da OS
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: neu.warning.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(Icons.build_rounded, size: 22, color: neu.warning),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OS ${order.number}',
                            style: TextStyle(
                              color: neu.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (order.customerName != null)
                            Text(
                              order.customerName!,
                              style: TextStyle(color: neu.ink, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(order.total),
                      style: TextStyle(color: neu.ink, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Ações
                _OsActionButton(
                  icon: Icons.payments_rounded,
                  iconColor: neu.success,
                  iconBg: neu.success.withValues(alpha: .14),
                  label: 'Receber pagamento',
                  subtitle: 'Registrar entrada no caixa',
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      final repo = ref.read(cashierRepositoryProvider);
                      final summary = await repo.paymentSummary(
                        saleKind: 'os',
                        saleId: order.id,
                        total: moneyToDouble(order.total),
                      );
                      if (!outerContext.mounted) return;
                      if (summary.balance <= 0) {
                        showNeuErrorSnackBar(outerContext, 'Esta OS já foi paga.');
                        return;
                      }
                      final title = ReceivableTitle(
                        id: order.id,
                        origin: 'os',
                        number: order.number,
                        total: summary.total,
                        paid: summary.paid,
                        balance: summary.balance,
                        status: summary.status,
                      );
                      if (!outerContext.mounted) return;
                      await showReceiveTitleDialog(
                        outerContext, ref,
                        config: config,
                        title: title,
                      );
                    } on AppException catch (e) {
                      if (outerContext.mounted) showNeuErrorSnackBar(outerContext, e.message);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _OsActionButton(
                  icon: Icons.visibility_rounded,
                  iconColor: neu.navy,
                  iconBg: neu.navy.withValues(alpha: .12),
                  label: 'Ver detalhes da OS',
                  subtitle: 'Itens, fotos, histórico',
                  onTap: () {
                    Navigator.of(context).pop();
                    showOsDetailDialog(outerContext, orderId: order.id);
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
    final title = 'OS ${order.number}';
    final cliente = order.customerName;

    return InkWell(
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      onTap: () => _showActions(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: neu.warning.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(NeuTokens.rChip),
              ),
              child: Center(
                child: Icon(
                  Icons.assignment_outlined,
                  size: 18,
                  color: neu.warning,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (cliente != null && cliente.isNotEmpty)
                    Text(
                      cliente,
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Valor e selo empilhados, não lado a lado: em linha somavam 288px
            // (151 + 137) numa linha de 280 no celular — o nome da OS, que está
            // no Expanded, era espremido a ZERO e a linha estourava mesmo assim.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMoney(order.total),
                  style: TextStyle(
                    color: neu.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                PaymentTag(status: order.paymentStatus, dense: true),
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
