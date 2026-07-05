import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../domain/settings_models.dart';

/// Renders a read-only view of a [SettingsSection] using the current [values]
/// map.  Module-owned sections are always read-only — the section's own module
/// settings screen (if any) is the authority; this card is just an overview.
///
/// Quando [hideTitle] é `true`, omite o cartão externo e o título interno (útil
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

  /// Quando `true`, omite cartão externo e título; útil dentro de
  /// [_CollapsibleSection] que já provê o cabeçalho.
  final bool hideTitle;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideTitle) ...[
          Row(
            children: [
              NeuIconChip.glyph(
                context,
                icon: Icons.tune_rounded,
                index: section.title.hashCode.abs() % 6,
                size: 40,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: neu.ink, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
        if (section.fields.isNotEmpty) ...[
          if (!hideTitle) const SizedBox(height: 18),
          for (final field in section.fields) ...[
            _FieldRow(
              field: field,
              value: values[field.key],
              neu: neu,
            ),
            if (field != section.fields.last)
              Divider(height: 28, color: neu.line),
          ],
        ] else ...[
          if (!hideTitle) const SizedBox(height: 10),
          Text(
            'Nenhuma configuração disponível.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13),
          ),
        ],
      ],
    );

    if (hideTitle) return content;

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: content,
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.value,
    required this.neu,
  });

  final SettingsField field;
  final dynamic value;
  final NeuTokens neu;

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
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _FieldValue(field: field, value: value, neu: neu),
        ),
      ],
    );
  }
}

class _FieldValue extends StatelessWidget {
  const _FieldValue({
    required this.field,
    required this.value,
    required this.neu,
  });

  final SettingsField field;
  final dynamic value;
  final NeuTokens neu;

  @override
  Widget build(BuildContext context) {
    final type = field.type;

    if (type == 'bool') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(
          value: value == true,
          activeThumbColor: neu.navy,
          onChanged: null, // read-only
        ),
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
        style: TextStyle(
          color: neu.ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (type == 'color') {
      if (value == null) {
        return Text('—', style: TextStyle(color: neu.inkMuted, fontSize: 14));
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
          style: TextStyle(color: neu.ink, fontSize: 14),
        );
      }
      return Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: parsed,
              borderRadius: BorderRadius.circular(NeuTokens.rChip),
              border: Border.all(color: neu.line),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: TextStyle(
              color: neu.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (type == 'image') {
      final url = value?.toString();
      if (url == null || url.isEmpty) {
        return Text('—', style: TextStyle(color: neu.inkMuted, fontSize: 14));
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        child: Image.network(
          url,
          height: 56,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Text(
            'Imagem indisponível',
            style: TextStyle(color: neu.inkMuted, fontSize: 12),
          ),
        ),
      );
    }

    // text / email / tel / url — read-only text (plain Text; sem controller para evitar leak)
    final display = value?.toString();
    if (display == null || display.isEmpty) {
      return Text('—', style: TextStyle(color: neu.inkMuted, fontSize: 14));
    }
    return Text(
      display,
      style: TextStyle(
        color: neu.ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
