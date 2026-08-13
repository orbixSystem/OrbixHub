/// Peças de UI compartilhadas pelas abas do detalhe da OS: o card de seção, a
/// ação compacta no cabeçalho da seção e o estado vazio inline.
library;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

/// Card de seção do detalhe da OS: relevo neumórfico + cabeçalho com glyph
/// colorido, título e uma ação opcional à direita. Unifica o visual de todas
/// as seções (diagnóstico, itens, totais, timeline, fotos, link).
class OsSectionCard extends StatelessWidget {
  const OsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.glyphIndex = 5,
    this.action,
    this.notice,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final int glyphIndex;
  final Widget? action;

  /// Aviso no rodapé da seção (ex.: [OfflinePendingNotice] — some quando online).
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(
                context,
                icon: icon,
                index: glyphIndex,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 16),
          child,
          ?notice,
        ],
      ),
    );
  }
}

/// Ação compacta no cabeçalho de uma seção (adicionar/editar). Menor que um
/// [NeuButton] cheio, sem quebrar o alinhamento do título.
class OsHeaderAction extends StatelessWidget {
  const OsHeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: neu.navy),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: neu.navy,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio compacto dentro de uma seção (mais enxuto que [NeuEmptyState],
/// que é para tela inteira). Ícone, frase curta e uma dica em cinza.
class OsInlineEmpty extends StatelessWidget {
  const OsInlineEmpty({super.key, required this.icon, required this.text, this.hint});
  final IconData icon;
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: neu.base,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: neu.inkFaint),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neu.inkFaint,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
