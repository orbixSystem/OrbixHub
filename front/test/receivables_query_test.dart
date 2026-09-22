import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_query.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';

/// A query do "A receber" — o que viaja para o servidor e como ela muda.
///
/// Duas classes de bug moram aqui, e as duas são silenciosas:
///  1. um `wire` divergente do `@IsIn` do backend vira 400 só em produção (o
///     teste de widget usa o fake e não percebe);
///  2. trocar um filtro sem voltar para a página 1 deixa a tela vazia com
///     resultados existindo — parece "não tem ninguém devendo".
void main() {
  group('contrato com o servidor (espelho do @IsIn do DTO)', () {
    // Se algum destes mudar, o DTO precisa mudar junto — e há um teste no
    // backend (`list-debtors.dto.spec.ts`) escrito com a mesma lista explícita.
    test('vencimento', () {
      expect(
        VencimentoFiltro.values.map((v) => v.wire).toList(),
        ['todos', 'vencidos', 'vence7', 'a_vencer', 'sem_prazo'],
      );
    });

    test('origem', () {
      expect(
        OrigemFiltro.values.map((v) => v.wire).toList(),
        ['todos', 'os', 'sale'],
      );
    });

    test('ordenação', () {
      expect(
        OrdemDevedores.values.map((v) => v.wire).toList(),
        ['valor', 'mais_antigo', 'nome', 'vencimento'],
      );
    });

    test('todo filtro tem rótulo em português, sem chave crua vazando', () {
      for (final v in VencimentoFiltro.values) {
        expect(v.rotulo, isNotEmpty);
        expect(v.rotulo, isNot(contains('_')));
      }
      for (final o in OrigemFiltro.values) {
        expect(o.rotulo, isNotEmpty);
      }
      for (final s in OrdemDevedores.values) {
        expect(s.rotulo, isNotEmpty);
      }
    });
  });

  group('toQuery — só viaja o que difere do padrão', () {
    test('query padrão manda apenas a paginação', () {
      expect(const DebtorsQuery().toQuery(), {'page': 1, 'pageSize': 20});
    });

    test('filtros não-padrão viajam pelo wire', () {
      final q = const DebtorsQuery(
        q: 'jose',
        vencimento: VencimentoFiltro.semPrazo,
        origem: OrigemFiltro.os,
        sort: OrdemDevedores.maisAntigo,
        page: 3,
        pageSize: 50,
      ).toQuery();
      expect(q, {
        'q': 'jose',
        'vencimento': 'sem_prazo',
        'origem': 'os',
        'sort': 'mais_antigo',
        'page': 3,
        'pageSize': 50,
      });
    });

    test('busca em branco não vira parâmetro', () {
      expect(const DebtorsQuery(q: '   ').toQuery().containsKey('q'), isFalse);
      expect(const DebtorsQuery(q: '').toQuery().containsKey('q'), isFalse);
    });

    test('busca viaja aparada (o servidor recebe o termo, não os espaços)', () {
      expect(const DebtorsQuery(q: '  jose  ').toQuery()['q'], 'jose');
    });
  });

  group('copyWith', () {
    test('limpar a busca REALMENTE limpa (sentinela, não `?? this.q`)', () {
      // O bug clássico: com `q ?? this.q`, passar null devolveria o texto
      // antigo e a busca ficaria presa — já aconteceu nas listas de OS,
      // clientes e estoque.
      const comBusca = DebtorsQuery(q: 'jose');
      expect(comBusca.copyWith(q: null).q, isNull);
    });

    test('não passar `q` preserva a busca atual', () {
      const comBusca = DebtorsQuery(q: 'jose');
      expect(comBusca.copyWith(page: 2).q, 'jose');
    });
  });

  group('temFiltroAtivo — decide se o vazio diz "ninguém deve" ou "os filtros escondem"', () {
    test('padrão não tem filtro', () {
      expect(const DebtorsQuery().temFiltroAtivo, isFalse);
    });

    test('ordenação e página NÃO contam (só reorganizam)', () {
      expect(
        const DebtorsQuery(sort: OrdemDevedores.nome, page: 5).temFiltroAtivo,
        isFalse,
      );
    });

    test('busca, vencimento e origem contam', () {
      expect(const DebtorsQuery(q: 'a').temFiltroAtivo, isTrue);
      expect(
        const DebtorsQuery(vencimento: VencimentoFiltro.vencidos).temFiltroAtivo,
        isTrue,
      );
      expect(const DebtorsQuery(origem: OrigemFiltro.os).temFiltroAtivo, isTrue);
    });

    test('busca só de espaços não conta como filtro', () {
      expect(const DebtorsQuery(q: '  ').temFiltroAtivo, isFalse);
    });
  });

  group('DebtorsQueryNotifier', () {
    /// O notifier usa Timer (debounce), então o relógio precisa ser o do teste.
    Future<void> comNotifier(
      WidgetTester tester,
      Future<void> Function(DebtorsQueryNotifier n, DebtorsQuery Function() q)
          corpo,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // `keepAlive` impede o autoDispose de descartar o estado entre leituras.
      final sub = container.listen(debtorsQueryProvider, (_, _) {});
      addTearDown(sub.close);
      await corpo(
        container.read(debtorsQueryProvider.notifier),
        () => container.read(debtorsQueryProvider),
      );
    }

    testWidgets('a busca espera o operador parar de digitar', (tester) async {
      await comNotifier(tester, (n, q) async {
        n.setQuery('j');
        n.setQuery('jo');
        n.setQuery('jose');
        // Antes do debounce, nada foi publicado: uma requisição por tecla
        // derrubaria o servidor e piscaria a lista.
        expect(q().q, isNull);

        await tester.pump(const Duration(milliseconds: 400));
        expect(q().q, 'jose');
      });
    });

    testWidgets('busca nova volta para a primeira página', (tester) async {
      await comNotifier(tester, (n, q) async {
        n.goToPage(4);
        n.setQuery('jose');
        await tester.pump(const Duration(milliseconds: 400));
        // Sem isto, a página 4 do resultado antigo pode nem existir no novo —
        // e a tela fica vazia com resultados existindo.
        expect(q().page, 1);
      });
    });

    testWidgets('limpar a busca publica null (não o texto anterior)',
        (tester) async {
      await comNotifier(tester, (n, q) async {
        n.setQuery('jose');
        await tester.pump(const Duration(milliseconds: 400));
        n.setQuery('');
        await tester.pump(const Duration(milliseconds: 400));
        expect(q().q, isNull);
      });
    });

    testWidgets('trocar filtro ou ordem reseta a página', (tester) async {
      await comNotifier(tester, (n, q) async {
        n.goToPage(3);
        n.setVencimento(VencimentoFiltro.vencidos);
        expect(q().page, 1);

        n.goToPage(3);
        n.setOrigem(OrigemFiltro.os);
        expect(q().page, 1);

        n.goToPage(3);
        n.setSort(OrdemDevedores.nome);
        expect(q().page, 1);
      });
    });

    testWidgets('goToPage nunca vai abaixo da primeira página', (tester) async {
      await comNotifier(tester, (n, q) async {
        n.goToPage(0);
        expect(q().page, 1);
        n.goToPage(-5);
        expect(q().page, 1);
      });
    });

    testWidgets('limpar filtros preserva a ORDEM escolhida', (tester) async {
      await comNotifier(tester, (n, q) async {
        n.setSort(OrdemDevedores.nome);
        n.setVencimento(VencimentoFiltro.vencidos);
        n.setOrigem(OrigemFiltro.os);
        n.setQuery('jose');
        await tester.pump(const Duration(milliseconds: 400));

        n.clearFilters();
        // Some o que ESCONDE; a ordenação é preferência de leitura, não filtro.
        expect(q().q, isNull);
        expect(q().vencimento, VencimentoFiltro.todos);
        expect(q().origem, OrigemFiltro.todos);
        expect(q().sort, OrdemDevedores.nome);
        expect(q().page, 1);
      });
    });

    testWidgets('digitar e apagar antes do debounce não publica nada',
        (tester) async {
      await comNotifier(tester, (n, q) async {
        n.setQuery('jose');
        n.setQuery('');
        await tester.pump(const Duration(milliseconds: 400));
        expect(q().q, isNull);
      });
    });
  });
}
