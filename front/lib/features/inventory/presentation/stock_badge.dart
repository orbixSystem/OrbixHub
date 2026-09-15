import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../domain/stock_status.dart';

/// Selo de estado do estoque — o mesmo desenho na lista de estoque, no caixa e
/// no vínculo de item da OS.
///
/// Uma única cor por estado em todo o app: vermelho é "não tem", âmbar é "está
/// acabando". Se cada tela escolhesse a sua, o vermelho do caixa acabaria
/// significando outra coisa que o vermelho do estoque.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.status, this.compacto = false});

  final StockStatus status;

  /// Versão só-ícone, para caber em linha de lista estreita (celular).
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final (String rotulo, Color cor, Color tint, IconData icone) = switch (status) {
      StockStatus.esgotado => (
        'Esgotado',
        neu.danger,
        neu.dangerTint,
        Icons.block_rounded,
      ),
      StockStatus.baixo => (
        'Baixo',
        neu.warning,
        neu.warningTint,
        Icons.warning_amber_rounded,
      ),
      _ => ('', neu.ink, neu.ink, Icons.circle),
    };
    if (rotulo.isEmpty) return const SizedBox.shrink();
    if (compacto) {
      return Tooltip(
        message: rotulo,
        child: Icon(icone, size: 18, color: cor),
      );
    }
    return NeuStatusChip(label: rotulo, color: cor, tint: tint, icon: icone);
  }
}

/// Cor do texto do item na lista quando o estoque manda: vermelho no esgotado,
/// âmbar no baixo, cor normal no resto. `null` = "não mexa na cor".
Color? corDoEstoque(BuildContext context, StockStatus status) => switch (status) {
  StockStatus.esgotado => context.neu.danger,
  StockStatus.baixo => context.neu.warning,
  _ => null,
};
