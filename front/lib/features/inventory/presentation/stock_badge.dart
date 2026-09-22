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

/// Borda do cartão quando o estoque pede atenção. `null` = cartão normal.
///
/// UNIFORME de propósito: o Flutter recusa pintar borda de larguras diferentes
/// por lado junto com canto arredondado ("The following is not uniform"), e a
/// primeira versão disto — faixa grossa só à esquerda — quebrava a tela inteira
/// em tempo de pintura. A visibilidade que a faixa daria vem de [fundoDoEstoque]
/// e do selo, que somados marcam o cartão bem mais que um contorno sozinho.
BoxBorder? bordaDoEstoque(BuildContext context, StockStatus status) {
  final cor = corDoEstoque(context, status);
  if (cor == null) return null;
  return Border.all(
    color: cor,
    width: status == StockStatus.esgotado ? 2 : 1.6,
  );
}

/// Fundo levemente tingido para o cartão que pede atenção. `null` = padrão.
///
/// Só a borda não resolve numa lista longa: o contorno se perde entre cartões
/// vizinhos, e o pedido era justamente "mais visível". O tingimento é fraco
/// (o texto continua sendo lido sobre ele) mas muda o cartão inteiro, que é o
/// que o olho pega ao varrer a lista.
Color? fundoDoEstoque(BuildContext context, StockStatus status) {
  final neu = context.neu;
  return switch (status) {
    StockStatus.esgotado => Color.lerp(neu.surface, neu.dangerTint, .75),
    StockStatus.baixo => Color.lerp(neu.surface, neu.warningTint, .6),
    _ => null,
  };
}
