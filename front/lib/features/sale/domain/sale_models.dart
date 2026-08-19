import 'package:freezed_annotation/freezed_annotation.dart';

part 'sale_models.freezed.dart';
part 'sale_models.g.dart';

/// Venda de balcão (`sale`) — entidade própria, NÃO é OS. Valores monetários de
/// coluna (Decimal) chegam como String serializada. `paymentStatus` é DERIVADO do
/// caixa no backend; `fiscalStatus` é snapshot do Fiscal. O backend é a verdade.
@freezed
abstract class Sale with _$Sale {
  const factory Sale({
    required String id,
    @Default('') String number,
    @JsonKey(name: 'customer_id') String? customerId,
    @JsonKey(name: 'customer_name') String? customerName,
    @Default('active') String status, // 'active' | 'canceled'
    @Default('0') String total,
    /// Desconto concedido (registro). `total` já vem líquido.
    @Default('0') String discount,

    /// Observação livre do balcão (a quem entregou, placa, nº do equipamento).
    /// Sai no comprovante — é o que identifica a venda quando quem comprou não
    /// é cliente cadastrado.
    String? description,
    @JsonKey(name: 'fiscal_status') String? fiscalStatus,
    // 'a_receber' | 'parcial' | 'pago' | 'cancelada' (flat, espelha payment.status)
    @JsonKey(name: 'payment_status') @Default('a_receber') String paymentStatus,
    @JsonKey(name: 'created_at') String? createdAt,
    @Default(<SaleItem>[]) List<SaleItem> items,
  }) = _Sale;

  factory Sale.fromJson(Map<String, dynamic> json) => _$SaleFromJson(json);
}

/// Uma linha da venda (snapshot do item de estoque ou avulso).
@freezed
abstract class SaleItem with _$SaleItem {
  const factory SaleItem({
    required String id,
    @Default('product') String kind, // 'product' | 'service'
    @JsonKey(name: 'inventory_item_id') String? inventoryItemId,
    @Default('') String name,
    @Default('1') String quantity,
    @JsonKey(name: 'unit_price') @Default('0') String unitPrice,
    @Default('0') String subtotal,
  }) = _SaleItem;

  factory SaleItem.fromJson(Map<String, dynamic> json) =>
      _$SaleItemFromJson(json);
}

/// Página de vendas (listagem).
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

/// Rascunho de uma linha da venda (envio ao backend). Item do estoque informa
/// `inventoryItemId`; avulso informa `name`+`kind`.
class SaleItemDraft {
  const SaleItemDraft({
    this.inventoryItemId,
    this.name,
    this.kind,
    required this.quantity,
    this.unitPrice,
  });

  final String? inventoryItemId;
  final String? name;
  final String? kind;
  final double quantity;
  final double? unitPrice;

  Map<String, dynamic> toJson() => {
        if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        if (name != null && name!.isNotEmpty) 'name': name,
        if (kind != null) 'kind': kind,
        'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
      };
}

/// Rascunho da venda (cliente opcional + itens).
class SaleDraft {
  const SaleDraft({
    this.customerId,
    required this.items,
    this.discount,
    this.description,
  });

  final String? customerId;
  final List<SaleItemDraft> items;

  /// Desconto em valor sobre o total. O backend clampa ao bruto.
  final double? discount;

  /// Observação livre do balcão (opcional).
  final String? description;

  Map<String, dynamic> toJson() => {
        if (customerId != null) 'customerId': customerId,
        'items': items.map((i) => i.toJson()).toList(),
        if (discount != null && discount! > 0) 'discount': discount,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}

/// Resultado da emissão de nota (Fiscal é dono do status).
@freezed
abstract class SaleFiscalResult with _$SaleFiscalResult {
  const factory SaleFiscalResult({
    @Default('nao_emitida') String status,
    String? externalId,
    String? message,
  }) = _SaleFiscalResult;

  factory SaleFiscalResult.fromJson(Map<String, dynamic> json) =>
      _$SaleFiscalResultFromJson(json);
}
