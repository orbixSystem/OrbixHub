import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import '../domain/customers_models.dart';

/// Dialog de criar/editar subject com campos DINÂMICOS vindos da config
/// (`subjectFields`). O campo de chave `identifier` mapeia para `subject.identifier`;
/// os demais vão para `attributes`. Nada de "Veículo"/"placa" hardcoded.
class SubjectFormDialog extends ConsumerStatefulWidget {
  const SubjectFormDialog({
    super.key,
    required this.customerId,
    required this.config,
    this.existing,
  });

  final String customerId;
  final CustomersConfig config;
  final Subject? existing;

  static Future<bool?> show(
    BuildContext context, {
    required String customerId,
    required CustomersConfig config,
    Subject? existing,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => SubjectFormDialog(
        customerId: customerId,
        config: config,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends ConsumerState<SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  String? _error;

  /// Código FIPE da opção selecionada por campo (alimenta a cascata).
  final Map<String, String?> _selectedCode = {};

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _label = TextEditingController(text: s?.label ?? '');
    _fields = {
      for (final f in widget.config.subjectFields)
        f.chave: TextEditingController(
          text: f.chave == 'identifier'
              ? (s?.identifier ?? '')
              : (s?.attributes[f.chave]?.toString() ?? ''),
        ),
    };
  }

  @override
  void dispose() {
    _label.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    String? identifier;
    final attributes = <String, dynamic>{};
    for (final f in widget.config.subjectFields) {
      final raw = _fields[f.chave]!.text.trim();
      if (f.chave == 'identifier') {
        identifier = raw.isEmpty ? null : raw;
        continue;
      }
      if (raw.isEmpty) continue;
      attributes[f.chave] =
          f.tipo == 'number' ? num.tryParse(raw) ?? raw : raw;
    }

    final draft = SubjectDraft(
      label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      identifier: identifier,
      attributes: attributes,
    );
    final repo = ref.read(customersRepositoryProvider);
    try {
      if (widget.existing == null) {
        await repo.createSubject(widget.customerId, draft);
      } else {
        await repo.updateSubject(widget.existing!.id, draft);
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
    final label = widget.config.subjectLabel.singular;
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Editar $label' : 'Novo $label'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Apelido'),
                ),
                for (final f in widget.config.subjectFields) ...[
                  const SizedBox(height: 12),
                  if (f.fonte != null)
                    _LookupField(
                      key: ValueKey(
                        'lookup-${f.chave}-${f.dependeDe == null ? '' : (_selectedCode[f.dependeDe] ?? '')}',
                      ),
                      field: f,
                      controller: _fields[f.chave]!,
                      marcaCodigo: f.dependeDe == null
                          ? null
                          : _selectedCode[f.dependeDe],
                      onSelected: (opt) {
                        // setState p/ os campos dependentes rebuildarem com o
                        // novo código (a cascata lê _selectedCode no build).
                        setState(() {
                          _selectedCode[f.chave] =
                              opt.meta['codigo'] as String?;
                          // troca de marca limpa os campos dependentes
                          for (final dep in widget.config.subjectFields) {
                            if (dep.dependeDe == f.chave) {
                              _fields[dep.chave]!.clear();
                              _selectedCode[dep.chave] = null;
                            }
                          }
                        });
                      },
                    )
                  else
                    TextFormField(
                      controller: _fields[f.chave],
                      decoration: InputDecoration(
                        labelText: '${f.rotulo}${f.obrigatorio ? ' *' : ''}',
                      ),
                      keyboardType: f.tipo == 'number'
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      inputFormatters: f.tipo == 'number'
                          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                          : null,
                      validator: (v) {
                        if (f.obrigatorio && (v == null || v.trim().isEmpty)) {
                          return '${f.rotulo} é obrigatório';
                        }
                        return null;
                      },
                    ),
                ],
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

/// Campo de texto com sugestões não-obrigatórias vindas do repository
/// (`lookup`). Permite digitar valores fora da lista; ao escolher uma opção,
/// notifica o pai (para guardar o código e disparar a cascata).
class _LookupField extends ConsumerWidget {
  const _LookupField({
    super.key,
    required this.field,
    required this.controller,
    required this.marcaCodigo,
    required this.onSelected,
  });

  final SubjectFieldConfig field;
  final TextEditingController controller;
  final String? marcaCodigo;
  final ValueChanged<LookupOption> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Autocomplete<LookupOption>(
      initialValue: TextEditingValue(text: controller.text),
      displayStringForOption: (o) => o.value,
      optionsBuilder: (value) async {
        if (value.text.isEmpty) return const Iterable<LookupOption>.empty();
        final repo = ref.read(customersRepositoryProvider);
        return repo.lookup(
          field.fonte!,
          marca: marcaCodigo,
          q: value.text,
        );
      },
      onSelected: (opt) {
        controller.text = opt.value;
        onSelected(opt);
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        return TextFormField(
          key: Key('subjectField-${field.chave}'),
          controller: textController,
          focusNode: focusNode,
          onChanged: (v) => controller.text = v,
          decoration: InputDecoration(
            labelText: '${field.rotulo}${field.obrigatorio ? ' *' : ''}',
          ),
          validator: (v) {
            if (field.obrigatorio && (v == null || v.trim().isEmpty)) {
              return '${field.rotulo} é obrigatório';
            }
            return null;
          },
        );
      },
    );
  }
}
