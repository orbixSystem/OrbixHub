// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OsMetrics {

 Map<String, int> get byStatus; num get revenue;@JsonKey(name: 'avgTicket') num get avgTicket; int get inExecution; int get overdue;@JsonKey(name: 'avgCycleMs') num? get avgCycleMs;
/// Create a copy of OsMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OsMetricsCopyWith<OsMetrics> get copyWith => _$OsMetricsCopyWithImpl<OsMetrics>(this as OsMetrics, _$identity);

  /// Serializes this OsMetrics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OsMetrics&&const DeepCollectionEquality().equals(other.byStatus, byStatus)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.avgTicket, avgTicket) || other.avgTicket == avgTicket)&&(identical(other.inExecution, inExecution) || other.inExecution == inExecution)&&(identical(other.overdue, overdue) || other.overdue == overdue)&&(identical(other.avgCycleMs, avgCycleMs) || other.avgCycleMs == avgCycleMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(byStatus),revenue,avgTicket,inExecution,overdue,avgCycleMs);

@override
String toString() {
  return 'OsMetrics(byStatus: $byStatus, revenue: $revenue, avgTicket: $avgTicket, inExecution: $inExecution, overdue: $overdue, avgCycleMs: $avgCycleMs)';
}


}

/// @nodoc
abstract mixin class $OsMetricsCopyWith<$Res>  {
  factory $OsMetricsCopyWith(OsMetrics value, $Res Function(OsMetrics) _then) = _$OsMetricsCopyWithImpl;
@useResult
$Res call({
 Map<String, int> byStatus, num revenue,@JsonKey(name: 'avgTicket') num avgTicket, int inExecution, int overdue,@JsonKey(name: 'avgCycleMs') num? avgCycleMs
});




}
/// @nodoc
class _$OsMetricsCopyWithImpl<$Res>
    implements $OsMetricsCopyWith<$Res> {
  _$OsMetricsCopyWithImpl(this._self, this._then);

  final OsMetrics _self;
  final $Res Function(OsMetrics) _then;

/// Create a copy of OsMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? byStatus = null,Object? revenue = null,Object? avgTicket = null,Object? inExecution = null,Object? overdue = null,Object? avgCycleMs = freezed,}) {
  return _then(_self.copyWith(
byStatus: null == byStatus ? _self.byStatus : byStatus // ignore: cast_nullable_to_non_nullable
as Map<String, int>,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,avgTicket: null == avgTicket ? _self.avgTicket : avgTicket // ignore: cast_nullable_to_non_nullable
as num,inExecution: null == inExecution ? _self.inExecution : inExecution // ignore: cast_nullable_to_non_nullable
as int,overdue: null == overdue ? _self.overdue : overdue // ignore: cast_nullable_to_non_nullable
as int,avgCycleMs: freezed == avgCycleMs ? _self.avgCycleMs : avgCycleMs // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}

}


/// Adds pattern-matching-related methods to [OsMetrics].
extension OsMetricsPatterns on OsMetrics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OsMetrics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OsMetrics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OsMetrics value)  $default,){
final _that = this;
switch (_that) {
case _OsMetrics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OsMetrics value)?  $default,){
final _that = this;
switch (_that) {
case _OsMetrics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, int> byStatus,  num revenue, @JsonKey(name: 'avgTicket')  num avgTicket,  int inExecution,  int overdue, @JsonKey(name: 'avgCycleMs')  num? avgCycleMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OsMetrics() when $default != null:
return $default(_that.byStatus,_that.revenue,_that.avgTicket,_that.inExecution,_that.overdue,_that.avgCycleMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, int> byStatus,  num revenue, @JsonKey(name: 'avgTicket')  num avgTicket,  int inExecution,  int overdue, @JsonKey(name: 'avgCycleMs')  num? avgCycleMs)  $default,) {final _that = this;
switch (_that) {
case _OsMetrics():
return $default(_that.byStatus,_that.revenue,_that.avgTicket,_that.inExecution,_that.overdue,_that.avgCycleMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, int> byStatus,  num revenue, @JsonKey(name: 'avgTicket')  num avgTicket,  int inExecution,  int overdue, @JsonKey(name: 'avgCycleMs')  num? avgCycleMs)?  $default,) {final _that = this;
switch (_that) {
case _OsMetrics() when $default != null:
return $default(_that.byStatus,_that.revenue,_that.avgTicket,_that.inExecution,_that.overdue,_that.avgCycleMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OsMetrics extends OsMetrics {
  const _OsMetrics({final  Map<String, int> byStatus = const <String, int>{}, this.revenue = 0, @JsonKey(name: 'avgTicket') this.avgTicket = 0, this.inExecution = 0, this.overdue = 0, @JsonKey(name: 'avgCycleMs') this.avgCycleMs}): _byStatus = byStatus,super._();
  factory _OsMetrics.fromJson(Map<String, dynamic> json) => _$OsMetricsFromJson(json);

 final  Map<String, int> _byStatus;
@override@JsonKey() Map<String, int> get byStatus {
  if (_byStatus is EqualUnmodifiableMapView) return _byStatus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_byStatus);
}

@override@JsonKey() final  num revenue;
@override@JsonKey(name: 'avgTicket') final  num avgTicket;
@override@JsonKey() final  int inExecution;
@override@JsonKey() final  int overdue;
@override@JsonKey(name: 'avgCycleMs') final  num? avgCycleMs;

/// Create a copy of OsMetrics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OsMetricsCopyWith<_OsMetrics> get copyWith => __$OsMetricsCopyWithImpl<_OsMetrics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OsMetricsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OsMetrics&&const DeepCollectionEquality().equals(other._byStatus, _byStatus)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.avgTicket, avgTicket) || other.avgTicket == avgTicket)&&(identical(other.inExecution, inExecution) || other.inExecution == inExecution)&&(identical(other.overdue, overdue) || other.overdue == overdue)&&(identical(other.avgCycleMs, avgCycleMs) || other.avgCycleMs == avgCycleMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_byStatus),revenue,avgTicket,inExecution,overdue,avgCycleMs);

@override
String toString() {
  return 'OsMetrics(byStatus: $byStatus, revenue: $revenue, avgTicket: $avgTicket, inExecution: $inExecution, overdue: $overdue, avgCycleMs: $avgCycleMs)';
}


}

/// @nodoc
abstract mixin class _$OsMetricsCopyWith<$Res> implements $OsMetricsCopyWith<$Res> {
  factory _$OsMetricsCopyWith(_OsMetrics value, $Res Function(_OsMetrics) _then) = __$OsMetricsCopyWithImpl;
@override @useResult
$Res call({
 Map<String, int> byStatus, num revenue,@JsonKey(name: 'avgTicket') num avgTicket, int inExecution, int overdue,@JsonKey(name: 'avgCycleMs') num? avgCycleMs
});




}
/// @nodoc
class __$OsMetricsCopyWithImpl<$Res>
    implements _$OsMetricsCopyWith<$Res> {
  __$OsMetricsCopyWithImpl(this._self, this._then);

  final _OsMetrics _self;
  final $Res Function(_OsMetrics) _then;

/// Create a copy of OsMetrics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? byStatus = null,Object? revenue = null,Object? avgTicket = null,Object? inExecution = null,Object? overdue = null,Object? avgCycleMs = freezed,}) {
  return _then(_OsMetrics(
byStatus: null == byStatus ? _self._byStatus : byStatus // ignore: cast_nullable_to_non_nullable
as Map<String, int>,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,avgTicket: null == avgTicket ? _self.avgTicket : avgTicket // ignore: cast_nullable_to_non_nullable
as num,inExecution: null == inExecution ? _self.inExecution : inExecution // ignore: cast_nullable_to_non_nullable
as int,overdue: null == overdue ? _self.overdue : overdue // ignore: cast_nullable_to_non_nullable
as int,avgCycleMs: freezed == avgCycleMs ? _self.avgCycleMs : avgCycleMs // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}


}


/// @nodoc
mixin _$LowStockItem {

 String get id; String get name; String? get sku;@JsonKey(name: 'current_stock') String get currentStock;@JsonKey(name: 'min_stock') String? get minStock;
/// Create a copy of LowStockItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LowStockItemCopyWith<LowStockItem> get copyWith => _$LowStockItemCopyWithImpl<LowStockItem>(this as LowStockItem, _$identity);

  /// Serializes this LowStockItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LowStockItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock)&&(identical(other.minStock, minStock) || other.minStock == minStock));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sku,currentStock,minStock);

@override
String toString() {
  return 'LowStockItem(id: $id, name: $name, sku: $sku, currentStock: $currentStock, minStock: $minStock)';
}


}

/// @nodoc
abstract mixin class $LowStockItemCopyWith<$Res>  {
  factory $LowStockItemCopyWith(LowStockItem value, $Res Function(LowStockItem) _then) = _$LowStockItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? sku,@JsonKey(name: 'current_stock') String currentStock,@JsonKey(name: 'min_stock') String? minStock
});




}
/// @nodoc
class _$LowStockItemCopyWithImpl<$Res>
    implements $LowStockItemCopyWith<$Res> {
  _$LowStockItemCopyWithImpl(this._self, this._then);

  final LowStockItem _self;
  final $Res Function(LowStockItem) _then;

/// Create a copy of LowStockItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sku = freezed,Object? currentStock = null,Object? minStock = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,currentStock: null == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as String,minStock: freezed == minStock ? _self.minStock : minStock // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LowStockItem].
extension LowStockItemPatterns on LowStockItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LowStockItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LowStockItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LowStockItem value)  $default,){
final _that = this;
switch (_that) {
case _LowStockItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LowStockItem value)?  $default,){
final _that = this;
switch (_that) {
case _LowStockItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? sku, @JsonKey(name: 'current_stock')  String currentStock, @JsonKey(name: 'min_stock')  String? minStock)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LowStockItem() when $default != null:
return $default(_that.id,_that.name,_that.sku,_that.currentStock,_that.minStock);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? sku, @JsonKey(name: 'current_stock')  String currentStock, @JsonKey(name: 'min_stock')  String? minStock)  $default,) {final _that = this;
switch (_that) {
case _LowStockItem():
return $default(_that.id,_that.name,_that.sku,_that.currentStock,_that.minStock);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? sku, @JsonKey(name: 'current_stock')  String currentStock, @JsonKey(name: 'min_stock')  String? minStock)?  $default,) {final _that = this;
switch (_that) {
case _LowStockItem() when $default != null:
return $default(_that.id,_that.name,_that.sku,_that.currentStock,_that.minStock);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LowStockItem implements LowStockItem {
  const _LowStockItem({required this.id, required this.name, this.sku, @JsonKey(name: 'current_stock') this.currentStock = '0', @JsonKey(name: 'min_stock') this.minStock});
  factory _LowStockItem.fromJson(Map<String, dynamic> json) => _$LowStockItemFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? sku;
@override@JsonKey(name: 'current_stock') final  String currentStock;
@override@JsonKey(name: 'min_stock') final  String? minStock;

/// Create a copy of LowStockItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LowStockItemCopyWith<_LowStockItem> get copyWith => __$LowStockItemCopyWithImpl<_LowStockItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LowStockItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LowStockItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock)&&(identical(other.minStock, minStock) || other.minStock == minStock));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sku,currentStock,minStock);

@override
String toString() {
  return 'LowStockItem(id: $id, name: $name, sku: $sku, currentStock: $currentStock, minStock: $minStock)';
}


}

/// @nodoc
abstract mixin class _$LowStockItemCopyWith<$Res> implements $LowStockItemCopyWith<$Res> {
  factory _$LowStockItemCopyWith(_LowStockItem value, $Res Function(_LowStockItem) _then) = __$LowStockItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? sku,@JsonKey(name: 'current_stock') String currentStock,@JsonKey(name: 'min_stock') String? minStock
});




}
/// @nodoc
class __$LowStockItemCopyWithImpl<$Res>
    implements _$LowStockItemCopyWith<$Res> {
  __$LowStockItemCopyWithImpl(this._self, this._then);

  final _LowStockItem _self;
  final $Res Function(_LowStockItem) _then;

/// Create a copy of LowStockItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sku = freezed,Object? currentStock = null,Object? minStock = freezed,}) {
  return _then(_LowStockItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,currentStock: null == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as String,minStock: freezed == minStock ? _self.minStock : minStock // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$InventoryMetrics {

 int get belowMin;@JsonKey(name: 'stockValue') num get stockValue; int get products; int get services;@JsonKey(name: 'lowStockSample') List<LowStockItem> get lowStockSample;
/// Create a copy of InventoryMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryMetricsCopyWith<InventoryMetrics> get copyWith => _$InventoryMetricsCopyWithImpl<InventoryMetrics>(this as InventoryMetrics, _$identity);

  /// Serializes this InventoryMetrics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryMetrics&&(identical(other.belowMin, belowMin) || other.belowMin == belowMin)&&(identical(other.stockValue, stockValue) || other.stockValue == stockValue)&&(identical(other.products, products) || other.products == products)&&(identical(other.services, services) || other.services == services)&&const DeepCollectionEquality().equals(other.lowStockSample, lowStockSample));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,belowMin,stockValue,products,services,const DeepCollectionEquality().hash(lowStockSample));

@override
String toString() {
  return 'InventoryMetrics(belowMin: $belowMin, stockValue: $stockValue, products: $products, services: $services, lowStockSample: $lowStockSample)';
}


}

/// @nodoc
abstract mixin class $InventoryMetricsCopyWith<$Res>  {
  factory $InventoryMetricsCopyWith(InventoryMetrics value, $Res Function(InventoryMetrics) _then) = _$InventoryMetricsCopyWithImpl;
@useResult
$Res call({
 int belowMin,@JsonKey(name: 'stockValue') num stockValue, int products, int services,@JsonKey(name: 'lowStockSample') List<LowStockItem> lowStockSample
});




}
/// @nodoc
class _$InventoryMetricsCopyWithImpl<$Res>
    implements $InventoryMetricsCopyWith<$Res> {
  _$InventoryMetricsCopyWithImpl(this._self, this._then);

  final InventoryMetrics _self;
  final $Res Function(InventoryMetrics) _then;

/// Create a copy of InventoryMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? belowMin = null,Object? stockValue = null,Object? products = null,Object? services = null,Object? lowStockSample = null,}) {
  return _then(_self.copyWith(
belowMin: null == belowMin ? _self.belowMin : belowMin // ignore: cast_nullable_to_non_nullable
as int,stockValue: null == stockValue ? _self.stockValue : stockValue // ignore: cast_nullable_to_non_nullable
as num,products: null == products ? _self.products : products // ignore: cast_nullable_to_non_nullable
as int,services: null == services ? _self.services : services // ignore: cast_nullable_to_non_nullable
as int,lowStockSample: null == lowStockSample ? _self.lowStockSample : lowStockSample // ignore: cast_nullable_to_non_nullable
as List<LowStockItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryMetrics].
extension InventoryMetricsPatterns on InventoryMetrics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryMetrics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryMetrics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryMetrics value)  $default,){
final _that = this;
switch (_that) {
case _InventoryMetrics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryMetrics value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryMetrics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int belowMin, @JsonKey(name: 'stockValue')  num stockValue,  int products,  int services, @JsonKey(name: 'lowStockSample')  List<LowStockItem> lowStockSample)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryMetrics() when $default != null:
return $default(_that.belowMin,_that.stockValue,_that.products,_that.services,_that.lowStockSample);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int belowMin, @JsonKey(name: 'stockValue')  num stockValue,  int products,  int services, @JsonKey(name: 'lowStockSample')  List<LowStockItem> lowStockSample)  $default,) {final _that = this;
switch (_that) {
case _InventoryMetrics():
return $default(_that.belowMin,_that.stockValue,_that.products,_that.services,_that.lowStockSample);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int belowMin, @JsonKey(name: 'stockValue')  num stockValue,  int products,  int services, @JsonKey(name: 'lowStockSample')  List<LowStockItem> lowStockSample)?  $default,) {final _that = this;
switch (_that) {
case _InventoryMetrics() when $default != null:
return $default(_that.belowMin,_that.stockValue,_that.products,_that.services,_that.lowStockSample);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryMetrics implements InventoryMetrics {
  const _InventoryMetrics({this.belowMin = 0, @JsonKey(name: 'stockValue') this.stockValue = 0, this.products = 0, this.services = 0, @JsonKey(name: 'lowStockSample') final  List<LowStockItem> lowStockSample = const <LowStockItem>[]}): _lowStockSample = lowStockSample;
  factory _InventoryMetrics.fromJson(Map<String, dynamic> json) => _$InventoryMetricsFromJson(json);

@override@JsonKey() final  int belowMin;
@override@JsonKey(name: 'stockValue') final  num stockValue;
@override@JsonKey() final  int products;
@override@JsonKey() final  int services;
 final  List<LowStockItem> _lowStockSample;
@override@JsonKey(name: 'lowStockSample') List<LowStockItem> get lowStockSample {
  if (_lowStockSample is EqualUnmodifiableListView) return _lowStockSample;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lowStockSample);
}


/// Create a copy of InventoryMetrics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryMetricsCopyWith<_InventoryMetrics> get copyWith => __$InventoryMetricsCopyWithImpl<_InventoryMetrics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryMetricsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryMetrics&&(identical(other.belowMin, belowMin) || other.belowMin == belowMin)&&(identical(other.stockValue, stockValue) || other.stockValue == stockValue)&&(identical(other.products, products) || other.products == products)&&(identical(other.services, services) || other.services == services)&&const DeepCollectionEquality().equals(other._lowStockSample, _lowStockSample));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,belowMin,stockValue,products,services,const DeepCollectionEquality().hash(_lowStockSample));

@override
String toString() {
  return 'InventoryMetrics(belowMin: $belowMin, stockValue: $stockValue, products: $products, services: $services, lowStockSample: $lowStockSample)';
}


}

/// @nodoc
abstract mixin class _$InventoryMetricsCopyWith<$Res> implements $InventoryMetricsCopyWith<$Res> {
  factory _$InventoryMetricsCopyWith(_InventoryMetrics value, $Res Function(_InventoryMetrics) _then) = __$InventoryMetricsCopyWithImpl;
@override @useResult
$Res call({
 int belowMin,@JsonKey(name: 'stockValue') num stockValue, int products, int services,@JsonKey(name: 'lowStockSample') List<LowStockItem> lowStockSample
});




}
/// @nodoc
class __$InventoryMetricsCopyWithImpl<$Res>
    implements _$InventoryMetricsCopyWith<$Res> {
  __$InventoryMetricsCopyWithImpl(this._self, this._then);

  final _InventoryMetrics _self;
  final $Res Function(_InventoryMetrics) _then;

/// Create a copy of InventoryMetrics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? belowMin = null,Object? stockValue = null,Object? products = null,Object? services = null,Object? lowStockSample = null,}) {
  return _then(_InventoryMetrics(
belowMin: null == belowMin ? _self.belowMin : belowMin // ignore: cast_nullable_to_non_nullable
as int,stockValue: null == stockValue ? _self.stockValue : stockValue // ignore: cast_nullable_to_non_nullable
as num,products: null == products ? _self.products : products // ignore: cast_nullable_to_non_nullable
as int,services: null == services ? _self.services : services // ignore: cast_nullable_to_non_nullable
as int,lowStockSample: null == lowStockSample ? _self._lowStockSample : lowStockSample // ignore: cast_nullable_to_non_nullable
as List<LowStockItem>,
  ));
}


}


/// @nodoc
mixin _$CustomersMetrics {

 int get active;@JsonKey(name: 'newInRange') int get newInRange;
/// Create a copy of CustomersMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomersMetricsCopyWith<CustomersMetrics> get copyWith => _$CustomersMetricsCopyWithImpl<CustomersMetrics>(this as CustomersMetrics, _$identity);

  /// Serializes this CustomersMetrics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomersMetrics&&(identical(other.active, active) || other.active == active)&&(identical(other.newInRange, newInRange) || other.newInRange == newInRange));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,active,newInRange);

@override
String toString() {
  return 'CustomersMetrics(active: $active, newInRange: $newInRange)';
}


}

/// @nodoc
abstract mixin class $CustomersMetricsCopyWith<$Res>  {
  factory $CustomersMetricsCopyWith(CustomersMetrics value, $Res Function(CustomersMetrics) _then) = _$CustomersMetricsCopyWithImpl;
@useResult
$Res call({
 int active,@JsonKey(name: 'newInRange') int newInRange
});




}
/// @nodoc
class _$CustomersMetricsCopyWithImpl<$Res>
    implements $CustomersMetricsCopyWith<$Res> {
  _$CustomersMetricsCopyWithImpl(this._self, this._then);

  final CustomersMetrics _self;
  final $Res Function(CustomersMetrics) _then;

/// Create a copy of CustomersMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? active = null,Object? newInRange = null,}) {
  return _then(_self.copyWith(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as int,newInRange: null == newInRange ? _self.newInRange : newInRange // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomersMetrics].
extension CustomersMetricsPatterns on CustomersMetrics {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomersMetrics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomersMetrics() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomersMetrics value)  $default,){
final _that = this;
switch (_that) {
case _CustomersMetrics():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomersMetrics value)?  $default,){
final _that = this;
switch (_that) {
case _CustomersMetrics() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int active, @JsonKey(name: 'newInRange')  int newInRange)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomersMetrics() when $default != null:
return $default(_that.active,_that.newInRange);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int active, @JsonKey(name: 'newInRange')  int newInRange)  $default,) {final _that = this;
switch (_that) {
case _CustomersMetrics():
return $default(_that.active,_that.newInRange);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int active, @JsonKey(name: 'newInRange')  int newInRange)?  $default,) {final _that = this;
switch (_that) {
case _CustomersMetrics() when $default != null:
return $default(_that.active,_that.newInRange);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomersMetrics implements CustomersMetrics {
  const _CustomersMetrics({this.active = 0, @JsonKey(name: 'newInRange') this.newInRange = 0});
  factory _CustomersMetrics.fromJson(Map<String, dynamic> json) => _$CustomersMetricsFromJson(json);

@override@JsonKey() final  int active;
@override@JsonKey(name: 'newInRange') final  int newInRange;

/// Create a copy of CustomersMetrics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomersMetricsCopyWith<_CustomersMetrics> get copyWith => __$CustomersMetricsCopyWithImpl<_CustomersMetrics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomersMetricsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomersMetrics&&(identical(other.active, active) || other.active == active)&&(identical(other.newInRange, newInRange) || other.newInRange == newInRange));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,active,newInRange);

@override
String toString() {
  return 'CustomersMetrics(active: $active, newInRange: $newInRange)';
}


}

/// @nodoc
abstract mixin class _$CustomersMetricsCopyWith<$Res> implements $CustomersMetricsCopyWith<$Res> {
  factory _$CustomersMetricsCopyWith(_CustomersMetrics value, $Res Function(_CustomersMetrics) _then) = __$CustomersMetricsCopyWithImpl;
@override @useResult
$Res call({
 int active,@JsonKey(name: 'newInRange') int newInRange
});




}
/// @nodoc
class __$CustomersMetricsCopyWithImpl<$Res>
    implements _$CustomersMetricsCopyWith<$Res> {
  __$CustomersMetricsCopyWithImpl(this._self, this._then);

  final _CustomersMetrics _self;
  final $Res Function(_CustomersMetrics) _then;

/// Create a copy of CustomersMetrics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? active = null,Object? newInRange = null,}) {
  return _then(_CustomersMetrics(
active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as int,newInRange: null == newInRange ? _self.newInRange : newInRange // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
