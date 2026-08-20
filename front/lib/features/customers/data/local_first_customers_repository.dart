import '../../../core/offline/local_first.dart';
import '../domain/customers_models.dart';
import '../domain/customers_repository.dart';

/// [CustomersRepository] offline-first (B8) — decorator sobre a impl real (dio).
/// Referência do padrão dos 4 módulos; ver [LocalFirstBase] para o contrato.
///
/// Entidades espelhadas: `customer`, `subject` (mais `service_order` — só lida,
/// para derivar o histórico offline).
///
/// Offline lançam "Requer conexão" (não há op de sync / o dado é do servidor):
/// `setSubjectPhoto`, `removeSubjectPhoto`, `lookup` (FIPE).
class LocalFirstCustomersRepository extends LocalFirstBase
    implements CustomersRepository {
  LocalFirstCustomersRepository({
    required this.inner,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final CustomersRepository inner;

  static const _pageSize = 20;

  // =========================== config ===================================

  @override
  Future<CustomersConfig> fetchConfig() async {
    if (isOnline()) {
      final config = await inner.fetchConfig();
      await putRow(LocalConfigEntities.customers, {
        'id': LocalConfigEntities.rowId,
        ...config.toJson(),
      });
      return config;
    }
    final cached = await rowById(
      LocalConfigEntities.customers,
      LocalConfigEntities.rowId,
    );
    // Sem config espelhada ainda: os defaults do modelo (a tela abre; os campos
    // dinâmicos aparecem assim que houver uma leitura online).
    if (cached == null) return const CustomersConfig();
    return CustomersConfig.fromJson(cached);
  }

  // ========================== customers =================================

  @override
  Future<CustomerPage> listCustomers({
    String? q,
    String status = 'active',
    String sort = 'recent',
    int page = 1,
  }) async {
    if (isOnline()) {
      final res = await inner.listCustomers(
        q: q,
        status: status,
        sort: sort,
        page: page,
      );
      await mirrorRows('customer', [for (final c in res.items) c.toJson()]);
      // Clientes criados/editados offline e ainda na fila continuam na lista (a
      // versão local vence) — senão sumiriam da tela assim que a rede voltasse.
      final merged = await mergePending(
        'customer',
        [for (final c in res.items) c.toJson()],
        includeExtras: page == 1, // só na 1ª página
        keepExtra: (row) => _matchesCustomerFilter(row, q: q, status: status),
      );
      return res.copyWith(
        items: [for (final row in merged) Customer.fromJson(row)],
        total: res.total + (merged.length - res.items.length),
      );
    }

    final all = await rows('customer');
    final filtered = all
        .where((row) => _matchesCustomerFilter(row, q: q, status: status))
        .toList();

    filtered.sort((a, b) {
      switch (sort) {
        case 'name_asc':
          return _name(a).compareTo(_name(b));
        case 'name_desc':
          return _name(b).compareTo(_name(a));
        case 'oldest':
          return _created(a).compareTo(_created(b));
        case 'recent':
        default:
          return _created(b).compareTo(_created(a));
      }
    });

    return CustomerPage(
      items: [
        for (final row in pageOf(filtered, page, _pageSize))
          Customer.fromJson(row),
      ],
      total: filtered.length,
      page: page,
      pageSize: _pageSize,
    );
  }

  /// Filtro da lista de clientes — usado tanto no caminho offline quanto para
  /// decidir se um cliente criado offline entra no resultado online.
  bool _matchesCustomerFilter(
    Map<String, dynamic> row, {
    String? q,
    required String status,
  }) {
    final rowStatus = (row['status'] ?? 'active') as String;
    if (rowStatus == 'deleted') return false; // soft delete some das listas
    if (status != 'all' && rowStatus != status) return false;
    if (q == null || q.isEmpty) return true;
    return matches(row['name'] as String?, q) ||
        matches(row['document'] as String?, q) ||
        matches(row['phone'] as String?, q);
  }

  String _name(Map<String, dynamic> row) =>
      ((row['name'] ?? '') as String).toLowerCase();

  String _created(Map<String, dynamic> row) =>
      (row['created_at'] ?? row['updated_at'] ?? '') as String;

  @override
  Future<Customer> getCustomer(String id) async {
    if (!await useLocal('customer', id)) {
      final customer = await inner.getCustomer(id);
      await putRow('customer', customer.toJson());
      return customer;
    }
    final row = await rowById('customer', id);
    if (row == null) notFoundLocally('Cliente');
    return Customer.fromJson(row);
  }

  @override
  Future<Customer> createCustomer(CustomerDraft draft) async {
    if (isOnline()) {
      final customer = await inner.createCustomer(draft);
      await putRow('customer', customer.toJson());
      return customer;
    }
    final id = newId();
    // Enfileira ANTES de gravar a linha otimista: se o enqueue falhar (sessão
    // expirada — S1 exige autor), não fica uma linha local órfã que nunca sobe.
    await enqueue('customer', 'create', {'id': id, ...draft.toJson()});
    final row = <String, dynamic>{
      'id': id,
      'name': draft.name ?? '',
      'type': draft.type ?? 'PF',
      'document': draft.document,
      'phone': draft.phone,
      'email': draft.email,
      'address': draft.address,
      'notes': draft.notes,
      'status': 'active',
      'created_at': nowIso(),
      'updated_at': nowIso(),
    };
    await putRow('customer', row);
    return Customer.fromJson(row);
  }

  @override
  Future<Customer> updateCustomer(String id, CustomerDraft draft) async {
    // Linha suja (criada offline e ainda na fila): editar no servidor daria 404.
    if (!await useLocal('customer', id)) {
      final customer = await inner.updateCustomer(id, draft);
      await putRow('customer', customer.toJson());
      return customer;
    }
    final row = await rowById('customer', id);
    if (row == null) notFoundLocally('Cliente');
    await enqueue('customer', 'update', {'id': id, ...draft.toJson()});
    // As chaves do draft coincidem com as colunas (name/type/document/...).
    final merged = {...row, ...draft.toJson(), 'updated_at': nowIso()};
    await putRow('customer', merged);
    return Customer.fromJson(merged);
  }

  @override
  Future<Customer> archiveCustomer(String id) =>
      _statusChange(id, 'archive', 'archived', inner.archiveCustomer);

  @override
  Future<Customer> unarchiveCustomer(String id) =>
      _statusChange(id, 'unarchive', 'active', inner.unarchiveCustomer);

  @override
  Future<Customer> deleteCustomer(String id) =>
      _statusChange(id, 'delete', 'deleted', inner.deleteCustomer);

  Future<Customer> _statusChange(
    String id,
    String op,
    String status,
    Future<Customer> Function(String id) online,
  ) async {
    if (!await useLocal('customer', id)) {
      final customer = await online(id);
      await putRow('customer', customer.toJson());
      return customer;
    }
    final row = await rowById('customer', id);
    if (row == null) notFoundLocally('Cliente');
    await enqueue('customer', op, {'id': id});
    final merged = {...row, 'status': status, 'updated_at': nowIso()};
    await putRow('customer', merged);
    return Customer.fromJson(merged);
  }

  // =========================== subjects =================================

  @override
  Future<SubjectPage> listSubjects({
    String? q,
    String? customerId,
    String status = 'active',
  }) async {
    if (isOnline()) {
      final res = await inner.listSubjects(
        q: q,
        customerId: customerId,
        status: status,
      );
      await mirrorRows('subject', [for (final s in res.items) s.toJson()]);
      final merged = await mergePending(
        'subject',
        [for (final s in res.items) s.toJson()],
        keepExtra: (row) =>
            _matchesSubjectFilter(row, q: q, customerId: customerId, status: status),
      );
      return res.copyWith(
        items: [for (final row in merged) Subject.fromJson(row)],
        total: res.total + (merged.length - res.items.length),
      );
    }
    final all = await rows('subject');
    final filtered = all
        .where((row) => _matchesSubjectFilter(
              row,
              q: q,
              customerId: customerId,
              status: status,
            ))
        .toList();

    return SubjectPage(
      items: [for (final row in filtered) Subject.fromJson(row)],
      total: filtered.length,
      page: 1,
      // Página fixa (a interface não pagina subjects). NUNCA `filtered.length`:
      // com lista vazia daria pageSize 0 e um consumidor dividiria por zero.
      pageSize: _pageSize,
    );
  }

  bool _matchesSubjectFilter(
    Map<String, dynamic> row, {
    String? q,
    String? customerId,
    required String status,
  }) {
    final rowStatus = (row['status'] ?? 'active') as String;
    if (rowStatus == 'deleted') return false;
    if (status != 'all' && rowStatus != status) return false;
    if (customerId != null && row['customer_id'] != customerId) return false;
    if (q == null || q.isEmpty) return true;
    return matches(row['identifier'] as String?, q) ||
        matches(row['label'] as String?, q);
  }

  @override
  Future<Subject> createSubject(String customerId, SubjectDraft draft) async {
    if (isOnline()) {
      final subject = await inner.createSubject(customerId, draft);
      await putRow('subject', subject.toJson());
      return subject;
    }
    final id = newId();
    // `customerId` é chave estrutural da op `subject.create` (sync.registry.ts).
    await enqueue('subject', 'create', {
      'id': id,
      'customerId': customerId,
      ...draft.toJson(),
    });
    final row = <String, dynamic>{
      'id': id,
      'customer_id': customerId,
      'label': draft.label,
      'identifier': draft.identifier,
      'attributes': draft.attributes ?? <String, dynamic>{},
      'status': 'active',
      'created_at': nowIso(),
      'updated_at': nowIso(),
    };
    await putRow('subject', row);
    return Subject.fromJson(row);
  }

  @override
  Future<Subject> updateSubject(String id, SubjectDraft draft) async {
    if (!await useLocal('subject', id)) {
      final subject = await inner.updateSubject(id, draft);
      await putRow('subject', subject.toJson());
      return subject;
    }
    final row = await rowById('subject', id);
    if (row == null) notFoundLocally('Objeto');
    await enqueue('subject', 'update', {'id': id, ...draft.toJson()});
    final merged = {...row, ...draft.toJson(), 'updated_at': nowIso()};
    await putRow('subject', merged);
    return Subject.fromJson(merged);
  }

  @override
  Future<Subject> archiveSubject(String id) =>
      _subjectStatus(id, 'archive', 'archived', inner.archiveSubject);

  @override
  Future<Subject> unarchiveSubject(String id) =>
      _subjectStatus(id, 'unarchive', 'active', inner.unarchiveSubject);

  @override
  Future<Subject> deleteSubject(String id) =>
      _subjectStatus(id, 'delete', 'deleted', inner.deleteSubject);

  Future<Subject> _subjectStatus(
    String id,
    String op,
    String status,
    Future<Subject> Function(String id) online,
  ) async {
    if (!await useLocal('subject', id)) {
      final subject = await online(id);
      await putRow('subject', subject.toJson());
      return subject;
    }
    final row = await rowById('subject', id);
    if (row == null) notFoundLocally('Objeto');
    await enqueue('subject', op, {'id': id});
    final merged = {...row, 'status': status, 'updated_at': nowIso()};
    await putRow('subject', merged);
    return Subject.fromJson(merged);
  }

  /// Upload de foto — só online (não há op de sync para foto de subject).
  @override
  Future<Subject> setSubjectPhoto(
    String id, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    if (!isOnline()) requiresConnection('enviar a foto do veículo');
    if (await isDirty('subject', id)) pendingSync('Este veículo');
    final subject = await inner.setSubjectPhoto(
      id,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    await putRow('subject', subject.toJson());
    return subject;
  }

  @override
  Future<Subject> removeSubjectPhoto(String id) async {
    if (!isOnline()) requiresConnection('remover a foto do veículo');
    if (await isDirty('subject', id)) pendingSync('Este veículo');
    final subject = await inner.removeSubjectPhoto(id);
    await putRow('subject', subject.toJson());
    return subject;
  }

  // =========================== histórico ================================

  /// Offline o histórico é DERIVADO das OS espelhadas (`service_order`) — o dado
  /// está no row-store, então preferimos o local a lançar "Requer conexão".
  @override
  Future<List<SubjectHistoryEntry>> subjectHistory(String id) async {
    if (isOnline()) return inner.subjectHistory(id);
    final orders = await rows('service_order');
    return _historyFrom(orders.where((o) => o['subject_id'] == id));
  }

  @override
  Future<List<SubjectHistoryEntry>> customerHistory(
    String customerId, {
    String? subjectId,
  }) async {
    if (isOnline()) {
      return inner.customerHistory(customerId, subjectId: subjectId);
    }
    final orders = await rows('service_order');
    final doCliente = _historyFrom(
      orders.where(
        (o) =>
            o['customer_id'] == customerId &&
            (subjectId == null || o['subject_id'] == subjectId),
      ),
    );
    // Filtrando por VEÍCULO só entram OS: venda de balcão não é "do carro" e
    // apareceria repetida em todos eles (mesma regra do compositor no servidor).
    if (subjectId != null) return doCliente;

    // Vendas de balcão do cliente, do espelho de `sale` — o histórico dele não é
    // só OS: quem compra uma palheta no balcão gerou histórico igual.
    final vendas = [
      for (final v in await rows('sale'))
        if (v['customer_id'] == customerId)
          SubjectHistoryEntry(
            id: v['id'] as String,
            kind: 'sale',
            title: 'Venda ${v['number'] ?? ''}'.trim(),
            status: (v['status'] ?? 'active') as String,
            occurredAt:
                (v['created_at'] ?? v['updated_at'] ?? nowIso()) as String,
          ),
    ];
    return [...doCliente, ...vendas]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  List<SubjectHistoryEntry> _historyFrom(Iterable<Map<String, dynamic>> orders) {
    final entries = [
      for (final o in orders)
        SubjectHistoryEntry(
          id: o['id'] as String,
          kind: 'os',
          title: 'OS ${o['number'] ?? ''}'.trim(),
          status: (o['status'] ?? 'aberta') as String,
          occurredAt: (o['created_at'] ?? o['updated_at'] ?? nowIso()) as String,
          subjectId: o['subject_id'] as String?,
          subjectLabel: o['subject_label'] as String?,
        ),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return entries;
  }

  // ========================== lookups (FIPE) ============================

  /// Catálogo externo (FIPE) — vive no servidor; offline não há o que servir.
  @override
  Future<List<LookupOption>> lookup(
    String fonte, {
    String? marca,
    String? modelo,
    String? q,
  }) async {
    if (!isOnline()) requiresConnection('consultar a tabela de marcas/modelos');
    return inner.lookup(fonte, marca: marca, modelo: modelo, q: q);
  }

  /// Consulta de placa — token, cota e cache vivem no servidor; offline não
  /// há o que servir (o botão da UI já fica desabilitado, isto é o cinto).
  @override
  Future<PlateInfo> plateLookup(String plate) async {
    if (!isOnline()) requiresConnection('consultar a placa');
    return inner.plateLookup(plate);
  }

  @override
  Future<PlateQuota> plateUsage() async {
    if (!isOnline()) requiresConnection('consultar o uso de placas');
    return inner.plateUsage();
  }

  /// Consulta na Receita: vive no servidor, não há o que servir offline.
  @override
  Future<CnpjEmpresa> lookupCnpj(String cnpj) async {
    if (!isOnline()) requiresConnection('consultar o CNPJ');
    return inner.lookupCnpj(cnpj);
  }
}
