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

  Map<String, SubjectFieldConfig> get _byChave =>
      {for (final f in widget.config.subjectFields) f.chave: f};

  /// Códigos selecionados dos ancestrais (cascata) de um campo, por chave.
  /// Ex.: modelo → {marca: cod}; ano → {modelo: cod, marca: cod}.
  Map<String, String?> _ancestorCodesOf(SubjectFieldConfig field) {
    final codes = <String, String?>{};
    var cur = field.dependeDe;
    while (cur != null) {
      codes[cur] = _selectedCode[cur];
      cur = _byChave[cur]?.dependeDe;
    }
    return codes;
  }

  /// Limpa (texto + código) todo campo que dependa, direta ou transitivamente,
  /// de `chave` — trocar a marca zera modelo e ano.
  void _clearDescendants(String chave) {
    for (final dep in widget.config.subjectFields) {
      var cur = dep.dependeDe;
      while (cur != null) {
        if (cur == chave) {
          _fields[dep.chave]?.clear();
          _selectedCode[dep.chave] = null;
          break;
        }
        cur = _byChave[cur]?.dependeDe;
      }
    }
  }

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
                      // A key inclui os códigos dos ancestrais: ao trocar marca
                      // (ou modelo), os campos dependentes rebuildam já limpos.
                      key: ValueKey(
                        'lookup-${f.chave}-${_ancestorCodesOf(f).values.join(',')}',
                      ),
                      field: f,
                      controller: _fields[f.chave]!,
                      ancestorCodes: _ancestorCodesOf(f),
                      onSelected: (opt) {
                        setState(() {
                          _selectedCode[f.chave] =
                              opt.meta['codigo'] as String?;
                          _clearDescendants(f.chave);
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
    required this.ancestorCodes,
    required this.onSelected,
  });

  final SubjectFieldConfig field;
  final TextEditingController controller;

  /// Códigos dos ancestrais da cascata, por chave (marca/modelo).
  final Map<String, String?> ancestorCodes;
  final ValueChanged<LookupOption> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Autocomplete<LookupOption>(
      initialValue: TextEditingValue(text: controller.text),
      displayStringForOption: (o) => o.value,
      // Sem guarda de texto vazio: ao focar (clicar) o campo já mostra as
      // primeiras opções, e refiltra conforme digita. Modelo exige marca e ano
      // exige marca+modelo; sem o ancestral, o backend devolve [] (nada a sugerir).
      optionsBuilder: (value) async {
        final repo = ref.read(customersRepositoryProvider);
        return repo.lookup(
          field.fonte!,
          marca: ancestorCodes['marca'],
          modelo: ancestorCodes['modelo'],
          q: value.text,
        );
      },
      onSelected: (opt) {
        controller.text = opt.value;
        onSelected(opt);
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 380),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (context, i) {
                  final o = opts[i];
                  final logo = o.meta['logoUrl'] as String?;
                  return ListTile(
                    dense: true,
                    leading: logo == null
                        ? null
                        : SizedBox(
                            width: 28,
                            height: 28,
                            child: Image.network(
                              logo,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.directions_car_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                    title: Text(o.label),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        return TextFormField(
          key: Key('subjectField-${field.chave}'),
          controller: textController,
          focusNode: focusNode,
          onChanged: (v) => controller.text = v,
          // Enter seleciona a opção destacada (a 1ª por padrão).
          onFieldSubmitted: (_) => onSubmit(),
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
