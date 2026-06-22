import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import '../domain/settings_models.dart';

/// Formulário editável dos dados da empresa (seção 'company' do bundle).
///
/// Agrupa campos por [SettingsField.group] quando presente. A ação "Salvar"
/// envia apenas as chaves que foram modificadas em relação ao mapa original.
class CompanyForm extends ConsumerStatefulWidget {
  const CompanyForm({
    super.key,
    required this.bundle,
    required this.company,
  });

  /// Bundle completo — usado para ler as definições de campos da seção 'company'.
  final SettingsBundle bundle;

  /// Mapa atual dos valores da empresa (snapshot do estado ao construir).
  final Map<String, dynamic> company;

  @override
  ConsumerState<CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<CompanyForm> {
  /// Controllers de texto indexados por field.key.
  final Map<String, TextEditingController> _textCtrl = {};

  /// Valores de campos select/dropdown indexados por field.key.
  final Map<String, String?> _selectValues = {};

  bool _saving = false;

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
  }

  void _initControllers() {
    final section = _companySection;
    if (section == null) return;
    for (final field in section.fields) {
      final raw = widget.company[field.key];
      if (_isTextField(field.type)) {
        _textCtrl[field.key] =
            TextEditingController(text: raw?.toString() ?? '');
      } else if (field.type == 'select') {
        // Validate the current value is among the known options.
        final current = raw?.toString();
        final valid = field.options.any((o) => o.value == current);
        _selectValues[field.key] = valid ? current : null;
      }
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

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};
    final section = _companySection;
    if (section == null) return patch;
    for (final field in section.fields) {
      final original = widget.company[field.key];
      if (_isTextField(field.type)) {
        final current = _textCtrl[field.key]?.text ?? '';
        final orig = original?.toString() ?? '';
        if (current != orig) patch[field.key] = current;
      } else if (field.type == 'select') {
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
    final groups = <String, List<SettingsField>>{};
    if (section != null) {
      for (final f in section.fields) {
        final g = f.group ?? 'Geral';
        groups.putIfAbsent(g, () => []).add(f);
      }
    }

    final logoUrl = widget.company['logoUrl'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      color: scheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Empresa & Identidade visual',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),

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
      ),
    );
  }

  Widget _buildFieldWidget(SettingsField field, ColorScheme scheme) {
    if (_isTextField(field.type)) {
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

    if (field.type == 'select' && field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: _selectValues[field.key],
        decoration: InputDecoration(
          labelText: field.label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
        items: field.options
            .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
            .toList(),
        onChanged: (v) => setState(() => _selectValues[field.key] = v),
      );
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
