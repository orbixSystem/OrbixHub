import 'package:flutter/material.dart';

import 'neu_button.dart';
import 'neu_card.dart';
import 'neu_tokens.dart';

/// Linha de lista padrão: cartão raso com chip à esquerda, título/subtítulo e
/// cauda (status/valor). Serve tanto para linhas densas (desktop) quanto para
/// cards de lista (mobile) — o molde adaptativo escolhe o padding.
class NeuListTile extends StatelessWidget {
  const NeuListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Densidade desktop (linhas mais baixas).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: dense ? 10 : 14,
      ),
      radius: NeuTokens.rField,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  DefaultTextStyle.merge(
                    style: TextStyle(color: neu.inkMuted, fontSize: 13),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Controles de paginação numerada (desktop): ‹ 1 2 3 › + total de registros.
class NeuPageControls extends StatelessWidget {
  const NeuPageControls({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;

  int get _pages => total <= 0 ? 1 : ((total + pageSize - 1) ~/ pageSize);

  /// Janela de números visíveis ao redor da página atual.
  List<int?> _window() {
    final last = _pages;
    if (last <= 7) return [for (var i = 1; i <= last; i++) i];
    final around = {1, last, page - 1, page, page + 1}
        .where((p) => p >= 1 && p <= last)
        .toList()
      ..sort();
    final out = <int?>[];
    int? prev;
    for (final p in around) {
      if (prev != null && p - prev > 1) out.add(null); // reticências
      out.add(p);
      prev = p;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        Text(
          '$total ${total == 1 ? 'registro' : 'registros'}',
          style: TextStyle(color: neu.inkMuted, fontSize: 13),
        ),
        const Spacer(),
        NeuIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Página anterior',
          size: 38,
          onPressed: page > 1 ? () => onPage(page - 1) : null,
        ),
        const SizedBox(width: 6),
        for (final p in _window()) ...[
          if (p == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: TextStyle(color: neu.inkFaint)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _PageDot(
                number: p,
                selected: p == page,
                onTap: () => onPage(p),
              ),
            ),
        ],
        const SizedBox(width: 6),
        NeuIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Próxima página',
          size: 38,
          onPressed: page < _pages ? () => onPage(page + 1) : null,
        ),
      ],
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? neu.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: selected ? neu.onNavy : neu.inkMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

/// Rodapé de lista para infinite scroll (mobile): carregando / fim + total.
class NeuListFooter extends StatelessWidget {
  const NeuListFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    required this.total,
  });

  final bool loading;
  final bool hasMore;
  final int total;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                hasMore
                    ? 'Role para carregar mais'
                    : '$total ${total == 1 ? 'registro' : 'registros'} no total',
                style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
              ),
      ),
    );
  }
}
