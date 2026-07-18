import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import '../domain/customers_models.dart';

/// Dialog de criar/editar cliente. Usa `documentRequired` da config para marcar
/// o documento como obrigatório. UI fala só com o repository (via di).
class CustomerFormDialog extends ConsumerStatefulWidget {
  const CustomerFormDialog({
    super.key,
    this.existing,
    required this.documentRequired,
  });

  final Customer? existing;
  final bool documentRequired;

  static Future<bool?> show(
    BuildContext context, {
    Customer? existing,
    required bool documentRequired,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CustomerFormDialog(
        existing: existing,
        documentRequired: documentRequired,
      ),
    );
  }

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _document;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  String _type = 'PF';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _document = TextEditingController(text: c?.document ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _type = c?.type ?? 'PF';
  }

  @override
  void dispose() {
    for (final c in [_name, _document, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(customersRepositoryProvider);
    final draft = CustomerDraft(
      name: _name.text.trim(),
      type: _type,
      document: _opt(_document.text),
      phone: _opt(_phone.text),
      email: _opt(_email.text),
      address: _opt(_address.text),
      notes: _opt(_notes.text),
    );
    try {
      if (widget.existing == null) {
        await repo.createCustomer(draft);
      } else {
        await repo.updateCustomer(widget.existing!.id, draft);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return NeuDialog(
      title: editing ? 'Editar cliente' : 'Novo cliente',
      maxWidth: context.isMobile ? 560 : 480,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        NeuButton(
          label: 'Salvar',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    counterText: '',
                  ),
                  validator: Validators.required('Nome'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(value: 'PF', child: Text('Pessoa física')),
                          DropdownMenuItem(value: 'PJ', child: Text('Pessoa jurídica')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _type = v ?? 'PF';
                            // Reaplica a máscara do documento ao trocar PF/PJ.
                            _document.text = _type == 'PJ'
                                ? formatCnpj(_document.text)
                                : formatCpf(_document.text);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _document,
                        keyboardType: TextInputType.number,
                        inputFormatters: [documentFormatter(_type)],
                        decoration: InputDecoration(
                          labelText:
                              'Documento${widget.documentRequired ? ' *' : ' (opcional)'}',
                          hintText: _type == 'PJ'
                              ? '00.000.000/0000-00'
                              : '000.000.000-00',
                        ),
                        validator: Validators.combine([
                          if (widget.documentRequired) Validators.required('Documento'),
                          Validators.document(_type),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Telefone *',
                    hintText: '(00) 00000-0000',
                  ),
                  validator: Validators.phone(optional: false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'E-mail (opcional)',
                    counterText: '',
                  ),
                  validator: Validators.email(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Endereço (opcional)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    counterText: '',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
          ],
        ),
      ),
    );
  }
}
