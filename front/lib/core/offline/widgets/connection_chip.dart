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
  const ConnectionChip({super.key, this.collapsed = false, this.dense = false});

  /// Modo colapsado (sidebar desktop encolhida): só um dot + Tooltip.
  final bool collapsed;

  /// Modo compacto (header mobile): pill menor.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityControllerProvider);
    final display = connectionDisplayFor(state, context.neu);

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

/// Resolve o [ConnectionDisplay] de um [ConnState] contra os tokens do tema
/// atual — pura, sem BuildContext, para poder ser testada diretamente.
ConnectionDisplay connectionDisplayFor(ConnState state, NeuTokens neu) {
  final others = state.pendingOtherAuthors;
  final othersTooltip =
      others > 0 ? '$others aguardando login de outro usuário' : null;

  switch (state.status) {
    case ConnStatus.online:
      return ConnectionDisplay(
        label: 'Online',
        color: neu.success,
        tint: neu.successTint,
        tooltip: othersTooltip,
      );
    case ConnStatus.syncing:
      return ConnectionDisplay(
        label: 'Sincronizando…',
        color: neu.warning,
        tint: neu.warningTint,
        tooltip: othersTooltip,
        spinner: true,
      );
    case ConnStatus.offline:
      return ConnectionDisplay(
        label: 'Offline • ${pendingLabel(state.pendingCount)}',
        color: neu.inkMuted,
        tint: neu.surfaceHi,
        tooltip: othersTooltip,
      );
  }
}
