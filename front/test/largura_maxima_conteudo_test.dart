import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/ui/adaptive.dart';

/// O teto de largura precisa agir SÓ onde o problema existe.
///
/// Se ele apertasse em telas médias, quebraria todas as telas de uma vez — e é
/// exatamente o tipo de mudança que ninguém percebe até estar em produção. Daí
/// o número (1400) estar fixado por teste, e não só escolhido.
void main() {
  // A superfície do teste tem 800px por padrão e CLAMPA qualquer filho maior —
  // sem redimensioná-la, o caso "monitor grande" nunca chegaria a acontecer.
  Future<double> larguraDoFilho(WidgetTester t, double larguraDaTela) async {
    await t.binding.setSurfaceSize(Size(larguraDaTela, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final chave = GlobalKey();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ConteudoLimitado(child: SizedBox(key: chave, height: 100)),
      ),
    );
    return t.getSize(find.byKey(chave)).width;
  }

  testWidgets('celular e tablet passam intactos', (t) async {
    expect(await larguraDoFilho(t, 390), 390);
    expect(await larguraDoFilho(t, 800), 800);
  });

  testWidgets('notebook comum NÃO é afetado', (t) async {
    // 1440 de tela menos a sidebar (272) dá ~1168 de conteúdo — o caso mais
    // comum do time. Apertar aqui seria estreitar a tela de quem não reclamou.
    expect(await larguraDoFilho(t, 1168), 1168);
    expect(await larguraDoFilho(t, 1399), 1399);
  });

  testWidgets('monitor grande é limitado e centralizado', (t) async {
    expect(await larguraDoFilho(t, 2288), kLarguraMaximaDeConteudo);
    expect(await larguraDoFilho(t, 3000), kLarguraMaximaDeConteudo);
  });

  testWidgets('alinha ao TOPO — conteúdo não pode flutuar no meio', (t) async {
    await t.binding.setSurfaceSize(const Size(2000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final chave = GlobalKey();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ConteudoLimitado(child: SizedBox(key: chave, height: 100)),
      ),
    );
    expect(t.getTopLeft(find.byKey(chave)).dy, 0);
  });
}
