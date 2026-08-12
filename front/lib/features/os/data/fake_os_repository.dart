import '../../customers/domain/customers_models.dart';
import '../domain/os_models.dart';
import '../domain/os_repository.dart';

/// In-memory [OsRepository] for tests/offline. Mirrors the contract incl. the
/// status FSM (transição validada no backend; aqui só aplicamos) e os totais
/// recalculados a cada mutação de item.
class FakeOsRepository implements OsRepository {
  FakeOsRepository({
    List<ServiceOrder>? orders,
    List<InventoryOption>? inventory,
    List<CustomerOption>? customers,
    Map<String, List<SubjectOption>>? subjects,
    List<OsTemplate>? templates,
  })  : _orders = {for (final o in orders ?? const <ServiceOrder>[]) o.id: o},
        _inventory = inventory ?? const <InventoryOption>[],
        _customers = customers ?? const <CustomerOption>[],
        _subjects = subjects ?? const <String, List<SubjectOption>>{},
        _templates = {
          for (final t in templates ?? const <OsTemplate>[]) t.id: t
        };

  final Map<String, ServiceOrder> _orders;
  final List<InventoryOption> _inventory;
  final List<CustomerOption> _customers;
  final Map<String, List<SubjectOption>> _subjects;
  final Map<String, OsTemplate> _templates;
  int _seq = 0;
  int _itemSeq = 0;
  int _eventSeq = 0;
  int _photoSeq = 0;
  int _tplSeq = 0;

  /// Tamanho do lote — espelha o DEFAULT_PAGE_SIZE do backend (20).
  static const _pageSize = 20;

  @override
  Future<OrderPage> listOrders({
    String? q,
    String? status,
    List<String>? statuses,
    String? customerId,
    String sort = 'recent',
    int page = 1,
  }) async {
    final term = q?.toLowerCase();
    var list = _orders.values.where((o) => true);
    if (statuses != null && statuses.isNotEmpty) {
      list = list.where((o) => statuses.contains(o.status));
    } else if (status != null && status.isNotEmpty) {
      list = list.where((o) => o.status == status);
    }
    if (customerId != null && customerId.isNotEmpty) {
      list = list.where((o) => o.customerId == customerId);
    }
    if (term != null && term.isNotEmpty) {
      list = list.where((o) =>
          o.number.toLowerCase().contains(term) ||
          (o.customerName?.toLowerCase().contains(term) ?? false));
    }
    final all = list.toList()..sort(_comparatorFor(sort));
    final total = all.length;
    // Paginação por skip/take (mesma semântica do backend).
    final skip = (page - 1) * _pageSize;
    final items = skip >= total
        ? <ServiceOrder>[]
        : all.skip(skip).take(_pageSize).toList();
    return OrderPage(items: items, total: total, page: page, pageSize: _pageSize);
  }

  /// Comparador espelhando o sort do backend, com `id` como desempate final
  /// (paginação estável). Total/cliente nulos vão para o fim.
  int Function(ServiceOrder, ServiceOrder) _comparatorFor(String sort) {
    double total(ServiceOrder o) => double.tryParse(o.total ?? '') ?? 0;
    String customer(ServiceOrder o) => (o.customerName ?? '').toLowerCase();
    int byId(ServiceOrder a, ServiceOrder b) => a.id.compareTo(b.id);

    int Function(ServiceOrder, ServiceOrder) primary;
    switch (sort) {
      case 'oldest':
        // Sem created_at confiável no fake: aproxima por id crescente.
        primary = (a, b) => a.id.compareTo(b.id);
      case 'number_asc':
        primary = (a, b) =>
            a.number.toLowerCase().compareTo(b.number.toLowerCase());
      case 'number_desc':
        primary = (a, b) =>
            b.number.toLowerCase().compareTo(a.number.toLowerCase());
      case 'customer_asc':
        primary = (a, b) => customer(a).compareTo(customer(b));
      case 'customer_desc':
        primary = (a, b) => customer(b).compareTo(customer(a));
      case 'total_desc':
        primary = (a, b) => total(b).compareTo(total(a));
      case 'total_asc':
        primary = (a, b) => total(a).compareTo(total(b));
      case 'status':
        primary = (a, b) => a.status.compareTo(b.status);
      case 'recent':
      default:
        // Sem created_at no fake: aproxima por id decrescente (ordem de criação).
        primary = (a, b) => b.id.compareTo(a.id);
    }
    return (a, b) {
      final p = primary(a, b);
      return p != 0 ? p : byId(a, b);
    };
  }

  @override
  Future<ServiceOrder> getOrder(String id) async => _orders[id]!;

  @override
  Future<ServiceOrder> createOrder(OrderDraft d) async {
    final id = 'os-${_seq++}';
    final customer = _customers.where((c) => c.id == d.customerId);
    final subjects =
        _subjects[d.customerId ?? ''] ?? const <SubjectOption>[];
    final subject = d.subjectId == null
        ? null
        : subjects.where((s) => s.id == d.subjectId);
    // Cliente novo na hora: derivamos um retrato a partir dos campos do draft.
    final newSubjectLabel = d.newSubjectIdentifier ??
        [
          d.newSubjectAttributes?['marca'],
          d.newSubjectAttributes?['modelo'],
        ].whereType<String>().join(' ');
    final order = ServiceOrder(
      id: id,
      number: 'OS-${(_seq).toString().padLeft(4, '0')}',
      customerId: d.customerId ?? 'new-$_seq',
      customerName: d.newCustomerName ??
          (customer.isNotEmpty ? customer.first.name : null),
      subjectId: d.subjectId,
      subjectLabel: subject != null && subject.isNotEmpty
          ? (subject.first.label ?? subject.first.identifier)
          : (newSubjectLabel.isEmpty ? null : newSubjectLabel),
      complaint: d.complaint,
      diagnosis: d.diagnosis,
      scheduledStart: d.scheduledStart,
      scheduledEnd: d.scheduledEnd,
      assignedTo: d.assignedTo,
      discount: '0',
      total: '0',
    );
    _orders[id] = order;
    return order;
  }

  @override
  Future<ServiceOrder> updateOrder(String id, OrderPatch p) async {
    final cur = _orders[id]!;
    final next = cur.copyWith(
      complaint: p.complaint ?? cur.complaint,
      diagnosis: p.diagnosis ?? cur.diagnosis,
      scheduledStart: p.scheduledStart ?? cur.scheduledStart,
      scheduledEnd: p.scheduledEnd ?? cur.scheduledEnd,
      assignedTo: p.assignedTo ?? cur.assignedTo,
      discount: p.discount?.toString() ?? cur.discount,
    );
    final retotaled = _recalc(next);
    _orders[id] = retotaled;
    return retotaled;
  }

  @override
  Future<void> deleteOrder(String id) async {
    _orders.remove(id);
  }

  @override
  Future<ServiceOrder> changeStatus(String id, String status) async {
    final next = _orders[id]!.copyWith(status: status);
    _orders[id] = next;
    return next;
  }

  @override
  Future<ServiceOrder> emitInvoice(String id) async {
    // Fake: simula emissão bem-sucedida (snapshot 'emitida'). Não muda pagamento
    // nem status da OS. O Fiscal real é quem decide o status de verdade.
    final next = _orders[id]!.copyWith(fiscalStatus: 'emitida');
    _orders[id] = next;
    return next;
  }

  /// E-mail sugerido por OS (o que o "cadastro do cliente" teria). Vazio = sem
  /// e-mail cadastrado → a tela abre com o campo em branco.
  final Map<String, String> trackingEmails = {};

  /// Envios feitos, na ordem — os testes conferem PARA QUEM o link foi.
  final List<({String orderId, String email})> sentTrackingLinks = [];

  @override
  Future<String?> trackingRecipientEmail(String orderId) async =>
      trackingEmails[orderId];

  @override
  Future<void> sendTrackingLinkEmail(String orderId, String email) async {
    sentTrackingLinks.add((orderId: orderId, email: email));
  }

  @override
  Future<ServiceOrder> createNote(
    String id, {
    required String message,
    required bool visiblePublic,
  }) async {
    final cur = _orders[id]!;
    final event = OrderEvent(
      id: 'ev-${_eventSeq++}',
      kind: 'note',
      message: message,
      visiblePublic: visiblePublic,
      createdAt: DateTime.now().toIso8601String(),
    );
    // Mais recente primeiro (espelha o backend).
    final next = cur.copyWith(events: [event, ...cur.events]);
    _orders[id] = next;
    return next;
  }

  @override
  Future<ServiceOrder> addPhoto(
    String orderId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? caption,
  }) async {
    final cur = _orders[orderId]!;
    final photo = OrderPhoto(
      id: 'ph-${_photoSeq++}',
      url: 'https://example.test/files/$filename',
      caption: caption,
      createdAt: DateTime.now().toIso8601String(),
    );
    final next = cur.copyWith(photos: [...cur.photos, photo]);
    _orders[orderId] = next;
    return next;
  }

  @override
  Future<ServiceOrder> deletePhoto(String orderId, String photoId) async {
    final cur = _orders[orderId]!;
    final next = cur.copyWith(
      photos: cur.photos.where((p) => p.id != photoId).toList(),
    );
    _orders[orderId] = next;
    return next;
  }

  final Map<String, List<PhotoComment>> _photoComments = {};

  @override
  Future<List<PhotoComment>> listPhotoComments(
    String orderId,
    String photoId,
  ) async =>
      List.unmodifiable(_photoComments[photoId] ?? const []);

  @override
  Future<PhotoComment> addPhotoComment(
    String orderId,
    String photoId,
    String body,
  ) async {
    final c = PhotoComment(
      authorKind: 'staff',
      authorName: 'Equipe',
      body: body,
      createdAt: DateTime.now().toIso8601String(),
    );
    _photoComments[photoId] = [...?_photoComments[photoId], c];
    return c;
  }

  @override
  Future<List<OsTemplate>> listTemplates() async =>
      _templates.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<List<OsTemplate>> listTemplatesFull() => listTemplates();

  @override
  Future<OsTemplatePage> listTemplatesPage({
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final q = query?.trim().toLowerCase() ?? '';
    final all = _templates.values
        .where((t) =>
            q.isEmpty ||
            t.name.toLowerCase().contains(q) ||
            (t.description?.toLowerCase().contains(q) ?? false))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final start = (page - 1) * pageSize;
    final items = start >= all.length
        ? <OsTemplate>[]
        : all.sublist(start, (start + pageSize).clamp(0, all.length));
    return OsTemplatePage(
      items: items,
      total: all.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<OsTemplate> getTemplate(String id) async => _templates[id]!;

  @override
  Future<OsTemplate> createTemplate(OsTemplateDraft draft) async {
    final id = 'tpl-${_tplSeq++}';
    final template = OsTemplate(
      id: id,
      name: draft.name,
      description: draft.description,
      items: _draftItems(draft.items),
    );
    _templates[id] = template;
    return template;
  }

  @override
  Future<OsTemplate> updateTemplate(String id, OsTemplateDraft draft) async {
    final next = OsTemplate(
      id: id,
      name: draft.name,
      description: draft.description,
      items: _draftItems(draft.items),
    );
    _templates[id] = next;
    return next;
  }

  @override
  Future<void> deleteTemplate(String id) async {
    _templates.remove(id);
  }

  List<OsTemplateItem> _draftItems(List<OsTemplateItemDraft> drafts) {
    return [
      for (final d in drafts)
        OsTemplateItem(
          id: 'ti-${_itemSeq++}',
          kind: d.kind,
          inventoryItemId: d.inventoryItemId,
          name: d.name ?? _inventoryName(d.inventoryItemId),
          quantity: (d.quantity ?? 1).toString(),
          unitPrice: d.unitPrice?.toString(),
        ),
    ];
  }

  String _inventoryName(String? inventoryItemId) {
    if (inventoryItemId == null) return 'Item';
    final match = _inventory.where((i) => i.id == inventoryItemId);
    return match.isNotEmpty ? match.first.name : 'Item';
  }

  @override
  Future<ServiceOrder> applyTemplate(String orderId, String templateId) async {
    final cur = _orders[orderId]!;
    final item = OrderItem(
      id: 'oi-${_itemSeq++}',
      kind: 'service',
      name: 'Item do template',
      quantity: '1',
      unitPrice: '100',
      discount: '0',
      total: '100',
    );
    final next = _recalc(cur.copyWith(items: [...cur.items, item]));
    _orders[orderId] = next;
    return next;
  }

  @override
  Future<ServiceOrder> addItem(String id, OrderItemDraft d) async {
    final cur = _orders[id]!;
    final inv = d.inventoryItemId == null
        ? null
        : _inventory.where((i) => i.id == d.inventoryItemId);
    final name = d.name ??
        (inv != null && inv.isNotEmpty ? inv.first.name : 'Item');
    final unitPrice = d.unitPrice ??
        (inv != null && inv.isNotEmpty
            ? double.tryParse(inv.first.salePrice ?? '0') ?? 0
            : 0);
    final qty = d.quantity ?? 1;
    final disc = d.discount ?? 0;
    final total = qty * unitPrice - disc;
    final item = OrderItem(
      id: 'oi-${_itemSeq++}',
      kind: d.kind,
      inventoryItemId: d.inventoryItemId,
      name: name,
      quantity: qty.toString(),
      unitPrice: unitPrice.toString(),
      discount: disc.toString(),
      total: total.toString(),
    );
    final next = _recalc(cur.copyWith(items: [...cur.items, item]));
    _orders[id] = next;
    return next;
  }

  @override
  Future<ServiceOrder> updateItem(
    String id,
    String itemId,
    OrderItemPatch p,
  ) async {
    final cur = _orders[id]!;
    final items = cur.items.map((it) {
      if (it.id != itemId) return it;
      final qty = p.quantity ?? double.tryParse(it.quantity) ?? 1;
      final unit = p.unitPrice ?? double.tryParse(it.unitPrice) ?? 0;
      final disc = p.discount ?? double.tryParse(it.discount) ?? 0;
      return it.copyWith(
        quantity: qty.toString(),
        unitPrice: unit.toString(),
        discount: disc.toString(),
        total: (qty * unit - disc).toString(),
      );
    }).toList();
    final next = _recalc(cur.copyWith(items: items));
    _orders[id] = next;
    return next;
  }

  @override
  Future<ServiceOrder> deleteItem(String id, String itemId) async {
    final cur = _orders[id]!;
    final next = _recalc(
      cur.copyWith(items: cur.items.where((it) => it.id != itemId).toList()),
    );
    _orders[id] = next;
    return next;
  }

  /// Recalcula o total da OS: soma dos itens menos o desconto da OS.
  ServiceOrder _recalc(ServiceOrder o) {
    final itemsTotal = o.items.fold<double>(
      0,
      (acc, it) => acc + (double.tryParse(it.total) ?? 0),
    );
    final discount = double.tryParse(o.discount ?? '0') ?? 0;
    return o.copyWith(total: (itemsTotal - discount).toString());
  }

  @override
  Future<List<InventoryOption>> searchInventory(String q) async {
    if (q.isEmpty) return _inventory;
    final term = q.toLowerCase();
    return _inventory.where((i) => i.name.toLowerCase().contains(term)).toList();
  }

  @override
  Future<List<CustomerOption>> searchCustomers(String q) async {
    if (q.isEmpty) return _customers;
    final term = q.toLowerCase();
    return _customers.where((c) => c.name.toLowerCase().contains(term)).toList();
  }

  @override
  Future<List<SubjectOption>> subjectsOf(String customerId) async =>
      _subjects[customerId] ?? const <SubjectOption>[];

  @override
  Future<List<MemberOption>> listMembers() async => const [
        MemberOption(
            id: '11111111-1111-1111-1111-111111111111', name: 'Ana Mecânica'),
        MemberOption(
            id: '22222222-2222-2222-2222-222222222222', name: 'Bruno Funilaria'),
      ];

  @override
  Future<CustomersConfig> customersConfig() async => const CustomersConfig(
        subjectFields: [
          SubjectFieldConfig(
              chave: 'identifier', rotulo: 'Placa / Identificação'),
          SubjectFieldConfig(
              chave: 'marca', rotulo: 'Marca', fonte: 'fipe.marcas'),
          SubjectFieldConfig(
              chave: 'modelo',
              rotulo: 'Modelo',
              fonte: 'fipe.modelos',
              dependeDe: 'marca'),
          SubjectFieldConfig(
              chave: 'ano',
              rotulo: 'Ano',
              tipo: 'number',
              fonte: 'fipe.anos',
              dependeDe: 'modelo'),
          SubjectFieldConfig(chave: 'cor', rotulo: 'Cor'),
        ],
      );

  @override
  Future<List<LookupOption>> lookup(
    String fonte, {
    String? marca,
    String? modelo,
    String? q,
  }) async {
    const byFonte = <String, List<LookupOption>>{
      'fipe.marcas': [
        LookupOption(value: 'Fiat', label: 'Fiat', meta: {'codigo': '21'}),
        LookupOption(
            value: 'Volkswagen',
            label: 'Volkswagen',
            meta: {'codigo': '59'}),
      ],
      'fipe.modelos': [
        LookupOption(value: 'Uno', label: 'Uno', meta: {'codigo': '1'}),
        LookupOption(value: 'Palio', label: 'Palio', meta: {'codigo': '2'}),
      ],
      'fipe.anos': [
        LookupOption(value: '2020', label: '2020', meta: {'codigo': '2020-1'}),
        LookupOption(value: '2021', label: '2021', meta: {'codigo': '2021-1'}),
      ],
    };
    final all = byFonte[fonte] ?? const <LookupOption>[];
    if (q == null || q.trim().isEmpty) return all;
    final term = q.toLowerCase();
    return all.where((o) => o.value.toLowerCase().contains(term)).toList();
  }
}
