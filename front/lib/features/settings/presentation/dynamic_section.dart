import 'package:flutter/material.dart';

import '../domain/settings_models.dart';

/// Renders a read-only view of a [SettingsSection] using the current [values]
/// map.  Module-owned sections are always read-only — the section's own module
/// settings screen (if any) is the authority; this card is just an overview.
///
/// Quando [hideTitle] é `true`, omite o Card externo e o título interno (útil
/// quando incorporado em um painel expansível que já provê o cabeçalho).
class DynamicSection extends StatelessWidget {
  const DynamicSection({
    super.key,
    required this.section,
    required this.values,
    this.hideTitle = false,
  });

  final SettingsSection section;
  final Map<String, dynamic> values;

  /// Quando `true`, omite Card externo e título; útil dentro de
  /// [_CollapsibleSection] que já provê o cabeçalho.
  final bool hideTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideTitle)
            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
          if (section.fields.isNotEmpty) ...[
            if (!hideTitle) const SizedBox(height: 16),
            for (final field in section.fields) ...[
              _FieldRow(
                field: field,
                value: values[field.key],
                scheme: scheme,
              ),
              if (field != section.fields.last)
                Divider(height: 24, color: scheme.outlineVariant),
            ],
          ] else ...[
            if (!hideTitle) const SizedBox(height: 8),
            Text(
              'Nenhuma configuração disponível.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
    );

    if (hideTitle) return content;

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
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.value,
    required this.scheme,
  });

  final SettingsField field;
  final dynamic value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            field.label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: _FieldValue(field: field, value: value, scheme: scheme),
        ),
      ],
    );
  }
}

class _FieldValue extends StatelessWidget {
  const _FieldValue({
    required this.field,
    required this.value,
    required this.scheme,
  });

  final SettingsField field;
  final dynamic value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final type = field.type;

    if (type == 'bool') {
      return Switch(
        value: value == true,
        onChanged: null, // read-only
      );
    }

    if (type == 'select') {
      final display = value == null
          ? '—'
          : field.options.firstWhere(
              (o) => o.value == value.toString(),
              orElse: () => SettingsFieldOption(
                value: value.toString(),
                label: value.toString(),
              ),
            ).label;
      return Text(
        display,
        style: TextStyle(color: scheme.onSurface, fontSize: 14),
      );
    }

    if (type == 'color') {
      if (value == null) {
        return Text('—', style: TextStyle(color: scheme.onSurfaceVariant));
      }
      Color? parsed;
      try {
        final hex = value.toString().replaceAll('#', '');
        final full = hex.length == 6 ? 'FF$hex' : hex;
        parsed = Color(int.parse(full, radix: 16));
      } catch (_) {
        // ignore invalid color string
      }
      if (parsed == null) {
        return Text(
          value.toString(),
          style: TextStyle(color: scheme.onSurface, fontSize: 14),
        );
      }
      return Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: parsed,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outlineVariant),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: TextStyle(color: scheme.onSurface, fontSize: 13),
          ),
        ],
      );
    }

    if (type == 'image') {
      final url = value?.toString();
      if (url == null || url.isEmpty) {
        return Text('—', style: TextStyle(color: scheme.onSurfaceVariant));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 56,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Text(
            'Imagem indisponível',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }

    // text / email / tel / url — read-only text (plain Text; sem controller para evitar leak)
    final display = value?.toString();
    if (display == null || display.isEmpty) {
      return Text('—', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return Text(
      display,
      style: TextStyle(color: scheme.onSurface, fontSize: 14),
    );
  }
}
