import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/cashier_format.dart';

/// Campo de **desconto na quitação**, compartilhado pelos três lugares onde se
/// recebe dinheiro (fiado, OS e venda).
///
/// Existe como widget único porque a regra de quem vê o campo é a mesma nos
/// três, e replicá-la seria garantir que um dia divirjam — o terceiro lugar
/// esqueceria a permissão e o campo apareceria para quem não pode conceder.
///
/// **Esconder não é proteger.** O backend valida permissão e teto de novo; isto
/// aqui só evita oferecer ao operador um controle que ele não pode usar.
class DescontoField extends ConsumerWidget {
  const DescontoField({
    super.key,
    required this.controller,
    required this.motivoController,
    required this.saldo,
    required this.onChanged,
    this.label = 'Desconto na quitação',
    this.ajuda,
  });

  final TextEditingController controller;
  final TextEditingController motivoController;

  /// Saldo sobre o qual o desconto incide — usado para avisar quando o valor
  /// digitado passa do que se deve.
  final double saldo;

  final VoidCallback onChanged;
  final String label;
  final String? ajuda;

  /// Quanto foi digitado, em reais. Zero quando vazio ou inválido.
  static double valorDe(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionControllerProvider).meOrNull;
    // Permissão vem de /me em runtime — nunca de lista fixa no cliente.
    if (me == null || !me.hasPermission('cashier.discount')) {
      return const SizedBox.shrink();
    }

    final neu = context.neu;
    final valor = valorDe(controller);
    final excede = valor > saldo + 0.005;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuTextField(
          label: label,
          controller: controller,
          hint: '0,00',
          // Mesma apresentação do campo de valor recebido: prefixo R$ e número
          // à direita. Campo de dinheiro que não se parece com campo de
          // dinheiro faz o operador digitar centavos onde queria reais.
          prefixText: 'R\$ ',
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [DecimalInputFormatter()],
          onChanged: (_) => onChanged(),
        ),
        if (excede)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              'Desconto maior que o saldo de ${formatMoney(saldo)}.',
              style: TextStyle(color: neu.danger, fontSize: 14),
            ),
          )
        else if (valor > 0) ...[
          const SizedBox(height: 10),
          NeuTextField(
            label: 'Motivo do desconto (opcional)',
            controller: motivoController,
            hint: 'Ex.: cliente antigo, pagamento à vista',
            prefixIcon: Icons.notes_rounded,
            onChanged: (_) => onChanged(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              ajuda ??
                  'O valor do documento não muda: o desconto encerra a dívida '
                      'e aparece separado no relatório.',
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }
}
