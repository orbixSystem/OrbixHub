import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';

/// Parse de valor digitado (aceita vírgula) → double >= 0, ou null se inválido.
double? _parseAmount(String raw) {
  final v = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (v == null || v < 0) return null;
  return v;
}

void _snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ),
  );
}

/// Abrir o caixa (valor inicial em gaveta).
Future<void> showOpenSessionDialog(BuildContext context, WidgetRef ref) async {
  final amountCtrl = TextEditingController(text: '0');
  final notesCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Abrir caixa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor inicial (gaveta)',
              prefixText: 'R\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Observação (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final amount = _parseAmount(amountCtrl.text) ?? 0;
  try {
    await ref.read(cashierControllerProvider.notifier).open(
          openingAmount: amount,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
    if (context.mounted) _snack(context, 'Caixa aberto.');
  } catch (e) {
    if (context.mounted) _snack(context, '$e', error: true);
  }
}

/// Fechar o caixa: informa contado → mostra esperado e diferença.
Future<void> showCloseSessionDialog(BuildContext context, WidgetRef ref) async {
  final countedCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Fechar caixa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Conte o dinheiro em gaveta e informe o valor. '
            'Calculamos o esperado e a diferença.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: countedCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor contado',
              prefixText: 'R\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Observação (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Fechar caixa')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final counted = _parseAmount(countedCtrl.text);
  if (counted == null) {
    _snack(context, 'Informe um valor válido.', error: true);
    return;
  }
  try {
    final closed = await ref.read(cashierControllerProvider.notifier).close(
          countedAmount: counted,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
    if (!context.mounted) return;
    final diff = moneyToDouble(closed.difference);
    final label = diff == 0
        ? 'Caixa fechado certinho (sem diferença).'
        : diff > 0
            ? 'Caixa fechado com SOBRA de ${formatMoney(diff)}.'
            : 'Caixa fechado com FALTA de ${formatMoney(diff.abs())}.';
    _snack(context, label, error: diff != 0);
  } catch (e) {
    if (context.mounted) _snack(context, '$e', error: true);
  }
}

/// Novo lançamento (avulso/despesa/sangria/suprimento) ou recebimento de OS.
class EntryDialog extends ConsumerStatefulWidget {
  const EntryDialog({
    super.key,
    required this.config,
    this.presetCategory,
    this.presetSaleId,
  });

  final CashierConfig config;
  final String? presetCategory;
  final String? presetSaleId;

  @override
  ConsumerState<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends ConsumerState<EntryDialog> {
  late String _category =
      widget.presetCategory ?? (widget.presetSaleId != null ? 'os_payment' : 'venda_avulsa');
  late String _method = widget.config.paymentMethods.first;
  final _amountCtrl = TextEditingController();
  late final _saleIdCtrl = TextEditingController(text: widget.presetSaleId ?? '');
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _saleIdCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories => const [
        'os_payment',
        'venda_avulsa',
        'despesa',
        'sangria',
        'suprimento',
      ];

  Future<void> _submit() async {
    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _snack(context, 'Informe um valor maior que zero.', error: true);
      return;
    }
    final isOsPayment = _category == 'os_payment';
    final saleId = _saleIdCtrl.text.trim();
    if (isOsPayment && saleId.isEmpty) {
      _snack(context, 'Recebimento de OS exige o id da OS.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(cashierControllerProvider.notifier).addEntry(
            EntryDraft(
              amount: amount,
              method: _method,
              category: _category,
              saleKind: isOsPayment ? 'os' : null,
              saleId: isOsPayment ? saleId : null,
              description: _descCtrl.text.trim(),
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      _snack(context, 'Lançamento registrado.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOsPayment = _category == 'os_payment';
    return AlertDialog(
      title: const Text('Novo lançamento'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c, child: Text(categoryLabel(c))),
              ],
              onChanged: _saving ? null : (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Forma'),
              items: [
                for (final m in widget.config.paymentMethods)
                  DropdownMenuItem(value: m, child: Text(methodLabel(m))),
              ],
              onChanged: _saving ? null : (v) => setState(() => _method = v ?? _method),
            ),
            if (isOsPayment) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _saleIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'OS (id)',
                  helperText: 'Recebimento aponta para a OS',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Registrar'),
        ),
      ],
    );
  }
}

Future<void> showEntryDialog(
  BuildContext context,
  WidgetRef ref,
  CashierConfig config, {
  String? presetCategory,
  String? presetSaleId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => EntryDialog(
      config: config,
      presetCategory: presetCategory,
      presetSaleId: presetSaleId,
    ),
  );
}
