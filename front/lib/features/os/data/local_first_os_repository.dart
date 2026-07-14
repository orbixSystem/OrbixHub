import 'dart:typed_data';

import '../../../core/offline/local_first.dart';
import '../../customers/domain/customers_models.dart';
import '../domain/os_models.dart';
import '../domain/os_repository.dart';

/// [OsRepository] offline-first (B8) — decorator sobre a impl real (dio).
///
/// Entidades espelhadas: `service_order`, `service_order_item`,
/// `service_order_event`, `service_order_photo`, `service_order_template`
/// (+ `customer`/`subject`/`inventory_item`, só lidas pelos pickers).
///
/// Específicos:
/// - **OS criada offline** ganha um número PROVISÓRIO `OS-P<n>` (o servidor
///   atribui o definitivo no replay; o B9 badgeia "pendente de envio").
/// - **Cliente novo na hora** (sem `customerId`): geramos o uuid do cliente (e do
///   veículo) aqui e enfileiramos `customer.create`/`subject.create` ANTES do
///   `service_order.create` — a ordem do outbox (`seq`) garante o replay correto.
/// - **Fotos**: BLOB em `PendingUploads` (S6) + linha de foto otimista; o
///   SyncEngine sobe o arquivo depois que a OS existir no servidor.
///
/// Offline lançam "Requer conexão" (sem op de sync / dado só do servidor):
/// `deleteOrder`, `emitInvoice`, `deletePhoto`, `listPhotoComments`,
/// `addPhotoComment`, `createTemplate`, `updateTemplate`, `deleteTemplate`,
/// `listMembers`, `lookup` (FIPE).
class LocalFirstOsRepository extends LocalFirstBase implements OsRepository {
  LocalFirstOsRepository({
    required this.inner,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final OsRepository inner;

  static const _orders = 'service_order';
  static const _items = 'service_order_item';
  static const _events = 'service_order_event';
  static const _photos = 'service_order_photo';
  static const _templates = 'service_order_template';
  static const _pageSize = 20;

  // ======================= espelho / montagem ===========================

  /// Espelha uma OS completa: o cabeçalho + itens/eventos/fotos (que no row-store
  /// vivem em entidades próprias, como no pull). Uma OS SUJA (mutação local ainda
  /// na fila) não é espelhada: a cópia do servidor é mais VELHA que a local.
  Future<void> _mirrorOrder(ServiceOrder order) async {
    if (await isDirty(_orders, order.id)) return;
    final header = {...order.toJson()}
      ..remove('items')
      ..remove('events')
      ..remove('photos');
    await putRow(_orders, header);
    await putRows(_items, [
      for (final i in order.items) {...i.toJson(), 'order_id': order.id},
    ]);
    await putRows(_events, [
      for (final e in order.events) {...e.toJson(), 'order_id': order.id},
    ]);
    await putRows(_photos, [
      for (final p in order.photos) {...p.toJson(), 'order_id': order.id},
    ]);
    await _pruneReplayedChildren(order.id);
  }

  /// **Poda dos filhos fantasma.** Itens/eventos/fotos criados offline recebem um
  /// uuid LOCAL que o servidor NÃO preserva no replay (`service_order.addItem`
  /// gera o id lá) — e o pull é um upsert que nunca remove nada. Sem esta poda, a
  /// linha local e a cópia do servidor conviveriam para sempre: item duplicado e
  /// total dobrado.
  ///
  /// Assim que a OS deixa de estar suja (nenhuma mutação dela pendente/falha ⇒ o
  /// servidor já aplicou tudo e o pull traz as cópias boas), apagamos as linhas
  /// marcadas com [LocalFirstBase.localOnlyKey]. Fotos ainda na fila de upload
  /// (S6) são preservadas — elas ainda não existem no servidor.
  Future<void> _pruneReplayedChildren(String orderId) async {
    if (await isDirty(_orders, orderId)) return;
    final pendingPhotoIds = {
      for (final up in await db.listPendingUploads()) up.id,
    };
    for (final entity in const [_items, _events, _photos]) {
      for (final row in await rows(entity)) {
        if (row['order_id'] != orderId || !isLocalOnly(row)) continue;
        final id = row['id'] as String;
        if (entity == _photos && pendingPhotoIds.contains(id)) continue;
        await removeRow(entity, id);
      }
    }
  }

  /// Monta a OS a partir do row-store (cabeçalho + filhos por `order_id`), depois
  /// de podar os filhos locais já reaplicados pelo servidor.
  Future<ServiceOrder> _assemble(Map<String, dynamic> header) async {
    final id = header['id'] as String;
    await _pruneReplayedChildren(id);
    final items = (await rows(_items)).where((r) => r['order_id'] == id).toList()
      ..sort((a, b) => _createdOf(a).compareTo(_createdOf(b)));
    final events = (await rows(_events)).where((r) => r['order_id'] == id).toList()
      ..sort((a, b) => _createdOf(b).compareTo(_createdOf(a))); // recente 1º
    final photos = (await rows(_photos)).where((r) => r['order_id'] == id).toList()
      ..sort((a, b) => _createdOf(b).compareTo(_createdOf(a)));
    return ServiceOrder.fromJson({
      ...header,
      'items': items,
      'events': events,
      'photos': photos,
    });
  }

  String _createdOf(Map<String, dynamic> row) =>
      (row['created_at'] ?? '') as String;

  Future<Map<String, dynamic>> _orderRow(String id) async {
    final row = await rowById(_orders, id);
    if (row == null) notFoundLocally('Ordem de serviço');
    return row;
  }

  /// Recalcula o total da OS local a partir dos itens espelhados (o servidor faz
  /// o mesmo no replay — isto é só para a tela não mostrar zero).
  Future<Map<String, dynamic>> _recalcTotal(Map<String, dynamic> header) async {
    final id = header['id'] as String;
    final items = (await rows(_items)).where((r) => r['order_id'] == id);
    var sum = 0.0;
    for (final i in items) {
      sum += toNum(i['total']).toDouble();
    }
    final discount = toNum(header['discount']).toDouble();
    final total = (sum - discount).clamp(0, double.infinity).toDouble();
    final updated = {...header, 'total': dec(total), 'updated_at': nowIso()};
    await putRow(_orders, updated);
    return updated;
  }

  // ============================ orders ==================================

  @override
  Future<OrderPage> listOrders({
    String? q,
    String? status,
    String? customerId,
    String sort = 'recent',
    int page = 1,
  }) async {
    if (isOnline()) {
      final res = await inner.listOrders(
        q: q,
        status: status,
        customerId: customerId,
        sort: sort,
        page: page,
      );
      for (final o in res.items) {
        await _mirrorOrder(o); // pula as sujas (a local é mais nova)
      }
      // OS criada offline (create ainda na fila) continua aparecendo na lista —
      // senão a `OS-P1` sumiria da tela assim que a rede voltasse.
      final merged = await mergePending(
        _orders,
        [for (final o in res.items) o.toJson()],
        includeExtras: page == 1, // extras só na 1ª página
        keepExtra: (row) => _matchesOrderFilter(
          row,
          q: q,
          status: status,
          customerId: customerId,
        ),
      );
      return res.copyWith(
        items: [for (final row in merged) ServiceOrder.fromJson(row)],
        total: res.total + (merged.length - res.items.length),
      );
    }

    final filtered = (await rows(_orders))
        .where((row) => _matchesOrderFilter(
              row,
              q: q,
              status: status,
              customerId: customerId,
            ))
        .toList();

    filtered.sort((a, b) {
      switch (sort) {
        case 'oldest':
          return _createdOf(a).compareTo(_createdOf(b));
        case 'number_asc':
          return ((a['number'] ?? '') as String)
              .compareTo((b['number'] ?? '') as String);
        case 'number_desc':
          return ((b['number'] ?? '') as String)
              .compareTo((a['number'] ?? '') as String);
        case 'total_desc':
          return toNum(b['total']).compareTo(toNum(a['total']));
        case 'total_asc':
          return toNum(a['total']).compareTo(toNum(b['total']));
        case 'recent':
        default:
          return _createdOf(b).compareTo(_createdOf(a));
      }
    });

    return OrderPage(
      items: [
        for (final row in pageOf(filtered, page, _pageSize))
          ServiceOrder.fromJson(row),
      ],
      total: filtered.length,
      page: page,
      pageSize: _pageSize,
    );
  }

  /// Filtro da lista de OS — usado offline e para decidir se uma OS criada
  /// offline entra no resultado online.
  bool _matchesOrderFilter(
    Map<String, dynamic> row, {
    String? q,
    String? status,
    String? customerId,
  }) {
    if (status != null && status.isNotEmpty && row['status'] != status) {
      return false;
    }
    if (customerId != null &&
        customerId.isNotEmpty &&
        row['customer_id'] != customerId) {
      return false;
    }
    if (q == null || q.isEmpty) return true;
    return matches(row['number'] as String?, q) ||
        matches(row['customer_name'] as String?, q) ||
        matches(row['subject_label'] as String?, q);
  }

  @override
  Future<ServiceOrder> getOrder(String id) async {
    if (!await useLocal(_orders, id)) {
      final order = await inner.getOrder(id);
      await _mirrorOrder(order);
      return order;
    }
    return _assemble(await _orderRow(id));
  }

  /// Número provisório da OS criada offline: `OS-P1`, `OS-P2`, … (contador local
  /// sobre as OS provisórias já espelhadas). O servidor atribui o número real no
  /// replay — o pull traz a linha corrigida.
  Future<String> _provisionalNumber() async {
    var max = 0;
    for (final row in await rows(_orders)) {
      final number = row['number'];
      if (number is! String || !number.startsWith('OS-P')) continue;
      final n = int.tryParse(number.substring(4)) ?? 0;
      if (n > max) max = n;
    }
    return 'OS-P${max + 1}';
  }

  @override
  Future<ServiceOrder> createOrder(OrderDraft draft) async {
    if (isOnline()) {
      final order = await inner.createOrder(draft);
      await _mirrorOrder(order);
      return order;
    }

    var customerId = draft.customerId;
    var customerName = '';
    String? subjectId = draft.subjectId;
    String? subjectLabel;

    if (customerId == null) {
      // "Cliente novo na hora": criamos o cliente (e o veículo) como mutações
      // próprias, ANTES da OS — o `seq` do outbox preserva essa ordem no replay.
      customerId = newId();
      customerName = draft.newCustomerName ?? '';
      await enqueue('customer', 'create', {
        'id': customerId,
        'name': customerName,
        if (draft.newCustomerPhone != null) 'phone': draft.newCustomerPhone,
      });
      await putRow('customer', {
        'id': customerId,
        'name': customerName,
        'type': 'PF',
        'phone': draft.newCustomerPhone,
        'status': 'active',
        'created_at': nowIso(),
        'updated_at': nowIso(),
      });
      if (draft.newSubjectIdentifier != null ||
          (draft.newSubjectAttributes?.isNotEmpty ?? false)) {
        subjectId = newId();
        subjectLabel = draft.newSubjectIdentifier;
        await enqueue('subject', 'create', {
          'id': subjectId,
          'customerId': customerId,
          if (draft.newSubjectIdentifier != null)
            'identifier': draft.newSubjectIdentifier,
          if (draft.newSubjectAttributes != null)
            'attributes': draft.newSubjectAttributes,
        });
        await putRow('subject', {
          'id': subjectId,
          'customer_id': customerId,
          'identifier': draft.newSubjectIdentifier,
          'attributes': draft.newSubjectAttributes ?? <String, dynamic>{},
          'status': 'active',
          'created_at': nowIso(),
          'updated_at': nowIso(),
        });
      }
    } else {
      customerName =
          ((await rowById('customer', customerId))?['name'] ?? '') as String;
      if (subjectId != null) {
        final subject = await rowById('subject', subjectId);
        subjectLabel =
            (subject?['identifier'] ?? subject?['label']) as String?;
      }
    }

    final id = newId();
    await enqueue(_orders, 'create', {
      'id': id,
      'customerId': customerId,
      'subjectId': ?subjectId,
      if (draft.complaint != null) 'complaint': draft.complaint,
      if (draft.diagnosis != null) 'diagnosis': draft.diagnosis,
      if (draft.scheduledStart != null) 'scheduledStart': draft.scheduledStart,
      if (draft.scheduledEnd != null) 'scheduledEnd': draft.scheduledEnd,
      if (draft.assignedTo != null) 'assignedTo': draft.assignedTo,
    });

    final header = <String, dynamic>{
      'id': id,
      'number': await _provisionalNumber(),
      'customer_id': customerId,
      'customer_name': customerName,
      'subject_id': subjectId,
      'subject_label': subjectLabel,
      'status': 'aberta',
      'assigned_to': draft.assignedTo,
      'complaint': draft.complaint,
      'diagnosis': draft.diagnosis,
      'scheduled_start': draft.scheduledStart,
      'scheduled_end': draft.scheduledEnd,
      'discount': '0.00',
      'total': '0.00',
      'payment_status': 'a_receber',
      'created_at': nowIso(),
      'updated_at': nowIso(),
    };
    await putRow(_orders, header);
    await _addEvent(id, kind: 'created', message: 'OS criada (offline)');
    return _assemble(header);
  }

  Future<void> _addEvent(
    String orderId, {
    required String kind,
    String? message,
    String? statusSnapshot,
    bool visiblePublic = false,
    String? id,
  }) =>
      putRow(_events, {
        'id': id ?? newId(),
        'order_id': orderId,
        LocalFirstBase.localOnlyKey: true, // podado quando o servidor replicar
        'kind': kind,
        'message': message,
        'status_snapshot': statusSnapshot,
        'visible_public': visiblePublic,
        'created_at': nowIso(),
      });

  @override
  Future<ServiceOrder> updateOrder(String id, OrderPatch patch) async {
    if (!await useLocal(_orders, id)) {
      final order = await inner.updateOrder(id, patch);
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(id);
    await enqueue(_orders, 'update', {'id': id, ...patch.toJson()});
    final merged = {
      ...header,
      if (patch.complaint != null) 'complaint': patch.complaint,
      if (patch.diagnosis != null) 'diagnosis': patch.diagnosis,
      if (patch.scheduledStart != null) 'scheduled_start': patch.scheduledStart,
      if (patch.scheduledEnd != null) 'scheduled_end': patch.scheduledEnd,
      if (patch.assignedTo != null) 'assigned_to': patch.assignedTo,
      if (patch.discount != null) 'discount': dec(patch.discount),
      'updated_at': nowIso(),
    };
    await putRow(_orders, merged);
    return _assemble(await _recalcTotal(merged));
  }

  /// Não há op de sync `service_order.delete` — excluir OS exige conexão.
  @override
  Future<void> deleteOrder(String id) async {
    if (!isOnline()) requiresConnection('excluir a OS');
    if (await isDirty(_orders, id)) pendingSync('Esta OS');
    await inner.deleteOrder(id);
    await removeRow(_orders, id);
  }

  @override
  Future<ServiceOrder> changeStatus(String id, String status) async {
    if (!await useLocal(_orders, id)) {
      final order = await inner.changeStatus(id, status);
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(id);
    await enqueue(_orders, 'changeStatus', {'id': id, 'status': status});
    final merged = {...header, 'status': status, 'updated_at': nowIso()};
    await putRow(_orders, merged);
    await _addEvent(id, kind: 'status_change', statusSnapshot: status);
    return _assemble(merged);
  }

  /// Emissão fiscal fala com o gateway do servidor — sempre online.
  @override
  Future<ServiceOrder> emitInvoice(String id) async {
    if (!isOnline()) requiresConnection('emitir a nota fiscal');
    if (await isDirty(_orders, id)) pendingSync('Esta OS');
    final order = await inner.emitInvoice(id);
    await _mirrorOrder(order);
    return order;
  }

  @override
  Future<ServiceOrder> createNote(
    String id, {
    required String message,
    required bool visiblePublic,
  }) async {
    if (!await useLocal(_orders, id)) {
      final order = await inner.createNote(
        id,
        message: message,
        visiblePublic: visiblePublic,
      );
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(id);
    await enqueue(_orders, 'createNote', {
      'id': id,
      'message': message,
      'visiblePublic': visiblePublic,
    });
    await _addEvent(
      id,
      kind: 'note',
      message: message,
      visiblePublic: visiblePublic,
    );
    return _assemble(header);
  }

  // ============================= fotos ==================================

  /// Offline a foto vira BLOB no banco cifrado (S6, `PendingUploads`) + uma linha
  /// de foto otimista (sem `url` — o B9 mostra "pendente de envio"). O SyncEngine
  /// sobe o arquivo assim que a OS existir no servidor.
  @override
  Future<ServiceOrder> addPhoto(
    String orderId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? caption,
  }) async {
    if (!await useLocal(_orders, orderId)) {
      final order = await inner.addPhoto(
        orderId,
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        caption: caption,
      );
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(orderId);
    final photoId = newId();
    await db.addPendingUpload(
      id: photoId,
      orderId: orderId,
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      contentType: contentType,
      caption: caption,
    );
    await putRow(_photos, {
      'id': photoId,
      'order_id': orderId,
      LocalFirstBase.localOnlyKey: true,
      'url': '', // sem url até o upload; a UI (B9) trata como pendente
      'caption': caption,
      'comment_count': 0,
      'created_at': nowIso(),
    });
    await _addEvent(orderId, kind: 'photo', message: caption);
    onWrite?.call(); // cutuca o engine (o blob não passa pelo outbox)
    return _assemble(header);
  }

  /// Não há op de sync para remover foto — exige conexão.
  @override
  Future<ServiceOrder> deletePhoto(String orderId, String photoId) async {
    if (!isOnline()) requiresConnection('remover a foto');
    if (await isDirty(_orders, orderId)) pendingSync('Esta OS');
    final order = await inner.deletePhoto(orderId, photoId);
    await _mirrorOrder(order);
    return order;
  }

  @override
  Future<List<PhotoComment>> listPhotoComments(
    String orderId,
    String photoId,
  ) async {
    if (!isOnline()) requiresConnection('ver os comentários da foto');
    if (await isDirty(_orders, orderId)) pendingSync('Esta OS');
    return inner.listPhotoComments(orderId, photoId);
  }

  @override
  Future<PhotoComment> addPhotoComment(
    String orderId,
    String photoId,
    String body,
  ) async {
    if (!isOnline()) requiresConnection('comentar na foto');
    if (await isDirty(_orders, orderId)) pendingSync('Esta OS');
    return inner.addPhotoComment(orderId, photoId, body);
  }

  // =========================== templates ================================

  @override
  Future<List<OsTemplate>> listTemplates() async {
    if (isOnline()) {
      final list = await inner.listTemplates();
      await putRows(_templates, [for (final t in list) t.toJson()]);
      return list;
    }
    final list = (await rows(_templates)).map(OsTemplate.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<List<OsTemplate>> listTemplatesFull() => listTemplates();

  @override
  Future<OsTemplatePage> listTemplatesPage({
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (isOnline()) {
      final res = await inner.listTemplatesPage(
        query: query,
        page: page,
        pageSize: pageSize,
      );
      await putRows(_templates, [for (final t in res.items) t.toJson()]);
      return res;
    }
    final q = query?.trim() ?? '';
    final all = (await listTemplates())
        .where((t) => q.isEmpty || matches(t.name, q) || matches(t.description, q))
        .toList();
    return OsTemplatePage(
      items: pageOf(all, page, pageSize),
      total: all.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<OsTemplate> getTemplate(String id) async {
    if (isOnline()) {
      final template = await inner.getTemplate(id);
      await putRow(_templates, template.toJson());
      return template;
    }
    final row = await rowById(_templates, id);
    if (row == null) notFoundLocally('Template');
    return OsTemplate.fromJson(row);
  }

  /// CRUD de template não tem op de sync — exige conexão.
  @override
  Future<OsTemplate> createTemplate(OsTemplateDraft draft) async {
    if (!isOnline()) requiresConnection('criar um template');
    final template = await inner.createTemplate(draft);
    await putRow(_templates, template.toJson());
    return template;
  }

  @override
  Future<OsTemplate> updateTemplate(String id, OsTemplateDraft draft) async {
    if (!isOnline()) requiresConnection('editar um template');
    final template = await inner.updateTemplate(id, draft);
    await putRow(_templates, template.toJson());
    return template;
  }

  @override
  Future<void> deleteTemplate(String id) async {
    if (!isOnline()) requiresConnection('excluir um template');
    await inner.deleteTemplate(id);
    await removeRow(_templates, id);
  }

  /// Offline montamos os itens a partir do template ESPELHADO (preço corrente do
  /// estoque local quando o item aponta para o catálogo) e enfileiramos
  /// `service_order.applyTemplate` — o servidor refaz a mesma expansão no replay.
  @override
  Future<ServiceOrder> applyTemplate(String orderId, String templateId) async {
    if (!await useLocal(_orders, orderId)) {
      final order = await inner.applyTemplate(orderId, templateId);
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(orderId);
    final templateRow = await rowById(_templates, templateId);
    if (templateRow == null) notFoundLocally('Template');
    final template = OsTemplate.fromJson(templateRow);

    await enqueue(_orders, 'applyTemplate', {
      'id': orderId,
      'templateId': templateId,
    });

    for (final item in template.items) {
      final price = await _unitPriceOf(item.inventoryItemId, item.unitPrice);
      await _putItem(
        orderId,
        kind: item.kind,
        inventoryItemId: item.inventoryItemId,
        name: item.name,
        quantity: toNum(item.quantity).toDouble(),
        unitPrice: price,
        discount: 0,
      );
    }
    return _assemble(await _recalcTotal(header));
  }

  Future<double> _unitPriceOf(String? inventoryItemId, String? fallback) async {
    if (inventoryItemId != null) {
      final item = await rowById('inventory_item', inventoryItemId);
      if (item != null) return toNum(item['sale_price']).toDouble();
    }
    return toNum(fallback).toDouble();
  }

  // ============================= itens ==================================

  /// Grava um item de OS otimista. O id local NÃO sobrevive ao replay (o servidor
  /// gera o dele — ver `service_order.addItem` no registry); o pull reconcilia.
  Future<void> _putItem(
    String orderId, {
    required String kind,
    String? inventoryItemId,
    required String name,
    required double quantity,
    required double unitPrice,
    required double discount,
  }) async {
    final total = (quantity * unitPrice) - discount;
    await putRow(_items, {
      'id': newId(),
      'order_id': orderId,
      LocalFirstBase.localOnlyKey: true, // o servidor gera OUTRO id no replay
      'kind': kind,
      'inventory_item_id': inventoryItemId,
      'name': name,
      'quantity': quantity.toString(),
      'unit_price': dec(unitPrice),
      'discount': dec(discount),
      'total': dec(total < 0 ? 0 : total),
      'created_at': nowIso(),
    });
  }

  @override
  Future<ServiceOrder> addItem(String id, OrderItemDraft draft) async {
    if (!await useLocal(_orders, id)) {
      final order = await inner.addItem(id, draft);
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(id);
    await enqueue(_orders, 'addItem', {'id': id, ...draft.toJson()});

    var name = draft.name ?? '';
    var unitPrice = draft.unitPrice ?? 0;
    if (draft.inventoryItemId != null) {
      final item = await rowById('inventory_item', draft.inventoryItemId!);
      if (item != null) {
        if (name.isEmpty) name = (item['name'] ?? '') as String;
        if (draft.unitPrice == null) {
          unitPrice = toNum(item['sale_price']).toDouble();
        }
      }
    }
    await _putItem(
      id,
      kind: draft.kind,
      inventoryItemId: draft.inventoryItemId,
      name: name,
      quantity: draft.quantity ?? 1,
      unitPrice: unitPrice.toDouble(),
      discount: draft.discount ?? 0,
    );
    return _assemble(await _recalcTotal(header));
  }

  @override
  Future<ServiceOrder> updateItem(
    String id,
    String itemId,
    OrderItemPatch patch,
  ) async {
    if (!await useLocal(_orders, id)) {
      final order = await inner.updateItem(id, itemId, patch);
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(id);
    final row = await rowById(_items, itemId);
    if (row == null) notFoundLocally('Item da OS');
    await enqueue(_orders, 'updateItem', {
      'id': id,
      'itemId': itemId,
      ...patch.toJson(),
    });
    final quantity = patch.quantity ?? toNum(row['quantity']).toDouble();
    final unitPrice = patch.unitPrice ?? toNum(row['unit_price']).toDouble();
    final discount = patch.discount ?? toNum(row['discount']).toDouble();
    final total = (quantity * unitPrice) - discount;
    await putRow(_items, {
      ...row,
      'quantity': quantity.toString(),
      'unit_price': dec(unitPrice),
      'discount': dec(discount),
      'total': dec(total < 0 ? 0 : total),
    });
    return _assemble(await _recalcTotal(header));
  }

  @override
  Future<ServiceOrder> deleteItem(String id, String itemId) async {
    if (!await useLocal(_orders, id)) {
      final order = await inner.deleteItem(id, itemId);
      await _mirrorOrder(order);
      return order;
    }
    final header = await _orderRow(id);
    await enqueue(_orders, 'deleteItem', {'id': id, 'itemId': itemId});
    await removeRow(_items, itemId);
    return _assemble(await _recalcTotal(header));
  }

  // ============================ pickers =================================

  /// Pickers offline saem do row-store (os dados estão lá — preferimos o local a
  /// lançar "Requer conexão").
  @override
  Future<List<InventoryOption>> searchInventory(String q) async {
    if (isOnline()) return inner.searchInventory(q);
    return [
      for (final row in await rows('inventory_item'))
        if ((row['is_active'] as bool? ?? true) &&
            (q.isEmpty ||
                matches(row['name'] as String?, q) ||
                matches(row['sku'] as String?, q)))
          InventoryOption.fromJson(row),
    ];
  }

  @override
  Future<List<CustomerOption>> searchCustomers(String q) async {
    if (isOnline()) return inner.searchCustomers(q);
    return [
      for (final row in await rows('customer'))
        if ((row['status'] ?? 'active') == 'active' &&
            (q.isEmpty ||
                matches(row['name'] as String?, q) ||
                matches(row['document'] as String?, q) ||
                matches(row['phone'] as String?, q)))
          CustomerOption.fromJson(row),
    ];
  }

  @override
  Future<List<SubjectOption>> subjectsOf(String customerId) async {
    if (isOnline()) return inner.subjectsOf(customerId);
    return [
      for (final row in await rows('subject'))
        if (row['customer_id'] == customerId &&
            (row['status'] ?? 'active') == 'active')
          SubjectOption.fromJson(row),
    ];
  }

  /// A equipe (`/employees/assignable`) não é entidade replicada — exige conexão.
  @override
  Future<List<MemberOption>> listMembers() async {
    if (!isOnline()) requiresConnection('carregar a lista de responsáveis');
    return inner.listMembers();
  }

  @override
  Future<CustomersConfig> customersConfig() async {
    if (isOnline()) {
      final config = await inner.customersConfig();
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
    if (cached == null) return const CustomersConfig();
    return CustomersConfig.fromJson(cached);
  }

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
}
