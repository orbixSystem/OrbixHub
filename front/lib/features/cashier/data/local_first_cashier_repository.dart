import '../../../core/error/app_exception.dart';
import '../../../core/offline/local_first.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../domain/cashier_repository.dart';

/// [CashierRepository] offline-first (B8) — decorator sobre a impl real (dio).
///
/// Entidades espelhadas: `cash_session`, `cash_entry`.
///
/// A sessão é **por ponto de caixa** (`deviceId`, B4): o decorator resolve o
/// mesmo id do device que a impl real usa e o manda no payload das ops
/// `cash_session.open` / `cash_entry.create`, além de filtrar a sessão corrente
/// local pelo device.
///
/// Offline lançam "Requer conexão": `updateConfig` (não há op de sync).
/// `summary`/`paymentSummary` são DERIVADOS dos lançamentos locais.
class LocalFirstCashierRepository extends LocalFirstBase
    implements CashierRepository {
  LocalFirstCashierRepository({
    required this.inner,
    required this.deviceId,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final CashierRepository inner;

  /// Ponto de caixa (mesma fonte do `CashierRepositoryImpl`). Degrada para
  /// `null` (ponto legado) se a leitura falhar.
  final Future<String?> Function() deviceId;

  static const _sessions = 'cash_session';
  static const _entries = 'cash_entry';
  static const _pageSize = 20;

  /// Saídas são despesa e sangria; o resto é entrada (espelha
  /// `directionForCategory` do backend — o cliente nunca escolhe a direção).
  static const _outCategories = {'despesa', 'sangria'};

  String _direction(String category) =>
      _outCategories.contains(category) ? 'out' : 'in';

  // ============================ config ==================================

  @override
  Future<CashierConfig> fetchConfig() async {
    if (isOnline()) {
      final config = await inner.fetchConfig();
      await putRow(LocalConfigEntities.cashier, {
        'id': LocalConfigEntities.rowId,
        ...config.toJson(),
      });
      return config;
    }
    final cached = await rowById(
      LocalConfigEntities.cashier,
      LocalConfigEntities.rowId,
    );
    if (cached == null) return const CashierConfig();
    return CashierConfig.fromJson(cached);
  }

  /// Config do módulo não tem op de sync — mudar exige conexão.
  @override
  Future<CashierConfig> updateConfig({
    List<String>? paymentMethods,
    bool? requireOpenSession,
    bool? countCashOnly,
  }) async {
    if (!isOnline()) requiresConnection('alterar a configuração do caixa');
    final config = await inner.updateConfig(
      paymentMethods: paymentMethods,
      requireOpenSession: requireOpenSession,
      countCashOnly: countCashOnly,
    );
    await putRow(LocalConfigEntities.cashier, {
      'id': LocalConfigEntities.rowId,
      ...config.toJson(),
    });
    return config;
  }

  // =========================== sessões ==================================

  Future<Map<String, dynamic>?> _openSessionRow() async {
    final device = await deviceId();
    final open = (await rows(_sessions))
        .where((r) => (r['status'] ?? 'open') == 'open')
        .where((r) => r['device_id'] == device)
        .toList()
      ..sort((a, b) => _openedAt(b).compareTo(_openedAt(a)));
    return open.isEmpty ? null : open.first;
  }

  String _openedAt(Map<String, dynamic> row) =>
      (row['opened_at'] ?? row['created_at'] ?? '') as String;

  /// Lançamentos VIVOS (não estornados) de uma sessão local.
  Future<List<Map<String, dynamic>>> _liveEntriesOf(String sessionId) async {
    return (await rows(_entries))
        .where((r) => r['cash_session_id'] == sessionId)
        .where((r) => r['reversed_at'] == null)
        .toList();
  }

  /// Monta a [CashSession] local com os totais correntes (mesma conta do backend:
  /// esperado = abertura + entradas − saídas).
  Future<CashSession> _sessionWithTotals(Map<String, dynamic> row) async {
    final live = await _liveEntriesOf(row['id'] as String);
    final totals = _totalsOf(live);
    return CashSession.fromJson({
      ...row,
      'byMethod': [for (final m in _byMethod(live)) m.toJson()],
      'totals': SessionTotals(
        inTotal: totals.inTotal,
        outTotal: totals.outTotal,
        expected: toNum(row['opening_amount']).toDouble() +
            totals.inTotal -
            totals.outTotal,
      ).toJson(),
    });
  }

  ({double inTotal, double outTotal}) _totalsOf(
    List<Map<String, dynamic>> entries,
  ) {
    var inTotal = 0.0;
    var outTotal = 0.0;
    for (final e in entries) {
      final amount = moneyToDouble((e['amount'] ?? '0').toString());
      if (e['direction'] == 'out') {
        outTotal += amount;
      } else {
        inTotal += amount;
      }
    }
    return (inTotal: inTotal, outTotal: outTotal);
  }

  List<MethodTotal> _byMethod(List<Map<String, dynamic>> entries) {
    final map = <String, MethodTotal>{};
    for (final e in entries) {
      final method = (e['method'] ?? 'outro') as String;
      final amount = moneyToDouble((e['amount'] ?? '0').toString());
      final cur = map[method] ?? MethodTotal(method: method);
      map[method] = e['direction'] == 'out'
          ? cur.copyWith(outAmount: cur.outAmount + amount)
          : cur.copyWith(inAmount: cur.inAmount + amount);
    }
    return map.values.toList(growable: false);
  }

  @override
  Future<CashSession?> currentSession() async {
    if (isOnline()) {
      final session = await inner.currentSession();
      if (session != null) await putRow(_sessions, session.toJson());
      return session;
    }
    final row = await _openSessionRow();
    if (row == null) return null;
    return _sessionWithTotals(row);
  }

  @override
  Future<CashSession> openSession({double? openingAmount, String? notes}) async {
    if (isOnline()) {
      final session = await inner.openSession(
        openingAmount: openingAmount,
        notes: notes,
      );
      await putRow(_sessions, session.toJson());
      return session;
    }
    final device = await deviceId();
    final id = newId();
    await enqueue(_sessions, 'open', {
      'id': id,
      'openingAmount': ?openingAmount,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'deviceId': ?device,
    });
    final row = <String, dynamic>{
      'id': id,
      'status': 'open',
      'opening_amount': dec(openingAmount ?? 0),
      'opened_at': nowIso(),
      'device_id': device,
      'notes': notes,
      'created_at': nowIso(),
      'updated_at': nowIso(),
    };
    await putRow(_sessions, row);
    return _sessionWithTotals(row);
  }

  @override
  Future<CashSession> closeSession({
    required double countedAmount,
    String? notes,
  }) async {
    if (isOnline()) {
      final session = await inner.closeSession(
        countedAmount: countedAmount,
        notes: notes,
      );
      await putRow(_sessions, session.toJson());
      return session;
    }
    final row = await _openSessionRow();
    if (row == null) notFoundLocally('Caixa aberto');
    final device = await deviceId();
    await enqueue(_sessions, 'close', {
      'countedAmount': countedAmount,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'deviceId': ?device,
    });
    final live = await _liveEntriesOf(row['id'] as String);
    final totals = _totalsOf(live);
    final expected = toNum(row['opening_amount']).toDouble() +
        totals.inTotal -
        totals.outTotal;
    final closed = {
      ...row,
      'status': 'closed',
      'closed_at': nowIso(),
      'closing_amount_counted': dec(countedAmount),
      'closing_amount_expected': dec(expected),
      'difference': dec(countedAmount - expected),
      'notes': notes ?? row['notes'],
      'updated_at': nowIso(),
    };
    await putRow(_sessions, closed);
    return _sessionWithTotals(closed);
  }

  @override
  Future<SessionPage> listSessions({int page = 1}) async {
    if (isOnline()) {
      final res = await inner.listSessions(page: page);
      await putRows(_sessions, [for (final s in res.items) s.toJson()]);
      return res;
    }
    final all = (await rows(_sessions))
      ..sort((a, b) => _openedAt(b).compareTo(_openedAt(a)));
    return SessionPage(
      items: [
        for (final row in pageOf(all, page, _pageSize)) CashSession.fromJson(row),
      ],
      total: all.length,
      page: page,
      pageSize: _pageSize,
    );
  }

  // ========================== lançamentos ===============================

  @override
  Future<CashEntry> createEntry(EntryDraft draft) async {
    if (isOnline()) {
      final entry = await inner.createEntry(draft);
      await putRow(_entries, entry.toJson());
      return entry;
    }
    final session = await _openSessionRow();
    if (session == null) {
      // Mesma regra do backend: lançar exige sessão aberta. Avisamos aqui em vez
      // de enfileirar uma mutação que o servidor recusaria no replay.
      throw const AppException(
        statusCode: 400,
        error: 'NoOpenSession',
        message: 'Abra o caixa antes de lançar.',
      );
    }
    final device = await deviceId();
    final id = newId();
    await enqueue(_entries, 'create', {
      'id': id,
      ...draft.toJson(),
      'deviceId': ?device,
    });
    final row = <String, dynamic>{
      'id': id,
      'cash_session_id': session['id'],
      'direction': _direction(draft.category),
      'amount': dec(draft.amount),
      'method': draft.method,
      'category': draft.category,
      'sale_kind': draft.saleKind,
      'sale_id': draft.saleId,
      'description': draft.description,
      'reversed_at': null,
      'created_at': nowIso(),
    };
    await putRow(_entries, row);
    return CashEntry.fromJson(row);
  }

  @override
  Future<CashEntry> reverseEntry(String id, String reason) async {
    if (isOnline()) {
      final entry = await inner.reverseEntry(id, reason);
      await putRow(_entries, entry.toJson());
      return entry;
    }
    final row = await rowById(_entries, id);
    if (row == null) notFoundLocally('Lançamento');
    await enqueue(_entries, 'reverse', {'id': id, 'reason': reason});
    final reversed = {...row, 'reversed_at': nowIso()};
    await putRow(_entries, reversed);
    return CashEntry.fromJson(reversed);
  }

  @override
  Future<EntryPage> listEntries({
    String? sessionId,
    String? direction,
    String? method,
    String? category,
    String? saleKind,
    String? saleId,
    String? from,
    String? to,
    int page = 1,
  }) async {
    if (isOnline()) {
      final res = await inner.listEntries(
        sessionId: sessionId,
        direction: direction,
        method: method,
        category: category,
        saleKind: saleKind,
        saleId: saleId,
        from: from,
        to: to,
        page: page,
      );
      await putRows(_entries, [for (final e in res.items) e.toJson()]);
      return res;
    }
    final filtered = (await rows(_entries)).where((row) {
      if (sessionId != null && row['cash_session_id'] != sessionId) return false;
      if (direction != null && row['direction'] != direction) return false;
      if (method != null && row['method'] != method) return false;
      if (category != null && row['category'] != category) return false;
      if (saleKind != null && row['sale_kind'] != saleKind) return false;
      if (saleId != null && row['sale_id'] != saleId) return false;
      return _inPeriod(row, from, to);
    }).toList()
      ..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));

    return EntryPage(
      items: [
        for (final row in pageOf(filtered, page, _pageSize))
          CashEntry.fromJson(row),
      ],
      total: filtered.length,
      page: page,
      pageSize: _pageSize,
    );
  }

  String _createdAt(Map<String, dynamic> row) =>
      (row['created_at'] ?? '') as String;

  bool _inPeriod(Map<String, dynamic> row, String? from, String? to) {
    final created = _createdAt(row);
    if (from != null && created.compareTo(from) < 0) return false;
    if (to != null && created.compareTo(to) > 0) return false;
    return true;
  }

  // ============================ resumos =================================

  /// Derivado dos lançamentos locais (o servidor faz a mesma conta) — offline não
  /// precisamos recusar: o dado está no espelho.
  @override
  Future<CashSummary> summary({String? from, String? to}) async {
    if (isOnline()) return inner.summary(from: from, to: to);
    final live = (await rows(_entries))
        .where((r) => r['reversed_at'] == null)
        .where((r) => _inPeriod(r, from, to))
        .toList();
    final totals = _totalsOf(live);
    return CashSummary(
      byMethod: _byMethod(live),
      byCategory: _keyed(live, 'category'),
      byOrigin: _keyed(live, 'sale_kind'),
      totalIn: totals.inTotal,
      totalOut: totals.outTotal,
      net: totals.inTotal - totals.outTotal,
    );
  }

  List<KeyedTotal> _keyed(List<Map<String, dynamic>> entries, String field) {
    final map = <String, KeyedTotal>{};
    for (final e in entries) {
      final key = (e[field] ?? 'outro').toString();
      final amount = moneyToDouble((e['amount'] ?? '0').toString());
      final cur = map[key] ?? KeyedTotal(key: key);
      map[key] = e['direction'] == 'out'
          ? cur.copyWith(outAmount: cur.outAmount + amount)
          : cur.copyWith(inAmount: cur.inAmount + amount);
    }
    return map.values.toList(growable: false);
  }

  /// Saldo de uma venda (OS/venda avulsa) a partir dos recebimentos locais.
  @override
  Future<PaymentDetail> paymentSummary({
    required String saleKind,
    required String saleId,
    double? total,
  }) async {
    if (isOnline()) {
      return inner.paymentSummary(
        saleKind: saleKind,
        saleId: saleId,
        total: total,
      );
    }
    final entries = (await rows(_entries))
        .where((r) => r['sale_kind'] == saleKind && r['sale_id'] == saleId)
        .where((r) => r['reversed_at'] == null)
        .toList()
      ..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));

    var paid = 0.0;
    for (final e in entries) {
      final amount = moneyToDouble((e['amount'] ?? '0').toString());
      paid += e['direction'] == 'out' ? -amount : amount;
    }
    final totalValue = total ?? 0;
    final balance = totalValue - paid;
    final status = paid <= 0
        ? 'a_receber'
        : (balance <= 0.004 ? 'pago' : 'parcial');

    return PaymentDetail(
      total: totalValue,
      paid: paid,
      balance: balance < 0 ? 0 : balance,
      status: status,
      entries: [for (final e in entries) CashEntry.fromJson(e)],
    );
  }
}
