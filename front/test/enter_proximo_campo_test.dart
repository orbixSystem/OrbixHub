import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';

/// Pedido do balcão: "ao adicionar produtos e clientes, clicar Enter e já ir
/// para o próximo campo". Como todo formulário do app é feito de `NeuTextField`,
/// o comportamento mora no campo — não em cada tela — e vale em todas de uma vez.
void main() {
  Future<void> montar(WidgetTester t, {int maxLinesDoPrimeiro = 1}) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              NeuTextField(label: 'Primeiro', maxLines: maxLinesDoPrimeiro),
              const NeuTextField(label: 'Segundo'),
            ],
          ),
        ),
      ),
    );
  }

  /// Qual campo está com o cursor: o `EditableText` que detém o foco primário.
  String? campoFocado(WidgetTester t) {
    for (final e in find.byType(EditableText, skipOffstage: false).evaluate()) {
      final w = e.widget as EditableText;
      if (w.focusNode.hasPrimaryFocus) return w.controller.text;
    }
    return null;
  }

  testWidgets('Enter leva o cursor para o próximo campo', (t) async {
    await montar(t);
    await t.enterText(find.byType(TextFormField).first, 'primeiro');
    await t.pumpAndSettle();
    expect(campoFocado(t), 'primeiro');

    // A tecla Enter do teclado físico (web/desktop) e o "avançar" do teclado do
    // celular chegam pelo mesmo caminho: a ação do campo.
    await t.testTextInput.receiveAction(TextInputAction.next);
    await t.pumpAndSettle();

    expect(campoFocado(t), '', reason: 'o cursor deve ter ido para o 2º campo');
  });

  testWidgets('o campo já traz a ação "próximo" (seta no teclado do celular)',
      (t) async {
    await montar(t);
    final campo = t.widget<EditableText>(find.byType(EditableText).first);
    expect(campo.textInputAction, TextInputAction.next);
  });

  testWidgets('em campo de várias linhas, Enter continua sendo quebra de linha',
      (t) async {
    await montar(t, maxLinesDoPrimeiro: 3);
    final campo = t.widget<EditableText>(find.byType(EditableText).first);
    // Não é "next": num campo de observações, Enter tem de quebrar linha.
    expect(campo.textInputAction, isNot(TextInputAction.next));
  });
}
