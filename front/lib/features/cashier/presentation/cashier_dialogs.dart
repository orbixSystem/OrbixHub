import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';

/// Lançamento manual de caixa: entrada genérica (suprimento) ou saída genérica
/// (despesa) com valor, forma de pagamento e descrição opcional.
///
/// Usado tanto no grid rápido da tela do Caixa quanto no FAB global do shell.
/// Não se confunde com Sangria/Suprimento (operações de gaveta) nem com
/// Receber/Venda (vinculados a uma OS ou venda).
Future<void> showEntryDialog(
  BuildContext context,
  WidgetRef ref,
  CashierConfig config,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EntrySheet(externalRef: ref, config: config),
  );
}

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({required this.externalRef, required this.config});
  final WidgetRef externalRef;
  final CashierConfig config;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isEntrada = true;
  late String _method;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _method = widget.config.paymentMethods.isNotEmpty
        ? widget.config.paymentMethods.first
        : 'dinheiro';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.externalRef
          .read(cashierControllerProvider.notifier)
          .addEntry(
            EntryDraft(
              amount: amount,
              method: _method,
              category: _isEntrada ? 'suprimento' : 'despesa',
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: context.neu.danger,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final accentColor = _isEntrada ? const Color(0xFF16A34A) : neu.danger;
    final accentIcon =
        _isEntrada ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: NeuSurface(
          elevation: NeuElevation.raised,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: neu.inkFaint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Cabeçalho
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(accentIcon, color: accentColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text('Lançamento de caixa',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Direção
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Entrada'),
                        icon: Icon(Icons.arrow_downward_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Saída'),
                        icon: Icon(Icons.arrow_upward_rounded, size: 16),
                      ),
                    ],
                    selected: {_isEntrada},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) =>
                        setState(() => _isEntrada = sel.first),
                  ),
                  const SizedBox(height: 16),
                  // Valor
                  NeuTextField(
                    label: 'Valor *',
                    controller: _amountCtrl,
                    hint: '0,00',
                    prefixIcon: Icons.attach_money_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [DecimalInputFormatter()],
                    validator: Validators.positiveNumber(field: 'Valor'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 14),
                  // Forma de pagamento
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento *',
                      prefixIcon: Icon(Icons.payment_outlined),
                    ),
                    items: [
                      for (final m in widget.config.paymentMethods)
                        DropdownMenuItem(value: m, child: Text(methodLabel(m))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _method = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  NeuTextField(
                    label: 'Descrição (opcional)',
                    controller: _descCtrl,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 20),
                  NeuButton(
                    label: _isEntrada ? 'Registrar entrada' : 'Registrar saída',
                    expanded: true,
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
