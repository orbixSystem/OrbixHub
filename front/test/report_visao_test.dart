import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/report/data/fake_report_repository.dart';
import 'package:orbixhub_front/features/report/domain/monthly_models.dart';
import 'package:orbixhub_front/features/report/domain/report_repository.dart';
import 'package:orbixhub_front/features/report/presentation/report_providers.dart';
import 'package:orbixhub_front/features/report/presentation/report_tabs.dart';
import 'package:orbixhub_front/features/report/presentation/tabs/visao_tab.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/livro_do_mes.dart';

/// A aba "Visão": a tela que Relatórios abre.
///
/// O que estes testes protegem não é layout, é HONESTIDADE. Um painel que
/// pinta toda alta de verde está comemorando a despesa que subiu, e quem
/// perceber isso uma vez deixa de confiar no resto da tela. E um resumo que
/// não existe (mês corrente) precisa dizer que não existe, senão a leitura
/// óbvia e errada é "a IA não funcionou".

Me _me() => const Me(
      user: User(id: 'u1', email: 'dono@x.dev', fullName: 'Dono'),
      activeTenant: Tenant(id: 't1', slug: 'x', name: 'Oficina X'),
      role: 'owner',
      permissions: ['report.read'],
      modules: ['report', 'os', 'cashier', 'expenses', 'customers', 'inventory'],
    );

/// Fake que permite dizer "este mês ainda não tem resumo".
class _SemResumo extends FakeReportRepository {
  @override
  Future<ResumoMensalPagina> resumoMensal({String? mes}) async =>
      const ResumoMensalPagina(periodos: []);
}

Future<void> _montar(WidgetTester t, {ReportRepository? repo}) async {
  t.view.physicalSize = const Size(1200, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  await t.pumpWidget(ProviderScope(
    overrides: [
      reportRepositoryProvider.overrideWithValue(repo ?? FakeReportRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: SingleChildScrollView(child: VisaoTab()),
      ),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  group('abas disponíveis (regra pura)', () {
    test('a Visão existe sempre que Relatórios existe', () {
      final abas = abasDisponiveis(_me());
      expect(abas.first.tab, ReportTab.visao);
      // Ela não é uma coleção de relatórios — é a leitura do mês.
      expect(abas.first.secoes, isEmpty);
    });

    test('aba sem nenhum relatório disponível não aparece', () {
      // Oficina sem o módulo de clientes não deve ver uma aba "Clientes" vazia
      // explicando que está vazia.
      const semClientes = Me(
        user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
        activeTenant: Tenant(id: 't1', slug: 'x', name: 'X'),
        role: 'owner',
        permissions: ['report.read'],
        modules: ['report', 'os'],
      );
      final abas = abasDisponiveis(semClientes).map((a) => a.tab);
      expect(abas, isNot(contains(ReportTab.clientes)));
      expect(abas, isNot(contains(ReportTab.estoque)));
      // As de OS continuam, porque o módulo está no plano.
      expect(abas, contains(ReportTab.ordens));
      expect(abas, contains(ReportTab.faturamento));
    });

    test('sem o módulo report, nenhuma aba — nem a Visão', () {
      const semReport = Me(
        user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
        activeTenant: Tenant(id: 't1', slug: 'x', name: 'X'),
        role: 'owner',
        permissions: ['report.read'],
        modules: ['os'],
      );
      expect(abasDisponiveis(semReport), isEmpty);
    });

    test('sem report.read, nenhuma aba', () {
      const mecanico = Me(
        user: User(id: 'u2', email: 'm@b.c', fullName: 'Mecânico'),
        activeTenant: Tenant(id: 't1', slug: 'x', name: 'X'),
        role: 'mechanic',
        permissions: ['os.read'],
        modules: ['report', 'os'],
      );
      expect(abasDisponiveis(mecanico), isEmpty);
    });

    test('cada aba tem um assunto só — páginas curtas', () {
      // Três abas com oito relatórios empilhados faziam a página de "Dinheiro"
      // rolar por três tabelas inteiras. Assunto por assunto, a página termina
      // na altura da tela.
      final abas = abasDisponiveis(_me());
      for (final a in abas) {
        expect(a.secoes.length, lessThanOrEqualTo(2),
            reason: 'a aba ${a.label} empilha ${a.secoes.length} relatórios');
      }
    });

    test('cada relatório mora em UMA aba só', () {
      final abas = abasDisponiveis(_me());
      final todas = abas.expand((a) => a.secoes).toList();
      expect(todas.length, todas.toSet().length,
          reason: 'relatório em duas abas viraria dois lugares para a mesma '
              'resposta');
    });
  });

  group('a variação segue o NEGÓCIO, não a direção', () {
    testWidgets('faturamento, despesa e fiado sobem — só um é boa notícia',
        (t) async {
      await _montar(t);

      final livro = t.widget<LivroDoMes>(find.byType(LivroDoMes));
      final porChave = {for (final k in livro.kpis) k.chave: k};

      expect(porChave['faturado']!.variacao!.pct, greaterThan(0));
      expect(porChave['despesas']!.variacao!.pct, greaterThan(0));
      expect(porChave['aReceber']!.variacao!.pct, greaterThan(0));

      // Pintar toda alta de verde faria a tela comemorar o que o dono precisa
      // cortar.
      expect(porChave['faturado']!.variacaoEhBoa, isTrue);
      expect(porChave['despesas']!.variacaoEhBoa, isFalse);
      expect(porChave['aReceber']!.variacaoEhBoa, isFalse);
    });

    test('queda de despesa é boa notícia', () {
      const k = KpiMensal(
        chave: 'despesas',
        valor: 100,
        maiorEhMelhor: false,
        variacao: VariacaoMensal(anterior: 200, pct: -50),
      );
      expect(k.variacaoEhBoa, isTrue);
    });

    test('sem variação não há cor nem seta a decidir', () {
      const k = KpiMensal(chave: 'faturado', valor: 100);
      expect(k.variacaoEhBoa, isNull);
    });

    test('variação zero não é nem boa nem ruim', () {
      const k = KpiMensal(
        chave: 'faturado',
        valor: 100,
        variacao: VariacaoMensal(anterior: 100, pct: 0),
      );
      expect(k.variacaoEhBoa, isNull);
    });
  });

  group('a tela', () {
    testWidgets('abre com o texto do mês, não com uma lista de gráficos',
        (t) async {
      await _montar(t);

      expect(
        find.textContaining('Setembro fechou 12% acima de agosto'),
        findsOneWidget,
      );
      // E as ações concretas — é o que separa relatório de enfeite.
      expect(find.text('Para este mês'), findsOneWidget);
      expect(find.textContaining('Combine prazo de pagamento'), findsOneWidget);
    });

    testWidgets('assina quem escreveu, no pé da página', (t) async {
      await _montar(t);
      // Creditar à IA um texto que ela não escreveu seria mentir sobre o
      // produto — e um dia alguém compara dois meses e percebe.
      expect(
        find.textContaining('Escrito por inteligência artificial'),
        findsOneWidget,
      );
      // E deixa claro de onde vieram os valores.
      expect(find.textContaining('Nenhum valor vem do modelo'), findsOneWidget);
    });

    testWidgets('sem IA, o sistema assina o próprio texto', (t) async {
      await _montar(t, repo: _ResumoSemIa());
      expect(
        find.textContaining('Escrito pelo próprio sistema'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Escrito por inteligência artificial'),
        findsNothing,
      );
    });

    testWidgets('mês sem resumo explica a ausência em vez de ficar vazio',
        (t) async {
      await _montar(t, repo: _SemResumo());

      expect(find.text('O mês ainda está em andamento'), findsOneWidget);
      // E os números continuam lá: eles não dependem de nada externo.
      expect(find.byType(LivroDoMes), findsOneWidget);
    });

    testWidgets('mostra os sinais mesmo sem resumo escrito', (t) async {
      await _montar(t, repo: _SemResumo());
      // O dono não deveria esperar o dia 1º para descobrir que o fiado dobrou.
      expect(find.textContaining('merecem atenção'), findsOneWidget);
      expect(
        find.text('O fiado cresceu mais que o faturamento'),
        findsOneWidget,
      );
    });

    testWidgets('falha ao buscar o texto não esconde os números', (t) async {
      await _montar(t, repo: _ResumoQueFalha());

      expect(find.byType(LivroDoMes), findsOneWidget);
      expect(find.textContaining('Setembro fechou'), findsNothing);
    });
  });
}

class _ResumoSemIa extends FakeReportRepository {
  @override
  Future<ResumoMensalPagina> resumoMensal({String? mes}) async {
    final base = await super.resumoMensal(mes: mes);
    return base.copyWith(
      resumo: base.resumo!.copyWith(
        aiStatus: 'fallback',
        aiModel: 'resumo-automatico',
      ),
    );
  }
}

class _ResumoQueFalha extends FakeReportRepository {
  @override
  Future<ResumoMensalPagina> resumoMensal({String? mes}) async =>
      throw Exception('servidor fora');
}
