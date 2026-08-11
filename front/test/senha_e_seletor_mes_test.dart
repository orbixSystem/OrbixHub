import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/features/expenses/presentation/month_picker_dialog.dart';

/// Olhinho de senha (no design system) e seletor de mês das despesas.
///
/// Os dois são UI pura, então o teste é de widget mesmo: o valor está em provar
/// que o botão aparece onde deve, que revelar/ocultar de fato troca o estado do
/// campo, e que o seletor devolve o mês que foi tocado.
Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

/// O `obscureText` efetivo do campo — é o que diz se a senha está escondida.
bool _estaOculto(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).obscureText;

void main() {
  group('olhinho da senha', () {
    testWidgets('campo de senha ganha o botão sem a tela pedir', (tester) async {
      // O ponto da mudança: login, cadastro e aceite de convite não montavam
      // botão nenhum, e passaram a ter só por declarar `obscureText`.
      await tester.pumpWidget(
        _app(const NeuTextField(label: 'Senha', obscureText: true)),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(_estaOculto(tester), isTrue);
    });

    testWidgets('campo comum NÃO ganha olhinho', (tester) async {
      await tester.pumpWidget(
        _app(const NeuTextField(label: 'Descrição')),
      );
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(_estaOculto(tester), isFalse);
    });

    testWidgets('tocar revela e tocar de novo oculta', (tester) async {
      await tester.pumpWidget(
        _app(const NeuTextField(label: 'Senha', obscureText: true)),
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(_estaOculto(tester), isFalse);
      // O ícone anuncia a AÇÃO: revelada, o próximo toque oculta.
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(_estaOculto(tester), isTrue);
    });

    testWidgets('suffix próprio da tela vence o olhinho automático', (tester) async {
      // Quem já montou o seu não pode acabar com dois ícones empilhados.
      await tester.pumpWidget(
        _app(
          const NeuTextField(
            label: 'Senha',
            obscureText: true,
            suffix: Icon(Icons.lock_outline),
          ),
        ),
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });
  });

  group('seletor de mês', () {
    /// O que o seletor devolveu. Preenchido pelo callback quando o diálogo
    /// fecha — por isso é lido DEPOIS do toque, nunca no retorno de [abrir]
    /// (nesse instante o diálogo mal abriu e o valor ainda é nulo).
    late List<DateTime?> resultado;

    setUp(() => resultado = []);

    Future<void> abrir(
      WidgetTester tester, {
      required DateTime inicial,
    }) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => NeuButton(
              label: 'abrir',
              onPressed: () async {
                resultado.add(
                  await showMonthPickerDialog(context, inicial: inicial),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra os 12 meses do ano de uma vez', (tester) async {
      // É o motivo de existir: chegar em dezembro do ano passado custava treze
      // toques nas setas.
      await abrir(tester, inicial: DateTime(2026, 8));
      for (final m in ['Jan', 'Fev', 'Ago', 'Dez']) {
        expect(find.text(m), findsOneWidget);
      }
    });

    testWidgets('tocar num mês devolve ele (dia 1)', (tester) async {
      await abrir(tester, inicial: DateTime(2026, 8));

      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      expect(find.text('Escolher mês'), findsNothing);
      expect(resultado.single, DateTime(2026, 3));
    });

    testWidgets('escolhe no ano navegado, não no ano de origem', (tester) async {
      // Regressão que o grid convida: voltar o ano e tocar em "Mar" tem de dar
      // março de 2025, não de 2026.
      await abrir(tester, inicial: DateTime(2026, 8));

      await tester.tap(find.byTooltip('Ano anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      expect(resultado.single, DateTime(2025, 3));
    });

    testWidgets('navegar o ano NÃO escolhe nada — só muda o grid', (tester) async {
      await abrir(tester, inicial: DateTime(2026, 8));
      expect(find.text('2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Ano anterior'));
      await tester.pumpAndSettle();

      expect(find.text('2025'), findsOneWidget);
      // Continua aberto: separar navegar de escolher é o que permite olhar 2025
      // e desistir.
      expect(find.text('Escolher mês'), findsOneWidget);
      expect(resultado, isEmpty);
    });

    testWidgets('atalho "Mês atual" devolve o mês de hoje', (tester) async {
      await abrir(tester, inicial: DateTime(2020, 1));

      await tester.tap(find.text('Mês atual'));
      await tester.pumpAndSettle();

      final hoje = DateTime.now();
      expect(resultado.single, DateTime(hoje.year, hoje.month));
    });

    testWidgets('cancelar não devolve mês nenhum', (tester) async {
      await abrir(tester, inicial: DateTime(2026, 8));

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(resultado.single, isNull);
    });

    testWidgets('cabe num celular estreito sem estourar', (tester) async {
      // 360x640 é o piso que a tela precisa atender. Overflow vira exceção no
      // teste, então basta abrir e assentar.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await abrir(tester, inicial: DateTime(2026, 8));

      expect(find.text('Escolher mês'), findsOneWidget);
      expect(find.text('Dez'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
