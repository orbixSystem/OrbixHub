import 'package:flutter/material.dart';

/// Tracinhos de confirmação estilo WhatsApp para mensagens enviadas:
/// **um tracinho** (cinza) = entregue / ainda não lida; **dois tracinhos azuis**
/// = lida pelo destinatário. Genérico — quem decide *quais* mensagens recebem o
/// indicador (as do staff no inbox, as do cliente no link público) é a tela.
class ReadTicks extends StatelessWidget {
  const ReadTicks({super.key, required this.read, this.onBrand = false});

  /// `true` quando o destinatário já visualizou (read_at != null) → dois azuis.
  final bool read;

  /// `true` quando os tracinhos ficam sobre fundo tangerina (bolha preenchida),
  /// para o estado "não lido" ter contraste suficiente.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final Color color = read
        ? const Color(0xFF34B7F1) // azul "lido" do WhatsApp
        : (onBrand
            ? Colors.white.withValues(alpha: 0.85)
            : Theme.of(context).colorScheme.onSurfaceVariant);
    // Não lido → 1 tracinho; lido → 2 tracinhos azuis.
    return Icon(
      read ? Icons.done_all_rounded : Icons.check_rounded,
      size: 15,
      color: color,
    );
  }
}

/// Decide se uma mensagem com este remetente exibe os tracinhos no inbox do staff
/// (só as respostas do staff têm recibo de leitura — as do cliente são recebidas).
bool showTicksFor(String? sender) => sender == 'staff';
