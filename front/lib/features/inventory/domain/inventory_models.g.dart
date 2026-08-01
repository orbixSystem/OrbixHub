// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InventoryItem _$InventoryItemFromJson(Map<String, dynamic> json) =>
    _InventoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String? ?? 'product',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      sku: json['sku'] as String?,
      manufacturerCode: json['manufacturer_code'] as String?,
      barcode: json['barcode'] as String?,
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      unit: json['unit'] as String?,
      salePrice: json['sale_price'] as String?,
      costPrice: json['cost_price'] as String?,
      marginPct: json['margin_pct'] as String?,
      currentStock: json['current_stock'] as String? ?? '0',
      minStock: json['min_stock'] as String?,
      attributes:
          json['attributes'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      isActive: json['is_active'] as bool? ?? true,
      ncm: json['ncm'] as String?,
      cfop: json['cfop'] as String?,
      origem: json['origem'] as String?,
      gtin: json['gtin'] as String?,
      codigoServico: json['codigo_servico'] as String?,
      aliquotaIss: json['aliquota_iss'] as String?,
    );

Map<String, dynamic> _$InventoryItemToJson(_InventoryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'kind': instance.kind,
      'duration_minutes': instance.durationMinutes,
      'sku': instance.sku,
      'manufacturer_code': instance.manufacturerCode,
      'barcode': instance.barcode,
      'category': instance.category,
      'brand': instance.brand,
      'unit': instance.unit,
      'sale_price': instance.salePrice,
      'cost_price': instance.costPrice,
      'margin_pct': instance.marginPct,
      'current_stock': instance.currentStock,
      'min_stock': instance.minStock,
      'attributes': instance.attributes,
      'is_active': instance.isActive,
      'ncm': instance.ncm,
      'cfop': instance.cfop,
      'origem': instance.origem,
      'gtin': instance.gtin,
      'codigo_servico': instance.codigoServico,
      'aliquota_iss': instance.aliquotaIss,
    };

_ItemPage _$ItemPageFromJson(Map<String, dynamic> json) => _ItemPage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <InventoryItem>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$ItemPageToJson(_ItemPage instance) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
};

_ItemFieldConfig _$ItemFieldConfigFromJson(Map<String, dynamic> json) =>
    _ItemFieldConfig(
      key: json['key'] as String,
      label: json['label'] as String,
      type: json['type'] as String? ?? 'text',
      isRequired: json['required'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ItemFieldConfigToJson(_ItemFieldConfig instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': instance.type,
      'required': instance.isRequired,
      'options': instance.options,
    };

_InventoryConfig _$InventoryConfigFromJson(Map<String, dynamic> json) =>
    _InventoryConfig(
      itemFields:
          (json['itemFields'] as List<dynamic>?)
              ?.map((e) => ItemFieldConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ItemFieldConfig>[],
    );

Map<String, dynamic> _$InventoryConfigToJson(_InventoryConfig instance) =>
    <String, dynamic>{
      'itemFields': instance.itemFields.map((e) => e.toJson()).toList(),
    };

_CatalogSuggestion _$CatalogSuggestionFromJson(Map<String, dynamic> json) =>
    _CatalogSuggestion(
      name: json['name'] as String,
      brand: json['brand'] as String?,
      ncm: json['ncm'] as String?,
      category: json['category'] as String?,
    );

Map<String, dynamic> _$CatalogSuggestionToJson(_CatalogSuggestion instance) =>
    <String, dynamic>{
      'name': instance.name,
      'brand': instance.brand,
      'ncm': instance.ncm,
      'category': instance.category,
    };

_LookupResult _$LookupResultFromJson(Map<String, dynamic> json) =>
    _LookupResult(
      source: json['source'] as String? ?? 'none',
      item: json['item'] == null
          ? null
          : InventoryItem.fromJson(json['item'] as Map<String, dynamic>),
      suggestion: json['suggestion'] == null
          ? null
          : CatalogSuggestion.fromJson(
              json['suggestion'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$LookupResultToJson(_LookupResult instance) =>
    <String, dynamic>{
      'source': instance.source,
      'item': instance.item?.toJson(),
      'suggestion': instance.suggestion?.toJson(),
    };
