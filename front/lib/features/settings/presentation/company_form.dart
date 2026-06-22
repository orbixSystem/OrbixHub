import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import '../domain/settings_models.dart';
import '../../auth/presentation/session_state.dart';

// ---------------------------------------------------------------------------
// CNAE cache — carregado uma vez e reutilizado em todos os rebuilds
// ---------------------------------------------------------------------------

/// Entrada da lista de subclasses CNAE do IBGE.
class _CnaeEntry {
  const _CnaeEntry({required this.id, required this.descricao});
  final String id;
  final String descricao;

  String get label => '$id - $descricao';
}

/// Cache em memória das subclasses CNAE. `null` = ainda não carregado.
/// `[]` = falha na requisição (fallback para campo texto).
List<_CnaeEntry>? _cnaeCache;
bool _cnaeLoading = false;

Future<List<_CnaeEntry>> _loadCnaes() async {
  if (_cnaeCache != null) return _cnaeCache!;
  if (_cnaeLoading) {
    // Aguarda até o cache ficar disponível (poll simples).
    while (_cnaeLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return _cnaeCache ?? [];
  }
  _cnaeLoading = true;
  final cnaeDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));
  try {
    final resp = await cnaeDio.get<String>(
      'https://servicodados.ibge.gov.br/api/v2/cnae/subclasses',
    );
    if (resp.statusCode == 200 && resp.data != null) {
      final raw = jsonDecode(resp.data!) as List<dynamic>;
      _cnaeCache = raw
          .map((e) => _CnaeEntry(
                id: (e['id'] as dynamic)?.toString() ?? '',
                descricao: (e['descricao'] as String?) ?? '',
              ))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } else {
      _cnaeCache = [];
    }
  } catch (_) {
    _cnaeCache = [];
  } finally {
    cnaeDio.close();
    _cnaeLoading = false;
  }
  return _cnaeCache!;
}

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
  /// Controllers de texto indexados por field.key.
  final Map<String, TextEditingController> _textCtrl = {};

  /// Valores de campos select/dropdown indexados por field.key.
  final Map<String, String?> _selectValues = {};

  bool _saving = false;

  /// Lista de subclasses CNAE — carregada de forma lazy no initState.
  /// `null` enquanto ainda está carregando; `[]` indica falha (usa fallback texto).
  List<_CnaeEntry>? _cnaes;

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

  void _initControllers() {
    final section = _companySection;
    if (section == null) return;

    // Resolve o email do dono logado para usar como default quando o campo
    // de email da empresa estiver vazio.
    String ownerEmail() {
      final session = ref.read(sessionControllerProvider);
      if (session is SessionAuthenticated) return session.me.user.email;
      return '';
    }

    for (final field in section.fields) {
      final raw = widget.company[field.key];
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
    final list = await _loadCnaes();
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

  /// Campos somente-leitura que nunca devem ser enviados no patch.
  static const _readOnlyFields = {'taxId'};

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};
    final section = _companySection;
    if (section == null) return patch;
    for (final field in section.fields) {
      // CNPJ (taxId) é não editável: nunca incluir no patch.
      if (_readOnlyFields.contains(field.key)) continue;
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

  /// Consulta o ViaCEP e preenche os campos de endereço automaticamente.
  Future<void> _buscarCep(String rawCep) async {
    final digits = rawCep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;

    // Usa Dio independente — sem o interceptor de auth da app (que aponta para a API).
    final viaCepDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    try {
      final response = await viaCepDio
          .get<String>('https://viacep.com.br/ws/$digits/json/');
      if (response.statusCode != 200 || response.data == null) {
        _showCepSnack('CEP não encontrado.');
        return;
      }
      final data = jsonDecode(response.data!) as Map<String, dynamic>;
      if (data['erro'] == true || data['erro'] == 'true') {
        _showCepSnack('CEP não encontrado.');
        return;
      }
      setState(() {
        if (_textCtrl.containsKey('logradouro')) {
          _textCtrl['logradouro']!.text = (data['logradouro'] as String?) ?? '';
        }
        if (_textCtrl.containsKey('bairro')) {
          _textCtrl['bairro']!.text = (data['bairro'] as String?) ?? '';
        }
        if (_textCtrl.containsKey('municipio')) {
          _textCtrl['municipio']!.text = (data['localidade'] as String?) ?? '';
        }
        // complemento: preenche apenas se estiver vazio
        if (_textCtrl.containsKey('complemento')) {
          final comp = (data['complemento'] as String?) ?? '';
          if (_textCtrl['complemento']!.text.isEmpty && comp.isNotEmpty) {
            _textCtrl['complemento']!.text = comp;
          }
        }
        // UF: atualiza o select
        final uf = (data['uf'] as String?);
        if (uf != null && _selectValues.containsKey('uf')) {
          _selectValues['uf'] = uf;
        }
      });
    } on DioException {
      // Falha silenciosa — não crasha o form
    } catch (_) {
      // Falha silenciosa
    } finally {
      viaCepDio.close();
    }
  }

  void _showCepSnack(String msg) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: scheme.errorContainer,
      ),
    );
  }

  Future<void> _removeLogo() async {
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
    final scheme = Theme.of(context).colorScheme;
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

    final logoUrl = widget.company['logoUrl'] as String?;

    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.embedded) ...[
            Text(
              'Empresa & Identidade visual',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
          ],

          // ---- Logo ---------------------------------------------------
          _LogoSection(
            logoUrl: logoUrl,
            saving: _saving,
            onUpload: _uploadLogo,
            onRemove: _removeLogo,
            scheme: scheme,
          ),

          if (section != null && section.fields.isNotEmpty) ...[
            const SizedBox(height: 24),

            // ---- Field groups ------------------------------------------
            for (final entry in groups.entries) ...[
              _GroupHeader(label: entry.key, scheme: scheme),
              const SizedBox(height: 12),
              for (final field in entry.value) ...[
                _buildFieldWidget(field, scheme),
                const SizedBox(height: 14),
              ],
            ],
          ],

          const SizedBox(height: 8),

          // ---- Save button -------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _save,
                      child: const Text('Salvar'),
                    ),
            ],
          ),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      color: scheme.surfaceContainerLowest,
      child: content,
    );
  }

  Widget _buildFieldWidget(SettingsField field, ColorScheme scheme) {
    // Campos somente-leitura: exibe desabilitado com ícone de cadeado.
    if (_readOnlyFields.contains(field.key)) {
      return TextFormField(
        controller: _textCtrl[field.key],
        readOnly: true,
        enabled: false,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: 'não editável',
          suffixIcon: Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    // ---- Campo CNAE (buscável via API IBGE) --------------------------------
    if (field.key == 'cnae') {
      return _buildCnaeField(field, scheme);
    }

    if (_isTextField(field.type)) {
      // Campo CEP: busca endereço via ViaCEP ao confirmar digitação.
      if (field.key == 'cep') {
        return TextFormField(
          controller: _textCtrl[field.key],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: field.label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, size: 18),
              tooltip: 'Buscar endereço',
              onPressed: () {
                final v = _textCtrl['cep']?.text ?? '';
                _buscarCep(v);
              },
            ),
          ),
          onFieldSubmitted: _buscarCep,
          onEditingComplete: () {
            final v = _textCtrl['cep']?.text ?? '';
            _buscarCep(v);
            FocusScope.of(context).nextFocus();
          },
        );
      }

      return TextFormField(
        controller: _textCtrl[field.key],
        keyboardType: _keyboardType(field.type),
        decoration: InputDecoration(
          labelText: field.label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
      );
    }

    // ---- Campos select (regime tributário, UF, …) -------------------------
    if (field.type == 'select' && field.options.isNotEmpty) {
      return _buildSelectDropdown(field, scheme);
    }

    // Unsupported field types: show read-only hint.
    return Row(
      children: [
        Text(
          '${field.label}: ',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        Text(
          widget.company[field.key]?.toString() ?? '—',
          style: TextStyle(color: scheme.onSurface, fontSize: 13),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Select ancorado (DropdownMenu — abre ABAIXO do campo)
  // -------------------------------------------------------------------------

  /// Constrói um [DropdownMenu] Material 3 ancorado abaixo do campo, substituindo
  /// o antigo [DropdownButtonFormField] que abria fora de posição no web.
  Widget _buildSelectDropdown(SettingsField field, ColorScheme scheme) {
    return DropdownMenu<String>(
      expandedInsets: EdgeInsets.zero,
      initialSelection: _selectValues[field.key],
      label: Text(field.label),
      menuHeight: 320,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          scheme.surfaceContainerHigh,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
      dropdownMenuEntries: field.options
          .map((o) => DropdownMenuEntry<String>(value: o.value, label: o.label))
          .toList(),
      onSelected: (v) => setState(() => _selectValues[field.key] = v),
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
  Widget _buildCnaeField(SettingsField field, ColorScheme scheme) {
    final currentCode = widget.company[field.key]?.toString() ?? '';

    // Ainda carregando.
    if (_cnaes == null) {
      return TextFormField(
        initialValue: currentCode,
        enabled: false,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: 'Carregando lista CNAE…',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          suffixIcon: const SizedBox(
            width: 16,
            height: 16,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    // Falha ao carregar: fallback para campo texto livre.
    if (_cnaes!.isEmpty) {
      return TextFormField(
        controller: _textCtrl.putIfAbsent(
          field.key,
          () => TextEditingController(text: currentCode),
        ),
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: 'Digite o código CNAE',
          helperText: 'Lista CNAE indisponível — insira o código manualmente.',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _selectValues[field.key] = v.isEmpty ? null : v),
      );
    }

    // Sucesso: Autocomplete com limite de 40 opções para performance.
    // O initialValue é o label completo do código salvo, se encontrado.
    final all = _cnaes!;
    final matchingEntry = all.cast<_CnaeEntry?>()
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
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            labelText: field.label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(option,
                          style: TextStyle(fontSize: 13, color: scheme.onSurface)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.scheme});
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: scheme.outlineVariant)),
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
    required this.scheme,
  });

  final String? logoUrl;
  final bool saving;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logo da empresa',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        if (logoUrl != null && logoUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              logoUrl!,
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child:
                    Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(Icons.business_outlined, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: saving ? null : onUpload,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: Text(logoUrl != null ? 'Trocar logo' : 'Enviar logo'),
            ),
            if (logoUrl != null) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: saving ? null : onRemove,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remover logo'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
