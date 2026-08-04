import '../../../core/offline/local_first.dart';
import '../domain/expense_models.dart';
import '../domain/expense_month_totals.dart';
import '../domain/expenses_repository.dart';

/// [ExpensesRepository] offline-first — decorator sobre a impl real (dio).
///
/// Era a ÚNICA feature do app fora da camada offline: sem rede a tela de contas a
/// pagar não degradava, falhava. E contas a pagar é justamente o que se consulta
/// no balcão, no celular, com rede ruim.
///
/// Entidades espelhadas: `expense`, `expense_category`, `expense_recurrence` — as
/// mesmas que o backend já expõe no pull (o módulo veio da `qa` com o lado
/// servidor pronto; faltava só este decorator).
///
/// **Os totais do mês são derivados localmente** ([totaisDoMes]). Online quem soma
/// é o servidor, que vê o mês inteiro; offline não há quem somar, e mostrar zero
/// seria pior que mostrar a conta feita com o que temos.
class LocalFirstExpensesRepository extends LocalFirstBase
    implements ExpensesRepository {
  LocalFirstExpensesRepository({
    required this.inner,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final ExpensesRepository inner;

  static const _contas = 'expense';
  static const _categorias = 'expense_category';


  /// Corpo que o backend aceita, a partir do draft.
  ///
  /// **Não é `draft.toJson()`.** O freezed emite TODAS as chaves (inclusive nulas)
  /// e ainda inclui `limparCategoria`, que é controle de UI e não campo do DTO. O
  /// push revalida o payload do outbox contra o DTO do módulo dono com
  /// `forbidNonWhitelisted`, então chave a mais = mutação REJEITADA no replay, e
  /// nula em campo obrigatório = 400. Espelha o corpo da impl dio, que é a
  /// definição do que funciona.
  Map<String, dynamic> _corpo(ExpenseDraft draft, {required bool criando}) {
    final r = draft.recorrencia;
    return <String, dynamic>{
      if (draft.description != null) 'description': draft.description,
      if (draft.dueDate != null) 'dueDate': draft.dueDate,
      if (draft.amount != null) 'amount': draft.amount,
      // Limpar categoria é `null` EXPLÍCITO; ausência é "não mexe".
      if (draft.limparCategoria)
        'categoryId': null
      else if (draft.categoryId != null)
        'categoryId': draft.categoryId,
      if (draft.notes != null) 'notes': draft.notes,
      // Recorrência só na criação — é o que o DTO de update aceita.
      if (criando && r != null)
        'recorrencia': <String, dynamic>{
          'frequency': r.frequency,
          // `dayOfMonth` tem default no draft (1) — sempre presente.
          'dayOfMonth': r.dayOfMonth,
          if (r.monthOfYear != null) 'monthOfYear': r.monthOfYear,
          if (r.endsOn != null) 'endsOn': r.endsOn,
        },
    };
  }

  @override
  Future<ExpensesMonth> listarMes({required int ano, required int mes}) async {
    if (isOnline()) {
      final remoto = await inner.listarMes(ano: ano, mes: mes);
      // Espelha para o mês voltar a abrir offline. Os totais NÃO são espelhados:
      // são derivados na leitura local, senão ficariam velhos assim que uma baixa
      // fosse dada sem rede.
      await putRows(_contas, [for (final e in remoto.items) e.toJson()]);
      await putRows(
        _categorias,
        [for (final c in remoto.categories) c.toJson()],
      );
      return remoto;
    }
    return _mesLocal(ano: ano, mes: mes);
  }

  /// Monta o mês a partir do espelho local.
  Future<ExpensesMonth> _mesLocal({
    required int ano,
    required int mes,
  }) async {
    final todas = [
      for (final r in await rows(_contas)) Expense.fromJson(r),
    ];
    final cats = [
      for (final r in await rows(_categorias)) ExpenseCategory.fromJson(r),
    ];
    return totaisDoMes(
      contas: contasDoMes(todas, ano: ano, mes: mes),
      categorias: cats.where((c) => c.status == 'active').toList(),
      // `clock` (relógio confiável, anti clock-rollback) e não `DateTime.now()`:
      // o que decide "vencido" não pode depender de o usuário mexer no relógio.
      hoje: clock.now,
    );
  }

  @override
  Future<List<ExpenseCategory>> categorias() async {
    if (isOnline()) {
      final remotas = await inner.categorias();
      await putRows(_categorias, [for (final c in remotas) c.toJson()]);
      return remotas;
    }
    final locais = [
      for (final r in await rows(_categorias)) ExpenseCategory.fromJson(r),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return locais.where((c) => c.status == 'active').toList(growable: false);
  }

  @override
  Future<Expense> criar(ExpenseDraft draft) async {
    if (isOnline()) {
      final criada = await inner.criar(draft);
      await putRow(_contas, criada.toJson());
      return criada;
    }
    final id = newId();
    await enqueue(_contas, 'create', {..._corpo(draft, criando: true), 'id': id});
    final row = <String, dynamic>{
      'id': id,
      'description': draft.description ?? '',
      'amount': draft.amount ?? 0,
      'due_date': draft.dueDate,
      'category_id': draft.categoryId,
      'notes': draft.notes,
      'paid_at': null,
      'cash_entry_id': null,
    };
    await putRow(_contas, row);
    return Expense.fromJson(row);
  }

  @override
  Future<Expense> editar(String id, ExpenseDraft draft) async {
    // Criada offline e ainda na fila: editar no servidor daria 404.
    if (!await useLocal(_contas, id)) {
      final atualizada = await inner.editar(id, draft);
      await putRow(_contas, atualizada.toJson());
      return atualizada;
    }
    final row = await rowById(_contas, id);
    if (row == null) notFoundLocally('Despesa');
    await enqueue(_contas, 'update', {..._corpo(draft, criando: false), 'id': id});
    // `!= null`, NÃO `containsKey`: o `toJson()` do freezed emite TODAS as chaves,
    // inclusive as nulas. Com `containsKey`, editar só o valor gravava
    // `due_date: null` — e `dueDate` é obrigatório, então o `fromJson` seguinte
    // estourava "type 'Null' is not a subtype of type 'String'".
    //
    // É também o motivo de `limparCategoria` existir: com ausência significando
    // "não mexe", limpar uma categoria já gravada seria impossível de expressar.
    final novo = <String, dynamic>{
      ...row,
      if (draft.description != null) 'description': draft.description,
      if (draft.amount != null) 'amount': draft.amount,
      if (draft.dueDate != null) 'due_date': draft.dueDate,
      if (draft.limparCategoria)
        'category_id': null
      else if (draft.categoryId != null)
        'category_id': draft.categoryId,
      if (draft.notes != null) 'notes': draft.notes,
    };
    await putRow(_contas, novo);
    return Expense.fromJson(novo);
  }

  @override
  Future<Expense> marcarPaga(
    String id, {
    num? valor,
    String? forma,
    DateTime? quando,
  }) async {
    if (!await useLocal(_contas, id)) {
      final paga = await inner.marcarPaga(
        id,
        valor: valor,
        forma: forma,
        quando: quando,
      );
      await putRow(_contas, paga.toJson());
      return paga;
    }
    final row = await rowById(_contas, id);
    if (row == null) notFoundLocally('Despesa');
    final pagoEm = (quando ?? clock.now).toUtc().toIso8601String();
    // Nomes de campo do `PayExpenseDto` (amount/method/paidAt) — os MESMOS que a
    // impl dio usa. Eu havia inventado `valor`/`forma`/`quando` aqui, e o push
    // voltava "property valor should not exist": o payload do outbox é revalidado
    // contra o DTO do módulo dono, então nome errado = mutação perdida no replay.
    await enqueue(_contas, 'pay', {
      'id': id,
      'amount': ?valor,
      'method': ?forma,
      'paidAt': pagoEm,
    });
    // NÃO criamos o `cash_entry` no espelho local, mesmo sendo tentador para o
    // caixa "já mostrar" a saída. Quem cria o lançamento é o servidor, no replay
    // (`cashier.registrarSaidaDeDespesa`); inventar um aqui geraria DOIS — o
    // local e o do replay — e o livro caixa passaria a mentir. O lançamento
    // aparece no próximo pull.
    final novo = <String, dynamic>{
      ...row,
      'paid_at': pagoEm,
      'paid_amount': valor ?? row['amount'],
      'paid_method': forma,
    };
    await putRow(_contas, novo);
    return Expense.fromJson(novo);
  }

  @override
  Future<Expense> desmarcarPaga(String id) async {
    if (!await useLocal(_contas, id)) {
      final aberta = await inner.desmarcarPaga(id);
      await putRow(_contas, aberta.toJson());
      return aberta;
    }
    final row = await rowById(_contas, id);
    if (row == null) notFoundLocally('Despesa');
    await enqueue(_contas, 'unpay', {'id': id});
    // Mesma razão do `marcarPaga`: o ESTORNO no caixa é do servidor. Aqui só
    // devolvemos a conta para "em aberto".
    final novo = <String, dynamic>{
      ...row,
      'paid_at': null,
      'paid_amount': null,
      'paid_method': null,
      'cash_entry_id': null,
    };
    await putRow(_contas, novo);
    return Expense.fromJson(novo);
  }

  @override
  Future<void> cancelar(String id) async {
    if (!await useLocal(_contas, id)) {
      await inner.cancelar(id);
      await removeRow(_contas, id);
      return;
    }
    if (await rowById(_contas, id) == null) notFoundLocally('Despesa');
    await enqueue(_contas, 'cancel', {'id': id});
    // Sai da lista local de imediato: o usuário mandou excluir, e manter a linha
    // até o sync pareceria que o toque não funcionou.
    await removeRow(_contas, id);
  }

  @override
  Future<ExpenseCategory> criarCategoria({
    required String name,
    String? icon,
    String? color,
  }) async {
    if (isOnline()) {
      final criada = await inner.criarCategoria(
        name: name,
        icon: icon,
        color: color,
      );
      await putRow(_categorias, criada.toJson());
      return criada;
    }
    final id = newId();
    await enqueue(_categorias, 'create', {
      'id': id,
      'name': name.trim(),
      'icon': ?icon,
      'color': ?color,
    });
    final row = <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'icon': icon ?? 'outros',
      'color': color ?? '#6B7280',
      'status': 'active',
    };
    await putRow(_categorias, row);
    return ExpenseCategory.fromJson(row);
  }
}
