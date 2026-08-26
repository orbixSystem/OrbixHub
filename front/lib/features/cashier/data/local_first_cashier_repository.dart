import '../../../core/error/app_exception.dart';
import '../../../core/offline/local_first.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../domain/cashier_repository.dart';
import '../domain/local_payment.dart';

/// [CashierRepository] offline-first (B8) — decorator sobre a impl real (dio).
///
/// Entidades espelhadas: `cash_session`, `cash_entry`, `cash_expense_template`,
/// `receivable_installment`.
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
  static const _templates = 'cash_expense_template';
  static const _installments = 'receivable_installment';
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

  /// `countCashOnly` da config espelhada (default do backend: `true`) — a
  /// conferência de fechamento considera só dinheiro.
  Future<bool> _countCashOnly() async {
    final cached = await rowById(
      LocalConfigEntities.cashier,
      LocalConfigEntities.rowId,
    );
    if (cached == null) return const CashierConfig().countCashOnly;
    return CashierConfig.fromJson(cached).countCashOnly;
  }

  /// Valor ESPERADO em caixa (mesma conta do backend): abertura + entradas −
  /// saídas, considerando só `dinheiro` quando `countCashOnly` (pix/cartão são
  /// informativos).
  Future<double> _expectedOf(
    Map<String, dynamic> session,
    List<Map<String, dynamic>> live,
  ) async {
    final considered = await _countCashOnly()
        ? live.where((e) => e['method'] == 'dinheiro').toList()
        : live;
    final totals = _totalsOf(considered);
    return round2(
      toNum(session['opening_amount']).toDouble() +
          totals.inTotal -
          totals.outTotal,
    );
  }

  /// Monta a [CashSession] local com os totais correntes.
  Future<CashSession> _sessionWithTotals(Map<String, dynamic> row) async {
    final live = await _liveEntriesOf(row['id'] as String);
    final totals = _totalsOf(live);
    return CashSession.fromJson({
      ...row,
      'byMethod': [for (final m in _byMethod(live)) m.toJson()],
      'totals': SessionTotals(
        inTotal: round2(totals.inTotal),
        outTotal: round2(totals.outTotal),
        expected: await _expectedOf(row, live),
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

  /// **Sessao suja**: existe mutacao de sessao deste device ainda nao confirmada
  /// (`open` na fila => o servidor nao conhece a sessao; `close` na fila => o
  /// servidor ainda a ve ABERTA). Enquanto isso, o caixa e servido LOCALMENTE
  /// mesmo com rede: perguntar ao servidor devolveria `null` (caixa "fechado") ou
  /// reabriria um caixa ja fechado offline.
  ///
  /// O `close` NAO carrega `id` no payload (o backend endereca pelo device), por
  /// isso `unsyncedIds` nao o enxerga — dai o [LocalDb.hasPendingOp].
  Future<bool> _sessionsDirty() async {
    if ((await dirtyIds(_sessions)).isNotEmpty) return true;
    return db.hasPendingOp(_sessions, 'close');
  }

  /// Caminho local do caixa: offline OU sessao suja.
  Future<bool> _useLocalSession() async => !isOnline() || await _sessionsDirty();

  @override
  Future<CashSession?> currentSession() async {
    if (!await _useLocalSession()) {
      final session = await inner.currentSession();
      if (session != null) await mirrorRows(_sessions, [session.toJson()]);
      return session;
    }
    final row = await _openSessionRow();
    if (row == null) return null;
    return _sessionWithTotals(row);
  }

  @override
  Future<CashSession> openSession({double? openingAmount, String? notes}) async {
    if (!await _useLocalSession()) {
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
    if (!await _useLocalSession()) {
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
    final expected = await _expectedOf(row, live);
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
      await mirrorRows(_sessions, [for (final s in res.items) s.toJson()]);
      // Sessao aberta/fechada offline e ainda na fila: o servidor nao a conhece
      // (ou ainda a ve aberta) — a versao local vence e entra no topo da 1a pagina.
      final device = await deviceId();
      final merged = await mergePending(
        _sessions,
        [for (final s in res.items) s.toJson()],
        includeExtras: page == 1,
        keepExtra: (row) => row['device_id'] == device,
      );
      return res.copyWith(
        items: [for (final row in merged) CashSession.fromJson(row)],
        total: res.total + (merged.length - res.items.length),
      );
    }
    // Histórico deste PONTO de caixa (coerente com `currentSession`, que também
    // filtra pelo device — B4).
    final device = await deviceId();
    final all = (await rows(_sessions))
        .where((r) => r['device_id'] == device)
        .toList()
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

  /// Último fechamento DESTE ponto de caixa. Online delega (o backend filtra por
  /// `deviceId`+`status`); offline lê o espelho local, que `listSessions` já
  /// mantém filtrado por device.
  @override
  Future<double?> lastClosingAmount() async {
    if (isOnline()) return inner.lastClosingAmount();
    final device = await deviceId();
    final fechadas = (await rows(_sessions))
        .where((r) => r['device_id'] == device && r['status'] == 'closed')
        .toList()
      ..sort((a, b) => _openedAt(b).compareTo(_openedAt(a)));
    if (fechadas.isEmpty) return null;
    final contado = fechadas.first['closing_amount_counted'];
    return contado == null ? null : moneyToDouble(contado);
  }

  // ========================== lançamentos ===============================

  @override
  Future<CashEntry> createEntry(EntryDraft draft) async {
    // Caixa aberto OFFLINE e ainda na fila: o servidor nao conhece a sessao —
    // lancar la devolveria 400 "abra o caixa". O lancamento vai para o outbox,
    // atras do `cash_session.open` (a ordem por `seq` garante o replay correto).
    if (!await _useLocalSession()) {
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
    // Lançamento criado offline e ainda na fila: estornar no servidor daria 404.
    if (!await useLocal(_entries, id)) {
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
  Future<CashEntry> updateEntry(
    String id, {
    String? description,
    String? category,
  }) async {
    if (!await useLocal(_entries, id)) {
      final entry =
          await inner.updateEntry(id, description: description, category: category);
      await putRow(_entries, entry.toJson());
      return entry;
    }
    final row = await rowById(_entries, id);
    if (row == null) notFoundLocally('Lançamento');
    if (row['reversed_at'] != null) {
      // Mesma regra (e mesmo 409) do servidor: estornado é histórico fechado.
      throw const AppException(
        statusCode: 409,
        error: 'Conflict',
        message: 'Lançamento estornado não pode ser editado.',
      );
    }
    // Trocar a direção é mudança financeira: recusa aqui, como o servidor, em
    // vez de enfileirar algo que o replay vai rejeitar depois.
    if (category != null &&
        _direction(category) != _direction(row['category'] as String)) {
      throw const AppException(
        statusCode: 400,
        error: 'BadRequest',
        message: 'Esta troca de categoria inverte entrada/saída. Use a '
            'correção do lançamento.',
      );
    }
    await enqueue(_entries, 'update', {
      'id': id,
      'description': ?description,
      'category': ?category,
    });
    final editado = {
      ...row,
      'description': ?description,
      'category': ?category,
      'updated_at': nowIso(),
    };
    await putRow(_entries, editado);
    return CashEntry.fromJson(editado);
  }

  @override
  Future<CashEntry> correctEntry(
    String id, {
    required String reason,
    double? amount,
    String? method,
    String? category,
    String? description,
  }) async {
    if (!await useLocal(_entries, id)) {
      final novo = await inner.correctEntry(
        id,
        reason: reason,
        amount: amount,
        method: method,
        category: category,
        description: description,
      );
      await putRow(_entries, novo.toJson());
      // O servidor estornou o original nesta mesma chamada. Refletir isso no
      // espelho evita a lista mostrar o valor antigo como válido até o próximo
      // pull (o que faria o total do dia parecer dobrado).
      final antigo = await rowById(_entries, id);
      if (antigo != null) {
        await putRow(_entries, {
          ...antigo,
          'reversed_at': nowIso(),
          'reversal_reason': reason,
        });
      }
      return novo;
    }

    final row = await rowById(_entries, id);
    if (row == null) notFoundLocally('Lançamento');
    if (row['reversed_at'] != null) {
      throw const AppException(
        statusCode: 409,
        error: 'Conflict',
        message: 'Lançamento já estornado.',
      );
    }

    // UMA op no outbox (`correct`), não duas: se fossem `reverse` + `create`
    // separadas, uma falha entre elas deixaria o caixa com dinheiro duplicado
    // ou estorno sem contrapartida. O servidor faz as duas pontas no replay.
    final novoId = newId();
    await enqueue(_entries, 'correct', {
      'id': id,
      'reason': reason,
      'newId': novoId,
      'amount': ?amount,
      'method': ?method,
      'category': ?category,
      'description': ?description,
    });

    // Espelho otimista: o original estornado + o novo lançamento.
    await putRow(_entries, {
      ...row,
      'reversed_at': nowIso(),
      'reversal_reason': reason,
    });
    final novaCategoria = category ?? row['category'] as String;
    final novo = {
      ...row,
      'id': novoId,
      'direction': _direction(novaCategoria),
      'amount': dec(amount ?? toNum(row['amount'])),
      'method': method ?? row['method'],
      'category': novaCategoria,
      'description': description ?? row['description'],
      'reversed_at': null,
      'reversal_reason': null,
      'created_at': nowIso(),
    };
    await putRow(_entries, novo);
    return CashEntry.fromJson(novo);
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
    if (isOnline()) {
      final res = await inner.listEntries(
        sessionId: sessionId,
        q: q,
        direction: direction,
        method: method,
        category: category,
        saleKind: saleKind,
        saleId: saleId,
        from: from,
        to: to,
        page: page,
      );
      await mirrorRows(_entries, [for (final e in res.items) e.toJson()]);
      // Lancamentos ainda na fila continuam no extrato (a versao local vence).
      final merged = await mergePending(
        _entries,
        [for (final e in res.items) e.toJson()],
        includeExtras: page == 1,
        keepExtra: (row) => _matchesEntryFilter(
          row,
          sessionId: sessionId,
          q: q,
          direction: direction,
          method: method,
          category: category,
          saleKind: saleKind,
          saleId: saleId,
          from: from,
          to: to,
        ),
      );
      return res.copyWith(
        items: [for (final row in merged) CashEntry.fromJson(row)],
        total: res.total + (merged.length - res.items.length),
      );
    }
    final filtered = (await rows(_entries))
        .where((row) => _matchesEntryFilter(
              row,
              sessionId: sessionId,
              q: q,
              direction: direction,
              method: method,
              category: category,
              saleKind: saleKind,
              saleId: saleId,
              from: from,
              to: to,
            ))
        .toList()
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

  /// Filtro do extrato — usado offline e para decidir se um lancamento ainda na
  /// fila entra no resultado online.
  bool _matchesEntryFilter(
    Map<String, dynamic> row, {
    String? sessionId,
    String? q,
    String? direction,
    String? method,
    String? category,
    String? saleKind,
    String? saleId,
    String? from,
    String? to,
  }) {
    if (sessionId != null && row['cash_session_id'] != sessionId) return false;
    // Mesma semântica do backend (`description contains`, sem caixa): o filtro
    // vale igual online e offline, senão a busca mudaria de resultado conforme a
    // conexão.
    if (q != null && q.trim().isNotEmpty) {
      final termo = q.trim().toLowerCase();
      final desc = (row['description'] ?? '').toString().toLowerCase();
      if (!desc.contains(termo)) return false;
    }
    if (direction != null && row['direction'] != direction) return false;
    if (method != null && row['method'] != method) return false;
    if (category != null && row['category'] != category) return false;
    if (saleKind != null && row['sale_kind'] != saleKind) return false;
    if (saleId != null && row['sale_id'] != saleId) return false;
    return _inPeriod(row, from, to);
  }

  String _createdAt(Map<String, dynamic> row) =>
      (row['created_at'] ?? '') as String;

  /// Compara INSTANTES (não strings): `from`/`to` podem vir como data pura
  /// ('2026-07-13'), e um `to` desses, comparado como texto contra um
  /// `created_at` ISO completo, descartaria TODOS os lançamentos do último dia.
  /// Data pura em `to` = fim do dia (mesma semântica do `parseDate` do backend).
  bool _inPeriod(Map<String, dynamic> row, String? from, String? to) {
    final created = DateTime.tryParse(_createdAt(row))?.toUtc();
    if (created == null) return true;
    final start = _bound(from, endOfDay: false);
    final end = _bound(to, endOfDay: true);
    if (start != null && created.isBefore(start)) return false;
    if (end != null && created.isAfter(end)) return false;
    return true;
  }

  DateTime? _bound(String? value, {required bool endOfDay}) {
    if (value == null || value.isEmpty) return null;
    final dateOnly = value.length <= 10; // 'YYYY-MM-DD'
    // Data pura é interpretada em UTC (o `DateTime.parse` a leria como hora
    // LOCAL, deslocando a fronteira pelo fuso).
    final parsed = DateTime.tryParse(dateOnly ? '${value}T00:00:00Z' : value)
        ?.toUtc();
    if (parsed == null) return null;
    if (!dateOnly || !endOfDay) return parsed;
    return parsed.add(const Duration(days: 1) - const Duration(microseconds: 1));
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
      // `sale_kind` nulo vira 'nenhum' — mesma chave do backend (shapeKeyedTotals).
      byOrigin: _keyed(live, 'sale_kind', fallback: 'nenhum'),
      totalIn: totals.inTotal,
      totalOut: totals.outTotal,
      net: totals.inTotal - totals.outTotal,
    );
  }

  List<KeyedTotal> _keyed(
    List<Map<String, dynamic>> entries,
    String field, {
    String fallback = 'outro',
  }) {
    final map = <String, KeyedTotal>{};
    for (final e in entries) {
      final key = (e[field] ?? fallback).toString();
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

  // ===================== despesas fixas =====================
  // Atalhos precisam existir OFFLINE: é justo sem rede que lançar rápido importa
  // mais. Modelo não é dinheiro — cadastrar/editar offline não move saldo nenhum.

  @override
  Future<List<ExpenseTemplate>> listExpenseTemplates({
    bool includeDisabled = false,
  }) async {
    if (isOnline()) {
      try {
        final remotos =
            await inner.listExpenseTemplates(includeDisabled: includeDisabled);
        for (final t in remotos) {
          await putRow(_templates, t.toJson());
        }
        return remotos;
      } on AppException {
        // Cai para o espelho local — um atalho é conveniência, não pode
        // derrubar a tela de lançamento se a rede oscilar no meio.
      }
    }
    final locais = (await rows(_templates))
        .where((r) => includeDisabled || (r['status'] ?? 'active') == 'active')
        .toList()
      ..sort((a, b) => (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()));
    return [for (final r in locais) ExpenseTemplate.fromJson(r)];
  }

  @override
  Future<ExpenseTemplate> createExpenseTemplate(
    ExpenseTemplateDraft draft,
  ) async {
    if (isOnline()) {
      final criado = await inner.createExpenseTemplate(draft);
      await putRow(_templates, criado.toJson());
      return criado;
    }
    final id = draft.id ?? newId();
    await enqueue(_templates, 'create', {...draft.toJson(), 'id': id});
    final row = <String, dynamic>{
      'id': id,
      'name': draft.name ?? '',
      'amount': dec(draft.amount ?? 0),
      'category': draft.category ?? 'despesa',
      'method': draft.method,
      'status': 'active',
    };
    await putRow(_templates, row);
    return ExpenseTemplate.fromJson(row);
  }

  @override
  Future<ExpenseTemplate> updateExpenseTemplate(
    String id,
    ExpenseTemplateDraft draft,
  ) async {
    // Criado offline e ainda na fila: editar no servidor daria 404.
    if (!await useLocal(_templates, id)) {
      final atualizado = await inner.updateExpenseTemplate(id, draft);
      await putRow(_templates, atualizado.toJson());
      return atualizado;
    }
    final row = await rowById(_templates, id);
    if (row == null) notFoundLocally('Despesa fixa');
    await enqueue(_templates, 'update', {...draft.toJson(), 'id': id});
    final patch = draft.toJson();
    final novo = <String, dynamic>{
      ...row,
      if (patch.containsKey('name')) 'name': patch['name'],
      if (patch.containsKey('amount')) 'amount': dec(draft.amount ?? 0),
      if (patch.containsKey('category')) 'category': patch['category'],
      if (patch.containsKey('method')) 'method': patch['method'],
      if (patch.containsKey('status')) 'status': patch['status'],
    };
    await putRow(_templates, novo);
    return ExpenseTemplate.fromJson(novo);
  }

  @override
  Future<ExpenseTemplate> disableExpenseTemplate(String id) =>
      // Desativar é um update de `status` — offline reusa a mesma op de sync, em
      // vez de precisar de uma op própria só para isso.
      updateExpenseTemplate(id, const ExpenseTemplateDraft(status: 'disabled'));

  // --- parcelas de fiado ---

  @override
  Future<List<Installment>> listInstallments({
    required String saleKind,
    required String saleId,
  }) async {
    if (isOnline()) {
      final items =
          await inner.listInstallments(saleKind: saleKind, saleId: saleId);
      await mirrorRows(_installments, [for (final i in items) i.toJson()]);
      // Junta o que ainda está na FILA. Rede de volta não é o mesmo que push
      // concluído: um plano criado offline segue só no aparelho até o outbox
      // esvaziar, e sem este merge a lista voltava vazia — o plano "sumia" da
      // tela minutos depois de ter sido criado.
      final merged = await mergePending(
        _installments,
        [for (final i in items) i.toJson()],
        keepExtra: (r) => r['sale_kind'] == saleKind && r['sale_id'] == saleId,
      );
      return _ordenadasPorVencimento(merged);
    }
    final local = (await rows(_installments))
        .where((r) => r['sale_kind'] == saleKind && r['sale_id'] == saleId)
        .toList();
    return _ordenadasPorVencimento(local);
  }

  /// Mais antiga primeiro — é a ordem em que se cobra, e a que o card assume.
  List<Installment> _ordenadasPorVencimento(List<Map<String, dynamic>> linhas) {
    final ordenadas = [...linhas]..sort((a, b) =>
        ((a['due_date'] ?? '') as String)
            .compareTo((b['due_date'] ?? '') as String));
    return [for (final r in ordenadas) Installment.fromJson(r)];
  }

  @override
  Future<void> createInstallmentPlan(InstallmentPlanDraft draft) async {
    if (isOnline()) {
      await inner.createInstallmentPlan(draft);
      return;
    }
    // Mesma regra do backend: só um plano pendente por venda/OS por vez —
    // checa localmente pra não enfileirar uma mutação que o servidor recusaria.
    final jaTemPendente = (await rows(_installments)).any((r) =>
        r['sale_kind'] == draft.saleKind &&
        r['sale_id'] == draft.saleId &&
        r['paid_at'] == null);
    if (jaTemPendente) {
      throw const AppException(
        statusCode: 400,
        error: 'BadRequest',
        message: 'Já existe um plano de parcelas pendentes para esta venda.',
      );
    }
    final schedule = computeInstallmentSchedule(
      totalAmount: draft.totalAmount,
      installmentCount: draft.installmentCount,
      dueDayOfMonth: draft.dueDayOfMonth,
      firstDueDate: draft.firstDueDate == null
          ? null
          : DateTime.tryParse(draft.firstDueDate!),
    );
    // Um uuid por parcela, gerado AQUI — vai no payload (`installmentIds`) pra
    // o replay usar os MESMOS ids em vez de gerar novos (senão duplicaria o
    // plano a cada reenvio do push). Mesmo idioma de `service_order.create`.
    final ids = [for (var i = 0; i < schedule.length; i++) newId()];
    await enqueue(_installments, 'create_plan', {
      ...draft.toJson(),
      'installmentIds': ids,
    });
    for (var i = 0; i < schedule.length; i++) {
      await putRow(_installments, {
        'id': ids[i],
        'sale_kind': draft.saleKind,
        'sale_id': draft.saleId,
        'amount': dec(schedule[i].amount),
        'due_date': schedule[i].dueDate.toIso8601String(),
        'paid_at': null,
        'entry_id': null,
        'notes': draft.notes,
        'created_at': nowIso(),
      });
    }
  }

  @override
  Future<Installment> payInstallment({
    required String installmentId,
    required String method,
    String? description,
    double discount = 0,
    String? discountReason,
  }) async {
    if (!await useLocal(_installments, installmentId)) {
      final inst = await inner.payInstallment(
        installmentId: installmentId,
        method: method,
        description: description,
        discount: discount,
        discountReason: discountReason,
      );
      await putRow(_installments, inst.toJson());
      return inst;
    }
    final row = await rowById(_installments, installmentId);
    if (row == null) notFoundLocally('Parcela');
    if (row['paid_at'] != null) {
      throw const AppException(
        statusCode: 404,
        error: 'NotFound',
        message: 'Parcela não encontrada ou já paga.',
      );
    }
    // Mesma "sessão implícita" do createEntry: quitar uma parcela é lançar no
    // caixa, e lançar exige uma sessão aberta local.
    final session = await _openSessionRow();
    if (session == null) {
      throw const AppException(
        statusCode: 400,
        error: 'NoOpenSession',
        message: 'Abra o caixa antes de lançar.',
      );
    }
    // `entryId` gerado aqui e enviado no payload (`cashEntryId`) — o replay usa
    // o MESMO id pro lançamento em vez de criar um novo, mesmo idioma de
    // `expense.pay`.
    final entryId = newId();
    final saleKind = row['sale_kind'] as String;
    // O desconto pega carona no payload que JÁ vai na fila: nenhum verbo novo
    // no outbox, nenhuma tabela local nova. O servidor revalida a alçada no
    // replay — o cliente offline não é autoridade sobre quanto se pode perdoar.
    await enqueue(_installments, 'pay', {
      'id': installmentId,
      'method': method,
      'description': ?description,
      'cashEntryId': entryId,
      if (discount > 0) 'discount': discount,
      if (discount > 0 && (discountReason ?? '').isNotEmpty)
        'discountReason': discountReason,
    });
    final valorParcela = moneyToDouble((row['amount'] ?? '0').toString());
    await putRow(_entries, {
      'id': entryId,
      'cash_session_id': session['id'],
      'direction': 'in',
      // Espelha o servidor: entra a parcela MENOS o desconto, e a parcela fecha
      // porque amount + discount cobre o valor dela.
      'amount': dec((valorParcela - discount).clamp(0, double.infinity)),
      'discount': dec(discount),
      'discount_reason': discount > 0 ? discountReason : null,
      'method': method,
      'category': saleKind == 'os' ? 'os_payment' : 'venda_avulsa',
      'sale_kind': saleKind,
      'sale_id': row['sale_id'],
      'description': description,
      'reversed_at': null,
      'created_at': nowIso(),
    });
    final paidRow = {
      ...row,
      'paid_at': nowIso(),
      'entry_id': entryId,
      'updated_at': nowIso(),
    };
    await putRow(_installments, paidRow);
    return Installment.fromJson(paidRow);
  }
}
