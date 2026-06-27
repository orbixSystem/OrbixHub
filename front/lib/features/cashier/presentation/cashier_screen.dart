import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_dialogs.dart';
import 'cashier_providers.dart';

/// Caixa do dia: abrir (valor inicial), extrato (entradas/saídas com método/
/// categoria/origem), totais por método e fechar (contado → diferença). Corpo
/// apenas — a moldura é do shell. UI só fala com o repository (via controller).
class CashierScreen extends ConsumerWidget {
  const CashierScreen({super.key});

  bool _canWrite(WidgetRef ref) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('cashier.write');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashierControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBox(
          message: '$e',
          onRetry: () => ref.invalidate(cashierControllerProvider),
        ),
        data: (state) => state.isOpen
            ? _OpenBody(state: state, canWrite: _canWrite(ref))
            : _ClosedBody(canWrite: _canWrite(ref)),
      ),
    );
  }
}

class _ClosedBody extends ConsumerWidget {
  const _ClosedBody({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.point_of_sale_outlined, size: 56, color: AppColors.inkFaint),
          const SizedBox(height: 16),
          Text('Caixa fechado', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Abra o caixa para registrar entradas e saídas do dia.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: canWrite ? () => showOpenSessionDialog(context, ref) : null,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Abrir caixa'),
            style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
          ),
        ],
      ),
    );
  }
}

class _OpenBody extends ConsumerWidget {
  const _OpenBody({required this.state, required this.canWrite});
  final CashierState state;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = state.session!;
    final totals = session.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Caixa do dia', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Aberto',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (canWrite)
              OutlinedButton.icon(
                onPressed: () => showCloseSessionDialog(context, ref),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Fechar caixa'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(session: session),
        const SizedBox(height: 16),
        if (canWrite)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => showEntryDialog(context, ref, state.config,
                    presetCategory: 'os_payment'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Receber venda'),
              ),
              OutlinedButton.icon(
                onPressed: () => showEntryDialog(context, ref, state.config,
                    presetCategory: 'venda_avulsa'),
                icon: const Icon(Icons.add),
                label: const Text('Lançamento'),
              ),
              OutlinedButton.icon(
                onPressed: () => showEntryDialog(context, ref, state.config,
                    presetCategory: 'despesa'),
                icon: const Icon(Icons.remove),
                label: const Text('Despesa / sangria'),
              ),
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
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.line),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const Text('Extrato', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(child: _ExtractList(entries: state.entries, canWrite: canWrite)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session});
  final CashSession session;

  @override
  Widget build(BuildContext context) {
    final t = session.totals;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 14,
        children: [
          _metric('Abertura', formatMoney(session.openingAmount)),
          _metric('Entradas', formatMoney(t?.inTotal ?? 0), color: AppColors.success),
          _metric('Saídas', formatMoney(t?.outTotal ?? 0), color: AppColors.danger),
          _metric('Esperado em caixa', formatMoney(t?.expected ?? 0),
              color: AppColors.brandDeep),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18, color: color ?? AppColors.ink)),
      ],
    );
  }
}

class _ExtractList extends ConsumerWidget {
  const _ExtractList({required this.entries, required this.canWrite});
  final List<CashEntry> entries;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Nenhum movimento ainda.', style: TextStyle(color: AppColors.inkMuted)),
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
      itemBuilder: (_, i) => _EntryTile(entry: entries[i], canWrite: canWrite),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.canWrite});
  final CashEntry entry;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIn = entry.direction == 'in';
    final reversed = entry.reversedAt != null;
    final color = reversed
        ? AppColors.inkFaint
        : isIn
            ? AppColors.success
            : AppColors.danger;
    final subtitleParts = <String>[
      methodLabel(entry.method),
      if (entry.saleKind == 'os') 'OS',
      if (entry.description != null && entry.description!.isNotEmpty) entry.description!,
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
          color: reversed ? AppColors.inkFaint : AppColors.ink,
        ),
      ),
      subtitle: Text(subtitleParts.join(' · '),
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
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
          if (canWrite && !reversed)
            IconButton(
              tooltip: 'Estornar',
              icon: const Icon(Icons.undo, size: 18),
              onPressed: () => _confirmReverse(context, ref),
            ),
          if (reversed)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('estornado',
                  style: TextStyle(color: AppColors.inkFaint, fontSize: 11)),
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
