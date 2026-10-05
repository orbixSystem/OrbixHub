import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/report/data/fake_report_repository.dart';
import 'package:orbixhub_front/features/report/presentation/report_providers.dart';
import 'package:orbixhub_front/features/report/presentation/report_tabs.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/visao_tab.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/painel.dart';

/// O painel de abertura de Relatórios.
///
/// A promessa desta tela é ser o APANHADO: um gráfico de cada assunto, para
/// quem não vai abrir as outras sete abas. Os testes protegem as duas metades
/// disso — que nenhum assunto suma da abertura, e que cada card leve à página
/// onde ele é tratado por inteiro. Mais a promessa de toda grade: dois por
/// linha no desktop, um por linha no celular, nada estourando.

Future<void> _montar(WidgetTester t, Size tela) async {
  t.view.physicalSize = tela;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: SingleChildScrollView(child: VisaoTab())),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a abertura traz um gráfico de cada assunto', (t) async {
    await _montar(t, const Size(1400, 4800));

    expect(find.byType(CardDeGrafico), findsNWidgets(9));
    for (final titulo in const [
      'Faturamento dia a dia',     // Faturamento
      'Entrou × saiu no caixa',    // Caixa
      'Acumulado do mês',
      'Para onde foi o dinheiro',  // Despesas
      'Como o cliente pagou',
      'Onde as ordens pararam',    // Ordens
      'Quem fez o trabalho',       // Equipe
      'Clientes que chegaram',     // Clientes
      'O que vai faltar',          // Estoque
    ]) {
      expect(find.text(titulo), findsOneWidget, reason: 'falta "$titulo"');
    }

    // Dois por linha: o primeiro e o segundo card começam na mesma altura e em
    // colunas diferentes. Empilhados, o segundo já saiu da tela quando o olho
    // chega nele — e era isso que a tela antiga fazia.
    final cards = t.widgetList<CardDeGrafico>(find.byType(CardDeGrafico));
    final primeiro = t.getTopLeft(find.byWidget(cards.first));
    final segundo = t.getTopLeft(find.byWidget(cards.elementAt(1)));
    expect(segundo.dy, primeiro.dy);
    expect(segundo.dx, greaterThan(primeiro.dx));
  });

  testWidgets('cada card carrega a explicação de onde vem o número',
      (t) async {
    await _montar(t, const Size(1400, 3600));

    // Sem isso o dono precisa perguntar a alguém o que "Acumulado" soma — e a
    // resposta some junto com a pessoa que sabia.
    final cards = t.widgetList<CardDeGrafico>(find.byType(CardDeGrafico));
    for (final c in cards) {
      expect(c.info, isNotNull, reason: '"${c.titulo}" sem explicação');
      expect(c.subtitulo, isNotNull, reason: '"${c.titulo}" sem subtítulo');
    }
  });

  testWidgets('cada assunto tem o caminho para a sua página', (t) async {
    await _montar(t, const Size(1400, 4800));

    // Sem o atalho, o resumo do estoque é um beco: o dono vê que falta peça e
    // não descobre que existe uma aba inteira sobre isso.
    for (final rotulo in const [
      'Abrir Faturamento',
      'Abrir Caixa',
      'Abrir Despesas',
      'Abrir Ordens',
      'Abrir Equipe',
      'Abrir Clientes',
      'Abrir Estoque',
    ]) {
      expect(find.text(rotulo), findsOneWidget, reason: 'falta "$rotulo"');
    }
  });

  _testesDaAbaInicial();

  testWidgets('o painel inteiro cabe num celular de 360px', (t) async {
    await _montar(t, const Size(360, 6000));

    // Uma coluna só, e nada estourando: nem a legenda da rosca (que precisa
    // ceder espaço ao desenho), nem a fila de ordens (rótulo + barra + conta).
    expect(t.takeException(), isNull);
    expect(find.byType(CardDeGrafico), findsNWidgets(9));
    final cards = t.widgetList<CardDeGrafico>(find.byType(CardDeGrafico));
    final primeiro = t.getTopLeft(find.byWidget(cards.first));
    final segundo = t.getTopLeft(find.byWidget(cards.elementAt(1)));
    expect(segundo.dx, primeiro.dx);
    expect(segundo.dy, greaterThan(primeiro.dy));
  });
}

/// Relatórios SEMPRE abre no relatório escrito do mês.
///
/// É a única página que responde "como foi o mês" em palavras, para quem não
/// vai ler gráfico nenhum. Guardada a última aba visitada, quem voltasse dias
/// depois caía numa tabela de estoque sem entender por quê.
void _testesDaAbaInicial() {
  test('a aba inicial é o relatório escrito do mês', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(selectedTabProvider), ReportTab.resumo);
  });

  test('sair da tela devolve a aba inicial na próxima visita', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // A tela viva: alguém observa, e a escolha do usuário se mantém.
    final assinatura = container.listen(selectedTabProvider, (_, _) {});
    container.read(selectedTabProvider.notifier).select(ReportTab.estoque);
    expect(container.read(selectedTabProvider), ReportTab.estoque);

    // A tela sai de cena. O descarte acontece no tique seguinte do loop, não
    // na mesma linha — por isso o teste espera antes de perguntar.
    assinatura.close();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(selectedTabProvider),
      ReportTab.resumo,
      reason: 'voltar a Relatórios tem de abrir no relatório do mês',
    );
  });
}
