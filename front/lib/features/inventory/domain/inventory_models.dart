import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_models.freezed.dart';
part 'inventory_models.g.dart';

/// Natureza do item: produto (controla estoque) ou serviço (mão de obra).
enum ItemKind { product, service }

/// Item de estoque/serviço. Genérico — sem termo de vertical. Valores monetários
/// em centavos (int); quantidades e margem chegam como Decimal serializado (string).
@freezed
abstract class InventoryItem with _$InventoryItem {
  const factory InventoryItem({
    required String id,
    required String kind, // 'product' | 'service'
    required String name,
    String? code,
    String? barcode,
    String? category,
    required String unit,
    @JsonKey(name: 'sale_price_cents') @Default(0) int salePriceCents,
    @JsonKey(name: 'cost_price_cents') int? costPriceCents,
    @JsonKey(name: 'margin_percent') String? marginPercent,
    @Default(true) bool sellable,
    @JsonKey(name: 'track_stock') @Default(true) bool trackStock,
    @JsonKey(name: 'stock_qty') @Default('0') String stockQty,
    @JsonKey(name: 'min_qty') String? minQty,
    @JsonKey(name: 'duration_minutes') int? durationMinutes,
    String? brand,
    required String status,
  }) = _InventoryItem;

  factory InventoryItem.fromJson(Map<String, dynamic> json) =>
      _$InventoryItemFromJson(json);
}

/// Um movimento de estoque (entrada/saída/ajuste). `balanceAfter` é o saldo
/// resultante; `quantity` é a magnitude do movimento. Ambos Decimal (string).
@freezed
abstract class InventoryMovement with _$InventoryMovement {
  const factory InventoryMovement({
    required String id,
    required String type, // 'in' | 'out' | 'adjust'
    required String quantity,
    @JsonKey(name: 'balance_after') required String balanceAfter,
    String? reason,
    String? note,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _InventoryMovement;

  factory InventoryMovement.fromJson(Map<String, dynamic> json) =>
      _$InventoryMovementFromJson(json);
}

/// Página de itens (`GET /inventory/items`).
@freezed
abstract class ItemPage with _$ItemPage {
  const factory ItemPage({
    @Default(<InventoryItem>[]) List<InventoryItem> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _ItemPage;

  factory ItemPage.fromJson(Map<String, dynamic> json) =>
      _$ItemPageFromJson(json);
}

/// Config do módulo Estoque & Serviços (de `GET /inventory/config`).
@freezed
abstract class InventoryConfig with _$InventoryConfig {
  const factory InventoryConfig({
    @Default('un') String defaultUnit,
    @Default(true) bool trackStockDefault,
    double? defaultMarginPercent,
    @Default(<String>[]) List<String> categories,
  }) = _InventoryConfig;

  factory InventoryConfig.fromJson(Map<String, dynamic> json) =>
      _$InventoryConfigFromJson(json);
}

/// Draft de escrita de item (create/update). Só envia campos não-nulos. Envia
/// chaves em camelCase (o backend espera `salePriceCents`, `trackStock`, …).
class ItemDraft {
  const ItemDraft({
    required this.kind,
    required this.name,
    required this.unit,
    this.code,
    this.barcode,
    this.category,
    this.brand,
    this.salePriceCents,
    this.costPriceCents,
    this.durationMinutes,
    this.marginPercent,
    this.minQty,
    this.sellable,
    this.trackStock,
  });

  final String kind;
  final String name;
  final String unit;
  final String? code;
  final String? barcode;
  final String? category;
  final String? brand;
  final int? salePriceCents;
  final int? costPriceCents;
  final int? durationMinutes;
  final double? marginPercent;
  final double? minQty;
  final bool? sellable;
  final bool? trackStock;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'name': name,
        'unit': unit,
        if (code != null) 'code': code,
        if (barcode != null) 'barcode': barcode,
        if (category != null) 'category': category,
        if (brand != null) 'brand': brand,
        if (salePriceCents != null) 'salePriceCents': salePriceCents,
        if (costPriceCents != null) 'costPriceCents': costPriceCents,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (marginPercent != null) 'marginPercent': marginPercent,
        if (minQty != null) 'minQty': minQty,
        if (sellable != null) 'sellable': sellable,
        if (trackStock != null) 'trackStock': trackStock,
      };
}

/// Draft de movimento de estoque. `type`: 'in' | 'out' | 'adjust'.
class MovementDraft {
  const MovementDraft({
    required this.type,
    required this.quantity,
    this.reason,
    this.note,
  });

  final String type;
  final double quantity;
  final String? reason;
  final String? note;

  Map<String, dynamic> toJson() => {
        'type': type,
        'quantity': quantity,
        if (reason != null) 'reason': reason,
        if (note != null) 'note': note,
      };
}
