import 'package:flutter/material.dart';

import 'neu_tokens.dart';

/// SnackBar de ERRO com a linguagem visual do resto do app (grafite + cantos
/// arredondados + ícone), em vez do `SnackBar` cru do Material (fundo cinza
/// escuro genérico, sem ícone, sem raio) que aparecia em toda ação que falhava.
///
/// Existe porque essa era a barra "feia" que o usuário via em produção — não é
/// só estética: uma barra que parece quebrada ao lado de um app cuidado faz
/// parecer que o ERRO em si é mais grave do que é (ex.: um 400 de validação
/// comum lendo como se o app tivesse travado).
///
/// Uso: troque `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
/// Text(e.message)))` por `showNeuErrorSnackBar(context, e.message)`.
void showNeuErrorSnackBar(BuildContext context, String message) {
  final neu = Theme.of(context).extension<NeuTokens>();
  showNeuErrorOn(ScaffoldMessenger.of(context), message, tokens: neu);
}

/// Mesmo visual, para quando o `ScaffoldMessengerState` já foi capturado ANTES
/// de um `await` (padrão comum para evitar usar `context` depois de um gap
/// assíncrono). Sem [tokens], cai nas cores fixas do tema padrão — ainda assim
/// bem melhor que o `SnackBar` cru.
void showNeuErrorOn(
  ScaffoldMessengerState messenger,
  String message, {
  NeuTokens? tokens,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens?.ink ?? const Color(0xFF2B2F44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 4),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: tokens?.danger ?? Colors.redAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens?.onNavy ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Mesma linguagem visual, para confirmações (verde) — "Salvo.", "Enviado.".
/// Bem mais raro que o de erro, mas evita um SEGUNDO estilo de barra na mesma
/// tela quando uma ação de sucesso também precisa avisar algo.
void showNeuSuccessSnackBar(BuildContext context, String message) {
  final neu = Theme.of(context).extension<NeuTokens>();
  showNeuSuccessOn(ScaffoldMessenger.of(context), message, tokens: neu);
}

/// Variante para `ScaffoldMessengerState` já capturado — ver [showNeuErrorOn].
void showNeuSuccessOn(
  ScaffoldMessengerState messenger,
  String message, {
  NeuTokens? tokens,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens?.ink ?? const Color(0xFF2B2F44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 20,
            color: tokens?.success ?? Colors.greenAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens?.onNavy ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
