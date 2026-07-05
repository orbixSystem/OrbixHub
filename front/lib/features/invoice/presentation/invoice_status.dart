import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Rótulo PT-BR por status da nota fiscal.
String invoiceStatusLabel(String status) {
  switch (status) {
    case 'draft':
      return 'Rascunho';
    case 'processing':
      return 'Processando';
    case 'authorized':
      return 'Autorizada';
    case 'rejected':
      return 'Rejeitada';
    case 'canceled':
      return 'Cancelada';
    case 'error':
      return 'Erro';
    default:
      return status;
  }
}

/// Rótulo PT-BR do tipo de documento fiscal.
String invoiceDocumentTypeLabel(String type) {
  switch (type) {
    case 'nfse':
      return 'NFS-e';
    case 'nfce':
      return 'NFC-e';
    case 'nfe':
      return 'NF-e';
    default:
      return type.toUpperCase();
  }
}

/// Cor semântica (token neu) por status. authorized=success;
/// processing/draft=navy/accent; rejected/error=danger; canceled=inkMuted.
Color invoiceStatusColor(BuildContext context, String status) {
  final neu = context.neu;
  switch (status) {
    case 'authorized':
      return neu.success;
    case 'processing':
      return neu.info;
    case 'draft':
      return neu.accent;
    case 'rejected':
    case 'error':
      return neu.danger;
    case 'canceled':
      return neu.inkMuted;
    default:
      return neu.inkMuted;
  }
}

/// Chip de status da nota (tint + texto na cor semântica), no padrão do
/// [OsStatusChip]/[NeuStatusChip].
class InvoiceStatusChip extends StatelessWidget {
  const InvoiceStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = invoiceStatusColor(context, status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return NeuStatusChip(
      label: invoiceStatusLabel(status),
      color: dark ? Color.lerp(color, Colors.white, .35)! : color,
      tint: color.withValues(alpha: dark ? .22 : .14),
    );
  }
}
