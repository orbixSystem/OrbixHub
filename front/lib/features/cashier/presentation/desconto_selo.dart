import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';

/// Mostra, no detalhe de um documento, que houve **desconto na quitação**.
///
/// Existe porque a decisão de deixar o documento intacto tem um efeito colateral
/// desagradável se não for dito: uma venda de R$ 100 aparece quitada tendo
/// entrado R$ 90, e quem confere não encontra os R$ 10. Sem esta linha o
/// desconto vira exatamente o buraco invisível que o modelo foi desenhado para
/// evitar.
///
/// Some quando não houve desconto — linha de valor zero é ruído.
class DescontoSelo extends StatelessWidget {
  const DescontoSelo({super.key, required this.payment, this.dense = false});

  final PaymentDetail payment;
  final bool dense;

  /// Motivos informados nos lançamentos, sem repetir e sem vazios.
  static List<String> motivosDe(PaymentDetail p) {
    final vistos = <String>{};
    for (final e in p.entries) {
      if (e.reversedAt != null) continue;
      final m = (e.discountReason ?? '').trim();
      if (m.isNotEmpty) vistos.add(m);
    }
    return vistos.toList();
  }

  @override
  Widget build(BuildContext context) {
    final desconto = payment.discount.toDouble();
    if (desconto <= 0.005) return const SizedBox.shrink();

    final neu = context.neu;
    final motivos = motivosDe(payment);

    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rChip,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: dense ? 10 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_offer_outlined, size: 18, color: neu.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Desconto concedido',
                        style: TextStyle(
                          color: neu.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(desconto),
                      style: TextStyle(
                        color: neu.warning,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // A conta explicada: é isto que faz o total fechar aos olhos de
                // quem confere, sem precisar deduzir.
                Text(
                  'Recebido ${formatMoney(payment.received)} + desconto '
                  '${formatMoney(desconto)} = ${formatMoney(payment.paid)} '
                  'de ${formatMoney(payment.total)}.',
                  style: TextStyle(color: neu.inkMuted, fontSize: 14),
                ),
                if (motivos.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    motivos.length == 1
                        ? 'Motivo: ${motivos.first}'
                        : 'Motivos: ${motivos.join(' · ')}',
                    style: TextStyle(color: neu.inkMuted, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
