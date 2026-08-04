import '../../../core/offline/local_first.dart';
import '../domain/expense_installments.dart';
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
  static const _regras = 'expense_recurrence';


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
      if (draft.supplierName != null) 'supplierName': draft.supplierName,
      if (draft.supplierDoc != null) 'supplierDoc': draft.supplierDoc,
      if (!criando && draft.limparFornecedor) 'limparFornecedor': true,
      // Parcelamento só na criação: reparcelar seria apagar as irmãs e recriar
      // outras — destrutivo disfarçado de edição, e o DTO de update não aceita.
      if (criando && draft.parcelas != null) 'parcelas': draft.parcelas,
      if (criando && draft.installmentIds != null)
        'installmentIds': draft.installmentIds,
      if (criando && draft.installmentGroupId != null)
        'installmentGroupId': draft.installmentGroupId,
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
      // As regras também: sem elas, offline a tela não sabe dizer quando é a
      // próxima cobrança de uma conta fixa.
      await putRows(_regras, [for (final r in remoto.recurrences) r.toJson()]);
      return remoto;
    }
    return _mesLocal(ano: ano, mes: mes);
  }

  @override
  Future<ExpenseDetail> detalhe(String id) async {
    // Criada offline e ainda na fila: o servidor não a conhece, daria 404.
    if (!await useLocal(_contas, id)) {
      final remoto = await inner.detalhe(id);
      await putRow(_contas, remoto.expense.toJson());
      if (remoto.recurrence != null) {
        await putRow(_regras, remoto.recurrence!.toJson());
      }
      await putRows(_contas, [for (final p in remoto.parcelas) p.toJson()]);
      return remoto;
    }
    return _detalheLocal(id);
  }

  /// Detalhe montado do espelho: a conta, a regra que a gerou e as irmãs do
  /// grupo de parcelamento. Todas as três já são entidades replicadas, então isto
  /// não precisa de rede.
  Future<ExpenseDetail> _detalheLocal(String id) async {
    final row = await rowById(_contas, id);
    if (row == null) notFoundLocally('Despesa');
    final conta = Expense.fromJson(row);

    ExpenseRecurrence? regra;
    final regraId = conta.recurrenceId;
    if (regraId != null) {
      final r = await rowById(_regras, regraId);
      if (r != null) regra = ExpenseRecurrence.fromJson(r);
    }

    final grupo = conta.installmentGroupId;
    final parcelas = <Expense>[];
    if (grupo != null) {
      for (final r in await rows(_contas)) {
        if (r['installment_group_id'] == grupo) parcelas.add(Expense.fromJson(r));
      }
      parcelas.sort(
        (a, b) => (a.installmentNo ?? 0).compareTo(b.installmentNo ?? 0),
      );
    }
    return ExpenseDetail(expense: conta, recurrence: regra, parcelas: parcelas);
  }

  /// Consulta externa — não tem espelho possível.
  ///
  /// Sem rede, falha com a mensagem do `inner` (o interceptor traduz para "sem
  /// conexão"). O formulário trata como opcional: fornecedor é campo de texto que
  /// a pessoa pode digitar à mão, e travar o cadastro porque a Receita não
  /// respondeu seria péssimo.
  @override
  Future<ExpenseSupplierLookup> consultarCnpj(String cnpj) =>
      inner.consultarCnpj(cnpj);

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
    final regras = [
      for (final r in await rows(_regras)) ExpenseRecurrence.fromJson(r),
    ];
    return totaisDoMes(
      contas: contasDoMes(todas, ano: ano, mes: mes),
      categorias: cats.where((c) => c.status == 'active').toList(),
      regras: regras,
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

    final n = draft.parcelas;
    if (n != null && n >= 2) return _criarParceladoLocal(draft, n);

    final id = newId();
    await enqueue(_contas, 'create', {..._corpo(draft, criando: true), 'id': id});
    await putRow(_contas, _linha(draft, id: id));
    return Expense.fromJson(_linha(draft, id: id));
  }

  /// Linha local de uma conta nova. `due_date` sempre presente: é obrigatório no
  /// modelo, e gravar nulo faria o `fromJson` seguinte estourar.
  Map<String, dynamic> _linha(
    ExpenseDraft draft, {
    required String id,
    num? valor,
    String? vencimento,
    int? parcela,
    int? deParcelas,
    String? grupo,
  }) =>
      <String, dynamic>{
        'id': id,
        'description': draft.description ?? '',
        'amount': valor ?? draft.amount ?? 0,
        'due_date': vencimento ?? draft.dueDate,
        'category_id': draft.categoryId,
        'notes': draft.notes,
        'supplier_name': draft.supplierName,
        'supplier_doc': draft.supplierDoc,
        'installment_no': parcela,
        'installment_total': deParcelas,
        'installment_group_id': grupo,
        'paid_at': null,
        'cash_entry_id': null,
      };

  /// Compra parcelada criada SEM REDE.
  ///
  /// Os ids das N parcelas e o grupo são gerados aqui e viajam no payload: sem
  /// isso o servidor geraria OUTROS ids no replay e o pull seguinte mostraria 12
  /// parcelas de uma compra em 6x. Uma única op na fila cria o grupo inteiro —
  /// meia compra parcelada seria pior que nenhuma.
  ///
  /// O rateio é repetido aqui (o servidor é a autoridade e recalcula no replay)
  /// porque offline não há quem calcular, e mostrar o total inteiro em cada
  /// parcela mentiria sobre o que se deve neste mês. Diferença de arredondamento
  /// se corrige no pull seguinte.
  Future<Expense> _criarParceladoLocal(ExpenseDraft draft, int n) async {
    final grupo = newId();
    final ids = [for (var i = 0; i < n; i++) newId()];
    final valores = ratearParcelas(draft.amount ?? 0, n);
    final datas = datasDasParcelas(DateTime.parse(draft.dueDate!), n);

    await enqueue(_contas, 'create', {
      ..._corpo(
        draft.copyWith(installmentIds: ids, installmentGroupId: grupo),
        criando: true,
      ),
      'id': ids.first,
    });

    Map<String, dynamic>? cabeca;
    for (var i = 0; i < n; i++) {
      final row = _linha(
        draft,
        id: ids[i],
        valor: valores[i],
        vencimento: datas[i].toIso8601String(),
        parcela: i + 1,
        deParcelas: n,
        grupo: grupo,
      );
      await putRow(_contas, row);
      cabeca ??= row;
    }
    return Expense.fromJson(cabeca!);
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
    bool tracksSupplier = false,
  }) async {
    if (isOnline()) {
      final criada = await inner.criarCategoria(
        name: name,
        icon: icon,
        color: color,
        tracksSupplier: tracksSupplier,
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
      'tracksSupplier': tracksSupplier,
    });
    final row = <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'icon': icon ?? 'outros',
      'color': color ?? '#6B7280',
      'tracks_supplier': tracksSupplier,
      'status': 'active',
    };
    await putRow(_categorias, row);
    return ExpenseCategory.fromJson(row);
  }
}
