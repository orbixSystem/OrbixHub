// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inventory_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InventoryItem {

 String get id; String get name; String? get sku;@JsonKey(name: 'manufacturer_code') String? get manufacturerCode; String? get barcode; String? get category; String? get brand; String? get unit;@JsonKey(name: 'sale_price') String? get salePrice;@JsonKey(name: 'cost_price') String? get costPrice;@JsonKey(name: 'margin_pct') String? get marginPct;@JsonKey(name: 'current_stock') String get currentStock;@JsonKey(name: 'min_stock') String? get minStock; Map<String, dynamic> get attributes;@JsonKey(name: 'is_active') bool get isActive;
/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryItemCopyWith<InventoryItem> get copyWith => _$InventoryItemCopyWithImpl<InventoryItem>(this as InventoryItem, _$identity);

  /// Serializes this InventoryItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.manufacturerCode, manufacturerCode) || other.manufacturerCode == manufacturerCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.costPrice, costPrice) || other.costPrice == costPrice)&&(identical(other.marginPct, marginPct) || other.marginPct == marginPct)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock)&&(identical(other.minStock, minStock) || other.minStock == minStock)&&const DeepCollectionEquality().equals(other.attributes, attributes)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sku,manufacturerCode,barcode,category,brand,unit,salePrice,costPrice,marginPct,currentStock,minStock,const DeepCollectionEquality().hash(attributes),isActive);

@override
String toString() {
  return 'InventoryItem(id: $id, name: $name, sku: $sku, manufacturerCode: $manufacturerCode, barcode: $barcode, category: $category, brand: $brand, unit: $unit, salePrice: $salePrice, costPrice: $costPrice, marginPct: $marginPct, currentStock: $currentStock, minStock: $minStock, attributes: $attributes, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class $InventoryItemCopyWith<$Res>  {
  factory $InventoryItemCopyWith(InventoryItem value, $Res Function(InventoryItem) _then) = _$InventoryItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? sku,@JsonKey(name: 'manufacturer_code') String? manufacturerCode, String? barcode, String? category, String? brand, String? unit,@JsonKey(name: 'sale_price') String? salePrice,@JsonKey(name: 'cost_price') String? costPrice,@JsonKey(name: 'margin_pct') String? marginPct,@JsonKey(name: 'current_stock') String currentStock,@JsonKey(name: 'min_stock') String? minStock, Map<String, dynamic> attributes,@JsonKey(name: 'is_active') bool isActive
});




}
/// @nodoc
class _$InventoryItemCopyWithImpl<$Res>
    implements $InventoryItemCopyWith<$Res> {
  _$InventoryItemCopyWithImpl(this._self, this._then);

  final InventoryItem _self;
  final $Res Function(InventoryItem) _then;

/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sku = freezed,Object? manufacturerCode = freezed,Object? barcode = freezed,Object? category = freezed,Object? brand = freezed,Object? unit = freezed,Object? salePrice = freezed,Object? costPrice = freezed,Object? marginPct = freezed,Object? currentStock = null,Object? minStock = freezed,Object? attributes = null,Object? isActive = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,manufacturerCode: freezed == manufacturerCode ? _self.manufacturerCode : manufacturerCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as String?,costPrice: freezed == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as String?,marginPct: freezed == marginPct ? _self.marginPct : marginPct // ignore: cast_nullable_to_non_nullable
as String?,currentStock: null == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as String,minStock: freezed == minStock ? _self.minStock : minStock // ignore: cast_nullable_to_non_nullable
as String?,attributes: null == attributes ? _self.attributes : attributes // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryItem].
extension InventoryItemPatterns on InventoryItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryItem value)  $default,){
final _that = this;
switch (_that) {
case _InventoryItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryItem value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? sku, @JsonKey(name: 'manufacturer_code')  String? manufacturerCode,  String? barcode,  String? category,  String? brand,  String? unit, @JsonKey(name: 'sale_price')  String? salePrice, @JsonKey(name: 'cost_price')  String? costPrice, @JsonKey(name: 'margin_pct')  String? marginPct, @JsonKey(name: 'current_stock')  String currentStock, @JsonKey(name: 'min_stock')  String? minStock,  Map<String, dynamic> attributes, @JsonKey(name: 'is_active')  bool isActive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that.id,_that.name,_that.sku,_that.manufacturerCode,_that.barcode,_that.category,_that.brand,_that.unit,_that.salePrice,_that.costPrice,_that.marginPct,_that.currentStock,_that.minStock,_that.attributes,_that.isActive);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? sku, @JsonKey(name: 'manufacturer_code')  String? manufacturerCode,  String? barcode,  String? category,  String? brand,  String? unit, @JsonKey(name: 'sale_price')  String? salePrice, @JsonKey(name: 'cost_price')  String? costPrice, @JsonKey(name: 'margin_pct')  String? marginPct, @JsonKey(name: 'current_stock')  String currentStock, @JsonKey(name: 'min_stock')  String? minStock,  Map<String, dynamic> attributes, @JsonKey(name: 'is_active')  bool isActive)  $default,) {final _that = this;
switch (_that) {
case _InventoryItem():
return $default(_that.id,_that.name,_that.sku,_that.manufacturerCode,_that.barcode,_that.category,_that.brand,_that.unit,_that.salePrice,_that.costPrice,_that.marginPct,_that.currentStock,_that.minStock,_that.attributes,_that.isActive);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? sku, @JsonKey(name: 'manufacturer_code')  String? manufacturerCode,  String? barcode,  String? category,  String? brand,  String? unit, @JsonKey(name: 'sale_price')  String? salePrice, @JsonKey(name: 'cost_price')  String? costPrice, @JsonKey(name: 'margin_pct')  String? marginPct, @JsonKey(name: 'current_stock')  String currentStock, @JsonKey(name: 'min_stock')  String? minStock,  Map<String, dynamic> attributes, @JsonKey(name: 'is_active')  bool isActive)?  $default,) {final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that.id,_that.name,_that.sku,_that.manufacturerCode,_that.barcode,_that.category,_that.brand,_that.unit,_that.salePrice,_that.costPrice,_that.marginPct,_that.currentStock,_that.minStock,_that.attributes,_that.isActive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryItem implements InventoryItem {
  const _InventoryItem({required this.id, required this.name, this.sku, @JsonKey(name: 'manufacturer_code') this.manufacturerCode, this.barcode, this.category, this.brand, this.unit, @JsonKey(name: 'sale_price') this.salePrice, @JsonKey(name: 'cost_price') this.costPrice, @JsonKey(name: 'margin_pct') this.marginPct, @JsonKey(name: 'current_stock') this.currentStock = '0', @JsonKey(name: 'min_stock') this.minStock, final  Map<String, dynamic> attributes = const <String, dynamic>{}, @JsonKey(name: 'is_active') this.isActive = true}): _attributes = attributes;
  factory _InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? sku;
@override@JsonKey(name: 'manufacturer_code') final  String? manufacturerCode;
@override final  String? barcode;
@override final  String? category;
@override final  String? brand;
@override final  String? unit;
@override@JsonKey(name: 'sale_price') final  String? salePrice;
@override@JsonKey(name: 'cost_price') final  String? costPrice;
@override@JsonKey(name: 'margin_pct') final  String? marginPct;
@override@JsonKey(name: 'current_stock') final  String currentStock;
@override@JsonKey(name: 'min_stock') final  String? minStock;
 final  Map<String, dynamic> _attributes;
@override@JsonKey() Map<String, dynamic> get attributes {
  if (_attributes is EqualUnmodifiableMapView) return _attributes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_attributes);
}

@override@JsonKey(name: 'is_active') final  bool isActive;

/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryItemCopyWith<_InventoryItem> get copyWith => __$InventoryItemCopyWithImpl<_InventoryItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.manufacturerCode, manufacturerCode) || other.manufacturerCode == manufacturerCode)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.category, category) || other.category == category)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.costPrice, costPrice) || other.costPrice == costPrice)&&(identical(other.marginPct, marginPct) || other.marginPct == marginPct)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock)&&(identical(other.minStock, minStock) || other.minStock == minStock)&&const DeepCollectionEquality().equals(other._attributes, _attributes)&&(identical(other.isActive, isActive) || other.isActive == isActive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sku,manufacturerCode,barcode,category,brand,unit,salePrice,costPrice,marginPct,currentStock,minStock,const DeepCollectionEquality().hash(_attributes),isActive);

@override
String toString() {
  return 'InventoryItem(id: $id, name: $name, sku: $sku, manufacturerCode: $manufacturerCode, barcode: $barcode, category: $category, brand: $brand, unit: $unit, salePrice: $salePrice, costPrice: $costPrice, marginPct: $marginPct, currentStock: $currentStock, minStock: $minStock, attributes: $attributes, isActive: $isActive)';
}


}

/// @nodoc
abstract mixin class _$InventoryItemCopyWith<$Res> implements $InventoryItemCopyWith<$Res> {
  factory _$InventoryItemCopyWith(_InventoryItem value, $Res Function(_InventoryItem) _then) = __$InventoryItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? sku,@JsonKey(name: 'manufacturer_code') String? manufacturerCode, String? barcode, String? category, String? brand, String? unit,@JsonKey(name: 'sale_price') String? salePrice,@JsonKey(name: 'cost_price') String? costPrice,@JsonKey(name: 'margin_pct') String? marginPct,@JsonKey(name: 'current_stock') String currentStock,@JsonKey(name: 'min_stock') String? minStock, Map<String, dynamic> attributes,@JsonKey(name: 'is_active') bool isActive
});




}
/// @nodoc
class __$InventoryItemCopyWithImpl<$Res>
    implements _$InventoryItemCopyWith<$Res> {
  __$InventoryItemCopyWithImpl(this._self, this._then);

  final _InventoryItem _self;
  final $Res Function(_InventoryItem) _then;

/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sku = freezed,Object? manufacturerCode = freezed,Object? barcode = freezed,Object? category = freezed,Object? brand = freezed,Object? unit = freezed,Object? salePrice = freezed,Object? costPrice = freezed,Object? marginPct = freezed,Object? currentStock = null,Object? minStock = freezed,Object? attributes = null,Object? isActive = null,}) {
  return _then(_InventoryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,manufacturerCode: freezed == manufacturerCode ? _self.manufacturerCode : manufacturerCode // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,unit: freezed == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String?,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as String?,costPrice: freezed == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as String?,marginPct: freezed == marginPct ? _self.marginPct : marginPct // ignore: cast_nullable_to_non_nullable
as String?,currentStock: null == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as String,minStock: freezed == minStock ? _self.minStock : minStock // ignore: cast_nullable_to_non_nullable
as String?,attributes: null == attributes ? _self._attributes : attributes // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ItemPage {

 List<InventoryItem> get items; int get total; int get page; int get pageSize;
/// Create a copy of ItemPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ItemPageCopyWith<ItemPage> get copyWith => _$ItemPageCopyWithImpl<ItemPage>(this as ItemPage, _$identity);

  /// Serializes this ItemPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ItemPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'ItemPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $ItemPageCopyWith<$Res>  {
  factory $ItemPageCopyWith(ItemPage value, $Res Function(ItemPage) _then) = _$ItemPageCopyWithImpl;
@useResult
$Res call({
 List<InventoryItem> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$ItemPageCopyWithImpl<$Res>
    implements $ItemPageCopyWith<$Res> {
  _$ItemPageCopyWithImpl(this._self, this._then);

  final ItemPage _self;
  final $Res Function(ItemPage) _then;

/// Create a copy of ItemPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<InventoryItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ItemPage].
extension ItemPagePatterns on ItemPage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ItemPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ItemPage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ItemPage value)  $default,){
final _that = this;
switch (_that) {
case _ItemPage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ItemPage value)?  $default,){
final _that = this;
switch (_that) {
case _ItemPage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<InventoryItem> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ItemPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<InventoryItem> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _ItemPage():
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<InventoryItem> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _ItemPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ItemPage implements ItemPage {
  const _ItemPage({final  List<InventoryItem> items = const <InventoryItem>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _ItemPage.fromJson(Map<String, dynamic> json) => _$ItemPageFromJson(json);

 final  List<InventoryItem> _items;
@override@JsonKey() List<InventoryItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of ItemPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ItemPageCopyWith<_ItemPage> get copyWith => __$ItemPageCopyWithImpl<_ItemPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ItemPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ItemPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'ItemPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$ItemPageCopyWith<$Res> implements $ItemPageCopyWith<$Res> {
  factory _$ItemPageCopyWith(_ItemPage value, $Res Function(_ItemPage) _then) = __$ItemPageCopyWithImpl;
@override @useResult
$Res call({
 List<InventoryItem> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$ItemPageCopyWithImpl<$Res>
    implements _$ItemPageCopyWith<$Res> {
  __$ItemPageCopyWithImpl(this._self, this._then);

  final _ItemPage _self;
  final $Res Function(_ItemPage) _then;

/// Create a copy of ItemPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_ItemPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<InventoryItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ItemFieldConfig {

 String get key; String get label; String get type;// 'text' | 'number' | 'tags' | 'select'
@JsonKey(name: 'required') bool get isRequired; List<String>? get options;
/// Create a copy of ItemFieldConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ItemFieldConfigCopyWith<ItemFieldConfig> get copyWith => _$ItemFieldConfigCopyWithImpl<ItemFieldConfig>(this as ItemFieldConfig, _$identity);

  /// Serializes this ItemFieldConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ItemFieldConfig&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&const DeepCollectionEquality().equals(other.options, options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,type,isRequired,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'ItemFieldConfig(key: $key, label: $label, type: $type, isRequired: $isRequired, options: $options)';
}


}

/// @nodoc
abstract mixin class $ItemFieldConfigCopyWith<$Res>  {
  factory $ItemFieldConfigCopyWith(ItemFieldConfig value, $Res Function(ItemFieldConfig) _then) = _$ItemFieldConfigCopyWithImpl;
@useResult
$Res call({
 String key, String label, String type,@JsonKey(name: 'required') bool isRequired, List<String>? options
});




}
/// @nodoc
class _$ItemFieldConfigCopyWithImpl<$Res>
    implements $ItemFieldConfigCopyWith<$Res> {
  _$ItemFieldConfigCopyWithImpl(this._self, this._then);

  final ItemFieldConfig _self;
  final $Res Function(ItemFieldConfig) _then;

/// Create a copy of ItemFieldConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? label = null,Object? type = null,Object? isRequired = null,Object? options = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,options: freezed == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ItemFieldConfig].
extension ItemFieldConfigPatterns on ItemFieldConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ItemFieldConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ItemFieldConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ItemFieldConfig value)  $default,){
final _that = this;
switch (_that) {
case _ItemFieldConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ItemFieldConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ItemFieldConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String label,  String type, @JsonKey(name: 'required')  bool isRequired,  List<String>? options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ItemFieldConfig() when $default != null:
return $default(_that.key,_that.label,_that.type,_that.isRequired,_that.options);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String label,  String type, @JsonKey(name: 'required')  bool isRequired,  List<String>? options)  $default,) {final _that = this;
switch (_that) {
case _ItemFieldConfig():
return $default(_that.key,_that.label,_that.type,_that.isRequired,_that.options);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String label,  String type, @JsonKey(name: 'required')  bool isRequired,  List<String>? options)?  $default,) {final _that = this;
switch (_that) {
case _ItemFieldConfig() when $default != null:
return $default(_that.key,_that.label,_that.type,_that.isRequired,_that.options);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ItemFieldConfig implements ItemFieldConfig {
  const _ItemFieldConfig({required this.key, required this.label, this.type = 'text', @JsonKey(name: 'required') this.isRequired = false, final  List<String>? options}): _options = options;
  factory _ItemFieldConfig.fromJson(Map<String, dynamic> json) => _$ItemFieldConfigFromJson(json);

@override final  String key;
@override final  String label;
@override@JsonKey() final  String type;
// 'text' | 'number' | 'tags' | 'select'
@override@JsonKey(name: 'required') final  bool isRequired;
 final  List<String>? _options;
@override List<String>? get options {
  final value = _options;
  if (value == null) return null;
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of ItemFieldConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ItemFieldConfigCopyWith<_ItemFieldConfig> get copyWith => __$ItemFieldConfigCopyWithImpl<_ItemFieldConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ItemFieldConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ItemFieldConfig&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&(identical(other.isRequired, isRequired) || other.isRequired == isRequired)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,type,isRequired,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'ItemFieldConfig(key: $key, label: $label, type: $type, isRequired: $isRequired, options: $options)';
}


}

/// @nodoc
abstract mixin class _$ItemFieldConfigCopyWith<$Res> implements $ItemFieldConfigCopyWith<$Res> {
  factory _$ItemFieldConfigCopyWith(_ItemFieldConfig value, $Res Function(_ItemFieldConfig) _then) = __$ItemFieldConfigCopyWithImpl;
@override @useResult
$Res call({
 String key, String label, String type,@JsonKey(name: 'required') bool isRequired, List<String>? options
});




}
/// @nodoc
class __$ItemFieldConfigCopyWithImpl<$Res>
    implements _$ItemFieldConfigCopyWith<$Res> {
  __$ItemFieldConfigCopyWithImpl(this._self, this._then);

  final _ItemFieldConfig _self;
  final $Res Function(_ItemFieldConfig) _then;

/// Create a copy of ItemFieldConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? label = null,Object? type = null,Object? isRequired = null,Object? options = freezed,}) {
  return _then(_ItemFieldConfig(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,isRequired: null == isRequired ? _self.isRequired : isRequired // ignore: cast_nullable_to_non_nullable
as bool,options: freezed == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}


/// @nodoc
mixin _$InventoryConfig {

 List<ItemFieldConfig> get itemFields;
/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryConfigCopyWith<InventoryConfig> get copyWith => _$InventoryConfigCopyWithImpl<InventoryConfig>(this as InventoryConfig, _$identity);

  /// Serializes this InventoryConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryConfig&&const DeepCollectionEquality().equals(other.itemFields, itemFields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(itemFields));

@override
String toString() {
  return 'InventoryConfig(itemFields: $itemFields)';
}


}

/// @nodoc
abstract mixin class $InventoryConfigCopyWith<$Res>  {
  factory $InventoryConfigCopyWith(InventoryConfig value, $Res Function(InventoryConfig) _then) = _$InventoryConfigCopyWithImpl;
@useResult
$Res call({
 List<ItemFieldConfig> itemFields
});




}
/// @nodoc
class _$InventoryConfigCopyWithImpl<$Res>
    implements $InventoryConfigCopyWith<$Res> {
  _$InventoryConfigCopyWithImpl(this._self, this._then);

  final InventoryConfig _self;
  final $Res Function(InventoryConfig) _then;

/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? itemFields = null,}) {
  return _then(_self.copyWith(
itemFields: null == itemFields ? _self.itemFields : itemFields // ignore: cast_nullable_to_non_nullable
as List<ItemFieldConfig>,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryConfig].
extension InventoryConfigPatterns on InventoryConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryConfig value)  $default,){
final _that = this;
switch (_that) {
case _InventoryConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryConfig value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ItemFieldConfig> itemFields)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that.itemFields);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ItemFieldConfig> itemFields)  $default,) {final _that = this;
switch (_that) {
case _InventoryConfig():
return $default(_that.itemFields);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ItemFieldConfig> itemFields)?  $default,) {final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that.itemFields);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryConfig implements InventoryConfig {
  const _InventoryConfig({final  List<ItemFieldConfig> itemFields = const <ItemFieldConfig>[]}): _itemFields = itemFields;
  factory _InventoryConfig.fromJson(Map<String, dynamic> json) => _$InventoryConfigFromJson(json);

 final  List<ItemFieldConfig> _itemFields;
@override@JsonKey() List<ItemFieldConfig> get itemFields {
  if (_itemFields is EqualUnmodifiableListView) return _itemFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_itemFields);
}


/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryConfigCopyWith<_InventoryConfig> get copyWith => __$InventoryConfigCopyWithImpl<_InventoryConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryConfig&&const DeepCollectionEquality().equals(other._itemFields, _itemFields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_itemFields));

@override
String toString() {
  return 'InventoryConfig(itemFields: $itemFields)';
}


}

/// @nodoc
abstract mixin class _$InventoryConfigCopyWith<$Res> implements $InventoryConfigCopyWith<$Res> {
  factory _$InventoryConfigCopyWith(_InventoryConfig value, $Res Function(_InventoryConfig) _then) = __$InventoryConfigCopyWithImpl;
@override @useResult
$Res call({
 List<ItemFieldConfig> itemFields
});




}
/// @nodoc
class __$InventoryConfigCopyWithImpl<$Res>
    implements _$InventoryConfigCopyWith<$Res> {
  __$InventoryConfigCopyWithImpl(this._self, this._then);

  final _InventoryConfig _self;
  final $Res Function(_InventoryConfig) _then;

/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? itemFields = null,}) {
  return _then(_InventoryConfig(
itemFields: null == itemFields ? _self._itemFields : itemFields // ignore: cast_nullable_to_non_nullable
as List<ItemFieldConfig>,
  ));
}


}


/// @nodoc
mixin _$CatalogSuggestion {

 String get name; String? get brand; String? get ncm; String? get category;
/// Create a copy of CatalogSuggestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogSuggestionCopyWith<CatalogSuggestion> get copyWith => _$CatalogSuggestionCopyWithImpl<CatalogSuggestion>(this as CatalogSuggestion, _$identity);

  /// Serializes this CatalogSuggestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogSuggestion&&(identical(other.name, name) || other.name == name)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.ncm, ncm) || other.ncm == ncm)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,brand,ncm,category);

@override
String toString() {
  return 'CatalogSuggestion(name: $name, brand: $brand, ncm: $ncm, category: $category)';
}


}

/// @nodoc
abstract mixin class $CatalogSuggestionCopyWith<$Res>  {
  factory $CatalogSuggestionCopyWith(CatalogSuggestion value, $Res Function(CatalogSuggestion) _then) = _$CatalogSuggestionCopyWithImpl;
@useResult
$Res call({
 String name, String? brand, String? ncm, String? category
});




}
/// @nodoc
class _$CatalogSuggestionCopyWithImpl<$Res>
    implements $CatalogSuggestionCopyWith<$Res> {
  _$CatalogSuggestionCopyWithImpl(this._self, this._then);

  final CatalogSuggestion _self;
  final $Res Function(CatalogSuggestion) _then;

/// Create a copy of CatalogSuggestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? brand = freezed,Object? ncm = freezed,Object? category = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,ncm: freezed == ncm ? _self.ncm : ncm // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CatalogSuggestion].
extension CatalogSuggestionPatterns on CatalogSuggestion {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CatalogSuggestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CatalogSuggestion() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CatalogSuggestion value)  $default,){
final _that = this;
switch (_that) {
case _CatalogSuggestion():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CatalogSuggestion value)?  $default,){
final _that = this;
switch (_that) {
case _CatalogSuggestion() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? brand,  String? ncm,  String? category)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CatalogSuggestion() when $default != null:
return $default(_that.name,_that.brand,_that.ncm,_that.category);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? brand,  String? ncm,  String? category)  $default,) {final _that = this;
switch (_that) {
case _CatalogSuggestion():
return $default(_that.name,_that.brand,_that.ncm,_that.category);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? brand,  String? ncm,  String? category)?  $default,) {final _that = this;
switch (_that) {
case _CatalogSuggestion() when $default != null:
return $default(_that.name,_that.brand,_that.ncm,_that.category);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CatalogSuggestion implements CatalogSuggestion {
  const _CatalogSuggestion({required this.name, this.brand, this.ncm, this.category});
  factory _CatalogSuggestion.fromJson(Map<String, dynamic> json) => _$CatalogSuggestionFromJson(json);

@override final  String name;
@override final  String? brand;
@override final  String? ncm;
@override final  String? category;

/// Create a copy of CatalogSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogSuggestionCopyWith<_CatalogSuggestion> get copyWith => __$CatalogSuggestionCopyWithImpl<_CatalogSuggestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogSuggestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogSuggestion&&(identical(other.name, name) || other.name == name)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.ncm, ncm) || other.ncm == ncm)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,brand,ncm,category);

@override
String toString() {
  return 'CatalogSuggestion(name: $name, brand: $brand, ncm: $ncm, category: $category)';
}


}

/// @nodoc
abstract mixin class _$CatalogSuggestionCopyWith<$Res> implements $CatalogSuggestionCopyWith<$Res> {
  factory _$CatalogSuggestionCopyWith(_CatalogSuggestion value, $Res Function(_CatalogSuggestion) _then) = __$CatalogSuggestionCopyWithImpl;
@override @useResult
$Res call({
 String name, String? brand, String? ncm, String? category
});




}
/// @nodoc
class __$CatalogSuggestionCopyWithImpl<$Res>
    implements _$CatalogSuggestionCopyWith<$Res> {
  __$CatalogSuggestionCopyWithImpl(this._self, this._then);

  final _CatalogSuggestion _self;
  final $Res Function(_CatalogSuggestion) _then;

/// Create a copy of CatalogSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? brand = freezed,Object? ncm = freezed,Object? category = freezed,}) {
  return _then(_CatalogSuggestion(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,ncm: freezed == ncm ? _self.ncm : ncm // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LookupResult {

 String get source; InventoryItem? get item; CatalogSuggestion? get suggestion;
/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LookupResultCopyWith<LookupResult> get copyWith => _$LookupResultCopyWithImpl<LookupResult>(this as LookupResult, _$identity);

  /// Serializes this LookupResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LookupResult&&(identical(other.source, source) || other.source == source)&&(identical(other.item, item) || other.item == item)&&(identical(other.suggestion, suggestion) || other.suggestion == suggestion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,source,item,suggestion);

@override
String toString() {
  return 'LookupResult(source: $source, item: $item, suggestion: $suggestion)';
}


}

/// @nodoc
abstract mixin class $LookupResultCopyWith<$Res>  {
  factory $LookupResultCopyWith(LookupResult value, $Res Function(LookupResult) _then) = _$LookupResultCopyWithImpl;
@useResult
$Res call({
 String source, InventoryItem? item, CatalogSuggestion? suggestion
});


$InventoryItemCopyWith<$Res>? get item;$CatalogSuggestionCopyWith<$Res>? get suggestion;

}
/// @nodoc
class _$LookupResultCopyWithImpl<$Res>
    implements $LookupResultCopyWith<$Res> {
  _$LookupResultCopyWithImpl(this._self, this._then);

  final LookupResult _self;
  final $Res Function(LookupResult) _then;

/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? item = freezed,Object? suggestion = freezed,}) {
  return _then(_self.copyWith(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as InventoryItem?,suggestion: freezed == suggestion ? _self.suggestion : suggestion // ignore: cast_nullable_to_non_nullable
as CatalogSuggestion?,
  ));
}
/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InventoryItemCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $InventoryItemCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CatalogSuggestionCopyWith<$Res>? get suggestion {
    if (_self.suggestion == null) {
    return null;
  }

  return $CatalogSuggestionCopyWith<$Res>(_self.suggestion!, (value) {
    return _then(_self.copyWith(suggestion: value));
  });
}
}


/// Adds pattern-matching-related methods to [LookupResult].
extension LookupResultPatterns on LookupResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LookupResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LookupResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LookupResult value)  $default,){
final _that = this;
switch (_that) {
case _LookupResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LookupResult value)?  $default,){
final _that = this;
switch (_that) {
case _LookupResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String source,  InventoryItem? item,  CatalogSuggestion? suggestion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LookupResult() when $default != null:
return $default(_that.source,_that.item,_that.suggestion);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String source,  InventoryItem? item,  CatalogSuggestion? suggestion)  $default,) {final _that = this;
switch (_that) {
case _LookupResult():
return $default(_that.source,_that.item,_that.suggestion);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String source,  InventoryItem? item,  CatalogSuggestion? suggestion)?  $default,) {final _that = this;
switch (_that) {
case _LookupResult() when $default != null:
return $default(_that.source,_that.item,_that.suggestion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LookupResult implements LookupResult {
  const _LookupResult({this.source = 'none', this.item, this.suggestion});
  factory _LookupResult.fromJson(Map<String, dynamic> json) => _$LookupResultFromJson(json);

@override@JsonKey() final  String source;
@override final  InventoryItem? item;
@override final  CatalogSuggestion? suggestion;

/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LookupResultCopyWith<_LookupResult> get copyWith => __$LookupResultCopyWithImpl<_LookupResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LookupResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LookupResult&&(identical(other.source, source) || other.source == source)&&(identical(other.item, item) || other.item == item)&&(identical(other.suggestion, suggestion) || other.suggestion == suggestion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,source,item,suggestion);

@override
String toString() {
  return 'LookupResult(source: $source, item: $item, suggestion: $suggestion)';
}


}

/// @nodoc
abstract mixin class _$LookupResultCopyWith<$Res> implements $LookupResultCopyWith<$Res> {
  factory _$LookupResultCopyWith(_LookupResult value, $Res Function(_LookupResult) _then) = __$LookupResultCopyWithImpl;
@override @useResult
$Res call({
 String source, InventoryItem? item, CatalogSuggestion? suggestion
});


@override $InventoryItemCopyWith<$Res>? get item;@override $CatalogSuggestionCopyWith<$Res>? get suggestion;

}
/// @nodoc
class __$LookupResultCopyWithImpl<$Res>
    implements _$LookupResultCopyWith<$Res> {
  __$LookupResultCopyWithImpl(this._self, this._then);

  final _LookupResult _self;
  final $Res Function(_LookupResult) _then;

/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? item = freezed,Object? suggestion = freezed,}) {
  return _then(_LookupResult(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as InventoryItem?,suggestion: freezed == suggestion ? _self.suggestion : suggestion // ignore: cast_nullable_to_non_nullable
as CatalogSuggestion?,
  ));
}

/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InventoryItemCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $InventoryItemCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}/// Create a copy of LookupResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CatalogSuggestionCopyWith<$Res>? get suggestion {
    if (_self.suggestion == null) {
    return null;
  }

  return $CatalogSuggestionCopyWith<$Res>(_self.suggestion!, (value) {
    return _then(_self.copyWith(suggestion: value));
  });
}
}

// dart format on
