/// Filtros do "A receber". Valor puro — vira query string online e parâmetros
/// da regra Dart offline (`receivables_filtro.dart`). `page` começa em 1, mesma
/// convenção do backend.
enum VencimentoFiltro { todos, vencidos, vence7, aVencer }

enum OrigemFiltro { todos, os, sale }

enum OrdemDevedores { valor, maisAntigo, nome, vencimento }

extension VencimentoWire on VencimentoFiltro {
  /// Valor que viaja na query string — o mesmo `@IsIn` do DTO do backend.
  String get wire => switch (this) {
        VencimentoFiltro.todos => 'todos',
        VencimentoFiltro.vencidos => 'vencidos',
        VencimentoFiltro.vence7 => 'vence7',
        VencimentoFiltro.aVencer => 'a_vencer',
      };

  String get rotulo => switch (this) {
        VencimentoFiltro.todos => 'Todos',
        VencimentoFiltro.vencidos => 'Vencidos',
        VencimentoFiltro.vence7 => 'Vence em 7 dias',
        VencimentoFiltro.aVencer => 'A vencer',
      };
}

extension OrigemWire on OrigemFiltro {
  String get wire => name; // todos | os | sale

  String get rotulo => switch (this) {
        OrigemFiltro.todos => 'Tudo',
        OrigemFiltro.os => 'OS',
        OrigemFiltro.sale => 'Venda de balcão',
      };
}

extension OrdemWire on OrdemDevedores {
  String get wire => switch (this) {
        OrdemDevedores.valor => 'valor',
        OrdemDevedores.maisAntigo => 'mais_antigo',
        OrdemDevedores.nome => 'nome',
        OrdemDevedores.vencimento => 'vencimento',
      };

  String get rotulo => switch (this) {
        OrdemDevedores.valor => 'Maior valor',
        OrdemDevedores.maisAntigo => 'Mais antigo',
        OrdemDevedores.nome => 'Nome (A–Z)',
        OrdemDevedores.vencimento => 'Vencimento',
      };
}

class DebtorsQuery {
  const DebtorsQuery({
    this.q,
    this.vencimento = VencimentoFiltro.todos,
    this.origem = OrigemFiltro.todos,
    this.sort = OrdemDevedores.valor,
    this.page = 1,
    this.pageSize = 20,
  });

  final String? q;
  final VencimentoFiltro vencimento;
  final OrigemFiltro origem;
  final OrdemDevedores sort;
  final int page;
  final int pageSize;

  /// Há algum filtro que ESCONDE devedor? Ordenação e página não contam: elas
  /// só reorganizam. Serve para a lista vazia dizer a verdade — "os filtros
  /// esconderam" em vez de "ninguém deve".
  bool get temFiltroAtivo =>
      (q ?? '').trim().isNotEmpty ||
      vencimento != VencimentoFiltro.todos ||
      origem != OrigemFiltro.todos;

  static const _sentinel = Object();

  /// `q` com sentinela: `q ?? this.q` faria `null` (limpar a busca) devolver o
  /// texto antigo — o bug que já apareceu nas listas de OS, clientes e estoque.
  DebtorsQuery copyWith({
    Object? q = _sentinel,
    VencimentoFiltro? vencimento,
    OrigemFiltro? origem,
    OrdemDevedores? sort,
    int? page,
    int? pageSize,
  }) =>
      DebtorsQuery(
        q: q == _sentinel ? this.q : q as String?,
        vencimento: vencimento ?? this.vencimento,
        origem: origem ?? this.origem,
        sort: sort ?? this.sort,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );

  /// Só o que difere do padrão do servidor viaja — mantém a URL curta e o
  /// backend com defaults iguais aos do app.
  Map<String, dynamic> toQuery() => {
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
        if (vencimento != VencimentoFiltro.todos) 'vencimento': vencimento.wire,
        if (origem != OrigemFiltro.todos) 'origem': origem.wire,
        if (sort != OrdemDevedores.valor) 'sort': sort.wire,
        'page': page,
        'pageSize': pageSize,
      };
}
