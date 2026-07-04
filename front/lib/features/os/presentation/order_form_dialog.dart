import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../customers/domain/customers_models.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';

/// Dois modos de origem do cliente na "Nova OS".
enum _CustomerMode { existing, novo }

/// Dialog "Nova OS": cria uma OS com **cliente existente** (autocomplete +
/// veículo opcional) OU com **cliente novo na hora** (nome + telefone e, se o
/// tenant usa veículos, placa/marca/modelo). Retorna o id da OS criada (String)
/// via Navigator.pop. UI fala só com o repo.
class OrderFormDialog extends ConsumerStatefulWidget {
  const OrderFormDialog({super.key});

  /// Abre o dialog. Resolve para o id da OS criada (String) ou null se cancelado.
  static Future<Object?> show(BuildContext context) {
    return showDialog<Object?>(
      context: context,
      builder: (_) => const OrderFormDialog(),
    );
  }

  @override
  ConsumerState<OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends ConsumerState<OrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _complaint = TextEditingController();

  // Responsável: dropdown de membros da equipe. Guarda o uuid do membro (ou
  // null). Nunca enviamos string vazia — o backend valida `assignedTo` como uuid.
  String? _assignedTo;
  List<MemberOption> _members = const [];

  // Cliente novo
  final _newName = TextEditingController();
  final _newPhone = TextEditingController();

  // Campos dinâmicos do veículo/subject (cliente novo), vindos da config
  // (`subjectFields`): `identifier` (placa) + atributos (marca/modelo/ano/cor/…).
  // Nada de "placa"/"marca" hardcoded — o vertical mora na config.
  final Map<String, TextEditingController> _subjFields = {};

  /// Código FIPE selecionado por campo — alimenta a cascata marca→modelo→ano.
  final Map<String, String?> _selectedCode = {};

  _CustomerMode _mode = _CustomerMode.existing;

  // Cliente existente
  CustomerOption? _customer;
  List<SubjectOption> _subjects = const [];
  SubjectOption? _subject;
  bool _loadingSubjects = false;

  // Config do módulo de clientes (usaSubjects + rótulo + campos dinâmicos).
  // Default seguro: usa veículos, sem campos até a config carregar.
  CustomersConfig _config = const CustomersConfig();
  bool get _usaSubjects => _config.usaSubjects;
  String get _subjectLabelSingular => _config.subjectLabel.singular;

  DateTime? _scheduledStart;
  DateTime? _scheduledEnd;

  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadMembers();
  }

  @override
  void dispose() {
    for (final c in [_complaint, _newName, _newPhone, ..._subjFields.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final cfg = await ref.read(osRepositoryProvider).customersConfig();
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _rebuildSubjFields();
      });
    } on AppException {
      // falha graciosa: mantém o default (usaSubjects=true, "Veículo", sem campos).
    }
  }

  /// (Re)cria os controllers dos campos dinâmicos a partir da config carregada.
  void _rebuildSubjFields() {
    for (final c in _subjFields.values) {
      c.dispose();
    }
    _subjFields
      ..clear()
      ..addEntries(
        _config.subjectFields.map((f) => MapEntry(f.chave, TextEditingController())),
      );
    _selectedCode.clear();
  }

  Map<String, SubjectFieldConfig> get _byChave =>
      {for (final f in _config.subjectFields) f.chave: f};

  /// Códigos selecionados dos ancestrais (cascata) de um campo: modelo→{marca},
  /// ano→{marca, modelo}.
  Map<String, String?> _ancestorCodesOf(SubjectFieldConfig field) {
    final codes = <String, String?>{};
    var cur = field.dependeDe;
    while (cur != null) {
      codes[cur] = _selectedCode[cur];
      cur = _byChave[cur]?.dependeDe;
    }
    return codes;
  }

  /// Limpa todo campo que dependa, direta ou transitivamente, de `chave` —
  /// trocar a marca zera modelo e ano.
  void _clearDescendants(String chave) {
    for (final dep in _config.subjectFields) {
      var cur = dep.dependeDe;
      while (cur != null) {
        if (cur == chave) {
          _subjFields[dep.chave]?.clear();
          _selectedCode[dep.chave] = null;
          break;
        }
        cur = _byChave[cur]?.dependeDe;
      }
    }
  }

  Future<void> _loadMembers() async {
    try {
      final members = await ref.read(osRepositoryProvider).listMembers();
      if (!mounted) return;
      setState(() => _members = members);
    } on AppException {
      // sem membros / falha silenciosa — dropdown fica só com "sem responsável".
    }
  }

  String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_scheduledStart ?? DateTime.now())
        : (_scheduledEnd ?? _scheduledStart ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _scheduledStart = dt;
        // Se fim já está definido e ficou antes do início, reseta.
        if (_scheduledEnd != null && _scheduledEnd!.isBefore(dt)) {
          _scheduledEnd = null;
        }
      } else {
        _scheduledEnd = dt;
      }
    });
  }

  bool get _canSubmit => _mode == _CustomerMode.existing
      ? _customer != null
      : _newName.text.trim().isNotEmpty;

  Future<void> _pickCustomer(CustomerOption c) async {
    setState(() {
      _customer = c;
      _subject = null;
      _subjects = const [];
      _loadingSubjects = true;
    });
    try {
      final subs = await ref.read(osRepositoryProvider).subjectsOf(c.id);
      if (mounted) setState(() => _subjects = subs);
    } on AppException {
      // sem veículos / falha silenciosa — segue sem subject
    } finally {
      if (mounted) setState(() => _loadingSubjects = false);
    }
  }

  OrderDraft _buildDraft() {
    final complaint = _opt(_complaint.text);
    final assignedTo = _assignedTo;
    final startIso = _scheduledStart?.toUtc().toIso8601String();
    final endIso = _scheduledEnd?.toUtc().toIso8601String();
    if (_mode == _CustomerMode.existing) {
      return OrderDraft(
        customerId: _customer!.id,
        subjectId: _subject?.id,
        complaint: complaint,
        assignedTo: assignedTo,
        scheduledStart: startIso,
        scheduledEnd: endIso,
      );
    }
    // Cliente novo: monta identifier (placa) + atributos do veículo a partir dos
    // campos dinâmicos da config. Tudo opcional aqui (cadastro-relâmpago da OS).
    Map<String, dynamic>? attrs;
    String? identifier;
    if (_usaSubjects) {
      final built = <String, dynamic>{};
      for (final f in _config.subjectFields) {
        final raw = _subjFields[f.chave]?.text.trim() ?? '';
        if (f.chave == 'identifier') {
          identifier = raw.isEmpty ? null : raw;
          continue;
        }
        if (raw.isEmpty) continue;
        built[f.chave] = f.tipo == 'number' ? (num.tryParse(raw) ?? raw) : raw;
      }
      attrs = built.isEmpty ? null : built;
    }
    return OrderDraft(
      newCustomerName: _newName.text.trim(),
      newCustomerPhone: _opt(_newPhone.text),
      newSubjectIdentifier: identifier,
      newSubjectAttributes: attrs,
      complaint: complaint,
      assignedTo: assignedTo,
      scheduledStart: startIso,
      scheduledEnd: endIso,
    );
  }

  Future<void> _save() async {
    if (!_canSubmit) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final order =
          await ref.read(osRepositoryProvider).createOrder(_buildDraft());
      if (mounted) Navigator.of(context).pop(order.id);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _subjectTitle(SubjectOption s) =>
      s.label?.isNotEmpty == true ? s.label! : (s.identifier ?? 'Veículo');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova ordem de serviço'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- toggle de origem do cliente ----
                SegmentedButton<_CustomerMode>(
                  segments: const [
                    ButtonSegment(
                      value: _CustomerMode.existing,
                      icon: Icon(Icons.person_search_outlined),
                      label: Text('Cliente existente'),
                    ),
                    ButtonSegment(
                      value: _CustomerMode.novo,
                      icon: Icon(Icons.person_add_alt_1_outlined),
                      label: Text('Cliente novo'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _saving
                      ? null
                      : (sel) => setState(() {
                            _mode = sel.first;
                            _error = null;
                          }),
                ),
                const SizedBox(height: 16),
                if (_mode == _CustomerMode.existing)
                  _existingSection()
                else
                  _novoSection(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _complaint,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Relato do cliente *',
                    hintText: 'Descreva o problema relatado pelo cliente…',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o relato do cliente'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _assignedTo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Responsável *',
                    prefixIcon: Icon(Icons.engineering_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— Selecione —'),
                    ),
                    for (final m in _members)
                      DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(m.name),
                      ),
                  ],
                  onChanged:
                      _saving ? null : (id) => setState(() => _assignedTo = id),
                  validator: (v) =>
                      (v == null) ? 'Selecione um responsável' : null,
                ),
                const SizedBox(height: 12),
                // ---- Datas de previsão (obrigatórias) ----
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeField(
                        label: 'Início previsto *',
                        value: _scheduledStart,
                        fmt: _dtFmt,
                        enabled: !_saving,
                        onTap: () => _pickDateTime(isStart: true),
                        validator: (_) => _scheduledStart == null
                            ? 'Informe a data/hora de início'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTimeField(
                        label: 'Término previsto *',
                        value: _scheduledEnd,
                        fmt: _dtFmt,
                        enabled: !_saving,
                        onTap: () => _pickDateTime(isStart: false),
                        validator: (_) {
                          if (_scheduledEnd == null) {
                            return 'Informe a data/hora de término';
                          }
                          if (_scheduledStart != null &&
                              !_scheduledEnd!.isAfter(_scheduledStart!)) {
                            return 'Deve ser após o início';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_saving || !_canSubmit) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar OS'),
        ),
      ],
    );
  }

  /// Cliente existente: autocomplete + veículo opcional. Sem clientes não quebra —
  /// o campo fica vazio e o usuário pode trocar para "Cliente novo".
  Widget _existingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Autocomplete<CustomerOption>(
          displayStringForOption: (c) => c.name,
          optionsBuilder: (value) async {
            try {
              return await ref
                  .read(osRepositoryProvider)
                  .searchCustomers(value.text);
            } on AppException {
              return const Iterable<CustomerOption>.empty();
            }
          },
          onSelected: _pickCustomer,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Cliente *',
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'Buscar por nome',
              ),
              onChanged: (_) {
                // Limpa a seleção se o usuário editar o texto após escolher.
                if (_customer != null) setState(() => _customer = null);
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 240, maxWidth: 412),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final c in options)
                        ListTile(
                          dense: true,
                          title: Text(c.name),
                          subtitle: (c.document ?? c.phone) == null
                              ? null
                              : Text([
                                  if (c.document != null) c.document!,
                                  if (c.phone != null) c.phone!,
                                ].join(' · ')),
                          onTap: () => onSelected(c),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_customer != null) ...[
          const SizedBox(height: 12),
          if (_loadingSubjects)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_subjects.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _subject?.id,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _subjectLabelSingular,
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— nenhum —')),
                for (final s in _subjects)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(_subjectTitle(s)),
                  ),
              ],
              onChanged: (id) => setState(() {
                _subject =
                    id == null ? null : _subjects.firstWhere((s) => s.id == id);
              }),
            ),
        ],
      ],
    );
  }

  /// Cliente novo na hora: nome* + telefone e, se o tenant usa veículos, uma
  /// seção com placa/identificação + marca + modelo.
  Widget _novoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _newName,
          decoration: const InputDecoration(
            labelText: 'Nome *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          // Reavalia o botão "Criar OS" enquanto digita.
          onChanged: (_) => setState(() {}),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefone *',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Informe o telefone' : null,
        ),
        if (_usaSubjects) ...[
          const SizedBox(height: 16),
          _subjectCard(),
        ],
      ],
    );
  }

  Widget _subjectCard() {
    // Cores derivadas do tema (legíveis em claro E escuro): um wash translúcido
    // do acento em vez de um tom claro fixo — antes quebrava no modo escuro.
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_outlined,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                _subjectLabelSingular,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          // Campos dinâmicos da config: identifier (placa) + marca/modelo/ano/cor.
          // Campos com `fonte` viram picker FIPE com cascata (marca→modelo→ano);
          // os demais, texto livre. Todos opcionais no cadastro-relâmpago da OS.
          for (final f in _config.subjectFields) ...[
            const SizedBox(height: 12),
            if (f.fonte != null)
              _SubjectLookupField(
                // A key inclui os códigos dos ancestrais: ao trocar marca (ou
                // modelo), os dependentes rebuildam já limpos.
                key: ValueKey(
                  'os-lookup-${f.chave}-${_ancestorCodesOf(f).values.join(',')}',
                ),
                field: f,
                controller: _subjFields[f.chave]!,
                ancestorCodes: _ancestorCodesOf(f),
                onSelected: (opt) {
                  setState(() {
                    _selectedCode[f.chave] = opt.meta['codigo'] as String?;
                    _clearDescendants(f.chave);
                  });
                },
              )
            else
              TextFormField(
                controller: _subjFields[f.chave],
                decoration: InputDecoration(
                  // A identificação (placa) é obrigatória; demais campos opcionais.
                  labelText: f.chave == 'identifier' ? '${f.rotulo} *' : f.rotulo,
                ),
                keyboardType: f.tipo == 'number'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                inputFormatters: f.tipo == 'number'
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                    : null,
                validator: f.chave == 'identifier'
                    ? (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe a ${f.rotulo.toLowerCase()}'
                        : null
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}

/// Campo de data+hora somente-leitura que abre picker ao ser tocado.
/// Valida via [FormField] para integrar com o [Form] do dialog.
class _DateTimeField extends FormField<DateTime?> {
  _DateTimeField({
    required String label,
    required DateTime? value,
    required DateFormat fmt,
    required bool enabled,
    required VoidCallback onTap,
    super.validator,
  }) : super(
          initialValue: value,
          builder: (state) {
            final scheme = state.context.findAncestorWidgetOfExactType<MaterialApp>() != null
                ? Theme.of(state.context).colorScheme
                : Theme.of(state.context).colorScheme;
            final hasError = state.hasError;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: enabled ? onTap : null,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: label,
                      prefixIcon: const Icon(Icons.calendar_month_outlined),
                      errorText: hasError ? state.errorText : null,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: hasError
                              ? scheme.error
                              : scheme.outlineVariant,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      value != null ? fmt.format(value) : '—',
                      style: TextStyle(
                        color: value != null
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
}

/// Campo de texto com sugestões (não-obrigatórias) vindas do repo de OS
/// (`lookup` → mesma fonte FIPE do módulo Clientes). Permite digitar valores fora
/// da lista; ao escolher uma opção, notifica o pai (guarda o código → cascata).
class _SubjectLookupField extends ConsumerWidget {
  const _SubjectLookupField({
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
      // Ao focar, já mostra as primeiras opções e refiltra ao digitar. Modelo
      // exige marca e ano exige marca+modelo; sem o ancestral o backend devolve [].
      optionsBuilder: (value) async {
        try {
          return await ref.read(osRepositoryProvider).lookup(
                field.fonte!,
                marca: ancestorCodes['marca'],
                modelo: ancestorCodes['modelo'],
                q: value.text,
              );
        } on AppException {
          return const Iterable<LookupOption>.empty();
        }
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
          key: Key('osSubjectField-${field.chave}'),
          controller: textController,
          focusNode: focusNode,
          onChanged: (v) => controller.text = v,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(labelText: field.rotulo),
        );
      },
    );
  }
}
