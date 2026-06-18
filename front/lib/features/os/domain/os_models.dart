import 'package:freezed_annotation/freezed_annotation.dart';

part 'os_models.freezed.dart';
part 'os_models.g.dart';

/// Item de uma ordem de serviço. `kind ∈ product|service`. Pode apontar para um
/// item do estoque (`inventoryItemId`) — guardamos só o id + um *snapshot* do
/// nome/preço no momento da adição ("aponta, não invade"). Decimais como String.
@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String id,
    @Default('product') String kind, // 'product' | 'service'
    @JsonKey(name: 'inventory_item_id') String? inventoryItemId,
    required String name,
    @Default('1') String quantity,
    @JsonKey(name: 'unit_price') @Default('0') String unitPrice,
    @Default('0') String discount,
    @Default('0') String total,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

/// Ordem de serviço. Aponta para cliente/veículo de outros módulos por id e
/// guarda um retrato (`customerName`/`subjectLabel`) para histórico. `status`
/// segue a FSM do backend. Decimais (`discount`/`total`) chegam como String.
@freezed
abstract class ServiceOrder with _$ServiceOrder {
  const factory ServiceOrder({
    required String id,
    required String number,
    @JsonKey(name: 'customer_id') required String customerId,
    @JsonKey(name: 'customer_name') String? customerName,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'subject_label') String? subjectLabel,
    @Default('aberta') String status,
    @JsonKey(name: 'assigned_to') String? assignedTo,
    String? complaint,
    String? diagnosis,
    @JsonKey(name: 'scheduled_start') String? scheduledStart,
    @JsonKey(name: 'scheduled_end') String? scheduledEnd,
    @JsonKey(name: 'started_at') String? startedAt,
    @JsonKey(name: 'finished_at') String? finishedAt,
    String? discount,
    String? total,
    @Default(<OrderItem>[]) List<OrderItem> items,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _ServiceOrder;

  factory ServiceOrder.fromJson(Map<String, dynamic> json) =>
      _$ServiceOrderFromJson(json);
}

/// Página de ordens (`GET /os/orders`).
@freezed
abstract class OrderPage with _$OrderPage {
  const factory OrderPage({
    @Default(<ServiceOrder>[]) List<ServiceOrder> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _OrderPage;

  factory OrderPage.fromJson(Map<String, dynamic> json) =>
      _$OrderPageFromJson(json);
}

/// Draft de criação de OS. Só envia campos não-nulos. Chaves em camelCase
/// (o backend espera `customerId`, `subjectId`, `scheduledStart`, …).
class OrderDraft {
  const OrderDraft({
    required this.customerId,
    this.subjectId,
    this.complaint,
    this.diagnosis,
    this.scheduledStart,
    this.scheduledEnd,
    this.assignedTo,
  });

  final String customerId;
  final String? subjectId;
  final String? complaint;
  final String? diagnosis;
  final String? scheduledStart;
  final String? scheduledEnd;
  final String? assignedTo;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        if (subjectId != null) 'subjectId': subjectId,
        if (complaint != null) 'complaint': complaint,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (scheduledStart != null) 'scheduledStart': scheduledStart,
        if (scheduledEnd != null) 'scheduledEnd': scheduledEnd,
        if (assignedTo != null) 'assignedTo': assignedTo,
      };
}

/// Patch de edição de OS (PATCH). Só envia campos presentes.
class OrderPatch {
  const OrderPatch({
    this.complaint,
    this.diagnosis,
    this.scheduledStart,
    this.scheduledEnd,
    this.assignedTo,
    this.discount,
  });

  final String? complaint;
  final String? diagnosis;
  final String? scheduledStart;
  final String? scheduledEnd;
  final String? assignedTo;
  final double? discount;

  Map<String, dynamic> toJson() => {
        if (complaint != null) 'complaint': complaint,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (scheduledStart != null) 'scheduledStart': scheduledStart,
        if (scheduledEnd != null) 'scheduledEnd': scheduledEnd,
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (discount != null) 'discount': discount,
      };
}

/// Draft de item de OS (create/update). `inventoryItemId` aponta para o estoque
/// (produto/serviço do catálogo) OU usa `name`/`unitPrice` para item avulso.
class OrderItemDraft {
  const OrderItemDraft({
    this.kind = 'product',
    this.inventoryItemId,
    this.name,
    this.quantity,
    this.unitPrice,
    this.discount,
  });

  final String kind; // 'product' | 'service'
  final String? inventoryItemId;
  final String? name;
  final double? quantity;
  final double? unitPrice;
  final double? discount;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        if (name != null) 'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
        if (discount != null) 'discount': discount,
      };
}

/// Patch de item de OS (qtd/preço/desconto).
class OrderItemPatch {
  const OrderItemPatch({this.quantity, this.unitPrice, this.discount});

  final double? quantity;
  final double? unitPrice;
  final double? discount;

  Map<String, dynamic> toJson() => {
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
        if (discount != null) 'discount': discount,
      };
}

/// Opção de cliente para o autocomplete da "Nova OS".
@freezed
abstract class CustomerOption with _$CustomerOption {
  const factory CustomerOption({
    required String id,
    required String name,
    String? document,
    String? phone,
  }) = _CustomerOption;

  factory CustomerOption.fromJson(Map<String, dynamic> json) =>
      _$CustomerOptionFromJson(json);
}

/// Opção de veículo/subject (do cliente selecionado).
@freezed
abstract class SubjectOption with _$SubjectOption {
  const factory SubjectOption({
    required String id,
    String? label,
    String? identifier,
  }) = _SubjectOption;

  factory SubjectOption.fromJson(Map<String, dynamic> json) =>
      _$SubjectOptionFromJson(json);
}

/// Opção de item do estoque para o picker (produto/serviço a adicionar à OS).
@freezed
abstract class InventoryOption with _$InventoryOption {
  const factory InventoryOption({
    required String id,
    required String name,
    @Default('product') String kind,
    @JsonKey(name: 'sale_price') String? salePrice,
  }) = _InventoryOption;

  factory InventoryOption.fromJson(Map<String, dynamic> json) =>
      _$InventoryOptionFromJson(json);
}
