import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Rótulo PT-BR por status da venda.
String saleStatusLabel(String status) {
  switch (status) {
    case 'concluida':
      return 'Concluída';
    case 'cancelada':
      return 'Cancelada';
    default:
      return status;
  }
}

/// Cor semântica (token neu) por status: concluída=success; cancelada=inkMuted.
Color saleStatusColor(BuildContext context, String status) {
  final neu = context.neu;
  switch (status) {
    case 'concluida':
      return neu.success;
    case 'cancelada':
      return neu.inkMuted;
    default:
      return neu.inkMuted;
  }
}

/// Chip de status da venda (tint + texto na cor semântica), no padrão do app.
class SaleStatusChip extends StatelessWidget {
  const SaleStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = saleStatusColor(context, status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return NeuStatusChip(
      label: saleStatusLabel(status),
      color: dark ? Color.lerp(color, Colors.white, .35)! : color,
      tint: color.withValues(alpha: dark ? .22 : .14),
    );
  }
}

/// Formas de pagamento aceitas (chave de contrato com o backend + rótulo + ícone).
enum PaymentMethod {
  dinheiro('dinheiro', 'Dinheiro', Icons.payments_outlined),
  cartao('cartao', 'Cartão', Icons.credit_card_outlined),
  pix('pix', 'Pix', Icons.qr_code_2_outlined),
  outro('outro', 'Outro', Icons.more_horiz_rounded);

  const PaymentMethod(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;

  static PaymentMethod fromKey(String key) => PaymentMethod.values.firstWhere(
        (m) => m.key == key,
        orElse: () => PaymentMethod.outro,
      );
}

/// Rótulo PT-BR da forma de pagamento a partir da chave do backend.
String paymentMethodLabel(String key) => PaymentMethod.fromKey(key).label;

/// Ícone da forma de pagamento a partir da chave do backend.
IconData paymentMethodIcon(String key) => PaymentMethod.fromKey(key).icon;

/// Formata uma data ISO em dd/MM/yyyy (local). Vazio se nula/inválida.
String saleFmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Formata uma data ISO em dd/MM/yyyy HH:mm (local). Vazio se nula/inválida.
String saleFmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
