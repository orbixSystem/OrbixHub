import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Substitui o "quadrado vermelho com a exceção crua" do Flutter por um aviso
/// discreto, e manda o erro para o console em vez da tela.
///
/// Por que existir: sem `ErrorWidget.builder`, qualquer exceção durante o build
/// vira uma faixa vermelha com texto técnico DENTRO do layout — no topo ou no
/// rodapé, dependendo de onde estava o widget quebrado. Para quem está usando o
/// sistema isso é assustador e não informa nada de útil.
///
/// O que este arquivo NÃO faz: esconder o problema de nós. O erro continua indo
/// para o console com o stack completo (via [FlutterError.presentError]), então
/// o diagnóstico não fica mais pobre — só sai da cara do usuário.
///
/// Também NÃO cobre as faixas listradas de "OVERFLOWED BY x PIXELS": aquilo é
/// pintado pelo próprio RenderFlex em modo debug e não passa por aqui. Elas não
/// existem em build de release; em debug, o jeito de fazê-las sumir é corrigir o
/// estouro de layout.
void installFriendlyErrorSurface() {
  // Mantém o relato padrão (console + DevTools) e nada mais.
  FlutterError.onError = FlutterError.presentError;

  ErrorWidget.builder = (FlutterErrorDetails details) => FalhaDeWidget(
        // Em debug o desenvolvedor precisa ver ONDE quebrou sem abrir o console;
        // em release o usuário só precisa saber que aquele pedaço não carregou.
        detalhe: kDebugMode ? details.exceptionAsString() : null,
      );
}

/// Aviso mínimo que ocupa o lugar de um widget que falhou.
///
/// Pequeno e neutro de propósito: substitui um pedaço quebrado da tela, então não
/// pode dominar o layout nem gritar em vermelho.
///
/// Nada aqui depende de `Theme.of(context)` nem de um `Directionality` herdado:
/// este widget aparece justamente quando algo está fora do lugar, e podendo ser
/// inserido acima do `MaterialApp` (ou dentro de uma subárvore meio construída),
/// depender de ancestrais o faria falhar também — e aí o Flutter cairia no
/// vermelho que estamos justamente evitando.
class FalhaDeWidget extends StatelessWidget {
  const FalhaDeWidget({super.key, this.detalhe});

  /// Texto técnico da exceção — preenchido só em debug.
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    final d = detalhe;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x11000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: Color(0x99000000),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Não foi possível exibir esta parte da tela.',
                    style: TextStyle(
                      color: Color(0x99000000),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            if (d != null) ...[
              const SizedBox(height: 6),
              Text(
                d,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0x77000000),
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
