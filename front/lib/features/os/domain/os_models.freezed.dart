// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'os_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrderItem {

 String get id; String get kind;// 'product' | 'service'
@JsonKey(name: 'inventory_item_id') String? get inventoryItemId; String get name; String get quantity;@JsonKey(name: 'unit_price') String get unitPrice; String get discount; String get total;// Agenda
@JsonKey(name: 'assigned_to') String? get assignedTo;@JsonKey(name: 'scheduled_start') String? get scheduledStart;@JsonKey(name: 'estimated_duration') int? get estimatedDuration;@JsonKey(name: 'scheduled_end') String? get scheduledEnd;
/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderItemCopyWith<OrderItem> get copyWith => _$OrderItemCopyWithImpl<OrderItem>(this as OrderItem, _$identity);

  /// Serializes this OrderItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.total, total) || other.total == total)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.scheduledStart, scheduledStart) || other.scheduledStart == scheduledStart)&&(identical(other.estimatedDuration, estimatedDuration) || other.estimatedDuration == estimatedDuration)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,inventoryItemId,name,quantity,unitPrice,discount,total,assignedTo,scheduledStart,estimatedDuration,scheduledEnd);

@override
String toString() {
  return 'OrderItem(id: $id, kind: $kind, inventoryItemId: $inventoryItemId, name: $name, quantity: $quantity, unitPrice: $unitPrice, discount: $discount, total: $total, assignedTo: $assignedTo, scheduledStart: $scheduledStart, estimatedDuration: $estimatedDuration, scheduledEnd: $scheduledEnd)';
}


}

/// @nodoc
abstract mixin class $OrderItemCopyWith<$Res>  {
  factory $OrderItemCopyWith(OrderItem value, $Res Function(OrderItem) _then) = _$OrderItemCopyWithImpl;
@useResult
$Res call({
 String id, String kind,@JsonKey(name: 'inventory_item_id') String? inventoryItemId, String name, String quantity,@JsonKey(name: 'unit_price') String unitPrice, String discount, String total,@JsonKey(name: 'assigned_to') String? assignedTo,@JsonKey(name: 'scheduled_start') String? scheduledStart,@JsonKey(name: 'estimated_duration') int? estimatedDuration,@JsonKey(name: 'scheduled_end') String? scheduledEnd
});




}
/// @nodoc
class _$OrderItemCopyWithImpl<$Res>
    implements $OrderItemCopyWith<$Res> {
  _$OrderItemCopyWithImpl(this._self, this._then);

  final OrderItem _self;
  final $Res Function(OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? inventoryItemId = freezed,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? discount = null,Object? total = null,Object? assignedTo = freezed,Object? scheduledStart = freezed,Object? estimatedDuration = freezed,Object? scheduledEnd = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,scheduledStart: freezed == scheduledStart ? _self.scheduledStart : scheduledStart // ignore: cast_nullable_to_non_nullable
as String?,estimatedDuration: freezed == estimatedDuration ? _self.estimatedDuration : estimatedDuration // ignore: cast_nullable_to_non_nullable
as int?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderItem].
extension OrderItemPatterns on OrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderItem value)  $default,){
final _that = this;
switch (_that) {
case _OrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String discount,  String total, @JsonKey(name: 'assigned_to')  String? assignedTo, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'estimated_duration')  int? estimatedDuration, @JsonKey(name: 'scheduled_end')  String? scheduledEnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice,_that.discount,_that.total,_that.assignedTo,_that.scheduledStart,_that.estimatedDuration,_that.scheduledEnd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String discount,  String total, @JsonKey(name: 'assigned_to')  String? assignedTo, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'estimated_duration')  int? estimatedDuration, @JsonKey(name: 'scheduled_end')  String? scheduledEnd)  $default,) {final _that = this;
switch (_that) {
case _OrderItem():
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice,_that.discount,_that.total,_that.assignedTo,_that.scheduledStart,_that.estimatedDuration,_that.scheduledEnd);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String discount,  String total, @JsonKey(name: 'assigned_to')  String? assignedTo, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'estimated_duration')  int? estimatedDuration, @JsonKey(name: 'scheduled_end')  String? scheduledEnd)?  $default,) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice,_that.discount,_that.total,_that.assignedTo,_that.scheduledStart,_that.estimatedDuration,_that.scheduledEnd);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderItem implements OrderItem {
  const _OrderItem({required this.id, this.kind = 'product', @JsonKey(name: 'inventory_item_id') this.inventoryItemId, required this.name, this.quantity = '1', @JsonKey(name: 'unit_price') this.unitPrice = '0', this.discount = '0', this.total = '0', @JsonKey(name: 'assigned_to') this.assignedTo, @JsonKey(name: 'scheduled_start') this.scheduledStart, @JsonKey(name: 'estimated_duration') this.estimatedDuration, @JsonKey(name: 'scheduled_end') this.scheduledEnd});
  factory _OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);

@override final  String id;
@override@JsonKey() final  String kind;
// 'product' | 'service'
@override@JsonKey(name: 'inventory_item_id') final  String? inventoryItemId;
@override final  String name;
@override@JsonKey() final  String quantity;
@override@JsonKey(name: 'unit_price') final  String unitPrice;
@override@JsonKey() final  String discount;
@override@JsonKey() final  String total;
// Agenda
@override@JsonKey(name: 'assigned_to') final  String? assignedTo;
@override@JsonKey(name: 'scheduled_start') final  String? scheduledStart;
@override@JsonKey(name: 'estimated_duration') final  int? estimatedDuration;
@override@JsonKey(name: 'scheduled_end') final  String? scheduledEnd;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderItemCopyWith<_OrderItem> get copyWith => __$OrderItemCopyWithImpl<_OrderItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.total, total) || other.total == total)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.scheduledStart, scheduledStart) || other.scheduledStart == scheduledStart)&&(identical(other.estimatedDuration, estimatedDuration) || other.estimatedDuration == estimatedDuration)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,inventoryItemId,name,quantity,unitPrice,discount,total,assignedTo,scheduledStart,estimatedDuration,scheduledEnd);

@override
String toString() {
  return 'OrderItem(id: $id, kind: $kind, inventoryItemId: $inventoryItemId, name: $name, quantity: $quantity, unitPrice: $unitPrice, discount: $discount, total: $total, assignedTo: $assignedTo, scheduledStart: $scheduledStart, estimatedDuration: $estimatedDuration, scheduledEnd: $scheduledEnd)';
}


}

/// @nodoc
abstract mixin class _$OrderItemCopyWith<$Res> implements $OrderItemCopyWith<$Res> {
  factory _$OrderItemCopyWith(_OrderItem value, $Res Function(_OrderItem) _then) = __$OrderItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind,@JsonKey(name: 'inventory_item_id') String? inventoryItemId, String name, String quantity,@JsonKey(name: 'unit_price') String unitPrice, String discount, String total,@JsonKey(name: 'assigned_to') String? assignedTo,@JsonKey(name: 'scheduled_start') String? scheduledStart,@JsonKey(name: 'estimated_duration') int? estimatedDuration,@JsonKey(name: 'scheduled_end') String? scheduledEnd
});




}
/// @nodoc
class __$OrderItemCopyWithImpl<$Res>
    implements _$OrderItemCopyWith<$Res> {
  __$OrderItemCopyWithImpl(this._self, this._then);

  final _OrderItem _self;
  final $Res Function(_OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? inventoryItemId = freezed,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? discount = null,Object? total = null,Object? assignedTo = freezed,Object? scheduledStart = freezed,Object? estimatedDuration = freezed,Object? scheduledEnd = freezed,}) {
  return _then(_OrderItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,scheduledStart: freezed == scheduledStart ? _self.scheduledStart : scheduledStart // ignore: cast_nullable_to_non_nullable
as String?,estimatedDuration: freezed == estimatedDuration ? _self.estimatedDuration : estimatedDuration // ignore: cast_nullable_to_non_nullable
as int?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OrderEvent {

 String get id; String get kind;// 'created' | 'status_change' | 'note' | 'photo'
 String? get message;@JsonKey(name: 'status_snapshot') String? get statusSnapshot;@JsonKey(name: 'visible_public') bool get visiblePublic;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of OrderEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderEventCopyWith<OrderEvent> get copyWith => _$OrderEventCopyWithImpl<OrderEvent>(this as OrderEvent, _$identity);

  /// Serializes this OrderEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message)&&(identical(other.statusSnapshot, statusSnapshot) || other.statusSnapshot == statusSnapshot)&&(identical(other.visiblePublic, visiblePublic) || other.visiblePublic == visiblePublic)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,message,statusSnapshot,visiblePublic,createdAt);

@override
String toString() {
  return 'OrderEvent(id: $id, kind: $kind, message: $message, statusSnapshot: $statusSnapshot, visiblePublic: $visiblePublic, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OrderEventCopyWith<$Res>  {
  factory $OrderEventCopyWith(OrderEvent value, $Res Function(OrderEvent) _then) = _$OrderEventCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String? message,@JsonKey(name: 'status_snapshot') String? statusSnapshot,@JsonKey(name: 'visible_public') bool visiblePublic,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$OrderEventCopyWithImpl<$Res>
    implements $OrderEventCopyWith<$Res> {
  _$OrderEventCopyWithImpl(this._self, this._then);

  final OrderEvent _self;
  final $Res Function(OrderEvent) _then;

/// Create a copy of OrderEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? message = freezed,Object? statusSnapshot = freezed,Object? visiblePublic = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,statusSnapshot: freezed == statusSnapshot ? _self.statusSnapshot : statusSnapshot // ignore: cast_nullable_to_non_nullable
as String?,visiblePublic: null == visiblePublic ? _self.visiblePublic : visiblePublic // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderEvent].
extension OrderEventPatterns on OrderEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderEvent value)  $default,){
final _that = this;
switch (_that) {
case _OrderEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderEvent value)?  $default,){
final _that = this;
switch (_that) {
case _OrderEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  String? message, @JsonKey(name: 'status_snapshot')  String? statusSnapshot, @JsonKey(name: 'visible_public')  bool visiblePublic, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderEvent() when $default != null:
return $default(_that.id,_that.kind,_that.message,_that.statusSnapshot,_that.visiblePublic,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  String? message, @JsonKey(name: 'status_snapshot')  String? statusSnapshot, @JsonKey(name: 'visible_public')  bool visiblePublic, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _OrderEvent():
return $default(_that.id,_that.kind,_that.message,_that.statusSnapshot,_that.visiblePublic,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  String? message, @JsonKey(name: 'status_snapshot')  String? statusSnapshot, @JsonKey(name: 'visible_public')  bool visiblePublic, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OrderEvent() when $default != null:
return $default(_that.id,_that.kind,_that.message,_that.statusSnapshot,_that.visiblePublic,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderEvent implements OrderEvent {
  const _OrderEvent({required this.id, this.kind = 'note', this.message, @JsonKey(name: 'status_snapshot') this.statusSnapshot, @JsonKey(name: 'visible_public') this.visiblePublic = false, @JsonKey(name: 'created_at') this.createdAt});
  factory _OrderEvent.fromJson(Map<String, dynamic> json) => _$OrderEventFromJson(json);

@override final  String id;
@override@JsonKey() final  String kind;
// 'created' | 'status_change' | 'note' | 'photo'
@override final  String? message;
@override@JsonKey(name: 'status_snapshot') final  String? statusSnapshot;
@override@JsonKey(name: 'visible_public') final  bool visiblePublic;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of OrderEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderEventCopyWith<_OrderEvent> get copyWith => __$OrderEventCopyWithImpl<_OrderEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message)&&(identical(other.statusSnapshot, statusSnapshot) || other.statusSnapshot == statusSnapshot)&&(identical(other.visiblePublic, visiblePublic) || other.visiblePublic == visiblePublic)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,message,statusSnapshot,visiblePublic,createdAt);

@override
String toString() {
  return 'OrderEvent(id: $id, kind: $kind, message: $message, statusSnapshot: $statusSnapshot, visiblePublic: $visiblePublic, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OrderEventCopyWith<$Res> implements $OrderEventCopyWith<$Res> {
  factory _$OrderEventCopyWith(_OrderEvent value, $Res Function(_OrderEvent) _then) = __$OrderEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String? message,@JsonKey(name: 'status_snapshot') String? statusSnapshot,@JsonKey(name: 'visible_public') bool visiblePublic,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$OrderEventCopyWithImpl<$Res>
    implements _$OrderEventCopyWith<$Res> {
  __$OrderEventCopyWithImpl(this._self, this._then);

  final _OrderEvent _self;
  final $Res Function(_OrderEvent) _then;

/// Create a copy of OrderEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? message = freezed,Object? statusSnapshot = freezed,Object? visiblePublic = null,Object? createdAt = freezed,}) {
  return _then(_OrderEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,statusSnapshot: freezed == statusSnapshot ? _self.statusSnapshot : statusSnapshot // ignore: cast_nullable_to_non_nullable
as String?,visiblePublic: null == visiblePublic ? _self.visiblePublic : visiblePublic // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OrderPhoto {

 String get id; String get url; String? get caption;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of OrderPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderPhotoCopyWith<OrderPhoto> get copyWith => _$OrderPhotoCopyWithImpl<OrderPhoto>(this as OrderPhoto, _$identity);

  /// Serializes this OrderPhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,url,caption,createdAt);

@override
String toString() {
  return 'OrderPhoto(id: $id, url: $url, caption: $caption, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OrderPhotoCopyWith<$Res>  {
  factory $OrderPhotoCopyWith(OrderPhoto value, $Res Function(OrderPhoto) _then) = _$OrderPhotoCopyWithImpl;
@useResult
$Res call({
 String id, String url, String? caption,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$OrderPhotoCopyWithImpl<$Res>
    implements $OrderPhotoCopyWith<$Res> {
  _$OrderPhotoCopyWithImpl(this._self, this._then);

  final OrderPhoto _self;
  final $Res Function(OrderPhoto) _then;

/// Create a copy of OrderPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? caption = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderPhoto].
extension OrderPhotoPatterns on OrderPhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderPhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderPhoto value)  $default,){
final _that = this;
switch (_that) {
case _OrderPhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _OrderPhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  String? caption, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderPhoto() when $default != null:
return $default(_that.id,_that.url,_that.caption,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  String? caption, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _OrderPhoto():
return $default(_that.id,_that.url,_that.caption,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  String? caption, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OrderPhoto() when $default != null:
return $default(_that.id,_that.url,_that.caption,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderPhoto implements OrderPhoto {
  const _OrderPhoto({required this.id, required this.url, this.caption, @JsonKey(name: 'created_at') this.createdAt});
  factory _OrderPhoto.fromJson(Map<String, dynamic> json) => _$OrderPhotoFromJson(json);

@override final  String id;
@override final  String url;
@override final  String? caption;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of OrderPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderPhotoCopyWith<_OrderPhoto> get copyWith => __$OrderPhotoCopyWithImpl<_OrderPhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderPhotoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,url,caption,createdAt);

@override
String toString() {
  return 'OrderPhoto(id: $id, url: $url, caption: $caption, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OrderPhotoCopyWith<$Res> implements $OrderPhotoCopyWith<$Res> {
  factory _$OrderPhotoCopyWith(_OrderPhoto value, $Res Function(_OrderPhoto) _then) = __$OrderPhotoCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, String? caption,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$OrderPhotoCopyWithImpl<$Res>
    implements _$OrderPhotoCopyWith<$Res> {
  __$OrderPhotoCopyWithImpl(this._self, this._then);

  final _OrderPhoto _self;
  final $Res Function(_OrderPhoto) _then;

/// Create a copy of OrderPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? caption = freezed,Object? createdAt = freezed,}) {
  return _then(_OrderPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PhotoComment {

@JsonKey(name: 'author_kind') String get authorKind;@JsonKey(name: 'author_name') String? get authorName; String get body;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of PhotoComment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoCommentCopyWith<PhotoComment> get copyWith => _$PhotoCommentCopyWithImpl<PhotoComment>(this as PhotoComment, _$identity);

  /// Serializes this PhotoComment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoComment&&(identical(other.authorKind, authorKind) || other.authorKind == authorKind)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,authorKind,authorName,body,createdAt);

@override
String toString() {
  return 'PhotoComment(authorKind: $authorKind, authorName: $authorName, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PhotoCommentCopyWith<$Res>  {
  factory $PhotoCommentCopyWith(PhotoComment value, $Res Function(PhotoComment) _then) = _$PhotoCommentCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'author_kind') String authorKind,@JsonKey(name: 'author_name') String? authorName, String body,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$PhotoCommentCopyWithImpl<$Res>
    implements $PhotoCommentCopyWith<$Res> {
  _$PhotoCommentCopyWithImpl(this._self, this._then);

  final PhotoComment _self;
  final $Res Function(PhotoComment) _then;

/// Create a copy of PhotoComment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? authorKind = null,Object? authorName = freezed,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
authorKind: null == authorKind ? _self.authorKind : authorKind // ignore: cast_nullable_to_non_nullable
as String,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoComment].
extension PhotoCommentPatterns on PhotoComment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoComment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoComment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoComment value)  $default,){
final _that = this;
switch (_that) {
case _PhotoComment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoComment value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoComment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'author_kind')  String authorKind, @JsonKey(name: 'author_name')  String? authorName,  String body, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoComment() when $default != null:
return $default(_that.authorKind,_that.authorName,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'author_kind')  String authorKind, @JsonKey(name: 'author_name')  String? authorName,  String body, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _PhotoComment():
return $default(_that.authorKind,_that.authorName,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'author_kind')  String authorKind, @JsonKey(name: 'author_name')  String? authorName,  String body, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PhotoComment() when $default != null:
return $default(_that.authorKind,_that.authorName,_that.body,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PhotoComment implements PhotoComment {
  const _PhotoComment({@JsonKey(name: 'author_kind') this.authorKind = 'staff', @JsonKey(name: 'author_name') this.authorName, this.body = '', @JsonKey(name: 'created_at') this.createdAt});
  factory _PhotoComment.fromJson(Map<String, dynamic> json) => _$PhotoCommentFromJson(json);

@override@JsonKey(name: 'author_kind') final  String authorKind;
@override@JsonKey(name: 'author_name') final  String? authorName;
@override@JsonKey() final  String body;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of PhotoComment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoCommentCopyWith<_PhotoComment> get copyWith => __$PhotoCommentCopyWithImpl<_PhotoComment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PhotoCommentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoComment&&(identical(other.authorKind, authorKind) || other.authorKind == authorKind)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,authorKind,authorName,body,createdAt);

@override
String toString() {
  return 'PhotoComment(authorKind: $authorKind, authorName: $authorName, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PhotoCommentCopyWith<$Res> implements $PhotoCommentCopyWith<$Res> {
  factory _$PhotoCommentCopyWith(_PhotoComment value, $Res Function(_PhotoComment) _then) = __$PhotoCommentCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'author_kind') String authorKind,@JsonKey(name: 'author_name') String? authorName, String body,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$PhotoCommentCopyWithImpl<$Res>
    implements _$PhotoCommentCopyWith<$Res> {
  __$PhotoCommentCopyWithImpl(this._self, this._then);

  final _PhotoComment _self;
  final $Res Function(_PhotoComment) _then;

/// Create a copy of PhotoComment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? authorKind = null,Object? authorName = freezed,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_PhotoComment(
authorKind: null == authorKind ? _self.authorKind : authorKind // ignore: cast_nullable_to_non_nullable
as String,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OsTemplateItem {

 String? get id; String get kind;// 'product' | 'service'
@JsonKey(name: 'inventory_item_id') String? get inventoryItemId; String get name; String get quantity;@JsonKey(name: 'unit_price') String? get unitPrice;
/// Create a copy of OsTemplateItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OsTemplateItemCopyWith<OsTemplateItem> get copyWith => _$OsTemplateItemCopyWithImpl<OsTemplateItem>(this as OsTemplateItem, _$identity);

  /// Serializes this OsTemplateItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OsTemplateItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,inventoryItemId,name,quantity,unitPrice);

@override
String toString() {
  return 'OsTemplateItem(id: $id, kind: $kind, inventoryItemId: $inventoryItemId, name: $name, quantity: $quantity, unitPrice: $unitPrice)';
}


}

/// @nodoc
abstract mixin class $OsTemplateItemCopyWith<$Res>  {
  factory $OsTemplateItemCopyWith(OsTemplateItem value, $Res Function(OsTemplateItem) _then) = _$OsTemplateItemCopyWithImpl;
@useResult
$Res call({
 String? id, String kind,@JsonKey(name: 'inventory_item_id') String? inventoryItemId, String name, String quantity,@JsonKey(name: 'unit_price') String? unitPrice
});




}
/// @nodoc
class _$OsTemplateItemCopyWithImpl<$Res>
    implements $OsTemplateItemCopyWith<$Res> {
  _$OsTemplateItemCopyWithImpl(this._self, this._then);

  final OsTemplateItem _self;
  final $Res Function(OsTemplateItem) _then;

/// Create a copy of OsTemplateItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? kind = null,Object? inventoryItemId = freezed,Object? name = null,Object? quantity = null,Object? unitPrice = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: freezed == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OsTemplateItem].
extension OsTemplateItemPatterns on OsTemplateItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OsTemplateItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OsTemplateItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OsTemplateItem value)  $default,){
final _that = this;
switch (_that) {
case _OsTemplateItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OsTemplateItem value)?  $default,){
final _that = this;
switch (_that) {
case _OsTemplateItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String? unitPrice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OsTemplateItem() when $default != null:
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String? unitPrice)  $default,) {final _that = this;
switch (_that) {
case _OsTemplateItem():
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String? unitPrice)?  $default,) {final _that = this;
switch (_that) {
case _OsTemplateItem() when $default != null:
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OsTemplateItem implements OsTemplateItem {
  const _OsTemplateItem({this.id, this.kind = 'product', @JsonKey(name: 'inventory_item_id') this.inventoryItemId, this.name = '', this.quantity = '1', @JsonKey(name: 'unit_price') this.unitPrice});
  factory _OsTemplateItem.fromJson(Map<String, dynamic> json) => _$OsTemplateItemFromJson(json);

@override final  String? id;
@override@JsonKey() final  String kind;
// 'product' | 'service'
@override@JsonKey(name: 'inventory_item_id') final  String? inventoryItemId;
@override@JsonKey() final  String name;
@override@JsonKey() final  String quantity;
@override@JsonKey(name: 'unit_price') final  String? unitPrice;

/// Create a copy of OsTemplateItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OsTemplateItemCopyWith<_OsTemplateItem> get copyWith => __$OsTemplateItemCopyWithImpl<_OsTemplateItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OsTemplateItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OsTemplateItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,inventoryItemId,name,quantity,unitPrice);

@override
String toString() {
  return 'OsTemplateItem(id: $id, kind: $kind, inventoryItemId: $inventoryItemId, name: $name, quantity: $quantity, unitPrice: $unitPrice)';
}


}

/// @nodoc
abstract mixin class _$OsTemplateItemCopyWith<$Res> implements $OsTemplateItemCopyWith<$Res> {
  factory _$OsTemplateItemCopyWith(_OsTemplateItem value, $Res Function(_OsTemplateItem) _then) = __$OsTemplateItemCopyWithImpl;
@override @useResult
$Res call({
 String? id, String kind,@JsonKey(name: 'inventory_item_id') String? inventoryItemId, String name, String quantity,@JsonKey(name: 'unit_price') String? unitPrice
});




}
/// @nodoc
class __$OsTemplateItemCopyWithImpl<$Res>
    implements _$OsTemplateItemCopyWith<$Res> {
  __$OsTemplateItemCopyWithImpl(this._self, this._then);

  final _OsTemplateItem _self;
  final $Res Function(_OsTemplateItem) _then;

/// Create a copy of OsTemplateItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? kind = null,Object? inventoryItemId = freezed,Object? name = null,Object? quantity = null,Object? unitPrice = freezed,}) {
  return _then(_OsTemplateItem(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: freezed == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OsTemplate {

 String get id; String get name; String? get description; List<OsTemplateItem> get items;// Soma (quantidade × preço corrente do estoque) calculada pelo backend.
 String? get total;
/// Create a copy of OsTemplate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OsTemplateCopyWith<OsTemplate> get copyWith => _$OsTemplateCopyWithImpl<OsTemplate>(this as OsTemplate, _$identity);

  /// Serializes this OsTemplate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OsTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(items),total);

@override
String toString() {
  return 'OsTemplate(id: $id, name: $name, description: $description, items: $items, total: $total)';
}


}

/// @nodoc
abstract mixin class $OsTemplateCopyWith<$Res>  {
  factory $OsTemplateCopyWith(OsTemplate value, $Res Function(OsTemplate) _then) = _$OsTemplateCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, List<OsTemplateItem> items, String? total
});




}
/// @nodoc
class _$OsTemplateCopyWithImpl<$Res>
    implements $OsTemplateCopyWith<$Res> {
  _$OsTemplateCopyWithImpl(this._self, this._then);

  final OsTemplate _self;
  final $Res Function(OsTemplate) _then;

/// Create a copy of OsTemplate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? items = null,Object? total = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OsTemplateItem>,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OsTemplate].
extension OsTemplatePatterns on OsTemplate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OsTemplate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OsTemplate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OsTemplate value)  $default,){
final _that = this;
switch (_that) {
case _OsTemplate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OsTemplate value)?  $default,){
final _that = this;
switch (_that) {
case _OsTemplate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  List<OsTemplateItem> items,  String? total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OsTemplate() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.items,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  List<OsTemplateItem> items,  String? total)  $default,) {final _that = this;
switch (_that) {
case _OsTemplate():
return $default(_that.id,_that.name,_that.description,_that.items,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  List<OsTemplateItem> items,  String? total)?  $default,) {final _that = this;
switch (_that) {
case _OsTemplate() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.items,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OsTemplate implements OsTemplate {
  const _OsTemplate({required this.id, required this.name, this.description, final  List<OsTemplateItem> items = const <OsTemplateItem>[], this.total}): _items = items;
  factory _OsTemplate.fromJson(Map<String, dynamic> json) => _$OsTemplateFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
 final  List<OsTemplateItem> _items;
@override@JsonKey() List<OsTemplateItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

// Soma (quantidade × preço corrente do estoque) calculada pelo backend.
@override final  String? total;

/// Create a copy of OsTemplate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OsTemplateCopyWith<_OsTemplate> get copyWith => __$OsTemplateCopyWithImpl<_OsTemplate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OsTemplateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OsTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(_items),total);

@override
String toString() {
  return 'OsTemplate(id: $id, name: $name, description: $description, items: $items, total: $total)';
}


}

/// @nodoc
abstract mixin class _$OsTemplateCopyWith<$Res> implements $OsTemplateCopyWith<$Res> {
  factory _$OsTemplateCopyWith(_OsTemplate value, $Res Function(_OsTemplate) _then) = __$OsTemplateCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, List<OsTemplateItem> items, String? total
});




}
/// @nodoc
class __$OsTemplateCopyWithImpl<$Res>
    implements _$OsTemplateCopyWith<$Res> {
  __$OsTemplateCopyWithImpl(this._self, this._then);

  final _OsTemplate _self;
  final $Res Function(_OsTemplate) _then;

/// Create a copy of OsTemplate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? items = null,Object? total = freezed,}) {
  return _then(_OsTemplate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OsTemplateItem>,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ServiceOrder {

 String get id; String get number;@JsonKey(name: 'customer_id') String get customerId;@JsonKey(name: 'customer_name') String? get customerName;@JsonKey(name: 'subject_id') String? get subjectId;@JsonKey(name: 'subject_label') String? get subjectLabel; String get status;@JsonKey(name: 'assigned_to') String? get assignedTo; String? get complaint; String? get diagnosis;@JsonKey(name: 'scheduled_start') String? get scheduledStart;@JsonKey(name: 'scheduled_end') String? get scheduledEnd;@JsonKey(name: 'started_at') String? get startedAt;@JsonKey(name: 'finished_at') String? get finishedAt;@JsonKey(name: 'public_token') String? get publicToken; String? get discount; String? get total;// Status de pagamento DERIVADO do caixa (a_receber | parcial | pago). Vem
// flat tanto na listagem quanto no detalhe; a venda nasce 'a_receber'.
@JsonKey(name: 'payment_status') String get paymentStatus;// Snapshot do status fiscal (o Fiscal é dono): nao_emitida|processando|emitida|rejeitada.
@JsonKey(name: 'fiscal_status') String? get fiscalStatus; List<OrderItem> get items; List<OrderEvent> get events; List<OrderPhoto> get photos;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of ServiceOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServiceOrderCopyWith<ServiceOrder> get copyWith => _$ServiceOrderCopyWithImpl<ServiceOrder>(this as ServiceOrder, _$identity);

  /// Serializes this ServiceOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServiceOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel)&&(identical(other.status, status) || other.status == status)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.complaint, complaint) || other.complaint == complaint)&&(identical(other.diagnosis, diagnosis) || other.diagnosis == diagnosis)&&(identical(other.scheduledStart, scheduledStart) || other.scheduledStart == scheduledStart)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.publicToken, publicToken) || other.publicToken == publicToken)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.total, total) || other.total == total)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.fiscalStatus, fiscalStatus) || other.fiscalStatus == fiscalStatus)&&const DeepCollectionEquality().equals(other.items, items)&&const DeepCollectionEquality().equals(other.events, events)&&const DeepCollectionEquality().equals(other.photos, photos)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,customerId,customerName,subjectId,subjectLabel,status,assignedTo,complaint,diagnosis,scheduledStart,scheduledEnd,startedAt,finishedAt,publicToken,discount,total,paymentStatus,fiscalStatus,const DeepCollectionEquality().hash(items),const DeepCollectionEquality().hash(events),const DeepCollectionEquality().hash(photos),createdAt]);

@override
String toString() {
  return 'ServiceOrder(id: $id, number: $number, customerId: $customerId, customerName: $customerName, subjectId: $subjectId, subjectLabel: $subjectLabel, status: $status, assignedTo: $assignedTo, complaint: $complaint, diagnosis: $diagnosis, scheduledStart: $scheduledStart, scheduledEnd: $scheduledEnd, startedAt: $startedAt, finishedAt: $finishedAt, publicToken: $publicToken, discount: $discount, total: $total, paymentStatus: $paymentStatus, fiscalStatus: $fiscalStatus, items: $items, events: $events, photos: $photos, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ServiceOrderCopyWith<$Res>  {
  factory $ServiceOrderCopyWith(ServiceOrder value, $Res Function(ServiceOrder) _then) = _$ServiceOrderCopyWithImpl;
@useResult
$Res call({
 String id, String number,@JsonKey(name: 'customer_id') String customerId,@JsonKey(name: 'customer_name') String? customerName,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'subject_label') String? subjectLabel, String status,@JsonKey(name: 'assigned_to') String? assignedTo, String? complaint, String? diagnosis,@JsonKey(name: 'scheduled_start') String? scheduledStart,@JsonKey(name: 'scheduled_end') String? scheduledEnd,@JsonKey(name: 'started_at') String? startedAt,@JsonKey(name: 'finished_at') String? finishedAt,@JsonKey(name: 'public_token') String? publicToken, String? discount, String? total,@JsonKey(name: 'payment_status') String paymentStatus,@JsonKey(name: 'fiscal_status') String? fiscalStatus, List<OrderItem> items, List<OrderEvent> events, List<OrderPhoto> photos,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$ServiceOrderCopyWithImpl<$Res>
    implements $ServiceOrderCopyWith<$Res> {
  _$ServiceOrderCopyWithImpl(this._self, this._then);

  final ServiceOrder _self;
  final $Res Function(ServiceOrder) _then;

/// Create a copy of ServiceOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? customerId = null,Object? customerName = freezed,Object? subjectId = freezed,Object? subjectLabel = freezed,Object? status = null,Object? assignedTo = freezed,Object? complaint = freezed,Object? diagnosis = freezed,Object? scheduledStart = freezed,Object? scheduledEnd = freezed,Object? startedAt = freezed,Object? finishedAt = freezed,Object? publicToken = freezed,Object? discount = freezed,Object? total = freezed,Object? paymentStatus = null,Object? fiscalStatus = freezed,Object? items = null,Object? events = null,Object? photos = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,complaint: freezed == complaint ? _self.complaint : complaint // ignore: cast_nullable_to_non_nullable
as String?,diagnosis: freezed == diagnosis ? _self.diagnosis : diagnosis // ignore: cast_nullable_to_non_nullable
as String?,scheduledStart: freezed == scheduledStart ? _self.scheduledStart : scheduledStart // ignore: cast_nullable_to_non_nullable
as String?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String?,publicToken: freezed == publicToken ? _self.publicToken : publicToken // ignore: cast_nullable_to_non_nullable
as String?,discount: freezed == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as String?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,fiscalStatus: freezed == fiscalStatus ? _self.fiscalStatus : fiscalStatus // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<OrderEvent>,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<OrderPhoto>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ServiceOrder].
extension ServiceOrderPatterns on ServiceOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServiceOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServiceOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServiceOrder value)  $default,){
final _that = this;
switch (_that) {
case _ServiceOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServiceOrder value)?  $default,){
final _that = this;
switch (_that) {
case _ServiceOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'customer_id')  String customerId, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'subject_label')  String? subjectLabel,  String status, @JsonKey(name: 'assigned_to')  String? assignedTo,  String? complaint,  String? diagnosis, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'scheduled_end')  String? scheduledEnd, @JsonKey(name: 'started_at')  String? startedAt, @JsonKey(name: 'finished_at')  String? finishedAt, @JsonKey(name: 'public_token')  String? publicToken,  String? discount,  String? total, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'fiscal_status')  String? fiscalStatus,  List<OrderItem> items,  List<OrderEvent> events,  List<OrderPhoto> photos, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServiceOrder() when $default != null:
return $default(_that.id,_that.number,_that.customerId,_that.customerName,_that.subjectId,_that.subjectLabel,_that.status,_that.assignedTo,_that.complaint,_that.diagnosis,_that.scheduledStart,_that.scheduledEnd,_that.startedAt,_that.finishedAt,_that.publicToken,_that.discount,_that.total,_that.paymentStatus,_that.fiscalStatus,_that.items,_that.events,_that.photos,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'customer_id')  String customerId, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'subject_label')  String? subjectLabel,  String status, @JsonKey(name: 'assigned_to')  String? assignedTo,  String? complaint,  String? diagnosis, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'scheduled_end')  String? scheduledEnd, @JsonKey(name: 'started_at')  String? startedAt, @JsonKey(name: 'finished_at')  String? finishedAt, @JsonKey(name: 'public_token')  String? publicToken,  String? discount,  String? total, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'fiscal_status')  String? fiscalStatus,  List<OrderItem> items,  List<OrderEvent> events,  List<OrderPhoto> photos, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _ServiceOrder():
return $default(_that.id,_that.number,_that.customerId,_that.customerName,_that.subjectId,_that.subjectLabel,_that.status,_that.assignedTo,_that.complaint,_that.diagnosis,_that.scheduledStart,_that.scheduledEnd,_that.startedAt,_that.finishedAt,_that.publicToken,_that.discount,_that.total,_that.paymentStatus,_that.fiscalStatus,_that.items,_that.events,_that.photos,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number, @JsonKey(name: 'customer_id')  String customerId, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'subject_label')  String? subjectLabel,  String status, @JsonKey(name: 'assigned_to')  String? assignedTo,  String? complaint,  String? diagnosis, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'scheduled_end')  String? scheduledEnd, @JsonKey(name: 'started_at')  String? startedAt, @JsonKey(name: 'finished_at')  String? finishedAt, @JsonKey(name: 'public_token')  String? publicToken,  String? discount,  String? total, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'fiscal_status')  String? fiscalStatus,  List<OrderItem> items,  List<OrderEvent> events,  List<OrderPhoto> photos, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _ServiceOrder() when $default != null:
return $default(_that.id,_that.number,_that.customerId,_that.customerName,_that.subjectId,_that.subjectLabel,_that.status,_that.assignedTo,_that.complaint,_that.diagnosis,_that.scheduledStart,_that.scheduledEnd,_that.startedAt,_that.finishedAt,_that.publicToken,_that.discount,_that.total,_that.paymentStatus,_that.fiscalStatus,_that.items,_that.events,_that.photos,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServiceOrder implements ServiceOrder {
  const _ServiceOrder({required this.id, required this.number, @JsonKey(name: 'customer_id') required this.customerId, @JsonKey(name: 'customer_name') this.customerName, @JsonKey(name: 'subject_id') this.subjectId, @JsonKey(name: 'subject_label') this.subjectLabel, this.status = 'aberta', @JsonKey(name: 'assigned_to') this.assignedTo, this.complaint, this.diagnosis, @JsonKey(name: 'scheduled_start') this.scheduledStart, @JsonKey(name: 'scheduled_end') this.scheduledEnd, @JsonKey(name: 'started_at') this.startedAt, @JsonKey(name: 'finished_at') this.finishedAt, @JsonKey(name: 'public_token') this.publicToken, this.discount, this.total, @JsonKey(name: 'payment_status') this.paymentStatus = 'a_receber', @JsonKey(name: 'fiscal_status') this.fiscalStatus, final  List<OrderItem> items = const <OrderItem>[], final  List<OrderEvent> events = const <OrderEvent>[], final  List<OrderPhoto> photos = const <OrderPhoto>[], @JsonKey(name: 'created_at') this.createdAt}): _items = items,_events = events,_photos = photos;
  factory _ServiceOrder.fromJson(Map<String, dynamic> json) => _$ServiceOrderFromJson(json);

@override final  String id;
@override final  String number;
@override@JsonKey(name: 'customer_id') final  String customerId;
@override@JsonKey(name: 'customer_name') final  String? customerName;
@override@JsonKey(name: 'subject_id') final  String? subjectId;
@override@JsonKey(name: 'subject_label') final  String? subjectLabel;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'assigned_to') final  String? assignedTo;
@override final  String? complaint;
@override final  String? diagnosis;
@override@JsonKey(name: 'scheduled_start') final  String? scheduledStart;
@override@JsonKey(name: 'scheduled_end') final  String? scheduledEnd;
@override@JsonKey(name: 'started_at') final  String? startedAt;
@override@JsonKey(name: 'finished_at') final  String? finishedAt;
@override@JsonKey(name: 'public_token') final  String? publicToken;
@override final  String? discount;
@override final  String? total;
// Status de pagamento DERIVADO do caixa (a_receber | parcial | pago). Vem
// flat tanto na listagem quanto no detalhe; a venda nasce 'a_receber'.
@override@JsonKey(name: 'payment_status') final  String paymentStatus;
// Snapshot do status fiscal (o Fiscal é dono): nao_emitida|processando|emitida|rejeitada.
@override@JsonKey(name: 'fiscal_status') final  String? fiscalStatus;
 final  List<OrderItem> _items;
@override@JsonKey() List<OrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

 final  List<OrderEvent> _events;
@override@JsonKey() List<OrderEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}

 final  List<OrderPhoto> _photos;
@override@JsonKey() List<OrderPhoto> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of ServiceOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServiceOrderCopyWith<_ServiceOrder> get copyWith => __$ServiceOrderCopyWithImpl<_ServiceOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServiceOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServiceOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel)&&(identical(other.status, status) || other.status == status)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.complaint, complaint) || other.complaint == complaint)&&(identical(other.diagnosis, diagnosis) || other.diagnosis == diagnosis)&&(identical(other.scheduledStart, scheduledStart) || other.scheduledStart == scheduledStart)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.publicToken, publicToken) || other.publicToken == publicToken)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.total, total) || other.total == total)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.fiscalStatus, fiscalStatus) || other.fiscalStatus == fiscalStatus)&&const DeepCollectionEquality().equals(other._items, _items)&&const DeepCollectionEquality().equals(other._events, _events)&&const DeepCollectionEquality().equals(other._photos, _photos)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,number,customerId,customerName,subjectId,subjectLabel,status,assignedTo,complaint,diagnosis,scheduledStart,scheduledEnd,startedAt,finishedAt,publicToken,discount,total,paymentStatus,fiscalStatus,const DeepCollectionEquality().hash(_items),const DeepCollectionEquality().hash(_events),const DeepCollectionEquality().hash(_photos),createdAt]);

@override
String toString() {
  return 'ServiceOrder(id: $id, number: $number, customerId: $customerId, customerName: $customerName, subjectId: $subjectId, subjectLabel: $subjectLabel, status: $status, assignedTo: $assignedTo, complaint: $complaint, diagnosis: $diagnosis, scheduledStart: $scheduledStart, scheduledEnd: $scheduledEnd, startedAt: $startedAt, finishedAt: $finishedAt, publicToken: $publicToken, discount: $discount, total: $total, paymentStatus: $paymentStatus, fiscalStatus: $fiscalStatus, items: $items, events: $events, photos: $photos, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ServiceOrderCopyWith<$Res> implements $ServiceOrderCopyWith<$Res> {
  factory _$ServiceOrderCopyWith(_ServiceOrder value, $Res Function(_ServiceOrder) _then) = __$ServiceOrderCopyWithImpl;
@override @useResult
$Res call({
 String id, String number,@JsonKey(name: 'customer_id') String customerId,@JsonKey(name: 'customer_name') String? customerName,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'subject_label') String? subjectLabel, String status,@JsonKey(name: 'assigned_to') String? assignedTo, String? complaint, String? diagnosis,@JsonKey(name: 'scheduled_start') String? scheduledStart,@JsonKey(name: 'scheduled_end') String? scheduledEnd,@JsonKey(name: 'started_at') String? startedAt,@JsonKey(name: 'finished_at') String? finishedAt,@JsonKey(name: 'public_token') String? publicToken, String? discount, String? total,@JsonKey(name: 'payment_status') String paymentStatus,@JsonKey(name: 'fiscal_status') String? fiscalStatus, List<OrderItem> items, List<OrderEvent> events, List<OrderPhoto> photos,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$ServiceOrderCopyWithImpl<$Res>
    implements _$ServiceOrderCopyWith<$Res> {
  __$ServiceOrderCopyWithImpl(this._self, this._then);

  final _ServiceOrder _self;
  final $Res Function(_ServiceOrder) _then;

/// Create a copy of ServiceOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? customerId = null,Object? customerName = freezed,Object? subjectId = freezed,Object? subjectLabel = freezed,Object? status = null,Object? assignedTo = freezed,Object? complaint = freezed,Object? diagnosis = freezed,Object? scheduledStart = freezed,Object? scheduledEnd = freezed,Object? startedAt = freezed,Object? finishedAt = freezed,Object? publicToken = freezed,Object? discount = freezed,Object? total = freezed,Object? paymentStatus = null,Object? fiscalStatus = freezed,Object? items = null,Object? events = null,Object? photos = null,Object? createdAt = freezed,}) {
  return _then(_ServiceOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,complaint: freezed == complaint ? _self.complaint : complaint // ignore: cast_nullable_to_non_nullable
as String?,diagnosis: freezed == diagnosis ? _self.diagnosis : diagnosis // ignore: cast_nullable_to_non_nullable
as String?,scheduledStart: freezed == scheduledStart ? _self.scheduledStart : scheduledStart // ignore: cast_nullable_to_non_nullable
as String?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String?,publicToken: freezed == publicToken ? _self.publicToken : publicToken // ignore: cast_nullable_to_non_nullable
as String?,discount: freezed == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as String?,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,fiscalStatus: freezed == fiscalStatus ? _self.fiscalStatus : fiscalStatus // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<OrderEvent>,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<OrderPhoto>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OrderPage {

 List<ServiceOrder> get items; int get total; int get page; int get pageSize;
/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderPageCopyWith<OrderPage> get copyWith => _$OrderPageCopyWithImpl<OrderPage>(this as OrderPage, _$identity);

  /// Serializes this OrderPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'OrderPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $OrderPageCopyWith<$Res>  {
  factory $OrderPageCopyWith(OrderPage value, $Res Function(OrderPage) _then) = _$OrderPageCopyWithImpl;
@useResult
$Res call({
 List<ServiceOrder> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$OrderPageCopyWithImpl<$Res>
    implements $OrderPageCopyWith<$Res> {
  _$OrderPageCopyWithImpl(this._self, this._then);

  final OrderPage _self;
  final $Res Function(OrderPage) _then;

/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ServiceOrder>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderPage].
extension OrderPagePatterns on OrderPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderPage value)  $default,){
final _that = this;
switch (_that) {
case _OrderPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderPage value)?  $default,){
final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ServiceOrder> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ServiceOrder> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _OrderPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ServiceOrder> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderPage implements OrderPage {
  const _OrderPage({final  List<ServiceOrder> items = const <ServiceOrder>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _OrderPage.fromJson(Map<String, dynamic> json) => _$OrderPageFromJson(json);

 final  List<ServiceOrder> _items;
@override@JsonKey() List<ServiceOrder> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderPageCopyWith<_OrderPage> get copyWith => __$OrderPageCopyWithImpl<_OrderPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'OrderPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$OrderPageCopyWith<$Res> implements $OrderPageCopyWith<$Res> {
  factory _$OrderPageCopyWith(_OrderPage value, $Res Function(_OrderPage) _then) = __$OrderPageCopyWithImpl;
@override @useResult
$Res call({
 List<ServiceOrder> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$OrderPageCopyWithImpl<$Res>
    implements _$OrderPageCopyWith<$Res> {
  __$OrderPageCopyWithImpl(this._self, this._then);

  final _OrderPage _self;
  final $Res Function(_OrderPage) _then;

/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_OrderPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ServiceOrder>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CustomerOption {

 String get id; String get name; String? get document; String? get phone;
/// Create a copy of CustomerOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerOptionCopyWith<CustomerOption> get copyWith => _$CustomerOptionCopyWithImpl<CustomerOption>(this as CustomerOption, _$identity);

  /// Serializes this CustomerOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.document, document) || other.document == document)&&(identical(other.phone, phone) || other.phone == phone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,document,phone);

@override
String toString() {
  return 'CustomerOption(id: $id, name: $name, document: $document, phone: $phone)';
}


}

/// @nodoc
abstract mixin class $CustomerOptionCopyWith<$Res>  {
  factory $CustomerOptionCopyWith(CustomerOption value, $Res Function(CustomerOption) _then) = _$CustomerOptionCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? document, String? phone
});




}
/// @nodoc
class _$CustomerOptionCopyWithImpl<$Res>
    implements $CustomerOptionCopyWith<$Res> {
  _$CustomerOptionCopyWithImpl(this._self, this._then);

  final CustomerOption _self;
  final $Res Function(CustomerOption) _then;

/// Create a copy of CustomerOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? document = freezed,Object? phone = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,document: freezed == document ? _self.document : document // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomerOption].
extension CustomerOptionPatterns on CustomerOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomerOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomerOption value)  $default,){
final _that = this;
switch (_that) {
case _CustomerOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomerOption value)?  $default,){
final _that = this;
switch (_that) {
case _CustomerOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? document,  String? phone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerOption() when $default != null:
return $default(_that.id,_that.name,_that.document,_that.phone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? document,  String? phone)  $default,) {final _that = this;
switch (_that) {
case _CustomerOption():
return $default(_that.id,_that.name,_that.document,_that.phone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? document,  String? phone)?  $default,) {final _that = this;
switch (_that) {
case _CustomerOption() when $default != null:
return $default(_that.id,_that.name,_that.document,_that.phone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomerOption implements CustomerOption {
  const _CustomerOption({required this.id, required this.name, this.document, this.phone});
  factory _CustomerOption.fromJson(Map<String, dynamic> json) => _$CustomerOptionFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? document;
@override final  String? phone;

/// Create a copy of CustomerOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerOptionCopyWith<_CustomerOption> get copyWith => __$CustomerOptionCopyWithImpl<_CustomerOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.document, document) || other.document == document)&&(identical(other.phone, phone) || other.phone == phone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,document,phone);

@override
String toString() {
  return 'CustomerOption(id: $id, name: $name, document: $document, phone: $phone)';
}


}

/// @nodoc
abstract mixin class _$CustomerOptionCopyWith<$Res> implements $CustomerOptionCopyWith<$Res> {
  factory _$CustomerOptionCopyWith(_CustomerOption value, $Res Function(_CustomerOption) _then) = __$CustomerOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? document, String? phone
});




}
/// @nodoc
class __$CustomerOptionCopyWithImpl<$Res>
    implements _$CustomerOptionCopyWith<$Res> {
  __$CustomerOptionCopyWithImpl(this._self, this._then);

  final _CustomerOption _self;
  final $Res Function(_CustomerOption) _then;

/// Create a copy of CustomerOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? document = freezed,Object? phone = freezed,}) {
  return _then(_CustomerOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,document: freezed == document ? _self.document : document // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubjectOption {

 String get id; String? get label; String? get identifier;
/// Create a copy of SubjectOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubjectOptionCopyWith<SubjectOption> get copyWith => _$SubjectOptionCopyWithImpl<SubjectOption>(this as SubjectOption, _$identity);

  /// Serializes this SubjectOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubjectOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.identifier, identifier) || other.identifier == identifier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,identifier);

@override
String toString() {
  return 'SubjectOption(id: $id, label: $label, identifier: $identifier)';
}


}

/// @nodoc
abstract mixin class $SubjectOptionCopyWith<$Res>  {
  factory $SubjectOptionCopyWith(SubjectOption value, $Res Function(SubjectOption) _then) = _$SubjectOptionCopyWithImpl;
@useResult
$Res call({
 String id, String? label, String? identifier
});




}
/// @nodoc
class _$SubjectOptionCopyWithImpl<$Res>
    implements $SubjectOptionCopyWith<$Res> {
  _$SubjectOptionCopyWithImpl(this._self, this._then);

  final SubjectOption _self;
  final $Res Function(SubjectOption) _then;

/// Create a copy of SubjectOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = freezed,Object? identifier = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubjectOption].
extension SubjectOptionPatterns on SubjectOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubjectOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubjectOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubjectOption value)  $default,){
final _that = this;
switch (_that) {
case _SubjectOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubjectOption value)?  $default,){
final _that = this;
switch (_that) {
case _SubjectOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? label,  String? identifier)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubjectOption() when $default != null:
return $default(_that.id,_that.label,_that.identifier);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? label,  String? identifier)  $default,) {final _that = this;
switch (_that) {
case _SubjectOption():
return $default(_that.id,_that.label,_that.identifier);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? label,  String? identifier)?  $default,) {final _that = this;
switch (_that) {
case _SubjectOption() when $default != null:
return $default(_that.id,_that.label,_that.identifier);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubjectOption implements SubjectOption {
  const _SubjectOption({required this.id, this.label, this.identifier});
  factory _SubjectOption.fromJson(Map<String, dynamic> json) => _$SubjectOptionFromJson(json);

@override final  String id;
@override final  String? label;
@override final  String? identifier;

/// Create a copy of SubjectOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubjectOptionCopyWith<_SubjectOption> get copyWith => __$SubjectOptionCopyWithImpl<_SubjectOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubjectOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubjectOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.identifier, identifier) || other.identifier == identifier));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,identifier);

@override
String toString() {
  return 'SubjectOption(id: $id, label: $label, identifier: $identifier)';
}


}

/// @nodoc
abstract mixin class _$SubjectOptionCopyWith<$Res> implements $SubjectOptionCopyWith<$Res> {
  factory _$SubjectOptionCopyWith(_SubjectOption value, $Res Function(_SubjectOption) _then) = __$SubjectOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String? label, String? identifier
});




}
/// @nodoc
class __$SubjectOptionCopyWithImpl<$Res>
    implements _$SubjectOptionCopyWith<$Res> {
  __$SubjectOptionCopyWithImpl(this._self, this._then);

  final _SubjectOption _self;
  final $Res Function(_SubjectOption) _then;

/// Create a copy of SubjectOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = freezed,Object? identifier = freezed,}) {
  return _then(_SubjectOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$InventoryOption {

 String get id; String get name; String get kind;@JsonKey(name: 'sale_price') String? get salePrice;@JsonKey(name: 'current_stock') String? get currentStock;
/// Create a copy of InventoryOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryOptionCopyWith<InventoryOption> get copyWith => _$InventoryOptionCopyWithImpl<InventoryOption>(this as InventoryOption, _$identity);

  /// Serializes this InventoryOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,salePrice,currentStock);

@override
String toString() {
  return 'InventoryOption(id: $id, name: $name, kind: $kind, salePrice: $salePrice, currentStock: $currentStock)';
}


}

/// @nodoc
abstract mixin class $InventoryOptionCopyWith<$Res>  {
  factory $InventoryOptionCopyWith(InventoryOption value, $Res Function(InventoryOption) _then) = _$InventoryOptionCopyWithImpl;
@useResult
$Res call({
 String id, String name, String kind,@JsonKey(name: 'sale_price') String? salePrice,@JsonKey(name: 'current_stock') String? currentStock
});




}
/// @nodoc
class _$InventoryOptionCopyWithImpl<$Res>
    implements $InventoryOptionCopyWith<$Res> {
  _$InventoryOptionCopyWithImpl(this._self, this._then);

  final InventoryOption _self;
  final $Res Function(InventoryOption) _then;

/// Create a copy of InventoryOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? salePrice = freezed,Object? currentStock = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as String?,currentStock: freezed == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryOption].
extension InventoryOptionPatterns on InventoryOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryOption value)  $default,){
final _that = this;
switch (_that) {
case _InventoryOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryOption value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String kind, @JsonKey(name: 'sale_price')  String? salePrice, @JsonKey(name: 'current_stock')  String? currentStock)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryOption() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.salePrice,_that.currentStock);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String kind, @JsonKey(name: 'sale_price')  String? salePrice, @JsonKey(name: 'current_stock')  String? currentStock)  $default,) {final _that = this;
switch (_that) {
case _InventoryOption():
return $default(_that.id,_that.name,_that.kind,_that.salePrice,_that.currentStock);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String kind, @JsonKey(name: 'sale_price')  String? salePrice, @JsonKey(name: 'current_stock')  String? currentStock)?  $default,) {final _that = this;
switch (_that) {
case _InventoryOption() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.salePrice,_that.currentStock);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryOption implements InventoryOption {
  const _InventoryOption({required this.id, required this.name, this.kind = 'product', @JsonKey(name: 'sale_price') this.salePrice, @JsonKey(name: 'current_stock') this.currentStock});
  factory _InventoryOption.fromJson(Map<String, dynamic> json) => _$InventoryOptionFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String kind;
@override@JsonKey(name: 'sale_price') final  String? salePrice;
@override@JsonKey(name: 'current_stock') final  String? currentStock;

/// Create a copy of InventoryOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryOptionCopyWith<_InventoryOption> get copyWith => __$InventoryOptionCopyWithImpl<_InventoryOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,salePrice,currentStock);

@override
String toString() {
  return 'InventoryOption(id: $id, name: $name, kind: $kind, salePrice: $salePrice, currentStock: $currentStock)';
}


}

/// @nodoc
abstract mixin class _$InventoryOptionCopyWith<$Res> implements $InventoryOptionCopyWith<$Res> {
  factory _$InventoryOptionCopyWith(_InventoryOption value, $Res Function(_InventoryOption) _then) = __$InventoryOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String kind,@JsonKey(name: 'sale_price') String? salePrice,@JsonKey(name: 'current_stock') String? currentStock
});




}
/// @nodoc
class __$InventoryOptionCopyWithImpl<$Res>
    implements _$InventoryOptionCopyWith<$Res> {
  __$InventoryOptionCopyWithImpl(this._self, this._then);

  final _InventoryOption _self;
  final $Res Function(_InventoryOption) _then;

/// Create a copy of InventoryOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? salePrice = freezed,Object? currentStock = freezed,}) {
  return _then(_InventoryOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as String?,currentStock: freezed == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
