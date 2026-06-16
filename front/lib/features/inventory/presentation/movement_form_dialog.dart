import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';

/// Dialog para registrar entrada/saída/ajuste de estoque de um produto.
class MovementFormDialog extends ConsumerStatefulWidget {
  const MovementFormDialog({super.key, required this.itemId});

  final String itemId;

  static Future<bool?> show(BuildContext context, {required String itemId}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MovementFormDialog(itemId: itemId),
    );
  }

  @override
  ConsumerState<MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends ConsumerState<MovementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  final _note = TextEditingController();
  String _type = 'in';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final qty = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (qty == null) {
      setState(() => _error = 'Quantidade inválida.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = MovementDraft(
      type: _type,
      quantity: qty,
      reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .registerMovement(widget.itemId, draft);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adjust = _type == 'adjust';
    return AlertDialog(
      title: const Text('Registrar movimento'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'in',
                    label: Text('Entrada'),
                    icon: Icon(Icons.south_west, size: 18),
                  ),
                  ButtonSegment(
                    value: 'out',
                    label: Text('Saída'),
                    icon: Icon(Icons.north_east, size: 18),
                  ),
                  ButtonSegment(
                    value: 'adjust',
                    label: Text('Ajuste'),
                    icon: Icon(Icons.tune, size: 18),
                  ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (sel) => setState(() => _type = sel.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: adjust ? 'Saldo-alvo *' : 'Quantidade *',
                  prefixIcon: const Icon(Icons.numbers),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o valor' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
