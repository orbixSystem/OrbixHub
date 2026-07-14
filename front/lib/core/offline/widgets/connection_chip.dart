import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../ui/neu_tokens.dart';
import '../connectivity_controller.dart';

/// Indicador PERSISTENTE de conectividade/sync (contraste com
/// [ConnectionBanner], que só aparece nas TRANSIÇÕES). Vive no rodapé da
/// sidebar (acima do `_UserFooter`) e, de forma compacta ([dense]), no
/// header do mobile.
///
/// Três estados: verde "Online" · âmbar "Sincronizando…" (com afordance de
/// progresso) · cinza-escuro "Offline • N pendentes". Quando há mutações de
/// outros autores ainda não puxadas ([ConnState.pendingOtherAuthors]), um
/// tooltip soma "M aguardando login de outro usuário".
///
/// [collapsed] (sidebar desktop encolhida) degrada para um dot colorido com
/// [Tooltip] — sem rótulo, cabe nos 76px do modo compacto.
class ConnectionChip extends ConsumerWidget {
  const ConnectionChip({
    super.key,
    this.collapsed = false,
    this.dense = false,
    this.onDark = false,
  });

  /// Modo colapsado (sidebar desktop encolhida): só um dot + Tooltip.
  final bool collapsed;

  /// Modo compacto (header mobile): pill menor.
  final bool dense;

  /// O chip está sobre um painel ESCURO (a sidebar é grafite/navy nos dois
  /// temas). Sem isto ele usaria os tints do canvas claro — um pill quase
  /// branco gritando no rodapé da sidebar.
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityControllerProvider);
    final display = connectionDisplayFor(state, context.neu, onDark: onDark);

    if (collapsed) {
      return Tooltip(
        message: _collapsedTooltip(display),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: display.color, shape: BoxShape.circle),
        ),
      );
    }

    final dotSize = dense ? 7.0 : 8.0;
    final Widget indicator = display.spinner
        ? SizedBox(
            width: dotSize,
            height: dotSize,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: display.color,
            ),
          )
        : Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: display.color, shape: BoxShape.circle),
          );

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: display.tint,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          SizedBox(width: dense ? 5 : 6),
          // Flexible (não só Text simples): num sidebar/header estreito o
          // rótulo trunca com reticências em vez de estourar o Row (contagens
          // grandes de pendências podem alongar bastante o texto).
          Flexible(
            child: Text(
              display.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: display.color,
                fontSize: dense ? 11 : 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (display.tooltip == null) return chip;
    return Tooltip(message: display.tooltip!, child: chip);
  }

  String _collapsedTooltip(ConnectionDisplay display) {
    return display.tooltip == null
        ? display.label
        : '${display.label}\n${display.tooltip}';
  }
}

/// Descrição visual resolvida para um [ConnState] — separado do widget para
/// ser testável isoladamente (sem precisar montar árvore).
class ConnectionDisplay {
  const ConnectionDisplay({
    required this.label,
    required this.color,
    required this.tint,
    this.tooltip,
    this.spinner = false,
  });

  final String label;
  final Color color;
  final Color tint;

  /// Texto extra (contagem de mutações de outros autores ainda não puxadas).
  final String? tooltip;

  /// Quando true, o indicador é um spinner em vez de um dot estático
  /// (afordance de progresso do estado "syncing").
  final bool spinner;
}

String pendingLabel(int n) => n == 1 ? '1 pendente' : '$n pendentes';

/// Paleta semântica do tema ESCURO — usada quando o indicador vive sobre um
/// painel escuro (sidebar) independentemente do tema do canvas. Os tons claros
/// (verde/âmbar/vermelho do tema claro) somem ou vibram sobre o navy.
final _dark = NeuTokens.dark();

/// Resolve o [ConnectionDisplay] de um [ConnState] contra os tokens do tema
/// atual — pura, sem BuildContext, para poder ser testada diretamente.
///
/// [onDark]: o chip está sobre a sidebar escura — cores da paleta escura e
/// tint translúcido (mesmo idioma do resto do chrome da sidebar).
ConnectionDisplay connectionDisplayFor(
  ConnState state,
  NeuTokens neu, {
  bool onDark = false,
}) {
  final others = state.pendingOtherAuthors;
  final othersTooltip =
      others > 0 ? '$others aguardando login de outro usuário' : null;
  final palette = onDark ? _dark : neu;
  Color tint(Color fallback) =>
      onDark ? Colors.white.withValues(alpha: 0.08) : fallback;

  switch (state.status) {
    case ConnStatus.online:
      return ConnectionDisplay(
        label: 'Online',
        color: palette.success,
        tint: tint(neu.successTint),
        tooltip: othersTooltip,
      );
    case ConnStatus.syncing:
      return ConnectionDisplay(
        label: 'Sincronizando…',
        color: palette.warning,
        tint: tint(neu.warningTint),
        tooltip: othersTooltip,
        spinner: true,
      );
    case ConnStatus.offline:
      // Sem pendências o "• 0 pendentes" era só ruído (é o caso da web, que
      // nem tem outbox): o rótulo só ganha a contagem quando há o que enviar.
      final pending = state.pendingCount;
      return ConnectionDisplay(
        label:
            pending > 0 ? 'Offline • ${pendingLabel(pending)}' : 'Offline',
        // Vermelho suave (não cinza): o offline é o mesmo idioma dos avisos
        // vermelhos das telas — inconfundível, sem ser um alerta cheio.
        color: palette.danger,
        tint: tint(neu.dangerTint),
        tooltip: othersTooltip,
      );
  }
}
