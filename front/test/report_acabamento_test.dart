import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/report/data/fake_report_repository.dart';
import 'package:orbixhub_front/features/report/presentation/report_providers.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/resumo_tab.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/visao_tab.dart';
import 'package:orbixhub_front/features/report/domain/monthly_models.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/livro_do_mes.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/motion.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/sparkline.dart';

/// O acabamento da tela — os detalhes que somem no primeiro refactor de quem
/// não sabe por que estão lá.
///
/// Nenhum deles é decoração: algarismo de largura variável desalinha uma coluna
/// de dinheiro, fio em pixel lógico engorda numa tela densa, e animação que
/// ignora a preferência de movimento reduzido é um problema de acessibilidade,
/// não de gosto.

Future<void> _montar(
  WidgetTester t, {
  bool movimentoReduzido = false,
}) async {
  t.view.physicalSize = const Size(1200, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await t.pumpWidget(ProviderScope(
    overrides: [
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(1200, 2600),
        disableAnimations: movimentoReduzido,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: VisaoTab())),
      ),
    ),
  ));
  await t.pumpAndSettle();
}

/// O valor de abertura, procurado DENTRO do livro.
///
/// O mesmo número aparece também como total do gráfico — a série do mês soma
/// exatamente o faturamento, como tem de somar. Procurar na tela inteira
/// acharia os dois.
Finder _valorDeAbertura(String texto) => find.descendant(
      of: find.byType(LivroDoMes),
      matching: find.text(texto),
    );

/// Todos os estilos de texto renderizados na tela.
List<TextStyle> _estilos(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.style)
    .whereType<TextStyle>()
    .toList();

void main() {
  testWidgets('os valores de dinheiro usam algarismo de largura fixa',
      (t) async {
    await _montar(t);

    final comTabular = _estilos(t).where(
      (s) => s.fontFeatures?.any((f) => f.feature == 'tnum') ?? false,
    );
    // Sem isto, a coluna do livro-caixa deixa de alinhar na vírgula — que é a
    // única razão de existir uma coluna — e o número que conta na abertura
    // muda de largura a cada quadro.
    expect(comTabular, isNotEmpty);
  });

  testWidgets('com movimento reduzido, nada anima — e nada falta', (t) async {
    await _montar(t, movimentoReduzido: true);

    // Os widgets de animação continuam na árvore (eles é que decidem), mas
    // nenhuma transição fica pendente: a tela já está no estado final.
    expect(t.binding.hasScheduledFrame, isFalse);
    // E o conteúdo todo está lá — movimento reduzido não é versão pobre.
    expect(find.byType(Sparkline), findsOneWidget);
    expect(_valorDeAbertura('R\$ 48.200,00'), findsOneWidget);
  });

  testWidgets('o número de abertura conta até o valor e PARA no valor certo',
      (t) async {
    t.view.physicalSize = const Size(1200, 2600);
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
    // Deixa os dados chegarem, mas segura a animação no meio do caminho.
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(_valorDeAbertura('R\$ 48.200,00'), findsNothing,
        reason: 'no meio da contagem o valor final ainda não apareceu');

    await t.pumpAndSettle();
    expect(_valorDeAbertura('R\$ 48.200,00'), findsOneWidget,
        reason: 'uma contagem que erra o destino é pior que nenhuma');
  });

  testWidgets('a espera diz o que está acontecendo', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      overrides: [
        reportRepositoryProvider.overrideWithValue(_RepoLento()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: VisaoTab())),
      ),
    ));
    await t.pump();

    // "Carregando" não diz nada; o sistema está somando o mês em cinco módulos.
    expect(find.text('Fechando as contas do mês'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('o sinal mostra o número que o sustenta', (t) async {
    await _montar(t);

    // Sem a evidência, o alerta é uma opinião; com ela, o dono sabe o tamanho
    // do problema sem abrir outra tela.
    expect(
      find.text('Fiado 310% contra 12.1% do faturamento'),
      findsOneWidget,
    );
    expect(
      find.text('Despesas 29.9% contra 12.1% do faturamento'),
      findsOneWidget,
    );
  });

  testWidgets('nenhuma tarja em caixa alta espaçada na tela', (t) async {
    await _montar(t);

    // O rótulo tracked-out em CAIXA ALTA acima de cada título é a assinatura
    // de página gerada. Se alguém reintroduzir um, este teste avisa.
    for (final texto in t.widgetList<Text>(find.byType(Text))) {
      final conteudo = texto.data ?? '';
      if (conteudo.length < 6) continue;
      final ehCaixaAlta = conteudo == conteudo.toUpperCase() &&
          conteudo.contains(RegExp('[A-ZÀ-Ü]'));
      final espacada = (texto.style?.letterSpacing ?? 0) > 0.5;
      expect(ehCaixaAlta && espacada, isFalse,
          reason: 'tarja em caixa alta espaçada: "$conteudo"');
    }
  });

  testWidgets('o livro cabe num celular estreito, sem estourar', (t) async {
    // 360px é o chão real do parque de aparelhos. A coluna da variação tem
    // largura fixa para o dinheiro continuar alinhado — e largura fixa é a
    // origem clássica de estouro quando a tela encolhe.
    t.view.physicalSize = const Size(360, 2600);
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

    // `takeException` devolve o erro que o framework registrou — é assim que
    // um overflow aparece num teste. (Minha primeira versão deste teste
    // instalava e restaurava o handler de erro na mesma linha e devolvia
    // sempre uma lista vazia: passava verde com a tela estourando.)
    expect(t.takeException(), isNull,
        reason: 'nenhum overflow pode sobrar num celular de 360px');
    expect(find.byType(LivroDoMes), findsOneWidget);
    // E o valor continua legível, não espremido a zero pelo FittedBox.
    expect(_valorDeAbertura('R\$ 48.200,00'), findsOneWidget);
  });

  testWidgets('o relatório escrito cabe num celular de 360px', (t) async {
    // A página mais densa de texto do módulo: manchete em corpo grande, grade
    // de números, duas colunas de balanço e trilhos coloridos. É onde um
    // layout quebra primeiro quando a tela encolhe.
    t.view.physicalSize = const Size(360, 5200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      overrides: [
        reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: ResumoTab())),
      ),
    ));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull,
        reason: 'nenhum overflow pode sobrar num celular de 360px');
    expect(find.textContaining('Setembro fechou'), findsOneWidget);
    expect(find.text('O que foi bem'), findsOneWidget);
  });

  test('a abertura dura menos de um segundo', () {
    // Animação de entrada que passa de ~800ms deixa de ser acabamento e vira
    // espera — e esta roda toda vez que alguém abre Relatórios.
    expect(kAberturaLonga.inMilliseconds, lessThanOrEqualTo(900));
    expect(kAberturaCurta.inMilliseconds, lessThan(kAberturaLonga.inMilliseconds));
  });
}


/// Fake que demora — é o único jeito de ver o estado de espera.
class _RepoLento extends FakeReportRepository {
  @override
  Future<VisaoMensal> overview({String? mes}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return super.overview(mes: mes);
  }
}
