import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/presentation/lock_animation.dart';

/// Transição de abrir/fechar caixa. O cadeado é desenhado (CustomPainter), então
/// o que dá para afirmar em teste é o comportamento: ele SAI do estado anterior,
/// CHEGA ao novo e o card se fecha sozinho — sem prender o usuário.

/// Estado atual do cadeado desenhado (0 = fechado, 1 = aberto).
double _lockT(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(of: find.byType(AnimatedLock), matching: find.byType(CustomPaint))
        .first,
  );
  return (paint.painter! as LockPainter).t;
}

void main() {
  group('AnimatedLock', () {
    testWidgets('nasce no estado final, sem animar (não "pisca" na tela)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Center(child: AnimatedLock(open: true))),
        ),
      );
      expect(_lockT(tester), 1.0);
    });

    testWidgets('anima de fechado para aberto quando o estado muda', (
      tester,
    ) async {
      Widget build(bool open) => MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: Center(child: AnimatedLock(open: open))),
          );

      await tester.pumpWidget(build(false));
      expect(_lockT(tester), 0.0);

      await tester.pumpWidget(build(true));
      await tester.pump(const Duration(milliseconds: 300));
      final meio = _lockT(tester);
      expect(meio, greaterThan(0.0), reason: 'a haste já deve ter saído');
      expect(meio, lessThan(1.0), reason: 'e ainda não chegou ao fim');

      await tester.pumpAndSettle();
      expect(_lockT(tester), 1.0);
    });
  });

  group('showCashierLockTransition', () {
    testWidgets('abrir: cadeado destrava e o card some sozinho', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showCashierLockTransition(context, opening: true),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Caixa aberto'), findsOneWidget);
      // Começa fechado (estado anterior) e caminha para aberto.
      await tester.pump(const Duration(milliseconds: 600));
      expect(_lockT(tester), greaterThan(0.0));

      // Fecha sozinho: nada de diálogo preso na tela. (pumpAndSettle só avança
      // animações — o auto-dismiss é um Timer, então adiantamos o relógio.)
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Caixa aberto'), findsNothing);
    });

    testWidgets('o texto fica sob um Material (sem sublinhado amarelo)', (
      tester,
    ) async {
      // showGeneralDialog entrega o conteúdo direto ao Overlay: Text sem
      // Material ancestral sai com o sublinhado amarelo duplo de debug.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showCashierLockTransition(context, opening: true),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.ancestor(
          of: find.text('Caixa aberto'),
          matching: find.byType(Material),
        ),
        findsWidgets,
        reason: 'sem Material acima, o texto sai sublinhado de amarelo',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('fechar: mostra o resultado da conferência no card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCashierLockTransition(
                  context,
                  opening: false,
                  message: 'Caixa fechado com FALTA de R\$ 10,00.',
                ),
                child: const Text('fechar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('fechar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Caixa fechado'), findsOneWidget);
      expect(
        find.textContaining('FALTA de R\$ 10,00'),
        findsOneWidget,
        reason: 'a diferença do caixa não pode se perder na animação',
      );
      await tester.pumpAndSettle();
    });
  });
}
