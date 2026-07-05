import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../../sale/presentation/sale_create_dialog.dart';
import 'cashier_dialogs.dart';
import 'cashier_providers.dart';

/// Módulo Caixa: duas abas — "Caixa do dia" (sessão atual: abrir/extrato/totais/
/// fechar) e "Histórico" (movimentos por período — o relatório do caixa). Corpo
/// apenas — a moldura é do shell. UI só fala com o repository (via controller).
/// Responsivo: padding e larguras se adaptam ao celular.
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  int _tab = 0; // 0 = Caixa do dia · 1 = Histórico

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('cashier.write');
  }

  /// Gestão do caixa (abrir/fechar, despesa/sangria/suprimento, estorno, histórico).
  /// Dono/gerente; o atendente (caixa) NÃO tem.
  bool _canManage() {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('cashier.manage');
  }

  bool _canSale() {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated &&
        s.me.hasModule('sale') &&
        s.me.hasPermission('sale.write');
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final canManage = _canManage();
    final showHistory = canManage && _tab == 1;
    return Padding(
      padding: EdgeInsets.all(narrow ? 14 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A aba "Histórico" (relatório do caixa) é só para gestão (dono/gerente).
          if (canManage) ...[
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.point_of_sale_outlined),
                    label: Text('Caixa do dia')),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.history),
                    label: Text('Histórico')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
          ],
          Expanded(child: showHistory ? const _CashierHistory() : _dayBody()),
        ],
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
      data: (state) => state.isOpen
          ? _OpenBody(
              state: state,
              canWrite: _canWrite(),
              canManage: _canManage(),
              canSale: _canSale())
          : _ClosedBody(
              canManage: _canManage(), canSale: _canSale()),
    );
  }
}

/// Abre o fluxo único de venda avulsa (venda + recebimento/a receber + nota). O
/// próprio diálogo cuida de tudo e mostra o resultado; aqui só o disparamos.
Future<void> _startSale(BuildContext context, WidgetRef ref) async {
  await showSaleCreateDialog(context);
}

/// Hora local "HH:MM" de um timestamp ISO (vazio se nulo/ inválido).
String _fmtHora(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

class _ClosedBody extends ConsumerWidget {
  const _ClosedBody({required this.canManage, required this.canSale});
  final bool canManage; // abrir caixa = gestão (dono/gerente)
  final bool canSale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.point_of_sale_outlined,
              size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Caixa fechado', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            canManage
                ? 'Abra o caixa para registrar entradas e saídas do dia.'
                : 'Aguarde o dono/gerente abrir o caixa para começar a operar.',
            style: TextStyle(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (canManage)
            FilledButton.icon(
              onPressed: () => showOpenSessionDialog(context, ref),
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Abrir caixa'),
              style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
            ),
          if (canSale) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _startSale(context, ref),
              icon: const Icon(Icons.shopping_cart_checkout_outlined),
              label: const Text('Venda avulsa'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(180, 48)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpenBody extends ConsumerWidget {
  const _OpenBody({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final session = state.session!;
    final totals = session.totals;
    final abertoHora = _fmtHora(session.openedAt);
    // Cabeçalho responsivo: título + "Aberto desde HH:MM" à esquerda, botão Fechar
    // à direita; em telas estreitas quebra pra baixo (Wrap). O botão Fechar ganha
    // minimumSize explícito (senão o tema global o estica e ele some).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Caixa do dia',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    abertoHora.isEmpty ? 'Aberto' : 'Aberto desde $abertoHora',
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (canManage)
              FilledButton.tonalIcon(
                onPressed: () => showCloseSessionDialog(context, ref),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Fechar caixa'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(session: session),
        const SizedBox(height: 16),
        if (canWrite || canSale || canManage)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canSale)
                FilledButton.icon(
                  onPressed: () => _startSale(context, ref),
                  icon: const Icon(Icons.shopping_cart_checkout_outlined),
                  label: const Text('Venda avulsa'),
                ),
              // Receber OS = operação do atendente (cashier.write).
              if (canWrite)
                FilledButton.icon(
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'os_payment'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Receber OS'),
                ),
              // Ajustes da gaveta = gestão (dono/gerente).
              if (canManage) ...[
                OutlinedButton.icon(
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'despesa'),
                  icon: const Icon(Icons.remove),
                  label: const Text('Despesa / sangria'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showEntryDialog(context, ref, state.config,
                      presetCategory: 'suprimento'),
                  icon: const Icon(Icons.add),
                  label: const Text('Suprimento'),
                ),
              ],
            ],
          ),
        if (totals != null && session.byMethod.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Totais por método',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in session.byMethod)
                Chip(
                  label: Text(
                    '${methodLabel(m.method)}: ${formatMoney(m.inAmount - m.outAmount)}',
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const Text('Extrato', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(child: _ExtractList(entries: state.entries, canManage: canManage)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session});
  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = session.totals;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 14,
        children: [
          _metric(scheme, 'Abertura', formatMoney(session.openingAmount)),
          _metric(scheme, 'Entradas', formatMoney(t?.inTotal ?? 0),
              color: AppColors.success),
          _metric(scheme, 'Saídas', formatMoney(t?.outTotal ?? 0),
              color: AppColors.danger),
          _metric(scheme, 'Esperado em caixa', formatMoney(t?.expected ?? 0),
              color: scheme.primary),
        ],
      ),
    );
  }

  Widget _metric(ColorScheme scheme, String label, String value,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: color ?? scheme.onSurface)),
      ],
    );
  }
}

class _ExtractList extends ConsumerWidget {
  const _ExtractList({required this.entries, required this.canManage});
  final List<CashEntry> entries;
  final bool canManage; // estorno = gestão (dono/gerente)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (entries.isEmpty) {
      return Center(
        child: Text('Nenhum movimento ainda.',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: scheme.outlineVariant),
      itemBuilder: (_, i) => _EntryTile(entry: entries[i], canManage: canManage),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.canManage});
  final CashEntry entry;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isIn = entry.direction == 'in';
    final reversed = entry.reversedAt != null;
    final color = reversed
        ? scheme.onSurfaceVariant
        : isIn
            ? AppColors.success
            : AppColors.danger;
    // A descrição já carrega o nº da venda/OS (ex.: "OS-0001"/"VND-0001"); se vier
    // vazia (entries antigas), cai no rótulo genérico da origem.
    final hasDesc = entry.description != null && entry.description!.isNotEmpty;
    final hora = _fmtHora(entry.createdAt);
    final subtitleParts = <String>[
      if (hora.isNotEmpty) hora,
      methodLabel(entry.method),
      if (hasDesc)
        entry.description!
      else if (entry.saleKind == 'os')
        'OS'
      else if (entry.saleKind == 'sale')
        'Venda',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isIn ? Icons.south_west : Icons.north_east,
        color: color,
      ),
      title: Text(
        categoryLabel(entry.category),
        style: TextStyle(
          decoration: reversed ? TextDecoration.lineThrough : null,
          color: reversed ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      ),
      subtitle: Text(subtitleParts.join(' · '),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isIn ? '+' : '−'} ${formatMoney(entry.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              decoration: reversed ? TextDecoration.lineThrough : null,
            ),
          ),
          if (canManage && !reversed)
            IconButton(
              tooltip: 'Estornar',
              icon: const Icon(Icons.undo, size: 18),
              onPressed: () => _confirmReverse(context, ref),
            ),
          if (reversed)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('estornado',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmReverse(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estornar lançamento'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Motivo do estorno'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Estornar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um motivo (mín. 3 caracteres).')),
      );
      return;
    }
    try {
      await ref.read(cashierControllerProvider.notifier).reverse(entry.id, reason);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}

// ===================== Histórico do Caixa (movimentos por período) =====================

/// Relatório do CAIXA: o que de fato passou pelo caixa no período (baseado nos
/// movimentos/`cash_entry`, não na data de criação da OS/venda). Período por
/// presets (Hoje/7/30 dias), totais por método/origem + extrato. Read-only.
class _CashierHistory extends ConsumerWidget {
  const _CashierHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final preset = ref.watch(cashierHistoryPresetProvider);
    final async = ref.watch(cashierHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final p in const [
              ('hoje', 'Hoje'),
              ('7d', '7 dias'),
              ('30d', '30 dias'),
            ])
              ChoiceChip(
                label: Text(p.$2),
                selected: preset == p.$1,
                onSelected: (_) =>
                    ref.read(cashierHistoryPresetProvider.notifier).set(p.$1),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBox(
              message: '$e',
              onRetry: () => ref.invalidate(cashierHistoryProvider),
            ),
            data: (data) {
              final s = data.summary;
              return ListView(
                children: [
                  // Resumo do período
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Wrap(
                      spacing: 28,
                      runSpacing: 14,
                      children: [
                        _metric(scheme, 'Recebido', formatMoney(s.totalIn),
                            color: AppColors.success),
                        _metric(scheme, 'Saídas', formatMoney(s.totalOut),
                            color: AppColors.danger),
                        _metric(scheme, 'Saldo', formatMoney(s.net),
                            color: scheme.primary),
                      ],
                    ),
                  ),
                  if (s.byMethod.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('Por forma (entrou · saiu · saldo)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          for (final m in s.byMethod)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(methodLabel(m.method),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Expanded(
                                    child: Text('+ ${formatMoney(m.inAmount)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            color: AppColors.success)),
                                  ),
                                  Expanded(
                                    child: Text('− ${formatMoney(m.outAmount)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            color: AppColors.danger)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        formatMoney(m.inAmount - m.outAmount),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text('Movimentos',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (data.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Nenhum movimento no período.',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
                    )
                  else
                    for (final e in data.entries) _HistoryEntryTile(entry: e),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _metric(ColorScheme scheme, String label, String value,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: color ?? scheme.onSurface)),
      ],
    );
  }
}

/// Linha do extrato histórico (read-only): data + categoria + método/origem + valor.
class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({required this.entry});
  final CashEntry entry;

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIn = entry.direction == 'in';
    final reversed = entry.reversedAt != null;
    final color = reversed
        ? scheme.onSurfaceVariant
        : (isIn ? AppColors.success : AppColors.danger);
    final hasDesc = entry.description != null && entry.description!.isNotEmpty;
    final sub = <String>[
      _fmtDate(entry.createdAt),
      methodLabel(entry.method),
      if (hasDesc) entry.description!,
    ].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(isIn ? Icons.south_west : Icons.north_east, color: color),
      title: Text(
        categoryLabel(entry.category),
        style: TextStyle(
          decoration: reversed ? TextDecoration.lineThrough : null,
          color: reversed ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      ),
      subtitle: Text(sub,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      trailing: Text(
        '${isIn ? '+' : '−'} ${formatMoney(entry.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
          decoration: reversed ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
