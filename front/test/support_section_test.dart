import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/support/data/fake_support_repository.dart';
import 'package:orbixhub_front/features/support/domain/support_models.dart';
import 'package:orbixhub_front/features/support/presentation/support_section.dart';

Widget _wrap(FakeSupportRepository repo) {
  return ProviderScope(
    overrides: [supportRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: SupportSection()),
      ),
    ),
  );
}

void main() {
  testWidgets('thread vazia convida a escrever, sem parecer erro', (tester) async {
    await tester.pumpWidget(_wrap(FakeSupportRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
    expect(find.byKey(const Key('support-campo')), findsOneWidget);
  });

  testWidgets('mostra os dois lados da conversa', (tester) async {
    final repo = FakeSupportRepository(inicial: [
      SupportMessage(
        id: '1',
        body: 'a nota não sai',
        authorName: 'Zé',
        createdAt: DateTime(2026, 8, 20, 9, 30),
      ),
      SupportMessage(
        id: '2',
        body: 'já estamos vendo',
        fromOrbix: true,
        createdAt: DateTime(2026, 8, 20, 9, 45),
      ),
    ]);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('a nota não sai'), findsOneWidget);
    expect(find.text('já estamos vendo'), findsOneWidget);
    // Quem falou aparece: a resposta é identificada como da Orbix.
    expect(find.text('Suporte Orbix'), findsOneWidget);
    expect(find.text('Zé'), findsOneWidget);
  });

  testWidgets('enviar manda a mensagem e limpa o campo', (tester) async {
    final repo = FakeSupportRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('support-campo')), 'preciso de ajuda');
    await tester.pump();
    await tester.tap(find.byKey(const Key('support-enviar')));
    await tester.pumpAndSettle();

    expect(repo.enviadas, 1);
    // Campo limpo: reenviar sem querer é o erro mais fácil de cometer aqui.
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      isEmpty,
    );
  });

  testWidgets('campo vazio não envia nada', (tester) async {
    final repo = FakeSupportRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('support-campo')), '   ');
    await tester.pump();
    await tester.tap(find.byKey(const Key('support-enviar')));
    await tester.pumpAndSettle();

    expect(repo.enviadas, 0);
  });
}
