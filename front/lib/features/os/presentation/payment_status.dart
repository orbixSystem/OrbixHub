import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../domain/os_models.dart';
import 'os_status.dart';

/// Status de pagamento da venda (derivado do caixa no backend).
const paymentStatuses = <String>['a_receber', 'parcial', 'pago'];

/// Rótulo PT-BR do status de pagamento.
String paymentStatusLabel(String status) {
  switch (status) {
    case 'pago':
      return 'Paga';
    case 'parcial':
      return 'Parcial';
    // A venda cancelada tem `payment_status = 'cancelada'`; sem este caso ela
    // caía no `default` e era rotulada "A receber" — uma cobrança que não existe.
    case 'cancelada':
      return 'Cancelada';
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
    case 'cancelada':
      return AppColors.danger;
    case 'a_receber':
    default:
      return AppColors.inkMuted;
  }
}

/// Valor da OS: o total e, quando houve pagamento PARCIAL, **quanto ainda
/// falta**.
///
/// Sem isto, uma OS parcial mostrava só o total e a tag "Parcial" — o número
/// que interessa na hora de cobrar ("quanto ele ainda deve?") não estava em
/// lugar nenhum da lista nem do cabeçalho, e só aparecia abrindo o diálogo de
/// recebimento. O total continua sendo o número âncora (é ele que se compara
/// entre OS); a diferença entra como anotação logo abaixo, na cor de atenção.
///
/// Só aparece no caso PARCIAL: numa OS totalmente em aberto o saldo é igual ao
/// total (repetir seria ruído) e numa OS quitada não falta nada.
class OsAmountDue extends StatelessWidget {
  const OsAmountDue({
    super.key,
    required this.total,
    required this.payment,
    this.fontSize = 14,
    this.alignEnd = true,
  });

  /// Total da OS (Decimal serializado, como vem do backend).
  final String? total;
  final OsPaymentSummary? payment;
  final double fontSize;
  final bool alignEnd;

  /// Pagou parte, mas não tudo — o único caso em que "falta X" acrescenta algo.
  bool get _parcial {
    final p = payment;
    if (p == null) return false;
    return p.paid > 0 && p.balance > 0;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final valor = Text(
      money(total),
      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: neu.ink,
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
      ),
    );
    if (!_parcial) return valor;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        valor,
        const SizedBox(height: 1),
        Text(
          'Falta ${money(payment!.balance.toString())}',
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.w700,
            fontSize: fontSize - 2.5,
          ),
        ),
      ],
    );
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
          // Flexible: a tag entra em linhas apertadas (rodapé do card de OS em
          // celular) e o rótulo precisa ceder em vez de estourar a linha.
          Flexible(
            child: Text(
              paymentStatusLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: dense ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
