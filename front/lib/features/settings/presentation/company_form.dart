import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../../di.dart';
import '../domain/external_lookups_repository.dart';
import '../domain/settings_models.dart';
import '../../auth/presentation/session_state.dart';

// ---------------------------------------------------------------------------
// CompanyForm
// ---------------------------------------------------------------------------

/// Formulário editável dos dados da empresa (seção 'company' do bundle).
///
/// Agrupa campos por [SettingsField.group] quando presente. A ação "Salvar"
/// envia apenas as chaves que foram modificadas em relação ao mapa original.
///
/// Quando [embedded] é `true`, omite o Card externo e o título (útil quando
/// este widget é incorporado dentro de um painel expansível).
class CompanyForm extends ConsumerStatefulWidget {
  const CompanyForm({
    super.key,
    required this.bundle,
    required this.company,
    this.embedded = false,
  });

  /// Bundle completo — usado para ler as definições de campos da seção 'company'.
  final SettingsBundle bundle;

  /// Mapa atual dos valores da empresa (snapshot do estado ao construir).
  final Map<String, dynamic> company;

  /// Quando `true`, omite o Card externo e o título interno (para uso em
  /// [_CollapsibleSection] que já provê o cabeçalho).
  final bool embedded;

  @override
  ConsumerState<CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<CompanyForm> {
  /// Valida os campos de texto (required/e-mail/telefone/CEP) antes de salvar.
  final _formKey = GlobalKey<FormState>();

  /// Controllers de texto indexados por field.key.
  final Map<String, TextEditingController> _textCtrl = {};

  /// Valores de campos select/dropdown indexados por field.key.
  final Map<String, String?> _selectValues = {};

  bool _saving = false;

  /// Lista de subclasses CNAE — carregada de forma lazy no initState.
  /// `null` enquanto ainda está carregando; `[]` indica falha (usa fallback texto).
  List<CnaeOption>? _cnaes;

  /// Retorna a seção 'company' do bundle, ou null se não existir.
  SettingsSection? get _companySection {
    try {
      return widget.bundle.sections.firstWhere((s) => s.key == 'company');
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadCnaesAsync();
  }

  @override
  void didUpdateWidget(covariant CompanyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Quando o mapa `company` muda de conteúdo (ex.: troca de tenant ou novo
    // fetch), re-semeia os controllers — caso contrário os campos manteriam os
    // valores da empresa ANTERIOR (o State é reusado entre rebuilds). Comparação
    // por conteúdo (não identidade) evita clobber de edições do mesmo tenant.
    if (!mapEquals(oldWidget.company, widget.company)) {
      for (final c in _textCtrl.values) {
        c.dispose();
      }
      _textCtrl.clear();
      _selectValues.clear();
      _initControllers();
    }
  }

  void _initControllers() {
    final section = _companySection;
    if (section == null) return;

    // Resolve o email do dono logado para usar como default quando o campo
    // de email da empresa estiver vazio.
    String ownerEmail() {
      final session = ref.read(sessionControllerProvider);
      return session.meOrNull?.user.email ?? '';
    }

    for (final field in section.fields) {
      final raw = widget.company[field.key];
      // CNAE especial: o Autocomplete grava em _selectValues; inicializa aqui.
      if (field.key == 'cnae') {
        _selectValues['cnae'] = raw?.toString();
        continue;
      }
      if (_isTextField(field.type)) {
        String initial = raw?.toString() ?? '';
        // Fix 3: pré-preenche email da empresa com o email do dono quando vazio.
        if (field.type == 'email' && initial.isEmpty) {
          initial = ownerEmail();
        }
        _textCtrl[field.key] = TextEditingController(text: initial);
      } else if (field.type == 'select') {
        // Validate the current value is among the known options.
        final current = raw?.toString();
        final valid = field.options.any((o) => o.value == current);
        _selectValues[field.key] = valid ? current : null;
      }
    }
  }

  Future<void> _loadCnaesAsync() async {
    final list =
        await ref.read(externalLookupsRepositoryProvider).cnaeSubclasses();
    if (mounted) {
      setState(() => _cnaes = list);
    }
  }

  @override
  void dispose() {
    for (final c in _textCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isTextField(String type) =>
      type == 'text' || type == 'email' || type == 'tel' || type == 'url';

  TextInputType _keyboardType(String type) {
    switch (type) {
      case 'email':
        return TextInputType.emailAddress;
      case 'tel':
        return TextInputType.phone;
      case 'url':
        return TextInputType.url;
      default:
        return TextInputType.text;
    }
  }

  /// Teclado por campo — sobrepõe [_keyboardType] para campos numéricos
  /// específicos (inscrições, número do endereço).
  TextInputType _keyboardFor(SettingsField field) {
    switch (field.key) {
      case 'inscricaoEstadual':
      case 'inscricaoMunicipal':
      case 'numero':
        return TextInputType.number;
      default:
        return _keyboardType(field.type);
    }
  }

  /// Máscaras de digitação por campo (telefone, CEP, inscrição só-dígitos).
  List<TextInputFormatter>? _formattersFor(String key) {
    switch (key) {
      case 'phone':
        return [PhoneInputFormatter()];
      case 'cep':
        return [CepInputFormatter()];
      case 'inscricaoMunicipal':
        return [DigitsOnlyFormatter(14)];
      default:
        return null;
    }
  }

  /// Validador por campo (obrigatórios + formato de e-mail/telefone/CEP).
  Validator? _validatorFor(String key) {
    switch (key) {
      case 'companyName':
        return Validators.required('Nome fantasia');
      case 'legalName':
        return Validators.required('Razão social');
      case 'email':
        return Validators.email();
      case 'phone':
        return Validators.phone();
      case 'cep':
        return Validators.cep();
      default:
        return null;
    }
  }

  /// Limite de caracteres por campo.
  int? _maxLengthFor(String key) {
    switch (key) {
      case 'companyName':
      case 'legalName':
      case 'bairro':
      case 'municipio':
        return 120;
      case 'email':
        return 160;
      case 'website':
      case 'logradouro':
      case 'complemento':
        return 200;
      case 'inscricaoEstadual':
        return 20;
      case 'numero':
        return 10;
      default:
        return null;
    }
  }

  /// Capitalização automática por campo (nomes → words; endereço → sentences;
  /// inscrição estadual → characters, para aceitar "ISENTO" em maiúsculas).
  TextCapitalization _capitalizationFor(String key) {
    switch (key) {
      case 'companyName':
      case 'legalName':
      case 'bairro':
      case 'municipio':
        return TextCapitalization.words;
      case 'logradouro':
      case 'complemento':
        return TextCapitalization.sentences;
      case 'inscricaoEstadual':
        return TextCapitalization.characters;
      default:
        return TextCapitalization.none;
    }
  }

  /// Campos somente-leitura que nunca devem ser enviados no patch.
  static const _readOnlyFields = {'taxId'};

  /// Campos obrigatórios (exigidos para salvar) — recebem ' *' no rótulo.
  static const _requiredFields = {'companyName', 'legalName'};

  /// Rótulo com sufixo de obrigatoriedade: obrigatórios terminam com ' *',
  /// opcionais com ' (opcional)'. Campos read-only (taxId) ficam sem sufixo
  /// (o próprio campo já sinaliza "não editável").
  String _labelFor(SettingsField field) {
    if (_readOnlyFields.contains(field.key)) return field.label;
    return _requiredFields.contains(field.key)
        ? '${field.label} *'
        : '${field.label} (opcional)';
  }

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};
    final section = _companySection;
    if (section == null) return patch;
    for (final field in section.fields) {
      // CNPJ (taxId) é não editável: nunca incluir no patch.
      if (_readOnlyFields.contains(field.key)) continue;
      // CNAE especial: o Autocomplete grava em _selectValues (type == 'text' no schema).
      if (field.key == 'cnae') {
        final current = _selectValues['cnae'];
        final orig = widget.company['cnae']?.toString();
        if (current != orig) patch['cnae'] = current;
        continue;
      }
      final original = widget.company[field.key];
      if (_isTextField(field.type)) {
        final current = _textCtrl[field.key]?.text ?? '';
        final orig = original?.toString() ?? '';
        if (current != orig) patch[field.key] = current;
      } else if (field.type == 'select') {
        // Campos select normais — regime, uf etc.
        // CNAE é tratado como select especial mas armazenado em _selectValues também.
        final current = _selectValues[field.key];
        final orig = original?.toString();
        if (current != orig) patch[field.key] = current;
      }
    }
    return patch;
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) return;
    final patch = _buildPatch();
    if (patch.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma alteração detectada.')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(settingsControllerProvider.notifier).saveCompany(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar configurações.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'png';
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .uploadLogo(bytes, name, 'image/$ext');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo atualizado com sucesso.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao fazer upload do logo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Consulta o ViaCEP (via repository) e preenche os campos de endereço.
  Future<void> _buscarCep(String rawCep) async {
    final digits = rawCep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;

    final addr =
        await ref.read(externalLookupsRepositoryProvider).addressByCep(digits);
    if (!mounted) return;
    if (addr == null) {
      _showCepSnack('CEP não encontrado.');
      return;
    }
    setState(() {
      if (_textCtrl.containsKey('logradouro')) {
        _textCtrl['logradouro']!.text = addr.logradouro ?? '';
      }
      if (_textCtrl.containsKey('bairro')) {
        _textCtrl['bairro']!.text = addr.bairro ?? '';
      }
      if (_textCtrl.containsKey('municipio')) {
        _textCtrl['municipio']!.text = addr.municipio ?? '';
      }
      // complemento: preenche apenas se estiver vazio
      if (_textCtrl.containsKey('complemento')) {
        final comp = addr.complemento ?? '';
        if (_textCtrl['complemento']!.text.isEmpty && comp.isNotEmpty) {
          _textCtrl['complemento']!.text = comp;
        }
      }
      // UF: atualiza o select
      final uf = addr.uf;
      if (uf != null && _selectValues.containsKey('uf')) {
        _selectValues['uf'] = uf;
      }
    });
  }

  void _showCepSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: context.neu.danger,
      ),
    );
  }

  Future<void> _removeLogo() async {
    final ok = await showNeuConfirm(
      context,
      title: 'Remover logo?',
      message: 'A logo da empresa será removida das telas e do link público.',
      confirmLabel: 'Remover',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsControllerProvider.notifier).removeLogo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo removido.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao remover logo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final section = _companySection;

    // Group fields by field.group (null → 'Geral').
    // Skip the 'Aparência' group — it is handled by the dedicated AppearanceSection.
    final groups = <String, List<SettingsField>>{};
    if (section != null) {
      for (final f in section.fields) {
        final g = f.group ?? 'Geral';
        // Aparência é renderizada pela AppearanceSection dedicada.
        // Campos do tipo 'image' (ex.: logoUrl) são tratados pelo _LogoSection — não
        // devem aparecer como linha de texto nos grupos.
        if (g == 'Aparência') continue;
        if (f.type == 'image') continue;
        groups.putIfAbsent(g, () => []).add(f);
      }
    }
    final groupList = groups.entries.toList();

    final logoUrl = widget.company['logoUrl'] as String?;

    final content = Form(
      key: _formKey,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          Text(
            'Empresa & Identidade visual',
            style: TextStyle(
              color: neu.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dados cadastrais e visuais da sua empresa.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
        ],

        // ---- Logo ---------------------------------------------------
        _LogoSection(
          logoUrl: logoUrl,
          saving: _saving,
          onUpload: _uploadLogo,
          onRemove: _removeLogo,
        ),

        if (section != null && section.fields.isNotEmpty) ...[
          const SizedBox(height: 24),

          // ---- Field groups ------------------------------------------
          for (var gi = 0; gi < groupList.length; gi++) ...[
            if (gi > 0) const SizedBox(height: 24),
            _GroupHeader(
              label: groupList[gi].key,
              icon: _groupIcon(groupList[gi].key),
              index: gi,
            ),
            const SizedBox(height: 16),
            _buildFieldsGrid(groupList[gi].value),
          ],
        ],

        const SizedBox(height: 28),

        // ---- Save button -------------------------------------------
        if (context.isMobile)
          NeuButton(
            label: 'Salvar',
            icon: Icons.check_rounded,
            onPressed: _save,
            loading: _saving,
            expanded: true,
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              NeuButton(
                label: 'Salvar',
                icon: Icons.check_rounded,
                onPressed: _save,
                loading: _saving,
              ),
            ],
          ),
      ],
      ),
    );

    final padded = Padding(
      padding: EdgeInsets.all(context.isMobile ? 20 : 28),
      child: content,
    );

    if (widget.embedded) return padded;

    return NeuCard(
      padding: EdgeInsets.all(context.isMobile ? 20 : 28),
      child: content,
    );
  }

  /// Ícone representativo de cada grupo de campos (cabeçalho de bloco).
  IconData _groupIcon(String group) {
    final k = group.toLowerCase();
    if (k.contains('endereç') || k.contains('endereco')) {
      return Icons.location_on_outlined;
    }
    if (k.contains('fiscal') || k.contains('tribut')) {
      return Icons.receipt_long_outlined;
    }
    if (k.contains('contato')) return Icons.alternate_email_rounded;
    if (k.contains('identidade')) return Icons.badge_outlined;
    return Icons.tune_rounded;
  }

  /// Campos que ocupam a LINHA INTEIRA no grid de 2 colunas (conteúdo longo:
  /// razão social, e-mail, site, logradouro e o CNAE buscável). Os demais são
  /// curtos e ficam lado a lado.
  static const _fullWidthFields = {
    'legalName',
    'email',
    'website',
    'logradouro',
    'cnae',
  };

  /// Texto de ajuda curto (PT-BR) exibido abaixo do campo, por chave.
  /// Retorna `null` quando o campo dispensa contexto.
  String? _helperFor(String key) {
    switch (key) {
      case 'companyName':
        return 'Nome como sua empresa é conhecida pelos clientes.';
      case 'legalName':
        return 'Razão social registrada no CNPJ.';
      case 'taxId':
        return 'Somente números. Não é editável aqui.';
      case 'phone':
        return 'Aparece nas comunicações com o cliente.';
      case 'email':
        return 'Usado nas comunicações e no link público de acompanhamento.';
      case 'website':
        return 'Endereço do site da empresa, se houver.';
      case 'inscricaoEstadual':
        return 'Deixe ISENTO se a empresa não tiver.';
      case 'inscricaoMunicipal':
        return 'Número da inscrição na prefeitura (usado na NFS-e).';
      case 'regimeTributario':
        return 'Regime de tributação (ex.: Simples Nacional).';
      case 'cnae':
        return 'Atividade econômica principal — busque por código ou descrição.';
      case 'cep':
        return 'Digite o CEP e toque na lupa para preencher o endereço.';
      case 'logradouro':
        return 'Rua ou avenida — preenchido automaticamente pelo CEP.';
      case 'numero':
        return 'Número do endereço.';
      case 'complemento':
        return 'Sala, andar ou bloco (opcional).';
      case 'bairro':
        return 'Bairro — preenchido pelo CEP.';
      case 'municipio':
        return 'Cidade — preenchida pelo CEP.';
      case 'uf':
        return 'Estado (UF) — preenchido pelo CEP.';
      default:
        return null;
    }
  }

  /// Distribui os campos de um grupo em um grid responsivo de 2 colunas.
  ///
  /// - Telas largas (não-mobile e largura ≥ ~536px): 2 campos por linha; campos
  ///   longos ([_fullWidthFields]) ocupam a linha inteira.
  /// - Mobile ou largura estreita: 1 campo por linha (empilhado).
  /// Usa [Wrap] com gap de 16px horizontal e vertical; cada campo vive em um
  /// [SizedBox] com largura calculada a partir do espaço disponível.
  Widget _buildFieldsGrid(List<SettingsField> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        const minField = 260.0;
        final maxW = constraints.maxWidth;
        // Duas colunas só quando cabem dois campos de ~260px lado a lado.
        final twoCols = !context.isMobile && maxW >= (minField * 2 + gap);
        // floorToDouble garante que 2*half + gap nunca estoure maxW.
        final halfW =
            twoCols ? ((maxW - gap) / 2).floorToDouble() : maxW;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final field in fields)
              SizedBox(
                width: (!twoCols || _fullWidthFields.contains(field.key))
                    ? maxW
                    : halfW,
                child: _buildFieldWidget(field),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFieldWidget(SettingsField field) {
    final neu = context.neu;

    // Campos somente-leitura: exibe desabilitado com ícone de cadeado.
    if (_readOnlyFields.contains(field.key)) {
      return NeuTextField(
        label: _labelFor(field),
        controller: _textCtrl[field.key],
        hint: 'não editável',
        enabled: false,
        helper: _helperFor(field.key),
        suffix: Tooltip(
          message: 'Não editável aqui. Altere em Identidade fiscal.',
          child: Icon(Icons.lock_outline, size: 18, color: neu.inkFaint),
        ),
      );
    }

    // ---- Campo CNAE (buscável via API IBGE) --------------------------------
    if (field.key == 'cnae') {
      return _buildCnaeField(field);
    }

    if (_isTextField(field.type)) {
      // Campo CEP: busca endereço via ViaCEP ao confirmar digitação.
      if (field.key == 'cep') {
        return NeuTextField(
          label: _labelFor(field),
          controller: _textCtrl[field.key],
          keyboardType: TextInputType.number,
          inputFormatters: [CepInputFormatter()],
          validator: Validators.cep(),
          helper: _helperFor(field.key),
          onFieldSubmitted: _buscarCep,
          suffix: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: NeuIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Buscar endereço',
              size: 38,
              onPressed: () {
                final v = _textCtrl['cep']?.text ?? '';
                _buscarCep(v);
              },
            ),
          ),
        );
      }

      return NeuTextField(
        label: _labelFor(field),
        controller: _textCtrl[field.key],
        keyboardType: _keyboardFor(field),
        inputFormatters: _formattersFor(field.key),
        validator: _validatorFor(field.key),
        maxLength: _maxLengthFor(field.key),
        textCapitalization: _capitalizationFor(field.key),
        helper: _helperFor(field.key),
      );
    }

    // ---- Campos select (regime tributário, UF, …) -------------------------
    if (field.type == 'select' && field.options.isNotEmpty) {
      return _buildSelectDropdown(field);
    }

    // Unsupported field types: show read-only hint.
    return _labeledInset(
      label: _labelFor(field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          widget.company[field.key]?.toString() ?? '—',
          style: TextStyle(color: neu.ink, fontSize: 15),
        ),
      ),
    );
  }

  /// Envolve um [child] arbitrário no visual de campo do design system:
  /// rótulo em cima (sempre visível) + cavidade (inset) com raio de campo.
  /// Usado por selects e pela caixa de busca do CNAE, que precisam de um
  /// controle Material próprio dentro da cavidade.
  Widget _labeledInset({
    required String label,
    required Widget child,
    String? helper,
  }) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              helper,
              style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Select ancorado (DropdownMenu — abre ABAIXO do campo)
  // -------------------------------------------------------------------------

  /// Constrói um select na cavidade (inset) do design system: rótulo acima e um
  /// [DropdownButton] sem borda própria dentro do campo.
  Widget _buildSelectDropdown(SettingsField field) {
    final neu = context.neu;
    return _labeledInset(
      label: _labelFor(field),
      helper: _helperFor(field.key),
      child: SizedBox(
        height: 48,
        child: DropdownButton<String>(
          value: _selectValues[field.key],
          isExpanded: true,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(NeuTokens.rField),
          dropdownColor: neu.surface,
          menuMaxHeight: 320,
          icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
          hint: Text(
            'Selecione',
            style: TextStyle(color: neu.inkFaint, fontSize: 15),
          ),
          style: TextStyle(color: neu.ink, fontSize: 15),
          items: field.options
              .map((o) => DropdownMenuItem<String>(
                    value: o.value,
                    child: Text(
                      o.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: neu.ink, fontSize: 15),
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectValues[field.key] = v),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Campo CNAE buscável (Fix 2 — máx 40 entradas para performance)
  // -------------------------------------------------------------------------

  static const int _cnaeMaxOptions = 40;

  /// Renderiza um campo CNAE buscável com [Autocomplete<String>].
  ///
  /// - Ainda carregando: TextFormField desabilitado com hint de loading.
  /// - Falha (_cnaes == []): fallback para campo texto livre.
  /// - Sucesso: Autocomplete que nunca materializa mais de 40 opções por query.
  Widget _buildCnaeField(SettingsField field) {
    final neu = context.neu;
    final currentCode = widget.company[field.key]?.toString() ?? '';

    // Ainda carregando.
    if (_cnaes == null) {
      return NeuTextField(
        label: _labelFor(field),
        enabled: false,
        hint: 'Carregando lista CNAE…',
        suffix: const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Falha ao carregar: fallback para campo texto livre.
    if (_cnaes!.isEmpty) {
      return NeuTextField(
        label: _labelFor(field),
        controller: _textCtrl.putIfAbsent(
          field.key,
          () => TextEditingController(text: currentCode),
        ),
        keyboardType: TextInputType.text,
        hint: 'Digite o código CNAE',
        helper: 'Lista CNAE indisponível — insira o código manualmente.',
        onChanged: (v) =>
            setState(() => _selectValues[field.key] = v.isEmpty ? null : v),
      );
    }

    // Sucesso: Autocomplete com limite de 40 opções para performance.
    // O initialValue é o label completo do código salvo, se encontrado.
    final all = _cnaes!;
    final matchingEntry = all.cast<CnaeOption?>()
        .firstWhere((e) => e?.id == currentCode, orElse: () => null);

    return Autocomplete<String>(
      initialValue: matchingEntry != null
          ? TextEditingValue(text: matchingEntry.label)
          : (currentCode.isNotEmpty
              ? TextEditingValue(text: currentCode)
              : TextEditingValue.empty),
      displayStringForOption: (option) => option,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return all.take(_cnaeMaxOptions).map((e) => e.label);
        // Digit-only query → prioriza startsWith no id; senão busca na descricao.
        final isDigits = RegExp(r'^\d+$').hasMatch(query);
        final matched = <String>[];
        for (final e in all) {
          if (matched.length >= _cnaeMaxOptions) break;
          if (isDigits) {
            if (e.id.startsWith(query)) matched.add(e.label);
          } else {
            if (e.label.toLowerCase().contains(query)) matched.add(e.label);
          }
        }
        return matched;
      },
      onSelected: (String label) {
        // Extrai o código (parte antes do " - ").
        final code = label.contains(' - ') ? label.split(' - ').first.trim() : label;
        setState(() => _selectValues[field.key] = code.isEmpty ? null : code);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return _labeledInset(
          label: _labelFor(field),
          helper: _helperFor(field.key),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            onFieldSubmitted: (_) => onFieldSubmitted(),
            style: TextStyle(color: neu.ink, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Busque por código ou descrição',
              hintStyle: TextStyle(color: neu.inkFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: NeuSurface(
            elevation: NeuElevation.raisedHigh,
            radius: NeuTokens.rField,
            color: neu.surface,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NeuTokens.rField),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Text(option,
                            style: TextStyle(fontSize: 14, color: neu.ink)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.icon,
    required this.index,
  });
  final String label;
  final IconData icon;
  final int index;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        NeuIconChip.glyph(context, icon: icon, index: index, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: neu.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.logoUrl,
    required this.saving,
    required this.onUpload,
    required this.onRemove,
  });

  final String? logoUrl;
  final bool saving;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    Widget preview() {
      if (hasLogo) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(NeuTokens.rChip),
          child: Image.network(
            logoUrl!,
            height: 72,
            width: 72,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              color: neu.inkMuted,
            ),
          ),
        );
      }
      return Icon(Icons.business_outlined, color: neu.inkMuted, size: 32);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logo da empresa',
          style: TextStyle(
            color: neu.inkMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              child: SizedBox(
                height: 88,
                width: 88,
                child: Center(child: preview()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  NeuButton(
                    label: hasLogo ? 'Trocar logo' : 'Enviar logo',
                    icon: Icons.upload_outlined,
                    kind: NeuButtonKind.secondary,
                    onPressed: saving ? null : onUpload,
                  ),
                  if (hasLogo)
                    NeuButton(
                      label: 'Remover logo',
                      icon: Icons.delete_outline,
                      kind: NeuButtonKind.danger,
                      onPressed: saving ? null : onRemove,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
