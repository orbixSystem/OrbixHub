import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_tab.dart';

/// Carteira grande é o caso normal de uma oficina com anos de fiado. Sem busca,
/// achar um cliente exige rolar; sem paginação, a tela monta a lista inteira.
/// Os dois são de UX, mas quebram calado — a lista simplesmente fica longa.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  DebtorsPage carteira(int quantos, {List<String> nomes = const []}) {
    final items = <Debtor>[
      for (var i = 0; i < quantos; i++)
        Debtor(
          customerId: 'c$i',
          customerName: i < nomes.length ? nomes[i] : 'Cliente $i',
          totalDue: 100 + i,
          titleCount: 1,
          oldestAt: '2026-08-01T10:00:00Z',
        ),
    ];
    return DebtorsPage(
      items: items,
      totalDue: items.fold<double>(0, (a, d) => a + d.totalDue.toDouble()),
    );
  }

  Future<void> montar(WidgetTester tester, DebtorsPage page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [debtorsProvider.overrideWith((ref) async => page)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ReceivablesTab(canWrite: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A paginação fica no fim da lista e o `ListView` só constrói o que está no
  /// viewport — sem rolar até lá, o finder não a encontra.
  Future<void> rolarAteFim(WidgetTester tester) async {
    await tester.dragUntilVisible(
      // Pelo TOOLTIP: o ícone `chevron_right` também aparece nos cards de
      // devedor, e o rótulo some no celular. O tooltip é único dos dois jeitos.
      find.byTooltip('Próxima página'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista curta não mostra controle de paginação', (tester) async {
    // Controle de paginação numa página só sugere que há mais coisa escondida.
    await montar(tester, carteira(5));
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('lista longa pagina em 20 e mostra o intervalo', (tester) async {
    await montar(tester, carteira(45));
    // Topo: intervalo e primeiro devedor.
    expect(find.text('1–20 de 45'), findsOneWidget);
    expect(find.text('Cliente 0'), findsOneWidget);
    // O 21º não está na página 1 — nem construído, nem escondido.
    expect(find.text('Cliente 20'), findsNothing);
    // Fim: o controle de página.
    await rolarAteFim(tester);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('avançar a página troca os devedores', (tester) async {
    await montar(tester, carteira(45));
    await rolarAteFim(tester);
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    // Quem estava na página 1 sai; o intervalo acompanha. Confere pelo
    // cabeçalho, que está no topo — os tiles ficam fora do viewport aqui.
    await tester.dragUntilVisible(
      find.text('Quem deve'),
      find.byType(ListView),
      const Offset(0, 300),
    );
    expect(find.text('21–40 de 45'), findsOneWidget);
    expect(find.text('Cliente 0'), findsNothing);
  });

  testWidgets('busca filtra por nome', (tester) async {
    await montar(tester, carteira(3, nomes: ['Maria Souza', 'João Lima', 'Ana Paula']));
    await tester.enterText(find.byType(TextField).first, 'lima');
    await tester.pumpAndSettle();
    expect(find.text('João Lima'), findsOneWidget);
    expect(find.text('Maria Souza'), findsNothing);
    // O total do topo acompanha o filtro: manter a soma geral faria o número
    // não bater com a lista à vista, e alguém ia conferir.
    expect(find.text('de 1 cliente'), findsOneWidget);
  });

  testWidgets('busca ignora acento — "jose" acha "José"', (tester) async {
    // Exigir o acento certo transforma a busca em adivinhação.
    await montar(tester, carteira(2, nomes: ['José da Silva', 'Marcos']));
    await tester.enterText(find.byType(TextField).first, 'jose');
    await tester.pumpAndSettle();
    expect(find.text('José da Silva'), findsOneWidget);
  });

  testWidgets('no celular os botões viram só seta e nada estoura',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844); // iPhone
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await montar(tester, carteira(45));
    await rolarAteFim(tester);
    // "Anterior" + "1 / 3" + "Próxima" por extenso não cabem em 390pt.
    expect(find.text('Anterior'), findsNothing);
    expect(find.text('Próxima'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no desktop os botões têm rótulo por extenso', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await montar(tester, carteira(45));
    await rolarAteFim(tester);
    expect(find.text('Anterior'), findsOneWidget);
    expect(find.text('Próxima'), findsOneWidget);
  });

  testWidgets('busca sem resultado explica, em vez de mostrar lista vazia',
      (tester) async {
    await montar(tester, carteira(3, nomes: ['Maria', 'João', 'Ana']));
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Ninguém encontrado'), findsOneWidget);
  });

  testWidgets('buscar na página 3 não deixa a tela vazia', (tester) async {
    // Filtrar encurta a lista abaixo da página atual: sem clamp, a tela ficava
    // em branco com resultados existindo.
    await montar(tester, carteira(45));
    await rolarAteFim(tester);
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byType(TextField).first,
      find.byType(ListView),
      const Offset(0, 300),
    );
    await tester.enterText(find.byType(TextField).first, 'Cliente 7');
    await tester.pumpAndSettle();
    expect(find.text('Ninguém encontrado'), findsNothing);
    // Confere pelo VALOR, não pelo nome: `find.text` casa também com o
    // EditableText da busca, onde o termo digitado está.
    //
    // DUAS ocorrências, e as duas certas: o card do devedor e o total do topo,
    // que segue o filtro. Um só resultado aqui significaria que o total parou
    // de acompanhar a busca.
    expect(find.text('R\$ 107,00'), findsNWidgets(2));
  });
}
