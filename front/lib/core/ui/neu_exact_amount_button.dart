import 'package:flutter/material.dart';

import 'neu_tokens.dart';

/// Botão "valor exato": preenche o campo de valor com o total devido num toque.
///
/// Existe porque digitar um número que já está na tela é trabalho que o sistema
/// devia poupar — e no balcão o caso mais comum é justamente receber o valor
/// exato (pix, cartão, ou dinheiro contado). Também elimina o erro de digitação
/// em cima de um valor conhecido.
class NeuExactAmountButton extends StatelessWidget {
  const NeuExactAmountButton({
    super.key,
    required this.onTap,
    this.label = 'Valor exato',
    this.tooltip = 'Preencher com o valor total',
  });

  final VoidCallback onTap;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: neu.navy.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(NeuTokens.rChip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.done_all_rounded, size: 15, color: neu.navy),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: neu.navy,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
