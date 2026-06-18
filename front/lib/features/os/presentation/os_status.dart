import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Os 7 status da OS, em ordem de fluxo.
const osStatuses = <String>[
  'aberta',
  'aguardando_aprovacao',
  'aprovada',
  'em_execucao',
  'concluida',
  'entregue',
  'cancelada',
];

/// Rótulo PT-BR por status.
String osStatusLabel(String status) {
  switch (status) {
    case 'aberta':
      return 'Aberta';
    case 'aguardando_aprovacao':
      return 'Aguardando aprovação';
    case 'aprovada':
      return 'Aprovada';
    case 'em_execucao':
      return 'Em execução';
    case 'concluida':
      return 'Concluída';
    case 'entregue':
      return 'Entregue';
    case 'cancelada':
      return 'Cancelada';
    default:
      return status;
  }
}

/// Cor de fundo do chip por status (do design system: grafite + tangerina).
Color osStatusColor(String status) {
  switch (status) {
    case 'em_execucao':
      return AppColors.brand;
    case 'aprovada':
      return AppColors.info;
    case 'concluida':
      return AppColors.success;
    case 'entregue':
      return AppColors.graphite;
    case 'cancelada':
      return AppColors.danger;
    case 'aguardando_aprovacao':
      return AppColors.warning;
    case 'aberta':
    default:
      return AppColors.inkMuted;
  }
}

/// FSM no front (espelha o backend): transições válidas a partir de cada status.
/// O backend é a verdade — isto só desenha os botões plausíveis.
const Map<String, List<String>> osTransitions = {
  'aberta': ['aguardando_aprovacao', 'em_execucao', 'cancelada'],
  'aguardando_aprovacao': ['aprovada', 'aberta', 'cancelada'],
  'aprovada': ['em_execucao', 'cancelada'],
  'em_execucao': ['concluida', 'cancelada'],
  'concluida': ['entregue'],
  'entregue': <String>[],
  // Cancelada só sai por "reabertura" (→ aberta) — privilegiada (os.approve).
  'cancelada': ['aberta'],
};

/// Estados terminais (espelha o backend): a OS não aceita edição de conteúdo
/// (itens, fotos, notas, cabeçalho). `cancelada` volta a ser editável reabrindo-a;
/// `entregue` é final. O backend é a verdade — isto só desabilita os controles.
bool osIsTerminal(String status) =>
    status == 'cancelada' || status == 'entregue';

/// Verbo do botão de transição (ação) para cada destino.
String osTransitionLabel(String target) {
  switch (target) {
    case 'aguardando_aprovacao':
      return 'Enviar p/ aprovação';
    case 'aprovada':
      return 'Aprovar';
    case 'aberta':
      return 'Reabrir';
    case 'em_execucao':
      return 'Iniciar execução';
    case 'concluida':
      return 'Concluir';
    case 'entregue':
      return 'Entregar';
    case 'cancelada':
      return 'Cancelar OS';
    default:
      return osStatusLabel(target);
  }
}

/// Chip colorido de status (texto branco sobre a cor do status).
class OsStatusChip extends StatelessWidget {
  const OsStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = osStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        osStatusLabel(status),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Formata um decimal serializado ("45.90") em "R$ 45,90". Null/vazio → "R$ 0,00".
String money(String? decimal) {
  final v = double.tryParse(decimal ?? '') ?? 0;
  return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}
