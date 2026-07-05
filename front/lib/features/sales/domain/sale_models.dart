import 'package:freezed_annotation/freezed_annotation.dart';

part 'sale_models.freezed.dart';
part 'sale_models.g.dart';

/// Venda de balcão (caixa). O módulo `sales` é dono do próprio registro e
/// **aponta** para o cliente por id + snapshot do nome ("aponta, não invade").
/// Valores monetários chegam do backend como STRING (decimal serializado) —
/// formatados na UI via `money(...)`. Campos em snake_case (contrato real).
@freezed
abstract class Sale with _$Sale {
  const factory Sale({
    required String id,
    String? number,
    @JsonKey(name: 'customer_id') String? customerId,
    @JsonKey(name: 'customer_name') String? customerName,
    @Default('concluida') String status, // 'concluida' | 'cancelada'
    @JsonKey(name: 'payment_method')
    @Default('dinheiro')
    String paymentMethod, // 'dinheiro' | 'cartao' | 'pix' | 'outro'
    @Default('0') String discount,
    @Default('0') String subtotal,
    @Default('0') String total,
    @JsonKey(name: 'stock_applied') @Default(false) bool stockApplied,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'canceled_at') String? canceledAt,
    // Preenchido só em GET /sales/:id (detalhe).
    @Default(<SaleItem>[]) List<SaleItem> items,
  }) = _Sale;

  factory Sale.fromJson(Map<String, dynamic> json) => _$SaleFromJson(json);
}

/// Item de uma venda. `kind ∈ product|service`. Pode apontar para um item do
/// estoque (`inventoryItemId`) ou ser avulso (só `name`). Decimais como String.
@freezed
abstract class SaleItem with _$SaleItem {
  const factory SaleItem({
    required String id,
    @JsonKey(name: 'inventory_item_id') String? inventoryItemId,
    @Default('product') String kind, // 'product' | 'service'
    required String name,
    @Default('1') String quantity,
    @JsonKey(name: 'unit_price') @Default('0') String unitPrice,
    @Default('0') String discount,
    @Default('0') String total,
  }) = _SaleItem;

  factory SaleItem.fromJson(Map<String, dynamic> json) =>
      _$SaleItemFromJson(json);
}

/// Página de vendas (`GET /sales`). `page` é 1-based; `pageSize` = 20.
@freezed
abstract class SalePage with _$SalePage {
  const factory SalePage({
    @Default(<Sale>[]) List<Sale> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _SalePage;

  factory SalePage.fromJson(Map<String, dynamic> json) =>
      _$SalePageFromJson(json);
}

/// Draft de um item do carrinho para o checkout (`POST /sales`). Só envia campos
/// não-nulos. `inventoryItemId` aponta para o estoque (produto/serviço) OU usa
/// `name`/`kind` para item avulso. `name`/`kind` seguem junto sempre — servem de
/// snapshot e alimentam a UI do carrinho. Quantidade/preços como números.
class SaleItemDraft {
  const SaleItemDraft({
    this.inventoryItemId,
    required this.name,
    this.kind = 'product',
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount,
    this.currentStock,
  });

  final String? inventoryItemId;
  final String name;
  final String kind; // 'product' | 'service'
  final num quantity;
  final num unitPrice;
  final num? discount;

  /// Saldo em estoque no momento em que o item foi adicionado ao carrinho — só
  /// para aviso de UX (produto do catálogo). Não vai no corpo do checkout.
  final num? currentStock;

  /// Subtotal da linha (qtd × preço − desconto), nunca negativo.
  num get lineTotal {
    final t = quantity * unitPrice - (discount ?? 0);
    return t < 0 ? 0 : t;
  }

  SaleItemDraft copyWith({
    num? quantity,
    num? unitPrice,
    num? discount,
  }) =>
      SaleItemDraft(
        inventoryItemId: inventoryItemId,
        name: name,
        kind: kind,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discount: discount ?? this.discount,
        currentStock: currentStock,
      );

  Map<String, dynamic> toJson() => {
        if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        'name': name,
        'kind': kind,
        'quantity': quantity,
        'unitPrice': unitPrice,
        if (discount != null) 'discount': discount,
      };
}

/// Draft do checkout de uma venda (`POST /sales`). `customerId` nulo = consumidor
/// final. `paymentMethod ∈ dinheiro|cartao|pix|outro`.
class SaleDraft {
  const SaleDraft({
    this.customerId,
    required this.items,
    this.discount,
    required this.paymentMethod,
  });

  final String? customerId;
  final List<SaleItemDraft> items;
  final num? discount;
  final String paymentMethod;

  Map<String, dynamic> toJson() => {
        if (customerId != null) 'customerId': customerId,
        'items': items.map((e) => e.toJson()).toList(),
        if (discount != null) 'discount': discount,
        'paymentMethod': paymentMethod,
      };
}
