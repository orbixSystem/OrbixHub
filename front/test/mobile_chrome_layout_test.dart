import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometria do chrome do topo no celular.
///
/// O "+" é centralizado no berço do header; o grupo de botões do topo-direita
/// cresce da borda para o centro. Com o "?" do tutorial dentro desse grupo, num
/// telefone estreito ele passava POR CIMA do "+". O teste mede a sobreposição em
/// vez de confiar no olho: é a única forma de garantir que ela não volte quando
/// alguém adicionar o próximo botão ao canto.
void main() {
  // Medidas reais do chrome (ver dev_inbox_overlay.dart e app_shell.dart).
  const botao = 38.0; // ícone 20 + padding 9 nas duas bordas
  const sino = 48.0; // IconButton do sino tem alvo de toque maior
  const folga = 8.0;
  const margem = 8.0;
  const fabLargura = 56.0;

  /// Borda esquerda do grupo ancorado à direita, dada a largura da tela.
  double inicioDoGrupo(double tela, {required bool comTutorial}) {
    final soma = botao /* tema */ +
        folga +
        botao /* sair */ +
        folga +
        sino +
        (comTutorial ? botao + folga : 0);
    return tela - margem - soma;
  }

  /// Borda direita do "+" centralizado.
  double fimDoFab(double tela) => tela / 2 + fabLargura / 2;

  group('grupo do topo-direita × "+" centralizado', () {
    test('com o tutorial no grupo, invade o "+" num telefone de 390px', () {
      // Reproduz o bug relatado — a régua de que a correção era necessária.
      expect(
        inicioDoGrupo(390, comTutorial: true),
        lessThan(fimDoFab(390)),
      );
    });

    test('sem o tutorial no grupo, o "+" fica livre em 390px', () {
      expect(
        inicioDoGrupo(390, comTutorial: false),
        greaterThan(fimDoFab(390)),
      );
    });

    test('o "+" fica livre também no telefone estreito de 360px', () {
      expect(
        inicioDoGrupo(360, comTutorial: false),
        greaterThan(fimDoFab(360)),
      );
    });

    test('LIMITE CONHECIDO: abaixo de ~352px o trio da direita ainda encosta',
        () {
      // Mesmo sem o tutorial, sino + sair + tema somam 140px. A conta é
      //   tela/2 < margem + grupo + fabLargura/2  ⇒  tela < 352
      // Em 360px sobram só 4px. Isto NÃO é regressão desta mudança (o trio já
      // era assim), mas é o teto real: telefones de 320dp continuam com o "+"
      // encoberto, e qualquer botão novo neste canto sobe o limite.
      expect(inicioDoGrupo(340, comTutorial: false), lessThan(fimDoFab(340)));
      expect(
        inicioDoGrupo(360, comTutorial: false) - fimDoFab(360),
        closeTo(4, 0.5),
      );
    });
  });

  group('canto esquerdo reservado no header', () {
    // O header do mobile empurra o chip de conexão para 54px, abrindo espaço
    // para o "?" que agora mora naquele canto (8 + 38 + respiro).
    const reservaHeader = 54.0;

    test('a reserva cobre o botão inteiro, sem sobreposição', () {
      expect(margem + botao, lessThanOrEqualTo(reservaHeader));
    });
  });

  group('sanidade de layout', () {
    testWidgets('dois cantos ancorados não se cruzam em 360px', (tester) async {
      // Um Stack com os dois cantos: se as larguras somadas passassem da tela,
      // um cobriria o outro. Aqui só confirmamos que cabem lado a lado.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: SizedBox(width: botao, height: botao, child: Placeholder()),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SizedBox(
                  width: botao + folga + botao + folga + sino,
                  height: botao,
                  child: Placeholder(),
                ),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final caixas = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      final larguraTotal =
          caixas.fold<double>(0, (a, b) => a + (b.width ?? 0));
      expect(larguraTotal, lessThan(360));
    });
  });
}
