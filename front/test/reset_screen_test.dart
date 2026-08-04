import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/features/auth/presentation/reset_screen.dart';

/// Monta só a rota /reset para que `GoRouterState.of(context)` enxergue a query
/// string — é dela que a tela tira o token do link do e-mail.
Future<void> _pumpReset(WidgetTester tester, String location) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/reset', builder: (_, _) => const ResetScreen()),
      GoRoute(path: '/login', builder: (_, _) => const SizedBox()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('esconde o token quando ele veio pronto no link do e-mail',
      (tester) async {
    await _pumpReset(tester, '/reset?token=tok123');
    expect(find.widgetWithText(TextFormField, 'Token'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Nova senha (mín. 8)'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, 'Confirmar nova senha'),
      findsOneWidget,
    );
  });

  testWidgets('mostra o campo de token para quem abriu /reset sem link',
      (tester) async {
    await _pumpReset(tester, '/reset');
    expect(find.widgetWithText(TextFormField, 'Token'), findsOneWidget);
  });

  testWidgets('não redefine quando a confirmação não bate', (tester) async {
    await _pumpReset(tester, '/reset?token=tok123');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nova senha (mín. 8)'),
      'senha12345',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar nova senha'),
      'senha54321',
    );
    await tester.tap(find.text('Redefinir'));
    await tester.pump();
    expect(find.text('As senhas não conferem.'), findsOneWidget);
  });

  testWidgets('cada senha tem seu próprio olho, revelando só o seu campo',
      (tester) async {
    await _pumpReset(tester, '/reset?token=tok123');
    final eyes = find.byIcon(Icons.visibility_outlined);
    expect(eyes, findsNWidgets(2));
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .every((f) => f.obscureText),
      isTrue,
    );

    // O olho do primeiro campo não pode revelar a confirmação junto.
    await tester.tap(eyes.first);
    await tester.pump();
    final obscured = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((f) => f.obscureText)
        .toList();
    expect(obscured, [false, true]);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((f) => f.obscureText),
      [false, false],
    );
  });
}
