import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Status de pagamento da venda (derivado do caixa no backend).
const paymentStatuses = <String>['a_receber', 'parcial', 'pago'];

/// Rótulo PT-BR do status de pagamento.
String paymentStatusLabel(String status) {
  switch (status) {
    case 'pago':
      return 'Paga';
    case 'parcial':
      return 'Parcial';
    case 'a_receber':
    default:
      return 'A receber';
  }
}

/// Cor do status de pagamento: paga=success, parcial=warning, a_receber=muted.
Color paymentStatusColor(String status) {
  switch (status) {
    case 'pago':
      return AppColors.success;
    case 'parcial':
      return AppColors.warning;
    case 'a_receber':
    default:
      return AppColors.inkMuted;
  }
}

/// Tag de pagamento (Paga / A receber / Parcial). Usada na listagem de OS e
/// dentro da OS. Visual de "pílula" suave (cor de fundo translúcida + texto na
/// cor), distinta do chip de status da OS (que é sólido), para não competir.
class PaymentTag extends StatelessWidget {
  const PaymentTag({super.key, required this.status, this.dense = false});

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = paymentStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == 'pago'
                ? Icons.check_circle_outline
                : status == 'parcial'
                    ? Icons.hourglass_bottom_outlined
                    : Icons.schedule_outlined,
            size: dense ? 13 : 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            paymentStatusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
