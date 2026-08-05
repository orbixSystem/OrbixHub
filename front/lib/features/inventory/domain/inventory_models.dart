import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_models.freezed.dart';
part 'inventory_models.g.dart';

/// Item de estoque (produto). Genérico — sem termo de vertical; o específico
/// da vertical vive em [attributes] (whitelist por `itemFields`). Preços/estoque
/// chegam como decimal serializado (String); `attributes` é objeto livre.
@freezed
abstract class InventoryItem with _$InventoryItem {
  const factory InventoryItem({
    required String id,
    required String name,
    @Default('product') String kind, // 'product' | 'service'
    @JsonKey(name: 'duration_minutes') int? durationMinutes,
    String? sku,
    @JsonKey(name: 'manufacturer_code') String? manufacturerCode,
    String? barcode,
    String? category,
    String? brand,
    String? unit,
    /// Observação livre — o cadastro SIMPLIFICADO usa isto como "descrição".
    String? description,
    @JsonKey(name: 'sale_price') String? salePrice,
    @JsonKey(name: 'cost_price') String? costPrice,
    @JsonKey(name: 'margin_pct') String? marginPct,
    @JsonKey(name: 'current_stock') @Default('0') String currentStock,
    @JsonKey(name: 'min_stock') String? minStock,
    @Default(<String, dynamic>{}) Map<String, dynamic> attributes,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    String? ncm,
    String? cfop,
    String? origem,
    String? gtin,
    @JsonKey(name: 'codigo_servico') String? codigoServico,
    @JsonKey(name: 'aliquota_iss') String? aliquotaIss,
  }) = _InventoryItem;

  factory InventoryItem.fromJson(Map<String, dynamic> json) =>
      _$InventoryItemFromJson(json);
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

/// Definição de um campo da vertical (vem de `GET /inventory/config`).
/// `type ∈ text|number|tags|select`. `isRequired` mapeia o `required` do backend
/// (palavra reservada-ish no Dart).
@freezed
abstract class ItemFieldConfig with _$ItemFieldConfig {
  const factory ItemFieldConfig({
    required String key,
    required String label,
    @Default('text') String type, // 'text' | 'number' | 'tags' | 'select'
    @JsonKey(name: 'required') @Default(false) bool isRequired,
    List<String>? options,
  }) = _ItemFieldConfig;

  factory ItemFieldConfig.fromJson(Map<String, dynamic> json) =>
      _$ItemFieldConfigFromJson(json);
}

/// Config do módulo Estoque (campos dinâmicos da vertical).
@freezed
abstract class InventoryConfig with _$InventoryConfig {
  const factory InventoryConfig({
    @Default(<ItemFieldConfig>[]) List<ItemFieldConfig> itemFields,
  }) = _InventoryConfig;

  factory InventoryConfig.fromJson(Map<String, dynamic> json) =>
      _$InventoryConfigFromJson(json);
}

/// Sugestão vinda de um catálogo externo (`source:'catalog'`). Campos editáveis.
@freezed
abstract class CatalogSuggestion with _$CatalogSuggestion {
  const factory CatalogSuggestion({
    required String name,
    String? brand,
    String? ncm,
    String? category,
  }) = _CatalogSuggestion;

  factory CatalogSuggestion.fromJson(Map<String, dynamic> json) =>
      _$CatalogSuggestionFromJson(json);
}

/// Resultado do código-first (`GET /inventory/lookup?code=`).
/// `source ∈ internal|catalog|none`.
@freezed
abstract class LookupResult with _$LookupResult {
  const factory LookupResult({
    @Default('none') String source,
    InventoryItem? item,
    CatalogSuggestion? suggestion,
  }) = _LookupResult;

  factory LookupResult.fromJson(Map<String, dynamic> json) =>
      _$LookupResultFromJson(json);
}

/// Draft de escrita de item (create/update). Só envia campos não-nulos.
/// Chaves em camelCase (o backend espera `manufacturerCode`, `salePrice`, …);
/// preços/estoque como números.
class ItemDraft {
  const ItemDraft({
    required this.name,
    this.kind = 'product',
    this.durationMinutes,
    this.sku,
    this.manufacturerCode,
    this.barcode,
    this.category,
    this.brand,
    this.unit,
    this.description,
    this.salePrice,
    this.costPrice,
    this.marginPct,
    this.currentStock,
    this.minStock,
    this.attributes,
    this.ncm,
    this.cfop,
    this.origem,
    this.gtin,
    this.codigoServico,
    this.aliquotaIss,
  });

  final String name;
  final String kind; // 'product' | 'service'
  final int? durationMinutes;
  final String? sku;
  final String? manufacturerCode;
  final String? barcode;
  final String? category;
  final String? brand;
  final String? unit;
  final String? description;
  final double? salePrice;
  final double? costPrice;
  final double? marginPct;
  final double? currentStock;
  final double? minStock;
  final Map<String, dynamic>? attributes;
  final String? ncm;
  final String? cfop;
  final String? origem;
  final String? gtin;
  final String? codigoServico;
  final double? aliquotaIss;

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (sku != null) 'sku': sku,
        if (manufacturerCode != null) 'manufacturerCode': manufacturerCode,
        if (barcode != null) 'barcode': barcode,
        if (category != null) 'category': category,
        if (brand != null) 'brand': brand,
        if (unit != null) 'unit': unit,
        if (description != null) 'description': description,
        if (salePrice != null) 'salePrice': salePrice,
        if (costPrice != null) 'costPrice': costPrice,
        if (marginPct != null) 'marginPct': marginPct,
        if (currentStock != null) 'currentStock': currentStock,
        if (minStock != null) 'minStock': minStock,
        if (attributes != null) 'attributes': attributes,
        if (ncm != null) 'ncm': ncm,
        if (cfop != null) 'cfop': cfop,
        if (origem != null) 'origem': origem,
        if (gtin != null) 'gtin': gtin,
        if (codigoServico != null) 'codigoServico': codigoServico,
        if (aliquotaIss != null) 'aliquotaIss': aliquotaIss,
      };

  /// Payload de EDIÇÃO — igual ao de criação, menos `kind`.
  ///
  /// O tipo (produto/serviço) é IMUTÁVEL depois de criado, então
  /// `UpdateInventoryItemDto` não declara `kind`. Como o backend valida com
  /// `whitelist + forbidNonWhitelisted`, mandar a chave derruba a requisição
  /// com "property kind should not exist" — e o replay da fila offline aplica a
  /// MESMA validação, então a mutação morria como `failed` e aparecia ao
  /// usuário na tela "Alterações pendentes".
  Map<String, dynamic> toUpdateJson() => toJson()..remove('kind');
}
