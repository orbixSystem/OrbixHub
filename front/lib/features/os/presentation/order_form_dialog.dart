import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../../core/vertical/vertical_providers.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../customers/domain/customers_models.dart';
import '../../customers/presentation/customer_form_dialog.dart';
import '../domain/os_models.dart';
import 'item_picker_dialog.dart';
import 'os_providers.dart';
import 'os_status.dart';
import 'template_picker_dialog.dart';
import 'tracking_link_share.dart';

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

/// Painel aberto dentro do passo "Detalhes". Os seletores de template e de item
/// abrem AQUI, no lugar, em vez de empilhar diálogo sobre diálogo.
enum _Painel { nenhum, template, item }

/// Foto escolhida ANTES de a OS existir: fica em memória com o preview e sobe
/// logo depois do `createOrder` (mesmo padrão do cadastro de veículo).
class _FotoPendente {
  const _FotoPendente({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

class _OrderFormDialogState extends ConsumerState<OrderFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _complaint = TextEditingController();
  final _diagnosis = TextEditingController();
  final _discount = TextEditingController();

  /// Legenda aplicada às fotos da abertura (ex.: "estado na entrada"). Uma só
  /// para o lote: na correria da recepção, pedir uma legenda por foto faria
  /// ninguém fotografar.
  final _fotoLegenda = TextEditingController();

  /// Situação com que a OS deve nascer. A OS é sempre criada `aberta` (o
  /// backend é dono da FSM) e o wizard faz a transição em seguida, então a
  /// linha do tempo registra a mudança como qualquer outra.
  String _statusInicial = 'aberta';

  /// Templates a aplicar assim que a OS existir (na ordem escolhida).
  final List<OsTemplate> _templates = [];

  /// Itens avulsos/do estoque a lançar assim que a OS existir.
  final List<OrderItemDraft> _itens = [];

  /// Fotos da abertura, em memória até haver um id de OS para anexá-las.
  final List<_FotoPendente> _fotos = [];

  /// Seletor aberto no lugar (nenhum diálogo novo).
  _Painel _painel = _Painel.nenhum;

  /// Guardar o que foi montado aqui como template reaproveitável. O nome fica
  /// num campo visível — nada é salvo sem o usuário ler o que vai salvar.
  bool _salvarComoTemplate = false;
  final _templateNome = TextEditingController();

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
  String _lastCustomerQuery = '';

  /// Cliente JÁ existente para o qual estamos cadastrando um veículo aqui
  /// mesmo (ele não tinha nenhum, ou quer registrar mais um). O veículo nasce
  /// junto com a OS, numa só requisição.
  bool _novoSubjetoParaExistente = false;

  /// Consultando a placa na API agora.
  bool _plateBusy = false;

  /// Retorno da última consulta por placa — vai junto no draft e fica salvo no
  /// veículo (colunas exclusivas), alimentando a ficha depois.
  PlateInfo? _plateInfo;

  /// Campos preenchidos pela consulta (destaque de "revise antes de salvar").
  final Set<String> _autoFilled = {};

  /// Geração do autofill — entra nas ValueKeys dos campos com sugestão para
  /// forçarem rebuild com o texto novo.
  int _fillGen = 0;

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
    for (final c in [
      _complaint,
      _diagnosis,
      _discount,
      _fotoLegenda,
      _templateNome,
      _newName,
      _newPhone,
      ..._subjFields.values,
    ]) {
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
      setState(() {
        _members = members;
        // Sugere o usuário logado como responsável (regra pura e testada em
        // `responsavelSugerido`): o campo é obrigatório e nascia vazio, sem
        // nenhuma pista de quem escolher.
        _assignedTo = responsavelSugerido(
          meuUserId: ref.read(sessionControllerProvider).meOrNull?.user.id,
          membros: members,
          jaEscolhido: _assignedTo,
        );
      });
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
      initialEntryMode: DatePickerEntryMode.input,
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
      // Cliente novo exige nome E telefone (mesma régua do cadastro completo).
      : _newName.text.trim().isNotEmpty && isValidPhone(_newPhone.text);

  /// Zera os campos do veículo (e a consulta de placa) — usado ao desistir do
  /// cadastro na hora ou ao trocar de cliente.
  void _clearSubjectFields() {
    for (final c in _subjFields.values) {
      c.clear();
    }
    _selectedCode.clear();
    _autoFilled.clear();
    _plateInfo = null;
    _fillGen++;
  }

  Future<void> _pickCustomer(CustomerOption c) async {
    setState(() {
      _customer = c;
      _subject = null;
      _subjects = const [];
      _loadingSubjects = true;
      // Trocar de cliente descarta um cadastro de veículo em andamento.
      _novoSubjetoParaExistente = false;
      _clearSubjectFields();
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
    final diagnosis = _opt(_diagnosis.text);
    final assignedTo = _assignedTo;
    final startIso = _scheduledStart?.toUtc().toIso8601String();
    final endIso = _scheduledEnd?.toUtc().toIso8601String();
    // Só manda desconto quando existe: 0 é o default do banco.
    final desconto = _descontoValor > 0 ? _descontoValor : null;
    if (_mode == _CustomerMode.existing) {
      // Cliente existente pode vir com um veículo NOVO cadastrado aqui mesmo —
      // o backend cria o veículo para ele e já vincula na OS.
      final (identifier, attrs) = _novoSubjetoParaExistente
          ? _buildSubjectFields()
          : (null, null);
      return OrderDraft(
        customerId: _customer!.id,
        subjectId: _subject?.id,
        newSubjectIdentifier: identifier,
        newSubjectAttributes: attrs,
        newSubjectPlateData:
            _novoSubjetoParaExistente ? _plateInfo?.toJson() : null,
        complaint: complaint,
        diagnosis: diagnosis,
        assignedTo: assignedTo,
        scheduledStart: startIso,
        scheduledEnd: endIso,
        discount: desconto,
      );
    }
    // Cliente novo: identifier (placa) + atributos do veículo a partir dos
    // campos dinâmicos da config.
    final (identifier, attrs) = _buildSubjectFields();
    return OrderDraft(
      newCustomerName: _newName.text.trim(),
      newCustomerPhone: _newPhone.text.trim(),
      newSubjectIdentifier: identifier,
      newSubjectAttributes: attrs,
      newSubjectPlateData: _plateInfo?.toJson(),
      complaint: complaint,
      diagnosis: diagnosis,
      assignedTo: assignedTo,
      scheduledStart: startIso,
      scheduledEnd: endIso,
      discount: desconto,
    );
  }

  /// Lê os campos dinâmicos do veículo: `identifier` (placa) sai separado; o
  /// resto vira `attributes`. Vazio quando o tenant não usa veículos.
  (String?, Map<String, dynamic>?) _buildSubjectFields() {
    if (!_usaSubjects) return (null, null);
    final built = <String, dynamic>{};
    String? identifier;
    for (final f in _config.subjectFields) {
      final raw = _subjFields[f.chave]?.text.trim() ?? '';
      if (f.chave == 'identifier') {
        identifier = raw.isEmpty ? null : raw;
        continue;
      }
      if (raw.isEmpty) continue;
      built[f.chave] = f.tipo == 'number' ? (num.tryParse(raw) ?? raw) : raw;
    }
    return (identifier, built.isEmpty ? null : built);
  }

  /// Cria a OS e, sobre ela, lança tudo que foi preenchido no wizard:
  /// templates, itens, fotos e a situação inicial. Cada etapa usa o mesmo
  /// endpoint que a tela de detalhe usaria — assim a baixa de estoque, o
  /// re-snapshot de preço e a FSM continuam sendo do backend, e offline o
  /// repositório local-first enfileira tudo na ordem.
  ///
  /// Se a OS nasce mas um anexo falha, NÃO desfazemos nada: a OS existe, o
  /// usuário vai para ela e dizemos exatamente o que não entrou. Perder o
  /// cadastro inteiro por causa de uma foto seria pior.
  Future<void> _save() async {
    if (!_canSubmit) return;
    // Os campos obrigatórios vivem no último passo, portanto estão montados
    // aqui — o Form valida-os antes de criar.
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final neu = context.neu;
    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(osRepositoryProvider);
    final ServiceOrder order;
    try {
      order = await repo.createOrder(_buildDraft());
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
      return;
    }

    // Daqui para baixo a OS JÁ EXISTE — falhas viram aviso, não erro fatal.
    final falhas = <String>[];
    for (final template in _templates) {
      try {
        await repo.applyTemplate(order.id, template.id);
      } on AppException {
        falhas.add('template "${template.name}"');
      }
    }
    for (final item in _itens) {
      try {
        await repo.addItem(order.id, item);
      } on AppException {
        falhas.add('item "${item.name ?? 'sem nome'}"');
      }
    }
    // "Salvar como template": o pacote montado aqui vira reaproveitável. Não
    // depende da OS — se um item falhou acima, o template ainda faz sentido.
    final nomeTemplate = _templateNome.text.trim();
    if (_salvarComoTemplate && nomeTemplate.isNotEmpty && _itens.isNotEmpty) {
      try {
        await repo.createTemplate(OsTemplateDraft(
          name: nomeTemplate,
          items: _itens.map(_paraItemDeTemplate).toList(),
        ));
        ref.invalidate(templateListProvider);
      } on AppException {
        falhas.add('template "$nomeTemplate"');
      }
    }

    final legenda = _opt(_fotoLegenda.text);
    for (final foto in _fotos) {
      try {
        await repo.addPhoto(
          order.id,
          bytes: foto.bytes,
          filename: foto.filename,
          contentType: foto.contentType,
          caption: legenda,
        );
      } on AppException {
        falhas.add('foto "${foto.filename}"');
      }
    }
    if (_statusInicial != 'aberta') {
      try {
        await repo.changeStatus(order.id, _statusInicial);
      } on AppException {
        falhas.add('situação "${osStatusLabel(_statusInicial)}"');
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    // Entregar o link ao cliente vem ANTES de abrir a ficha: o cliente ainda
    // está no balcão. Só ao confirmar aqui o wizard fecha e a navegação para a
    // OS acontece. OS criada offline nasce sem `public_token` (o link só existe
    // depois que o servidor a registra) — nesse caso não há passo nenhum.
    final token = order.publicToken;
    if (token != null && token.isNotEmpty) {
      await OsTrackingLinkDialog.show(context, order: order);
      if (!mounted) return;
    }
    Navigator.of(context).pop(order.id);
    // Depois do pop: o messenger do app sobrevive ao diálogo.
    if (falhas.isNotEmpty) {
      showNeuErrorOn(
        messenger,
        'OS criada, mas não foi possível lançar: ${falhas.join(', ')}. '
        'Dá para refazer pela tela da OS.',
        tokens: neu,
      );
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
      // O passo Detalhes concentra relato, itens, totais e fotos — 480 apertava
      // as linhas de lançamento.
      maxWidth: 560,
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
                  fontSize: 14,
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
                    fontSize: 14,
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
  Future<void> _criarClienteInline() async {
    final customer = await CustomerFormDialog.show(
      context,
      documentRequired: false,
      initialName: _lastCustomerQuery.trim(),
    );
    if (customer != null && mounted) {
      await _pickCustomer(CustomerOption(
        id: customer.id,
        name: customer.name,
        document: customer.document,
        phone: customer.phone,
      ));
    }
  }

  Widget _customerAutocomplete() {
    final neu = context.neu;
    return Autocomplete<CustomerOption>(
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) async {
        _lastCustomerQuery = value.text;
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
              suffixIcon: IconButton(
                tooltip: 'Criar novo cliente',
                icon: Icon(Icons.person_add_alt_1_outlined,
                    size: 18, color: neu.inkMuted),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _criarClienteInline();
                },
              ),
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
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 412),
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
                  // Criar novo — sempre visível no final da lista
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.person_add_alt_1_outlined,
                        size: 20, color: neu.navy),
                    title: Text(
                      _lastCustomerQuery.trim().isNotEmpty
                          ? 'Criar cliente "${_lastCustomerQuery.trim()}"'
                          : 'Criar novo cliente',
                      style: TextStyle(
                          color: neu.navy, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _criarClienteInline();
                    },
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
          // Obrigatório aqui como no cadastro completo: o cliente criado pela
          // OS é um cliente como outro qualquer, e é pelo telefone que a
          // oficina o avisa. O backend também exige.
          onChanged: (_) => setState(() {}),
          validator: Validators.combine([
            Validators.required('Telefone'),
            Validators.phone(),
          ]),
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
      // Cadastrando um veículo novo para este cliente (aqui mesmo).
      if (_novoSubjetoParaExistente) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Novo $_subjectLabelSingular para ${_customer?.name ?? "o cliente"}',
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _novoSubjetoParaExistente = false;
                            _clearSubjectFields();
                          }),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _novoSubjectFields(),
          ],
        );
      }
      if (_subjects.isEmpty) {
        // Sem veículo cadastrado: em vez de só avisar, oferece cadastrar agora.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nenhum ${_subjectLabelSingular.toLowerCase()} cadastrado para '
              'este cliente.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            NeuButton(
              label: 'Cadastrar $_subjectLabelSingular',
              icon: Icons.add_rounded,
              kind: NeuButtonKind.secondary,
              onPressed: _saving
                  ? null
                  : () => setState(() => _novoSubjetoParaExistente = true),
            ),
            const SizedBox(height: 8),
            Text(
              'Ou siga sem selecionar — dá para vincular depois.',
              style: TextStyle(color: neu.inkFaint, fontSize: 14),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _labeledDropdown(
            label: '$_subjectLabelSingular (opcional)',
            value: _subject?.id,
            icon: ref.watch(objetoIconProvider),
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
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _subject = null;
                        _novoSubjetoParaExistente = true;
                      }),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Cadastrar outro $_subjectLabelSingular'),
            ),
          ),
        ],
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
        // A geração do autofill entra na key: preencher pela placa rebuilda o
        // campo com o texto novo (o Autocomplete só lê o valor inicial).
        key: ValueKey(
          'os-lookup-${f.chave}-$_fillGen-'
          '${_ancestorCodesOf(f).values.join(',')}',
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
    final field = NeuTextField(
      key: Key('os-subjectField-${f.chave}'),
      label: isIdentifier ? '${f.rotulo} *' : '${f.rotulo} (opcional)',
      controller: _subjFields[f.chave],
      helper: _autoFilled.contains(f.chave)
          ? 'Preenchido pela consulta da placa'
          : null,
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
    // Campo da placa ganha a busca na base de veículos (mesma da tela de
    // cadastro): preenche marca/modelo/ano/cor e guarda os dados da consulta.
    if (!isIdentifier || !_identifierIsPlate) return field;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 25),
          child: _plateLookupButton(),
        ),
      ],
    );
  }

  /// Botão de consulta por placa. Online-only — offline fica inerte com o
  /// aviso padrão (a consulta é feita pelo servidor).
  Widget _plateLookupButton() {
    if (_plateBusy) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final button = NeuIconButton(
      icon: Icons.manage_search_rounded,
      tooltip: 'Consultar ${_byChave['identifier']?.rotulo ?? 'identificador'}',
      size: 48,
      onPressed: _saving ? null : _plateLookup,
    );
    return ref.watch(isOfflineProvider)
        ? RequiresConnection(
            reason: 'a consulta de placa é feita no servidor',
            child: button,
          )
        : button;
  }

  /// O identificador é uma placa? Decidido pela CONFIG do tenant (rótulo), não
  /// por vertical hardcoded.
  /// A consulta do identificador numa base externa é uma CAPACIDADE do tenant,
  /// não um palpite sobre o texto. Antes isto era
  /// `f.rotulo.toLowerCase().contains('placa')` — renomear o campo mudava
  /// comportamento, e um nicho novo (nº de série) não tinha como habilitar.
  bool get _identifierIsPlate =>
      _byChave['identifier'] != null &&
      ref.watch(hasFeatureProvider(Features.identifierLookup));

  /// Consulta a placa e preenche os campos do veículo. Usa o "equivalente"
  /// FIPE devolvido pelo backend, então a cascata (marca→modelo→ano) continua
  /// funcionando; sem equivalente, cai no texto cru do registro.
  Future<void> _plateLookup() async {
    final plate = _subjFields['identifier']?.text.trim() ?? '';
    if (!isValidPlate(plate)) {
      _snack('Digite uma placa válida antes de buscar (ex.: ABC1D23).');
      return;
    }
    setState(() => _plateBusy = true);
    try {
      final info =
          await ref.read(customersRepositoryProvider).plateLookup(plate);
      if (!mounted) return;
      final match = info.fipeMatch;
      final values = <String, (String?, String?)>{
        'marca': (match?.marca?.value ?? info.marca, match?.marca?.codigo),
        'modelo': (match?.modelo?.value ?? info.modelo, match?.modelo?.codigo),
        'ano': (
          match?.ano?.value ?? info.anoModelo ?? info.ano,
          match?.ano?.codigo,
        ),
        'cor': (_titleCase(info.cor), null),
      };
      setState(() {
        _plateInfo = info.copyWith(cached: false, usage: null);
        _autoFilled.clear();
        values.forEach((chave, entry) {
          final (value, codigo) = entry;
          final ctrl = _subjFields[chave];
          if (ctrl == null || value == null || value.isEmpty) return;
          ctrl.text = value;
          _selectedCode[chave] = codigo;
          _autoFilled.add(chave);
        });
        _fillGen++;
      });
      final usage = info.usage;
      final custo = info.cached
          ? 'do cache — não gastou consulta'
          : usage != null
              ? 'consulta ${usage.used} de ${usage.limit} do mês'
              : 'consulta realizada';
      _snack(
        _autoFilled.isEmpty
            ? 'Veículo encontrado, mas sem dados para preencher ($custo).'
            : 'Dados do veículo preenchidos ($custo). Revise antes de salvar.',
      );
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _plateBusy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    showNeuErrorSnackBar(context, msg);
  }

  /// 'PRATA' → 'Prata' (a base devolve as cores em caixa alta).
  String? _titleCase(String? v) {
    if (v == null || v.isEmpty) return v;
    return v
        .split(' ')
        .map((w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Passo 3 — Detalhes
  // ---------------------------------------------------------------------------

  Widget _detalhesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // OPCIONAL, e de propósito: nem toda OS nasce de uma queixa. Venda de
        // peça faturada, serviço contratado por órgão público, retorno de
        // garantia — em todos esses não há "problema relatado", e exigir o
        // campo obrigava a inventar texto ou a abandonar a OS no meio. O
        // backend sempre aceitou `complaint` opcional (`CreateOrderDto`); a
        // obrigatoriedade só existia aqui.
        NeuTextField(
          label: 'Relato do cliente (opcional)',
          controller: _complaint,
          hint: 'Descreva o problema relatado pelo cliente…',
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          enabled: !_saving,
        ),
        const SizedBox(height: 12),
        // Diagnóstico opcional: quando quem recebe já sabe o que é (ou o
        // mecânico está do lado), não faz sentido criar a OS para depois
        // abri-la só para escrever isto.
        NeuTextField(
          label: 'Diagnóstico (opcional)',
          controller: _diagnosis,
          hint: 'O que a oficina identificou…',
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          enabled: !_saving,
        ),
        const SizedBox(height: 12),
        _responsavelDropdown(),
        const SizedBox(height: 12),
        // ---- Datas de previsão (OPCIONAIS — cadastro-relâmpago da OS; a agenda
        // usa quando preenchidas). Se preenchidas, término > início.
        // Empilhados no celular: "Início previsto (opcional)" + data e hora não
        // caber em meia tela apertava o texto e quebrava a linha.
        _StackedOrSideBySide(
          stacked: context.isMobile,
          children: [
              _DateTimeField(
                label: 'Início previsto (opcional)',
                value: _scheduledStart,
                fmt: _dtFmt,
                enabled: !_saving,
                onTap: () => _pickDateTime(isStart: true),
              ),
              _DateTimeField(
                label: 'Término previsto (opcional)',
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
          ],
        ),
        _secao('Situação inicial'),
        _situacaoInicial(),
        _secao(
          'Serviços e peças',
          hint: 'Opcional — dá para lançar depois, na tela da OS.',
        ),
        _itensSection(),
        const SizedBox(height: 12),
        _totaisSection(),
        _secao(
          'Fotos',
          hint: 'Registre o estado do veículo na entrada.',
        ),
        _fotosSection(),
      ],
    );
  }

  // ---- Situação inicial -----------------------------------------------------

  /// Situações com que a OS pode nascer: 'aberta' mais as transições que a FSM
  /// permite a partir dela — menos 'cancelada' (ninguém abre uma OS cancelada).
  /// Deriva da FSM em vez de repetir a lista: se o backend mudar as transições,
  /// aqui acompanha.
  List<String> get _situacoesIniciais => [
        'aberta',
        ...?osTransitions['aberta']?.where((s) => s != 'cancelada'),
      ];

  Widget _situacaoInicial() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in _situacoesIniciais)
          _statusChip(status, selected: _statusInicial == status),
      ],
    );
  }

  Widget _statusChip(String status, {required bool selected}) {
    final neu = context.neu;
    final cor = osStatusColor(status);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _saving ? null : () => setState(() => _statusInicial = status),
      child: NeuSurface(
        elevation: selected ? NeuElevation.flat : NeuElevation.raised,
        radius: NeuTokens.rField,
        color: selected ? cor.withValues(alpha: 0.16) : null,
        border: selected ? Border.all(color: cor, width: 1.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              osStatusLabel(status),
              style: TextStyle(
                color: selected ? neu.ink : neu.inkMuted,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Serviços e peças -----------------------------------------------------

  void _escolherTemplate(OsTemplate template) {
    if (_templates.any((t) => t.id == template.id)) {
      _snack('O template "${template.name}" já está nesta OS.');
      return;
    }
    setState(() {
      _templates.add(template);
      _painel = _Painel.nenhum;
    });
  }

  /// O painel de template pediu para guardar o que está lançado como template
  /// novo. Aqui a OS ainda nem existe, então só marcamos a intenção (com o nome
  /// à vista): o template é criado junto com a OS, no "Criar OS".
  void _marcarSalvarComoTemplate(String nome) {
    setState(() {
      _salvarComoTemplate = true;
      _templateNome.text = nome;
      _painel = _Painel.nenhum;
    });
  }

  /// Item de OS → item de template (mesma tradução da tela de templates).
  OsTemplateItemDraft _paraItemDeTemplate(OrderItemDraft d) =>
      OsTemplateItemDraft(
        kind: d.kind,
        inventoryItemId: d.inventoryItemId,
        name: d.inventoryItemId == null ? d.name : null,
        quantity: d.quantity,
        unitPrice: d.unitPrice,
      );

  double _totalDoItem(OrderItemDraft item) {
    final bruto =
        (item.quantity ?? 1) * (item.unitPrice ?? 0) - (item.discount ?? 0);
    return bruto < 0 ? 0 : bruto;
  }

  double get _totalTemplates => _templates.fold(
        0,
        (soma, t) => soma + (double.tryParse(t.total ?? '0') ?? 0),
      );

  double get _totalItens =>
      _itens.fold(0, (soma, item) => soma + _totalDoItem(item));

  double get _descontoValor =>
      double.tryParse(_discount.text.trim().replaceAll(',', '.')) ?? 0;

  double get _totalGeral {
    final bruto = _totalTemplates + _totalItens - _descontoValor;
    return bruto < 0 ? 0 : bruto;
  }

  Widget _itensSection() {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_painel == _Painel.nenhum)
          Row(
            children: [
              Expanded(
                child: NeuButton(
                  label: 'Aplicar template',
                  icon: Icons.checklist_rounded,
                  kind: NeuButtonKind.secondary,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _painel = _Painel.template),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeuButton(
                  label: 'Adicionar item',
                  icon: Icons.add_rounded,
                  kind: NeuButtonKind.secondary,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _painel = _Painel.item),
                ),
              ),
            ],
          )
        else
          _painelInline(),
        if (_painel == _Painel.nenhum && _templates.isEmpty && _itens.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Nenhuma peça ou serviço lançado.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
          ),
        ],
        for (var i = 0; i < _templates.length; i++) ...[
          const SizedBox(height: 10),
          _linhaLancamento(
            icone: Icons.checklist_rounded,
            titulo: _templates[i].name,
            detalhe: _templates[i].items.length == 1
                ? '1 item do template'
                : '${_templates[i].items.length} itens do template',
            valor: double.tryParse(_templates[i].total ?? '0') ?? 0,
            onRemove: _saving ? null : () => setState(() => _templates.removeAt(i)),
          ),
        ],
        for (var i = 0; i < _itens.length; i++) ...[
          const SizedBox(height: 10),
          _linhaLancamento(
            icone: _itens[i].kind == 'service'
                ? Icons.handyman_outlined
                : Icons.inventory_2_outlined,
            titulo: _itens[i].name?.trim().isNotEmpty == true
                ? _itens[i].name!
                : 'Item',
            detalhe: '${_fmtQuantidade(_itens[i].quantity ?? 1)} × '
                '${money((_itens[i].unitPrice ?? 0).toStringAsFixed(2))}',
            valor: _totalDoItem(_itens[i]),
            onRemove: _saving ? null : () => setState(() => _itens.removeAt(i)),
          ),
        ],
        if (_itens.isNotEmpty && _painel == _Painel.nenhum) ...[
          const SizedBox(height: 14),
          _salvarComoTemplateBloco(),
        ],
      ],
    );
  }

  /// O seletor aberto — template ou item — dentro de uma cavidade, no lugar dos
  /// dois botões. Nada de diálogo por cima de diálogo: o passo continua sendo
  /// uma folha só, e o "Voltar/Cancelar" do painel devolve os botões.
  Widget _painelInline() {
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(14),
      child: _painel == _Painel.template
          ? TemplatePickerPanel(
              qtdItensParaSalvar: _itens.length,
              maxAltura: 240,
              onSelected: _escolherTemplate,
              onCancel: () => setState(() => _painel = _Painel.nenhum),
              onCriarTemplate: _marcarSalvarComoTemplate,
            )
          : ItemPickerPanel(
              onConfirm: (draft) => setState(() {
                _itens.add(draft);
                _painel = _Painel.nenhum;
              }),
              onCancel: () => setState(() => _painel = _Painel.nenhum),
            ),
    );
  }

  /// "Guarde isto para a próxima": o pacote de peças e serviços que acabou de
  /// ser montado vira um template reaproveitável. O nome fica à vista e é
  /// editável — o template só nasce junto com a OS, no "Criar OS".
  Widget _salvarComoTemplateBloco() {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _saving
              ? null
              : () => setState(
                    () => _salvarComoTemplate = !_salvarComoTemplate,
                  ),
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: _salvarComoTemplate,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _salvarComoTemplate = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'Salvar estas peças e serviços como template',
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_salvarComoTemplate) ...[
          const SizedBox(height: 8),
          NeuTextField(
            label: 'Nome do template *',
            controller: _templateNome,
            hint: 'ex.: Revisão simples',
            prefixIcon: Icons.checklist_rounded,
            enabled: !_saving,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            validator: (v) => (_salvarComoTemplate && (v == null || v.trim().isEmpty))
                ? 'Dê um nome ao template (ou desmarque a opção)'
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Fica salvo ao criar a OS e aparece em "Aplicar template" na '
              'próxima vez.',
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  /// 1 → "1"; 1.5 → "1,5" (quantidade fracionada existe: 0,5 h de mão de obra).
  String _fmtQuantidade(double v) => v == v.truncate()
      ? v.toInt().toString()
      : v.toString().replaceAll('.', ',');

  Widget _linhaLancamento({
    required IconData icone,
    required String titulo,
    required String detalhe,
    required double valor,
    VoidCallback? onRemove,
  }) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icone, size: 18, color: neu.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            money(valor.toStringAsFixed(2)),
            style: TextStyle(
              color: neu.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          NeuIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Remover',
            size: 34,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  // ---- Desconto e total -----------------------------------------------------

  Widget _totaisSection() {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuTextField(
          label: 'Desconto (opcional)',
          controller: _discount,
          hint: '0,00',
          prefixIcon: Icons.discount_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !_saving,
          onChanged: (_) => setState(() {}),
          validator:
              Validators.positiveNumber(optional: true, field: 'Desconto'),
        ),
        const SizedBox(height: 12),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                money(_totalGeral.toStringAsFixed(2)),
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (_templates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              'O template é somado pelo preço atual do estoque; o valor final é '
              'confirmado quando a OS for criada.',
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ---- Fotos ----------------------------------------------------------------

  /// Escolhe imagens e guarda os bytes em memória — só sobem depois que a OS
  /// existir (é preciso um id para anexar).
  Future<void> _addFotos() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (picked == null || !mounted) return;
    final novas = <_FotoPendente>[];
    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final ext = (file.extension ?? 'jpeg').toLowerCase();
      novas.add(_FotoPendente(
        bytes: bytes,
        filename: file.name,
        contentType: 'image/$ext',
      ));
    }
    if (novas.isEmpty) return;
    setState(() => _fotos.addAll(novas));
  }

  Widget _fotosSection() {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuButton(
          label: _fotos.isEmpty ? 'Anexar fotos' : 'Anexar mais fotos',
          icon: Icons.add_a_photo_outlined,
          kind: NeuButtonKind.secondary,
          onPressed: _saving ? null : _addFotos,
        ),
        if (_fotos.isEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Nenhuma foto anexada.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _fotos.length; i++)
                _MiniaturaFoto(
                  bytes: _fotos[i].bytes,
                  onRemove:
                      _saving ? null : () => setState(() => _fotos.removeAt(i)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          NeuTextField(
            label: 'Legenda das fotos (opcional)',
            controller: _fotoLegenda,
            hint: 'ex.: estado na entrada',
            prefixIcon: Icons.notes_outlined,
            enabled: !_saving,
            maxLength: 200,
          ),
        ],
      ],
    );
  }

  /// Título de seção do passo Detalhes — separa os blocos sem virar um card
  /// dentro do diálogo.
  Widget _secao(String titulo, {String? hint}) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: neu.line)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              style: TextStyle(color: neu.inkFaint, fontSize: 12),
            ),
          ],
        ],
      ),
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
              fontSize: 14,
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
                      fontSize: 14,
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
                        fontSize: 14,
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
                '${field.rotulo} (opcional)',
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 14,
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

/// Miniatura de uma foto ainda não enviada (bytes em memória), com o X para
/// desistir dela antes de criar a OS.
class _MiniaturaFoto extends StatelessWidget {
  const _MiniaturaFoto({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NeuTokens.rField),
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: neu.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 15, color: neu.ink),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dois campos que ficam lado a lado quando há largura e empilhados no celular.
/// Em meia tela de celular, rótulo + data formatada não cabem: o texto aperta e
/// a linha quebra. Um sobre o outro dá largura inteira a cada um.
class _StackedOrSideBySide extends StatelessWidget {
  const _StackedOrSideBySide({
    required this.children,
    required this.stacked,
  });

  final List<Widget> children;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
