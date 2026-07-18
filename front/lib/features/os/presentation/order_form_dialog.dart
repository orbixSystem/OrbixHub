import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../customers/domain/customers_models.dart';
import '../domain/os_models.dart';
import 'os_providers.dart';

/// Dois modos de origem do cliente na "Nova OS".
enum _CustomerMode { existing, novo }

/// Passos do wizard "Nova OS". O passo [veiculo] só existe quando o tenant usa
/// veículos/subjects (`usaSubjects`); do contrário o wizard tem 2 passos.
enum _WizardStep { cliente, veiculo, detalhes }

/// Dialog "Nova OS": cria uma OS em um **wizard por passos** (mais guiado, para
/// usuário pouco digital) com **cliente existente** (autocomplete + veículo
/// opcional) OU **cliente novo na hora** (nome + telefone e, se o tenant usa
/// veículos, placa/marca/modelo). Retorna o id da OS criada (String) via
/// Navigator.pop. UI fala só com o repo.
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

  // Passo atual do wizard (índice na lista dinâmica de passos [_steps]).
  int _stepIndex = 0;

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
    // Todos os campos obrigatórios (relato + responsável) vivem no último passo,
    // portanto estão montados aqui — o Form valida-os antes de criar.
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

  // ---------------------------------------------------------------------------
  // Navegação do wizard
  // ---------------------------------------------------------------------------

  /// Passos vigentes: o passo [veiculo] some quando o tenant não usa subjects.
  List<_WizardStep> get _steps => [
        _WizardStep.cliente,
        if (_usaSubjects) _WizardStep.veiculo,
        _WizardStep.detalhes,
      ];

  _WizardStep get _current => _steps[_stepIndex];
  bool get _isFirst => _stepIndex == 0;
  bool get _isLast => _stepIndex == _steps.length - 1;

  /// Pode avançar do passo atual? Só o passo do cliente bloqueia (precisa de um
  /// cliente válido); veículo é opcional. O último passo não usa este gate.
  bool get _canAdvance => switch (_current) {
        _WizardStep.cliente => _canSubmit,
        _WizardStep.veiculo => true,
        _WizardStep.detalhes => _canSubmit,
      };

  void _next() {
    if (!_canAdvance || _isLast) return;
    setState(() => _stepIndex++);
  }

  void _back() {
    if (_isFirst) return;
    setState(() => _stepIndex--);
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // Config pode reduzir os passos (usaSubjects=false) depois de aberto —
    // mantém o índice dentro dos limites.
    if (_stepIndex > _steps.length - 1) _stepIndex = _steps.length - 1;

    final primaryEnabled = _isLast ? _canSubmit : _canAdvance;

    return NeuDialog(
      title: 'Nova ordem de serviço',
      maxWidth: context.isMobile ? 560 : 480,
      actions: [
        NeuButton(
          label: _isFirst ? 'Cancelar' : 'Voltar',
          kind: NeuButtonKind.secondary,
          icon: _isFirst ? null : Icons.arrow_back_rounded,
          onPressed: _saving
              ? null
              : (_isFirst ? () => Navigator.of(context).pop() : _back),
        ),
        NeuButton(
          label: _isLast ? 'Criar OS' : 'Próximo',
          icon: _isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
          loading: _saving,
          onPressed: (_saving || !primaryEnabled)
              ? null
              : (_isLast ? _save : _next),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stepperHeader(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey(_current),
                child: _stepBody(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: neu.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_current) {
      case _WizardStep.cliente:
        return _clienteStep();
      case _WizardStep.veiculo:
        return _veiculoStep();
      case _WizardStep.detalhes:
        return _detalhesStep();
    }
  }

  // ---------------------------------------------------------------------------
  // Cabeçalho de progresso (stepper)
  // ---------------------------------------------------------------------------

  Widget _stepperHeader() {
    final neu = context.neu;
    final steps = _steps;
    final labels = <_WizardStep, String>{
      _WizardStep.cliente: 'Cliente',
      _WizardStep.veiculo: _subjectLabelSingular,
      _WizardStep.detalhes: 'Detalhes',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 15),
                height: 2,
                color: i <= _stepIndex ? neu.navy : neu.line,
              ),
            ),
          _stepDot(i, labels[steps[i]]!),
        ],
      ],
    );
  }

  Widget _stepDot(int i, String label) {
    final neu = context.neu;
    final done = i < _stepIndex;
    final active = i == _stepIndex;
    final filled = done || active;
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? neu.navy : neu.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: filled ? neu.navy : neu.line,
                width: 2,
              ),
              boxShadow: active ? neu.raised() : null,
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 18, color: neu.onNavy)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: filled ? neu.onNavy : neu.inkMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? neu.ink : neu.inkMuted,
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Passo 1 — Cliente
  // ---------------------------------------------------------------------------

  Widget _clienteStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeToggle(),
        const SizedBox(height: 16),
        if (_mode == _CustomerMode.existing)
          _customerAutocomplete()
        else
          _novoCustomerFields(),
      ],
    );
  }

  Widget _modeToggle() {
    return Row(
      children: [
        Expanded(
          child: _modeChip(
            _CustomerMode.existing,
            Icons.person_search_outlined,
            'Cliente existente',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _modeChip(
            _CustomerMode.novo,
            Icons.person_add_alt_1_outlined,
            'Cliente novo',
          ),
        ),
      ],
    );
  }

  Widget _modeChip(_CustomerMode mode, IconData icon, String label) {
    final neu = context.neu;
    final selected = _mode == mode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _saving
          ? null
          : () => setState(() {
                _mode = mode;
                _error = null;
              }),
      child: NeuSurface(
        elevation: selected ? NeuElevation.flat : NeuElevation.raised,
        radius: NeuTokens.rField,
        color: selected ? neu.navy : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18, color: selected ? neu.onNavy : neu.inkMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? neu.onNavy : neu.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cliente existente: autocomplete restilizado (mantém optionsBuilder/onSelected).
  /// Sem clientes não quebra — o campo fica vazio e o usuário pode trocar de modo.
  Widget _customerAutocomplete() {
    final neu = context.neu;
    return Autocomplete<CustomerOption>(
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
        return _fieldShell(
          label: 'Cliente *',
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(color: neu.ink, fontSize: 15),
            onChanged: (_) {
              // Limpa a seleção se o usuário editar o texto após escolher.
              if (_customer != null) setState(() => _customer = null);
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nome',
              hintStyle: TextStyle(color: neu.inkFaint),
              prefixIcon:
                  Icon(Icons.person_outline, size: 20, color: neu.inkMuted),
              border: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: neu.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(NeuTokens.rField),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 412),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final c in options)
                    ListTile(
                      dense: true,
                      title: Text(c.name, style: TextStyle(color: neu.ink)),
                      subtitle: (c.document ?? c.phone) == null
                          ? null
                          : Text(
                              [
                                if (c.document != null) c.document!,
                                if (c.phone != null) c.phone!,
                              ].join(' · '),
                              style: TextStyle(color: neu.inkMuted),
                            ),
                      onTap: () => onSelected(c),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Cliente novo na hora: nome* + telefone.
  Widget _novoCustomerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuTextField(
          label: 'Nome *',
          controller: _newName,
          prefixIcon: Icons.person_outline,
          enabled: !_saving,
          maxLength: 120,
          // Reavalia o botão "Próximo" enquanto digita.
          onChanged: (_) => setState(() {}),
          validator: Validators.required('Nome'),
        ),
        const SizedBox(height: 12),
        NeuTextField(
          label: 'Telefone *',
          controller: _newPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneInputFormatter()],
          prefixIcon: Icons.phone_outlined,
          enabled: !_saving,
          validator: Validators.phone(optional: false),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Passo 2 — Veículo (opcional; ausente quando !_usaSubjects)
  // ---------------------------------------------------------------------------

  Widget _veiculoStep() {
    final neu = context.neu;
    if (_mode == _CustomerMode.existing) {
      // Cliente existente: escolhe entre os veículos já cadastrados.
      if (_loadingSubjects) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        );
      }
      if (_subjects.isEmpty) {
        return Text(
          'Nenhum ${_subjectLabelSingular.toLowerCase()} cadastrado para este '
          'cliente. Você pode seguir sem selecionar.',
          style: TextStyle(color: neu.inkMuted, fontSize: 14),
        );
      }
      return _labeledDropdown(
        label: _subjectLabelSingular,
        value: _subject?.id,
        icon: Icons.directions_car_outlined,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('— nenhum —'),
          ),
          for (final s in _subjects)
            DropdownMenuItem<String?>(
              value: s.id,
              child: Text(_subjectTitle(s)),
            ),
        ],
        onChanged: (id) => setState(() {
          _subject =
              id == null ? null : _subjects.firstWhere((s) => s.id == id);
        }),
      );
    }
    // Cliente novo: campos dinâmicos da config (placa + marca/modelo/ano/cor),
    // com cascata FIPE. Todos opcionais no cadastro-relâmpago da OS.
    return _novoSubjectFields();
  }

  Widget _novoSubjectFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campos dinâmicos da config. Campos com `fonte` viram picker FIPE com
        // cascata (marca→modelo→ano); os demais, texto livre.
        for (var idx = 0; idx < _config.subjectFields.length; idx++) ...[
          if (idx > 0) const SizedBox(height: 12),
          _subjectFieldWidget(_config.subjectFields[idx]),
        ],
      ],
    );
  }

  Widget _subjectFieldWidget(SubjectFieldConfig f) {
    if (f.fonte != null) {
      return _SubjectLookupField(
        // A key inclui os códigos dos ancestrais: ao trocar marca (ou modelo),
        // os dependentes rebuildam já limpos.
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
      );
    }
    // A identificação (placa) é obrigatória se preenchida; demais campos livres.
    final isIdentifier = f.chave == 'identifier';
    return NeuTextField(
      label: isIdentifier ? '${f.rotulo} *' : f.rotulo,
      controller: _subjFields[f.chave],
      keyboardType: f.tipo == 'number'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      // Identificação = placa: máscara Mercosul/antiga (MAIÚSCULO, 7 chars).
      inputFormatters: isIdentifier ? [PlateInputFormatter()] : null,
      validator: isIdentifier
          ? (v) => (v == null || v.trim().isEmpty)
              ? 'Informe a ${f.rotulo.toLowerCase()}'
              : null
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Passo 3 — Detalhes
  // ---------------------------------------------------------------------------

  Widget _detalhesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuTextField(
          label: 'Relato do cliente *',
          controller: _complaint,
          hint: 'Descreva o problema relatado pelo cliente…',
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          enabled: !_saving,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Informe o relato do cliente'
              : null,
        ),
        const SizedBox(height: 12),
        _responsavelDropdown(),
        const SizedBox(height: 12),
        // ---- Datas de previsão (OPCIONAIS — cadastro-relâmpago da OS; a agenda
        // usa quando preenchidas). Se preenchidas, término > início.
        Row(
          children: [
            Expanded(
              child: _DateTimeField(
                label: 'Início previsto',
                value: _scheduledStart,
                fmt: _dtFmt,
                enabled: !_saving,
                onTap: () => _pickDateTime(isStart: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateTimeField(
                label: 'Término previsto',
                value: _scheduledEnd,
                fmt: _dtFmt,
                enabled: !_saving,
                onTap: () => _pickDateTime(isStart: false),
                validator: (_) {
                  if (_scheduledEnd != null &&
                      _scheduledStart != null &&
                      !_scheduledEnd!.isAfter(_scheduledStart!)) {
                    return 'Deve ser após o início';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Responsável: dropdown obrigatório (validado no Form). Mantém o
  /// [DropdownButtonFormField] para preservar a validação, estilizado na
  /// cavidade (inset) do design system.
  Widget _responsavelDropdown() {
    final neu = context.neu;
    return _fieldShell(
      label: 'Responsável *',
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String?>(
        initialValue: _assignedTo,
        isExpanded: true,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        dropdownColor: neu.surface,
        icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
        style: TextStyle(color: neu.ink, fontSize: 15),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('— Selecione —',
                style: TextStyle(color: neu.inkFaint, fontSize: 15)),
          ),
          for (final m in _members)
            DropdownMenuItem<String?>(
              value: m.id,
              child: Text(m.name, style: TextStyle(color: neu.ink)),
            ),
        ],
        onChanged: _saving ? null : (id) => setState(() => _assignedTo = id),
        validator: (v) => (v == null) ? 'Selecione um responsável' : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers de apresentação
  // ---------------------------------------------------------------------------

  /// Envolve um controle arbitrário no visual de campo do design system: rótulo
  /// em cima (sempre visível) + cavidade (inset) com raio de campo. Mesma
  /// estrutura do [NeuTextField], para dropdowns e autocompletes.
  Widget _fieldShell({
    required String label,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
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
          padding: padding,
          child: child,
        ),
      ],
    );
  }

  Widget _labeledDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final neu = context.neu;
    return _fieldShell(
      label: label,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: neu.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(NeuTokens.rField),
                dropdownColor: neu.surface,
                icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
                style: TextStyle(color: neu.ink, fontSize: 15),
                padding: const EdgeInsets.symmetric(vertical: 12),
                items: items,
                onChanged: _saving ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de data+hora somente-leitura que abre picker ao ser tocado.
/// Valida via [FormField] para integrar com o [Form] do dialog. Estilo do
/// design system: cavidade (inset) com rótulo em cima.
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
            final neu = state.context.neu;
            final hasError = state.hasError;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: neu.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: enabled ? onTap : null,
                  borderRadius: BorderRadius.circular(NeuTokens.rField),
                  child: NeuSurface(
                    elevation: NeuElevation.inset,
                    radius: NeuTokens.rField,
                    border: hasError
                        ? Border.all(color: neu.danger, width: 1.5)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 20, color: neu.inkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            value != null ? fmt.format(value) : '—',
                            style: TextStyle(
                              color: value != null ? neu.ink : neu.inkFaint,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        color: neu.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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
/// Estilizado no design system: rótulo em cima + cavidade (inset).
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
    final neu = context.neu;
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
            color: neu.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(NeuTokens.rField),
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
                        : NeuNetworkImage(
                            url: logo,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                          ),
                    title: Text(o.label, style: TextStyle(color: neu.ink)),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                field.rotulo,
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
                key: Key('osSubjectField-${field.chave}'),
                controller: textController,
                focusNode: focusNode,
                onChanged: (v) => controller.text = v,
                onFieldSubmitted: (_) => onSubmit(),
                style: TextStyle(color: neu.ink, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
