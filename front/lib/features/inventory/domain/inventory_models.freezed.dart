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

 String get id; String get kind;// 'product' | 'service'
 String get name; String? get code; String? get barcode; String? get category; String get unit;@JsonKey(name: 'sale_price_cents') int get salePriceCents;@JsonKey(name: 'cost_price_cents') int? get costPriceCents;@JsonKey(name: 'margin_percent') String? get marginPercent; bool get sellable;@JsonKey(name: 'track_stock') bool get trackStock;@JsonKey(name: 'stock_qty') String get stockQty;@JsonKey(name: 'min_qty') String? get minQty;@JsonKey(name: 'duration_minutes') int? get durationMinutes; String? get brand; String get status;
/// Create a copy of InventoryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryItemCopyWith<InventoryItem> get copyWith => _$InventoryItemCopyWithImpl<InventoryItem>(this as InventoryItem, _$identity);

  /// Serializes this InventoryItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.category, category) || other.category == category)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.salePriceCents, salePriceCents) || other.salePriceCents == salePriceCents)&&(identical(other.costPriceCents, costPriceCents) || other.costPriceCents == costPriceCents)&&(identical(other.marginPercent, marginPercent) || other.marginPercent == marginPercent)&&(identical(other.sellable, sellable) || other.sellable == sellable)&&(identical(other.trackStock, trackStock) || other.trackStock == trackStock)&&(identical(other.stockQty, stockQty) || other.stockQty == stockQty)&&(identical(other.minQty, minQty) || other.minQty == minQty)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,name,code,barcode,category,unit,salePriceCents,costPriceCents,marginPercent,sellable,trackStock,stockQty,minQty,durationMinutes,brand,status);

@override
String toString() {
  return 'InventoryItem(id: $id, kind: $kind, name: $name, code: $code, barcode: $barcode, category: $category, unit: $unit, salePriceCents: $salePriceCents, costPriceCents: $costPriceCents, marginPercent: $marginPercent, sellable: $sellable, trackStock: $trackStock, stockQty: $stockQty, minQty: $minQty, durationMinutes: $durationMinutes, brand: $brand, status: $status)';
}


}

/// @nodoc
abstract mixin class $InventoryItemCopyWith<$Res>  {
  factory $InventoryItemCopyWith(InventoryItem value, $Res Function(InventoryItem) _then) = _$InventoryItemCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String name, String? code, String? barcode, String? category, String unit,@JsonKey(name: 'sale_price_cents') int salePriceCents,@JsonKey(name: 'cost_price_cents') int? costPriceCents,@JsonKey(name: 'margin_percent') String? marginPercent, bool sellable,@JsonKey(name: 'track_stock') bool trackStock,@JsonKey(name: 'stock_qty') String stockQty,@JsonKey(name: 'min_qty') String? minQty,@JsonKey(name: 'duration_minutes') int? durationMinutes, String? brand, String status
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? code = freezed,Object? barcode = freezed,Object? category = freezed,Object? unit = null,Object? salePriceCents = null,Object? costPriceCents = freezed,Object? marginPercent = freezed,Object? sellable = null,Object? trackStock = null,Object? stockQty = null,Object? minQty = freezed,Object? durationMinutes = freezed,Object? brand = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,salePriceCents: null == salePriceCents ? _self.salePriceCents : salePriceCents // ignore: cast_nullable_to_non_nullable
as int,costPriceCents: freezed == costPriceCents ? _self.costPriceCents : costPriceCents // ignore: cast_nullable_to_non_nullable
as int?,marginPercent: freezed == marginPercent ? _self.marginPercent : marginPercent // ignore: cast_nullable_to_non_nullable
as String?,sellable: null == sellable ? _self.sellable : sellable // ignore: cast_nullable_to_non_nullable
as bool,trackStock: null == trackStock ? _self.trackStock : trackStock // ignore: cast_nullable_to_non_nullable
as bool,stockQty: null == stockQty ? _self.stockQty : stockQty // ignore: cast_nullable_to_non_nullable
as String,minQty: freezed == minQty ? _self.minQty : minQty // ignore: cast_nullable_to_non_nullable
as String?,durationMinutes: freezed == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  String name,  String? code,  String? barcode,  String? category,  String unit, @JsonKey(name: 'sale_price_cents')  int salePriceCents, @JsonKey(name: 'cost_price_cents')  int? costPriceCents, @JsonKey(name: 'margin_percent')  String? marginPercent,  bool sellable, @JsonKey(name: 'track_stock')  bool trackStock, @JsonKey(name: 'stock_qty')  String stockQty, @JsonKey(name: 'min_qty')  String? minQty, @JsonKey(name: 'duration_minutes')  int? durationMinutes,  String? brand,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.code,_that.barcode,_that.category,_that.unit,_that.salePriceCents,_that.costPriceCents,_that.marginPercent,_that.sellable,_that.trackStock,_that.stockQty,_that.minQty,_that.durationMinutes,_that.brand,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  String name,  String? code,  String? barcode,  String? category,  String unit, @JsonKey(name: 'sale_price_cents')  int salePriceCents, @JsonKey(name: 'cost_price_cents')  int? costPriceCents, @JsonKey(name: 'margin_percent')  String? marginPercent,  bool sellable, @JsonKey(name: 'track_stock')  bool trackStock, @JsonKey(name: 'stock_qty')  String stockQty, @JsonKey(name: 'min_qty')  String? minQty, @JsonKey(name: 'duration_minutes')  int? durationMinutes,  String? brand,  String status)  $default,) {final _that = this;
switch (_that) {
case _InventoryItem():
return $default(_that.id,_that.kind,_that.name,_that.code,_that.barcode,_that.category,_that.unit,_that.salePriceCents,_that.costPriceCents,_that.marginPercent,_that.sellable,_that.trackStock,_that.stockQty,_that.minQty,_that.durationMinutes,_that.brand,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  String name,  String? code,  String? barcode,  String? category,  String unit, @JsonKey(name: 'sale_price_cents')  int salePriceCents, @JsonKey(name: 'cost_price_cents')  int? costPriceCents, @JsonKey(name: 'margin_percent')  String? marginPercent,  bool sellable, @JsonKey(name: 'track_stock')  bool trackStock, @JsonKey(name: 'stock_qty')  String stockQty, @JsonKey(name: 'min_qty')  String? minQty, @JsonKey(name: 'duration_minutes')  int? durationMinutes,  String? brand,  String status)?  $default,) {final _that = this;
switch (_that) {
case _InventoryItem() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.code,_that.barcode,_that.category,_that.unit,_that.salePriceCents,_that.costPriceCents,_that.marginPercent,_that.sellable,_that.trackStock,_that.stockQty,_that.minQty,_that.durationMinutes,_that.brand,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryItem implements InventoryItem {
  const _InventoryItem({required this.id, required this.kind, required this.name, this.code, this.barcode, this.category, required this.unit, @JsonKey(name: 'sale_price_cents') this.salePriceCents = 0, @JsonKey(name: 'cost_price_cents') this.costPriceCents, @JsonKey(name: 'margin_percent') this.marginPercent, this.sellable = true, @JsonKey(name: 'track_stock') this.trackStock = true, @JsonKey(name: 'stock_qty') this.stockQty = '0', @JsonKey(name: 'min_qty') this.minQty, @JsonKey(name: 'duration_minutes') this.durationMinutes, this.brand, required this.status});
  factory _InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);

@override final  String id;
@override final  String kind;
// 'product' | 'service'
@override final  String name;
@override final  String? code;
@override final  String? barcode;
@override final  String? category;
@override final  String unit;
@override@JsonKey(name: 'sale_price_cents') final  int salePriceCents;
@override@JsonKey(name: 'cost_price_cents') final  int? costPriceCents;
@override@JsonKey(name: 'margin_percent') final  String? marginPercent;
@override@JsonKey() final  bool sellable;
@override@JsonKey(name: 'track_stock') final  bool trackStock;
@override@JsonKey(name: 'stock_qty') final  String stockQty;
@override@JsonKey(name: 'min_qty') final  String? minQty;
@override@JsonKey(name: 'duration_minutes') final  int? durationMinutes;
@override final  String? brand;
@override final  String status;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.code, code) || other.code == code)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.category, category) || other.category == category)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.salePriceCents, salePriceCents) || other.salePriceCents == salePriceCents)&&(identical(other.costPriceCents, costPriceCents) || other.costPriceCents == costPriceCents)&&(identical(other.marginPercent, marginPercent) || other.marginPercent == marginPercent)&&(identical(other.sellable, sellable) || other.sellable == sellable)&&(identical(other.trackStock, trackStock) || other.trackStock == trackStock)&&(identical(other.stockQty, stockQty) || other.stockQty == stockQty)&&(identical(other.minQty, minQty) || other.minQty == minQty)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,name,code,barcode,category,unit,salePriceCents,costPriceCents,marginPercent,sellable,trackStock,stockQty,minQty,durationMinutes,brand,status);

@override
String toString() {
  return 'InventoryItem(id: $id, kind: $kind, name: $name, code: $code, barcode: $barcode, category: $category, unit: $unit, salePriceCents: $salePriceCents, costPriceCents: $costPriceCents, marginPercent: $marginPercent, sellable: $sellable, trackStock: $trackStock, stockQty: $stockQty, minQty: $minQty, durationMinutes: $durationMinutes, brand: $brand, status: $status)';
}


}

/// @nodoc
abstract mixin class _$InventoryItemCopyWith<$Res> implements $InventoryItemCopyWith<$Res> {
  factory _$InventoryItemCopyWith(_InventoryItem value, $Res Function(_InventoryItem) _then) = __$InventoryItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String name, String? code, String? barcode, String? category, String unit,@JsonKey(name: 'sale_price_cents') int salePriceCents,@JsonKey(name: 'cost_price_cents') int? costPriceCents,@JsonKey(name: 'margin_percent') String? marginPercent, bool sellable,@JsonKey(name: 'track_stock') bool trackStock,@JsonKey(name: 'stock_qty') String stockQty,@JsonKey(name: 'min_qty') String? minQty,@JsonKey(name: 'duration_minutes') int? durationMinutes, String? brand, String status
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? code = freezed,Object? barcode = freezed,Object? category = freezed,Object? unit = null,Object? salePriceCents = null,Object? costPriceCents = freezed,Object? marginPercent = freezed,Object? sellable = null,Object? trackStock = null,Object? stockQty = null,Object? minQty = freezed,Object? durationMinutes = freezed,Object? brand = freezed,Object? status = null,}) {
  return _then(_InventoryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,salePriceCents: null == salePriceCents ? _self.salePriceCents : salePriceCents // ignore: cast_nullable_to_non_nullable
as int,costPriceCents: freezed == costPriceCents ? _self.costPriceCents : costPriceCents // ignore: cast_nullable_to_non_nullable
as int?,marginPercent: freezed == marginPercent ? _self.marginPercent : marginPercent // ignore: cast_nullable_to_non_nullable
as String?,sellable: null == sellable ? _self.sellable : sellable // ignore: cast_nullable_to_non_nullable
as bool,trackStock: null == trackStock ? _self.trackStock : trackStock // ignore: cast_nullable_to_non_nullable
as bool,stockQty: null == stockQty ? _self.stockQty : stockQty // ignore: cast_nullable_to_non_nullable
as String,minQty: freezed == minQty ? _self.minQty : minQty // ignore: cast_nullable_to_non_nullable
as String?,durationMinutes: freezed == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$InventoryMovement {

 String get id; String get type;// 'in' | 'out' | 'adjust'
 String get quantity;@JsonKey(name: 'balance_after') String get balanceAfter; String? get reason; String? get note;@JsonKey(name: 'created_at') String get createdAt;
/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryMovementCopyWith<InventoryMovement> get copyWith => _$InventoryMovementCopyWithImpl<InventoryMovement>(this as InventoryMovement, _$identity);

  /// Serializes this InventoryMovement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryMovement&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.balanceAfter, balanceAfter) || other.balanceAfter == balanceAfter)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,quantity,balanceAfter,reason,note,createdAt);

@override
String toString() {
  return 'InventoryMovement(id: $id, type: $type, quantity: $quantity, balanceAfter: $balanceAfter, reason: $reason, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $InventoryMovementCopyWith<$Res>  {
  factory $InventoryMovementCopyWith(InventoryMovement value, $Res Function(InventoryMovement) _then) = _$InventoryMovementCopyWithImpl;
@useResult
$Res call({
 String id, String type, String quantity,@JsonKey(name: 'balance_after') String balanceAfter, String? reason, String? note,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class _$InventoryMovementCopyWithImpl<$Res>
    implements $InventoryMovementCopyWith<$Res> {
  _$InventoryMovementCopyWithImpl(this._self, this._then);

  final InventoryMovement _self;
  final $Res Function(InventoryMovement) _then;

/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? quantity = null,Object? balanceAfter = null,Object? reason = freezed,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,balanceAfter: null == balanceAfter ? _self.balanceAfter : balanceAfter // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryMovement].
extension InventoryMovementPatterns on InventoryMovement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryMovement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryMovement value)  $default,){
final _that = this;
switch (_that) {
case _InventoryMovement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryMovement value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String quantity, @JsonKey(name: 'balance_after')  String balanceAfter,  String? reason,  String? note, @JsonKey(name: 'created_at')  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
return $default(_that.id,_that.type,_that.quantity,_that.balanceAfter,_that.reason,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String quantity, @JsonKey(name: 'balance_after')  String balanceAfter,  String? reason,  String? note, @JsonKey(name: 'created_at')  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _InventoryMovement():
return $default(_that.id,_that.type,_that.quantity,_that.balanceAfter,_that.reason,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String quantity, @JsonKey(name: 'balance_after')  String balanceAfter,  String? reason,  String? note, @JsonKey(name: 'created_at')  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _InventoryMovement() when $default != null:
return $default(_that.id,_that.type,_that.quantity,_that.balanceAfter,_that.reason,_that.note,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryMovement implements InventoryMovement {
  const _InventoryMovement({required this.id, required this.type, required this.quantity, @JsonKey(name: 'balance_after') required this.balanceAfter, this.reason, this.note, @JsonKey(name: 'created_at') required this.createdAt});
  factory _InventoryMovement.fromJson(Map<String, dynamic> json) => _$InventoryMovementFromJson(json);

@override final  String id;
@override final  String type;
// 'in' | 'out' | 'adjust'
@override final  String quantity;
@override@JsonKey(name: 'balance_after') final  String balanceAfter;
@override final  String? reason;
@override final  String? note;
@override@JsonKey(name: 'created_at') final  String createdAt;

/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryMovementCopyWith<_InventoryMovement> get copyWith => __$InventoryMovementCopyWithImpl<_InventoryMovement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryMovementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryMovement&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.balanceAfter, balanceAfter) || other.balanceAfter == balanceAfter)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,quantity,balanceAfter,reason,note,createdAt);

@override
String toString() {
  return 'InventoryMovement(id: $id, type: $type, quantity: $quantity, balanceAfter: $balanceAfter, reason: $reason, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$InventoryMovementCopyWith<$Res> implements $InventoryMovementCopyWith<$Res> {
  factory _$InventoryMovementCopyWith(_InventoryMovement value, $Res Function(_InventoryMovement) _then) = __$InventoryMovementCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String quantity,@JsonKey(name: 'balance_after') String balanceAfter, String? reason, String? note,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class __$InventoryMovementCopyWithImpl<$Res>
    implements _$InventoryMovementCopyWith<$Res> {
  __$InventoryMovementCopyWithImpl(this._self, this._then);

  final _InventoryMovement _self;
  final $Res Function(_InventoryMovement) _then;

/// Create a copy of InventoryMovement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? quantity = null,Object? balanceAfter = null,Object? reason = freezed,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_InventoryMovement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,balanceAfter: null == balanceAfter ? _self.balanceAfter : balanceAfter // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
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
mixin _$InventoryConfig {

 String get defaultUnit; bool get trackStockDefault; double? get defaultMarginPercent; List<String> get categories;
/// Create a copy of InventoryConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryConfigCopyWith<InventoryConfig> get copyWith => _$InventoryConfigCopyWithImpl<InventoryConfig>(this as InventoryConfig, _$identity);

  /// Serializes this InventoryConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryConfig&&(identical(other.defaultUnit, defaultUnit) || other.defaultUnit == defaultUnit)&&(identical(other.trackStockDefault, trackStockDefault) || other.trackStockDefault == trackStockDefault)&&(identical(other.defaultMarginPercent, defaultMarginPercent) || other.defaultMarginPercent == defaultMarginPercent)&&const DeepCollectionEquality().equals(other.categories, categories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,defaultUnit,trackStockDefault,defaultMarginPercent,const DeepCollectionEquality().hash(categories));

@override
String toString() {
  return 'InventoryConfig(defaultUnit: $defaultUnit, trackStockDefault: $trackStockDefault, defaultMarginPercent: $defaultMarginPercent, categories: $categories)';
}


}

/// @nodoc
abstract mixin class $InventoryConfigCopyWith<$Res>  {
  factory $InventoryConfigCopyWith(InventoryConfig value, $Res Function(InventoryConfig) _then) = _$InventoryConfigCopyWithImpl;
@useResult
$Res call({
 String defaultUnit, bool trackStockDefault, double? defaultMarginPercent, List<String> categories
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
@pragma('vm:prefer-inline') @override $Res call({Object? defaultUnit = null,Object? trackStockDefault = null,Object? defaultMarginPercent = freezed,Object? categories = null,}) {
  return _then(_self.copyWith(
defaultUnit: null == defaultUnit ? _self.defaultUnit : defaultUnit // ignore: cast_nullable_to_non_nullable
as String,trackStockDefault: null == trackStockDefault ? _self.trackStockDefault : trackStockDefault // ignore: cast_nullable_to_non_nullable
as bool,defaultMarginPercent: freezed == defaultMarginPercent ? _self.defaultMarginPercent : defaultMarginPercent // ignore: cast_nullable_to_non_nullable
as double?,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String defaultUnit,  bool trackStockDefault,  double? defaultMarginPercent,  List<String> categories)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that.defaultUnit,_that.trackStockDefault,_that.defaultMarginPercent,_that.categories);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String defaultUnit,  bool trackStockDefault,  double? defaultMarginPercent,  List<String> categories)  $default,) {final _that = this;
switch (_that) {
case _InventoryConfig():
return $default(_that.defaultUnit,_that.trackStockDefault,_that.defaultMarginPercent,_that.categories);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String defaultUnit,  bool trackStockDefault,  double? defaultMarginPercent,  List<String> categories)?  $default,) {final _that = this;
switch (_that) {
case _InventoryConfig() when $default != null:
return $default(_that.defaultUnit,_that.trackStockDefault,_that.defaultMarginPercent,_that.categories);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryConfig implements InventoryConfig {
  const _InventoryConfig({this.defaultUnit = 'un', this.trackStockDefault = true, this.defaultMarginPercent, final  List<String> categories = const <String>[]}): _categories = categories;
  factory _InventoryConfig.fromJson(Map<String, dynamic> json) => _$InventoryConfigFromJson(json);

@override@JsonKey() final  String defaultUnit;
@override@JsonKey() final  bool trackStockDefault;
@override final  double? defaultMarginPercent;
 final  List<String> _categories;
@override@JsonKey() List<String> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryConfig&&(identical(other.defaultUnit, defaultUnit) || other.defaultUnit == defaultUnit)&&(identical(other.trackStockDefault, trackStockDefault) || other.trackStockDefault == trackStockDefault)&&(identical(other.defaultMarginPercent, defaultMarginPercent) || other.defaultMarginPercent == defaultMarginPercent)&&const DeepCollectionEquality().equals(other._categories, _categories));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,defaultUnit,trackStockDefault,defaultMarginPercent,const DeepCollectionEquality().hash(_categories));

@override
String toString() {
  return 'InventoryConfig(defaultUnit: $defaultUnit, trackStockDefault: $trackStockDefault, defaultMarginPercent: $defaultMarginPercent, categories: $categories)';
}


}

/// @nodoc
abstract mixin class _$InventoryConfigCopyWith<$Res> implements $InventoryConfigCopyWith<$Res> {
  factory _$InventoryConfigCopyWith(_InventoryConfig value, $Res Function(_InventoryConfig) _then) = __$InventoryConfigCopyWithImpl;
@override @useResult
$Res call({
 String defaultUnit, bool trackStockDefault, double? defaultMarginPercent, List<String> categories
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
@override @pragma('vm:prefer-inline') $Res call({Object? defaultUnit = null,Object? trackStockDefault = null,Object? defaultMarginPercent = freezed,Object? categories = null,}) {
  return _then(_InventoryConfig(
defaultUnit: null == defaultUnit ? _self.defaultUnit : defaultUnit // ignore: cast_nullable_to_non_nullable
as String,trackStockDefault: null == trackStockDefault ? _self.trackStockDefault : trackStockDefault // ignore: cast_nullable_to_non_nullable
as bool,defaultMarginPercent: freezed == defaultMarginPercent ? _self.defaultMarginPercent : defaultMarginPercent // ignore: cast_nullable_to_non_nullable
as double?,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
