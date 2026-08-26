import '../../../core/error/app_exception.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../domain/cashier_repository.dart';

/// Fake in-memory do Caixa — para dev/teste (não é persistência offline).
/// Reproduz as regras essenciais: 1 sessão aberta, direção derivada da categoria,
/// estorno lógico fora dos somatórios, esperado só-dinheiro. Não modela o
/// `deviceId` por ponto de caixa (esse detalhe é do transporte dio, ver
/// [CashierRepositoryImpl]) — a interface não expõe deviceId por chamada, então
/// o fake se comporta como um único ponto de caixa, o que é suficiente p/ dev/teste.
class FakeCashierRepository implements CashierRepository {
  CashierConfig _config = const CashierConfig();
  CashSession? _open;

  /// Sessões já fechadas, mais recente primeiro (o backend ordena por
  /// `opened_at desc`). Alimenta o histórico e a sugestão de abertura.
  final List<CashSession> _closed = [];
  final List<CashEntry> _entries = [];
  int _seq = 0;

  String _id(String prefix) => '$prefix-${++_seq}';

  List<CashEntry> get _liveOfOpen => _entries
      .where((e) => e.reversedAt == null && _open != null)
      .toList(growable: false);

  List<MethodTotal> _byMethod(Iterable<CashEntry> entries) {
    final map = <String, MethodTotal>{};
    for (final e in entries) {
      final cur = map[e.method] ??
          MethodTotal(method: e.method, inAmount: 0, outAmount: 0);
      final amt = moneyToDouble(e.amount);
      map[e.method] = e.direction == 'in'
          ? cur.copyWith(inAmount: cur.inAmount + amt)
          : cur.copyWith(outAmount: cur.outAmount + amt);
    }
    return map.values.toList(growable: false);
  }

  CashSession _withTotals(CashSession s) {
    final live = _liveOfOpen;
    final byMethod = _byMethod(live);
    final cashIn = live
        .where((e) => e.method == 'dinheiro' && e.direction == 'in')
        .fold<double>(0, (a, e) => a + moneyToDouble(e.amount));
    final cashOut = live
        .where((e) => e.method == 'dinheiro' && e.direction == 'out')
        .fold<double>(0, (a, e) => a + moneyToDouble(e.amount));
    final totalIn =
        live.where((e) => e.direction == 'in').fold<double>(0, (a, e) => a + moneyToDouble(e.amount));
    final totalOut =
        live.where((e) => e.direction == 'out').fold<double>(0, (a, e) => a + moneyToDouble(e.amount));
    final opening = moneyToDouble(s.openingAmount);
    final expected = _config.countCashOnly
        ? opening + cashIn - cashOut
        : opening + totalIn - totalOut;
    return s.copyWith(
      byMethod: byMethod,
      totals: SessionTotals(inTotal: totalIn, outTotal: totalOut, expected: expected),
    );
  }

  @override
  Future<CashierConfig> fetchConfig() async => _config;

  @override
  Future<CashierConfig> updateConfig({
    List<String>? paymentMethods,
    bool? requireOpenSession,
    bool? countCashOnly,
  }) async {
    _config = _config.copyWith(
      paymentMethods: paymentMethods ?? _config.paymentMethods,
      requireOpenSession: requireOpenSession ?? _config.requireOpenSession,
      countCashOnly: countCashOnly ?? _config.countCashOnly,
    );
    return _config;
  }

  @override
  Future<CashSession?> currentSession() async =>
      _open == null ? null : _withTotals(_open!);

  @override
  Future<CashSession> openSession({double? openingAmount, String? notes}) async {
    if (_open != null) {
      throw Exception('Já existe um caixa aberto.');
    }
    _open = CashSession(
      id: _id('sess'),
      status: 'open',
      openingAmount: (openingAmount ?? 0).toStringAsFixed(2),
      notes: notes,
    );
    return _withTotals(_open!);
  }

  @override
  Future<CashSession> closeSession({
    required double countedAmount,
    String? notes,
  }) async {
    final s = _withTotals(_open!);
    final expected = s.totals?.expected ?? 0;
    final closed = _open!.copyWith(
      status: 'closed',
      closingAmountCounted: countedAmount.toStringAsFixed(2),
      closingAmountExpected: expected.toStringAsFixed(2),
      difference: (countedAmount - expected).toStringAsFixed(2),
      byMethod: s.byMethod,
    );
    // Guarda no topo (mais recente primeiro, como o backend ordena) — é o que
    // alimenta o histórico e a sugestão de abertura da sessão seguinte.
    _closed.insert(0, closed);
    _open = null;
    return closed;
  }

  @override
  Future<SessionPage> listSessions({int page = 1}) async =>
      SessionPage(items: _closed);

  @override
  Future<double?> lastClosingAmount() async {
    if (_closed.isEmpty) return null;
    final contado = _closed.first.closingAmountCounted;
    return contado == null ? null : moneyToDouble(contado);
  }

  @override
  Future<CashEntry> createEntry(EntryDraft draft) async {
    if (_open == null && _config.requireOpenSession) {
      throw Exception('Abra o caixa antes de lançar movimentos.');
    }
    _open ??= CashSession(id: _id('sess'), status: 'open', openingAmount: '0.00');
    final entry = CashEntry(
      id: _id('entry'),
      direction: isOutflowCategory(draft.category) ? 'out' : 'in',
      amount: draft.amount.toStringAsFixed(2),
      method: draft.method,
      category: draft.category,
      saleKind: draft.saleKind,
      saleId: draft.saleId,
      description: draft.description,
      createdAt: DateTime.now().toIso8601String(),
    );
    _entries.insert(0, entry);
    return entry;
  }

  @override
  Future<CashEntry> reverseEntry(String id, String reason) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    final reversed =
        _entries[idx].copyWith(reversedAt: DateTime.now().toIso8601String());
    _entries[idx] = reversed;
    return reversed;
  }

  @override
  Future<CashEntry> updateEntry(
    String id, {
    String? description,
    String? category,
  }) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    final editado = _entries[idx].copyWith(
      description: description ?? _entries[idx].description,
      category: category ?? _entries[idx].category,
    );
    _entries[idx] = editado;
    return editado;
  }

  @override
  Future<CashEntry> correctEntry(
    String id, {
    required String reason,
    double? amount,
    String? method,
    String? category,
    String? description,
    double? discount,
    String? discountReason,
  }) async {
    // Espelha o servidor: estorna o original e cria um NOVO (nunca sobrescreve).
    final original = _entries.firstWhere((e) => e.id == id);
    await reverseEntry(id, reason);
    return createEntry(EntryDraft(
      amount: amount ?? double.parse(original.amount),
      method: method ?? original.method,
      category: category ?? original.category,
      saleKind: original.saleKind,
      saleId: original.saleId,
      description: description ?? original.description,
      // Herda o desconto original quando não vier no patch — mesmo contrato do
      // servidor.
      discount: discount ?? double.tryParse(original.discount) ?? 0,
      discountReason: discountReason ?? original.discountReason,
    ));
  }

  @override
  Future<EntryPage> listEntries({
    String? sessionId,
    String? q,
    String? direction,
    String? method,
    String? category,
    String? saleKind,
    String? saleId,
    String? from,
    String? to,
    int page = 1,
  }) async {
    final filtered = _entries.where((e) {
      if (direction != null && e.direction != direction) return false;
      if (method != null && e.method != method) return false;
      if (category != null && e.category != category) return false;
      if (saleId != null && e.saleId != saleId) return false;
      return true;
    }).toList(growable: false);
    return EntryPage(items: filtered, total: filtered.length);
  }

  @override
  Future<CashSummary> summary({String? from, String? to}) async {
    final live = _entries.where((e) => e.reversedAt == null);
    final byMethod = _byMethod(live);
    final totalIn =
        live.where((e) => e.direction == 'in').fold<double>(0, (a, e) => a + moneyToDouble(e.amount));
    final totalOut =
        live.where((e) => e.direction == 'out').fold<double>(0, (a, e) => a + moneyToDouble(e.amount));
    return CashSummary(
      byMethod: byMethod,
      totalIn: totalIn,
      totalOut: totalOut,
      net: totalIn - totalOut,
    );
  }

  @override
  Future<PaymentDetail> paymentSummary({
    required String saleKind,
    required String saleId,
    double? total,
  }) async {
    final entries = _entries
        .where((e) => e.saleId == saleId && e.reversedAt == null)
        .toList(growable: false);
    final paid = entries
        .where((e) => e.direction == 'in')
        .fold<double>(0, (a, e) => a + moneyToDouble(e.amount));
    final t = total ?? 0;
    final status = paid <= 0
        ? 'a_receber'
        : (paid + 0.005 >= t ? 'pago' : 'parcial');
    return PaymentDetail(
      total: t,
      paid: paid,
      balance: (t - paid) < 0 ? 0 : t - paid,
      status: status,
      entries: entries,
    );
  }

  // --- despesas fixas ---
  // Semeadas com os casos reais de oficina: dois com valor fechado (atalho de um
  // toque) e um com valor 0, que é o "varia" — assim o dev/teste vê os dois
  // comportamentos sem ter de cadastrar nada.
  final List<ExpenseTemplate> _templates = [
    const ExpenseTemplate(
      id: 'tpl-aluguel',
      name: 'Aluguel',
      amount: '1200',
      method: 'pix',
    ),
    const ExpenseTemplate(
      id: 'tpl-internet',
      name: 'Internet',
      amount: '120',
      method: 'pix',
    ),
    const ExpenseTemplate(id: 'tpl-luz', name: 'Conta de luz'),
  ];

  var _tplSeq = 0;

  @override
  Future<List<ExpenseTemplate>> listExpenseTemplates({
    bool includeDisabled = false,
  }) async =>
      _templates
          .where((t) => includeDisabled || t.ativo)
          .toList(growable: false);

  @override
  Future<ExpenseTemplate> createExpenseTemplate(
    ExpenseTemplateDraft draft,
  ) async {
    final nome = (draft.name ?? '').trim();
    if (_templates.any(
      (t) => t.ativo && t.name.toLowerCase() == nome.toLowerCase(),
    )) {
      throw AppException(
        statusCode: 409,
        error: 'Conflict',
        message: 'Já existe uma despesa fixa "$nome".',
      );
    }
    final tpl = ExpenseTemplate(
      id: draft.id ?? 'tpl-fake-${++_tplSeq}',
      name: nome,
      amount: (draft.amount ?? 0).toStringAsFixed(2),
      category: draft.category ?? 'despesa',
      method: draft.method,
    );
    _templates.add(tpl);
    return tpl;
  }

  @override
  Future<ExpenseTemplate> updateExpenseTemplate(
    String id,
    ExpenseTemplateDraft draft,
  ) async {
    final i = _templates.indexWhere((t) => t.id == id);
    if (i < 0) {
      throw const AppException(
        statusCode: 404,
        error: 'NotFound',
        message: 'Despesa fixa não encontrada.',
      );
    }
    final atual = _templates[i];
    final novo = atual.copyWith(
      name: draft.name ?? atual.name,
      amount: draft.amount != null
          ? draft.amount!.toStringAsFixed(2)
          : atual.amount,
      category: draft.category ?? atual.category,
      method: draft.limparMethod ? null : (draft.method ?? atual.method),
      status: draft.status ?? atual.status,
    );
    _templates[i] = novo;
    return novo;
  }

  @override
  Future<ExpenseTemplate> disableExpenseTemplate(String id) =>
      updateExpenseTemplate(id, const ExpenseTemplateDraft(status: 'disabled'));

  // --- parcelas de fiado (fake — sempre vazias em dev) ---

  @override
  Future<List<Installment>> listInstallments({
    required String saleKind,
    required String saleId,
  }) async =>
      const [];

  @override
  Future<void> createInstallmentPlan(InstallmentPlanDraft draft) async {}

  @override
  Future<Installment> payInstallment({
    required String installmentId,
    required String method,
    String? description,
    double discount = 0,
    String? discountReason,
  }) async {
    throw UnimplementedError('payInstallment não implementado no fake.');
  }
}
