import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';

/// Bottom sheet de SANGRIA (retirada da gaveta). Fluxo rápido: valor + forma
/// (sempre dinheiro) + descrição opcional. Separado para deixar claro o que é:
/// tirar dinheiro da gaveta sem dar falta.
Future<void> showSangriaSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SangriaSheet(externalRef: ref),
  );
}

class _SangriaSheet extends ConsumerStatefulWidget {
  const _SangriaSheet({required this.externalRef});
  final WidgetRef externalRef;

  @override
  ConsumerState<_SangriaSheet> createState() => _SangriaSheetState();
}

class _SangriaSheetState extends ConsumerState<_SangriaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

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
              method: 'dinheiro',
              category: 'sangria',
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
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: NeuSurface(
        elevation: NeuElevation.raised,
        child: Padding(
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
                        color: neu.danger.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_upward_rounded,
                          color: neu.danger, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('Sangria — Retirada da gaveta',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child: Text(
                    'Registra uma saída de dinheiro da gaveta. '
                    'Não cria conta a pagar — é uma retirada operacional.',
                    style: TextStyle(color: neu.inkMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
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
                NeuTextField(
                  label: 'Descrição (opcional)',
                  controller: _descCtrl,
                  hint: 'Ex.: Troco para o dia',
                  maxLength: 500,
                ),
                const SizedBox(height: 20),
                NeuButton(
                  label: 'Registrar sangria',
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
