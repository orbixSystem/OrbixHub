import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Toda tela do shell precisa usar a MESMA transição.
///
/// O router monta as páginas com `pageBuilder: (_, s) => neuPage(s, Tela())` —
/// fade-through, com o fundo preenchido pelo canvas do tema. Uma rota escrita
/// com `builder:` em vez disso cai na transição default do Material (slide), o
/// que fazia o Caixa e a Agenda entrarem de um jeito diferente de todas as outras
/// telas e "bugar" visualmente na troca.
///
/// Este teste lê o próprio arquivo de rotas porque a divergência é estrutural:
/// não há como flagrá-la montando uma tela isolada, e ela reaparece silenciosa
/// a cada rota nova escrita fora do padrão.
void main() {
  test('nenhuma rota do shell usa builder: em vez de pageBuilder/neuPage', () {
    final fonte = File('lib/core/router/app_router.dart').readAsStringSync();

    // `builder:` legítimo existe só no ShellRoute (que monta o AppShell com o
    // child) e recebe três parâmetros — as rotas usam dois.
    final foraDoPadrao = RegExp(r'^\s*builder: \(_, _\) =>', multiLine: true)
        .allMatches(fonte)
        .map((m) {
      final antes = fonte.substring(0, m.start);
      final linha = antes.split('\n').length;
      // Recupera o `path:` mais próximo acima, para a mensagem ser acionável.
      final path = RegExp(r"path: '([^']+)'")
          .allMatches(antes)
          .lastOrNull
          ?.group(1);
      return '${path ?? '?'} (linha $linha)';
    }).toList();

    expect(
      foraDoPadrao,
      isEmpty,
      reason: 'estas rotas usam builder: e por isso ganham a transição default '
          'do Material, diferente do fade-through das demais — troque por '
          '`pageBuilder: (_, s) => neuPage(s, ...)`: ${foraDoPadrao.join(', ')}',
    );
  });

  test('as telas que já bugaram seguem no padrão (regressão)', () {
    final fonte = File('lib/core/router/app_router.dart').readAsStringSync();
    for (final tela in [
      'CashierScreen',
      'AgendaScreen',
      'BusinessHoursScreen',
    ]) {
      expect(
        fonte,
        contains('neuPage(s, const $tela())'),
        reason: '$tela precisa entrar com a mesma transição das outras telas',
      );
    }
  });
}
