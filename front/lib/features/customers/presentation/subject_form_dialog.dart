import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../domain/customers_models.dart';
import 'customers_providers.dart';

/// Dialog de criar/editar subject com campos DINÂMICOS vindos da config
/// (`subjectFields`). O campo de chave `identifier` mapeia para `subject.identifier`;
/// os demais vão para `attributes`. Nada de "Veículo"/"placa" hardcoded.
///
/// UI no design system neumórfico com layouts SEPARADOS: no desktop/tablet (≥600)
/// duas colunas — foto à esquerda, campos à direita; no mobile empilha (foto no
/// topo). O topo traz um "photo picker" grande. No modo edição a foto sobe/na hora
/// (setSubjectPhoto/removeSubjectPhoto); no modo criação a foto fica em memória e
/// sobe DEPOIS de o subject ser criado (createSubject → setSubjectPhoto).
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

  // ---- foto ----
  /// URL da foto atual (só no modo edição). Reflete o resultado dos uploads.
  String? _photoUrl;

  /// Bytes escolhidos ainda não enviados (usado no modo CRIAÇÃO — sem id ainda,
  /// preview local via Image.memory; sobe após o createSubject).
  Uint8List? _localBytes;
  String? _localFilename;
  String? _localContentType;

  /// Enquanto envia/remove foto no modo edição.
  bool _photoBusy = false;

  bool get _editing => widget.existing != null;

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
    _photoUrl = s?.photoUrl;
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _invalidateLists() =>
      ref.invalidate(subjectsForCustomerProvider(widget.customerId));

  /// Abre o seletor de imagem. No modo edição envia na hora; no modo criação só
  /// guarda os bytes para o preview (sobem depois do createSubject).
  Future<void> _pickPhoto() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? 'jpeg').toLowerCase();
    final contentType = 'image/$ext';

    if (_editing) {
      setState(() => _photoBusy = true);
      try {
        final updated =
            await ref.read(customersRepositoryProvider).setSubjectPhoto(
                  widget.existing!.id,
                  bytes: bytes,
                  filename: file.name,
                  contentType: contentType,
                );
        if (!mounted) return;
        setState(() {
          _photoUrl = updated.photoUrl;
          _localBytes = null;
        });
        _invalidateLists();
      } on AppException catch (e) {
        _snack(e.message);
      } finally {
        if (mounted) setState(() => _photoBusy = false);
      }
    } else {
      setState(() {
        _localBytes = bytes;
        _localFilename = file.name;
        _localContentType = contentType;
      });
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showNeuConfirm(
      context,
      title: 'Remover foto?',
      message: 'A foto do veículo será removida.',
      confirmLabel: 'Remover',
    );
    if (!confirmed || !mounted) return;

    if (_editing && (_photoUrl?.isNotEmpty ?? false)) {
      setState(() => _photoBusy = true);
      try {
        await ref
            .read(customersRepositoryProvider)
            .removeSubjectPhoto(widget.existing!.id);
        if (!mounted) return;
        setState(() => _photoUrl = null);
        _invalidateLists();
      } on AppException catch (e) {
        _snack(e.message);
      } finally {
        if (mounted) setState(() => _photoBusy = false);
      }
    } else {
      setState(() {
        _localBytes = null;
        _localFilename = null;
        _localContentType = null;
      });
    }
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
        // Cria PRIMEIRO; se havia foto escolhida, sobe depois (com o id novo).
        // Se o upload falhar, o veículo já foi criado — avisa e segue.
        final created = await repo.createSubject(widget.customerId, draft);
        if (_localBytes != null) {
          try {
            await repo.setSubjectPhoto(
              created.id,
              bytes: _localBytes!,
              filename: _localFilename ?? 'foto.jpg',
              contentType: _localContentType ?? 'image/jpeg',
            );
          } on AppException catch (e) {
            _snack('Veículo criado, mas a foto não pôde ser enviada: '
                '${e.message}');
          }
        }
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
    final neu = context.neu;
    final label = widget.config.subjectLabel.singular;
    final twoCol = !context.isMobile;

    final photo = _VehiclePhotoPicker(
      localBytes: _localBytes,
      photoUrl: _photoUrl,
      busy: _photoBusy,
      onPick: _pickPhoto,
      onRemove: _removePhoto,
    );
    final fields = _fieldsColumn(neu);

    final Widget content = twoCol
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 244, child: photo),
              const SizedBox(width: 22),
              Expanded(child: fields),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              photo,
              const SizedBox(height: 20),
              fields,
            ],
          );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          EdgeInsets.symmetric(horizontal: twoCol ? 40 : 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: twoCol ? 720 : 460),
        child: NeuSurface(
          elevation: NeuElevation.raisedHigh,
          radius: NeuTokens.rPanel,
          color: neu.surface,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeuIconChip.glyph(context,
                        icon: Icons.directions_car_rounded,
                        index: 1,
                        size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _editing ? 'Editar $label' : 'Novo $label',
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    NeuIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Fechar',
                      size: 38,
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(child: content),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  NeuSurface(
                    elevation: NeuElevation.flat,
                    radius: NeuTokens.rField,
                    color: neu.danger.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 18, color: neu.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: neu.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeuButton(
                      label: 'Cancelar',
                      kind: NeuButtonKind.secondary,
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 10),
                    NeuButton(
                      label: 'Salvar',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldsColumn(NeuTokens neu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuTextField(
          controller: _label,
          label: 'Apelido',
          hint: 'Ex.: Carro da esposa (opcional)',
        ),
        for (final f in widget.config.subjectFields) ...[
          const SizedBox(height: 14),
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
                  _selectedCode[f.chave] = opt.meta['codigo'] as String?;
                  _clearDescendants(f.chave);
                });
              },
            )
          else
            NeuTextField(
              controller: _fields[f.chave],
              label: '${f.rotulo}${f.obrigatorio ? ' *' : ''}',
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
      ],
    );
  }
}

/// Seletor de foto do veículo (destaque no topo do form). Com foto: preview
/// (memória na criação, rede na edição) + "Trocar"/"Remover". Sem foto: estado
/// vazio convidativo e tocável.
class _VehiclePhotoPicker extends StatelessWidget {
  const _VehiclePhotoPicker({
    required this.localBytes,
    required this.photoUrl,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? localBytes;
  final String? photoUrl;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  bool get _hasPhoto =>
      localBytes != null || (photoUrl != null && photoUrl!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Foto do veículo',
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: _hasPhoto ? _preview(neu) : _empty(neu),
        ),
        if (_hasPhoto) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NeuButton(
                  label: 'Trocar',
                  icon: Icons.sync_rounded,
                  kind: NeuButtonKind.secondary,
                  onPressed: busy ? null : onPick,
                ),
              ),
              const SizedBox(width: 8),
              NeuIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Remover foto',
                size: 48,
                color: neu.danger,
                onPressed: busy ? null : onRemove,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _preview(NeuTokens neu) {
    final Widget img = localBytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(NeuTokens.rField),
            child: Image.memory(
              localBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          )
        : NeuNetworkImage(
            url: photoUrl,
            radius: NeuTokens.rField,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
    return GestureDetector(
      onTap: busy ? null : onPick,
      child: Stack(
        fit: StackFit.expand,
        children: [
          img,
          if (busy)
            ClipRRect(
              borderRadius: BorderRadius.circular(NeuTokens.rField),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(NeuTokens neu) {
    return GestureDetector(
      onTap: busy ? null : onPick,
      child: NeuSurface(
        elevation: NeuElevation.inset,
        radius: NeuTokens.rField,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 36, color: neu.navy),
                const SizedBox(height: 12),
                Text(
                  'Adicionar foto do veículo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toque para escolher uma imagem',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto com sugestões não-obrigatórias vindas do repository
/// (`lookup`). Permite digitar valores fora da lista; ao escolher uma opção,
/// notifica o pai (para guardar o código e disparar a cascata). Estilizado no
/// design system: rótulo acima + cavidade (inset), mantendo toda a lógica.
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
    final neu = context.neu;
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
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              color: neu.surface,
              elevation: 6,
              borderRadius: BorderRadius.circular(NeuTokens.rField),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 280, maxWidth: 380),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.directions_car_outlined,
                                  size: 20,
                                  color: neu.inkMuted,
                                ),
                              ),
                            ),
                      title: Text(o.label, style: TextStyle(color: neu.ink)),
                      onTap: () => onSelected(o),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                '${field.rotulo}${field.obrigatorio ? ' *' : ''}',
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              child: TextFormField(
                key: Key('subjectField-${field.chave}'),
                controller: textController,
                focusNode: focusNode,
                onChanged: (v) => controller.text = v,
                // Enter seleciona a opção destacada (a 1ª por padrão).
                onFieldSubmitted: (_) => onSubmit(),
                style: TextStyle(color: neu.ink, fontSize: 15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon:
                      Icon(Icons.expand_more_rounded, color: neu.inkMuted),
                  errorStyle: TextStyle(
                    color: neu.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                validator: (v) {
                  if (field.obrigatorio && (v == null || v.trim().isEmpty)) {
                    return '${field.rotulo} é obrigatório';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
