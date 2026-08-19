// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sale_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Sale {

 String get id; String get number;@JsonKey(name: 'customer_id') String? get customerId;@JsonKey(name: 'customer_name') String? get customerName; String get status;// 'active' | 'canceled'
 String get total;/// Desconto concedido (registro). `total` já vem líquido.
 String get discount;/// Observação livre do balcão (a quem entregou, placa, nº do equipamento).
/// Sai no comprovante — é o que identifica a venda quando quem comprou não
/// é cliente cadastrado.
 String? get description;@JsonKey(name: 'fiscal_status') String? get fiscalStatus;// 'a_receber' | 'parcial' | 'pago' | 'cancelada' (flat, espelha payment.status)
@JsonKey(name: 'payment_status') String get paymentStatus;@JsonKey(name: 'created_at') String? get createdAt; List<SaleItem> get items;
/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaleCopyWith<Sale> get copyWith => _$SaleCopyWithImpl<Sale>(this as Sale, _$identity);

  /// Serializes this Sale to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Sale&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.status, status) || other.status == status)&&(identical(other.total, total) || other.total == total)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.description, description) || other.description == description)&&(identical(other.fiscalStatus, fiscalStatus) || other.fiscalStatus == fiscalStatus)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,customerId,customerName,status,total,discount,description,fiscalStatus,paymentStatus,createdAt,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'Sale(id: $id, number: $number, customerId: $customerId, customerName: $customerName, status: $status, total: $total, discount: $discount, description: $description, fiscalStatus: $fiscalStatus, paymentStatus: $paymentStatus, createdAt: $createdAt, items: $items)';
}


}

/// @nodoc
abstract mixin class $SaleCopyWith<$Res>  {
  factory $SaleCopyWith(Sale value, $Res Function(Sale) _then) = _$SaleCopyWithImpl;
@useResult
$Res call({
 String id, String number,@JsonKey(name: 'customer_id') String? customerId,@JsonKey(name: 'customer_name') String? customerName, String status, String total, String discount, String? description,@JsonKey(name: 'fiscal_status') String? fiscalStatus,@JsonKey(name: 'payment_status') String paymentStatus,@JsonKey(name: 'created_at') String? createdAt, List<SaleItem> items
});




}
/// @nodoc
class _$SaleCopyWithImpl<$Res>
    implements $SaleCopyWith<$Res> {
  _$SaleCopyWithImpl(this._self, this._then);

  final Sale _self;
  final $Res Function(Sale) _then;

/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? customerId = freezed,Object? customerName = freezed,Object? status = null,Object? total = null,Object? discount = null,Object? description = freezed,Object? fiscalStatus = freezed,Object? paymentStatus = null,Object? createdAt = freezed,Object? items = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,fiscalStatus: freezed == fiscalStatus ? _self.fiscalStatus : fiscalStatus // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<SaleItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [Sale].
extension SalePatterns on Sale {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Sale value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Sale() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Sale value)  $default,){
final _that = this;
switch (_that) {
case _Sale():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Sale value)?  $default,){
final _that = this;
switch (_that) {
case _Sale() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'customer_id')  String? customerId, @JsonKey(name: 'customer_name')  String? customerName,  String status,  String total,  String discount,  String? description, @JsonKey(name: 'fiscal_status')  String? fiscalStatus, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'created_at')  String? createdAt,  List<SaleItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Sale() when $default != null:
return $default(_that.id,_that.number,_that.customerId,_that.customerName,_that.status,_that.total,_that.discount,_that.description,_that.fiscalStatus,_that.paymentStatus,_that.createdAt,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number, @JsonKey(name: 'customer_id')  String? customerId, @JsonKey(name: 'customer_name')  String? customerName,  String status,  String total,  String discount,  String? description, @JsonKey(name: 'fiscal_status')  String? fiscalStatus, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'created_at')  String? createdAt,  List<SaleItem> items)  $default,) {final _that = this;
switch (_that) {
case _Sale():
return $default(_that.id,_that.number,_that.customerId,_that.customerName,_that.status,_that.total,_that.discount,_that.description,_that.fiscalStatus,_that.paymentStatus,_that.createdAt,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number, @JsonKey(name: 'customer_id')  String? customerId, @JsonKey(name: 'customer_name')  String? customerName,  String status,  String total,  String discount,  String? description, @JsonKey(name: 'fiscal_status')  String? fiscalStatus, @JsonKey(name: 'payment_status')  String paymentStatus, @JsonKey(name: 'created_at')  String? createdAt,  List<SaleItem> items)?  $default,) {final _that = this;
switch (_that) {
case _Sale() when $default != null:
return $default(_that.id,_that.number,_that.customerId,_that.customerName,_that.status,_that.total,_that.discount,_that.description,_that.fiscalStatus,_that.paymentStatus,_that.createdAt,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Sale implements Sale {
  const _Sale({required this.id, this.number = '', @JsonKey(name: 'customer_id') this.customerId, @JsonKey(name: 'customer_name') this.customerName, this.status = 'active', this.total = '0', this.discount = '0', this.description, @JsonKey(name: 'fiscal_status') this.fiscalStatus, @JsonKey(name: 'payment_status') this.paymentStatus = 'a_receber', @JsonKey(name: 'created_at') this.createdAt, final  List<SaleItem> items = const <SaleItem>[]}): _items = items;
  factory _Sale.fromJson(Map<String, dynamic> json) => _$SaleFromJson(json);

@override final  String id;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'customer_id') final  String? customerId;
@override@JsonKey(name: 'customer_name') final  String? customerName;
@override@JsonKey() final  String status;
// 'active' | 'canceled'
@override@JsonKey() final  String total;
/// Desconto concedido (registro). `total` já vem líquido.
@override@JsonKey() final  String discount;
/// Observação livre do balcão (a quem entregou, placa, nº do equipamento).
/// Sai no comprovante — é o que identifica a venda quando quem comprou não
/// é cliente cadastrado.
@override final  String? description;
@override@JsonKey(name: 'fiscal_status') final  String? fiscalStatus;
// 'a_receber' | 'parcial' | 'pago' | 'cancelada' (flat, espelha payment.status)
@override@JsonKey(name: 'payment_status') final  String paymentStatus;
@override@JsonKey(name: 'created_at') final  String? createdAt;
 final  List<SaleItem> _items;
@override@JsonKey() List<SaleItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaleCopyWith<_Sale> get copyWith => __$SaleCopyWithImpl<_Sale>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SaleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Sale&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.status, status) || other.status == status)&&(identical(other.total, total) || other.total == total)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.description, description) || other.description == description)&&(identical(other.fiscalStatus, fiscalStatus) || other.fiscalStatus == fiscalStatus)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,customerId,customerName,status,total,discount,description,fiscalStatus,paymentStatus,createdAt,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'Sale(id: $id, number: $number, customerId: $customerId, customerName: $customerName, status: $status, total: $total, discount: $discount, description: $description, fiscalStatus: $fiscalStatus, paymentStatus: $paymentStatus, createdAt: $createdAt, items: $items)';
}


}

/// @nodoc
abstract mixin class _$SaleCopyWith<$Res> implements $SaleCopyWith<$Res> {
  factory _$SaleCopyWith(_Sale value, $Res Function(_Sale) _then) = __$SaleCopyWithImpl;
@override @useResult
$Res call({
 String id, String number,@JsonKey(name: 'customer_id') String? customerId,@JsonKey(name: 'customer_name') String? customerName, String status, String total, String discount, String? description,@JsonKey(name: 'fiscal_status') String? fiscalStatus,@JsonKey(name: 'payment_status') String paymentStatus,@JsonKey(name: 'created_at') String? createdAt, List<SaleItem> items
});




}
/// @nodoc
class __$SaleCopyWithImpl<$Res>
    implements _$SaleCopyWith<$Res> {
  __$SaleCopyWithImpl(this._self, this._then);

  final _Sale _self;
  final $Res Function(_Sale) _then;

/// Create a copy of Sale
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? customerId = freezed,Object? customerName = freezed,Object? status = null,Object? total = null,Object? discount = null,Object? description = freezed,Object? fiscalStatus = freezed,Object? paymentStatus = null,Object? createdAt = freezed,Object? items = null,}) {
  return _then(_Sale(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,fiscalStatus: freezed == fiscalStatus ? _self.fiscalStatus : fiscalStatus // ignore: cast_nullable_to_non_nullable
as String?,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<SaleItem>,
  ));
}


}


/// @nodoc
mixin _$SaleItem {

 String get id; String get kind;// 'product' | 'service'
@JsonKey(name: 'inventory_item_id') String? get inventoryItemId; String get name; String get quantity;@JsonKey(name: 'unit_price') String get unitPrice; String get subtotal;
/// Create a copy of SaleItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaleItemCopyWith<SaleItem> get copyWith => _$SaleItemCopyWithImpl<SaleItem>(this as SaleItem, _$identity);

  /// Serializes this SaleItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SaleItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,inventoryItemId,name,quantity,unitPrice,subtotal);

@override
String toString() {
  return 'SaleItem(id: $id, kind: $kind, inventoryItemId: $inventoryItemId, name: $name, quantity: $quantity, unitPrice: $unitPrice, subtotal: $subtotal)';
}


}

/// @nodoc
abstract mixin class $SaleItemCopyWith<$Res>  {
  factory $SaleItemCopyWith(SaleItem value, $Res Function(SaleItem) _then) = _$SaleItemCopyWithImpl;
@useResult
$Res call({
 String id, String kind,@JsonKey(name: 'inventory_item_id') String? inventoryItemId, String name, String quantity,@JsonKey(name: 'unit_price') String unitPrice, String subtotal
});




}
/// @nodoc
class _$SaleItemCopyWithImpl<$Res>
    implements $SaleItemCopyWith<$Res> {
  _$SaleItemCopyWithImpl(this._self, this._then);

  final SaleItem _self;
  final $Res Function(SaleItem) _then;

/// Create a copy of SaleItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? inventoryItemId = freezed,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? subtotal = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SaleItem].
extension SaleItemPatterns on SaleItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SaleItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SaleItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SaleItem value)  $default,){
final _that = this;
switch (_that) {
case _SaleItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SaleItem value)?  $default,){
final _that = this;
switch (_that) {
case _SaleItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String subtotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SaleItem() when $default != null:
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice,_that.subtotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String subtotal)  $default,) {final _that = this;
switch (_that) {
case _SaleItem():
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice,_that.subtotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind, @JsonKey(name: 'inventory_item_id')  String? inventoryItemId,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String subtotal)?  $default,) {final _that = this;
switch (_that) {
case _SaleItem() when $default != null:
return $default(_that.id,_that.kind,_that.inventoryItemId,_that.name,_that.quantity,_that.unitPrice,_that.subtotal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SaleItem implements SaleItem {
  const _SaleItem({required this.id, this.kind = 'product', @JsonKey(name: 'inventory_item_id') this.inventoryItemId, this.name = '', this.quantity = '1', @JsonKey(name: 'unit_price') this.unitPrice = '0', this.subtotal = '0'});
  factory _SaleItem.fromJson(Map<String, dynamic> json) => _$SaleItemFromJson(json);

@override final  String id;
@override@JsonKey() final  String kind;
// 'product' | 'service'
@override@JsonKey(name: 'inventory_item_id') final  String? inventoryItemId;
@override@JsonKey() final  String name;
@override@JsonKey() final  String quantity;
@override@JsonKey(name: 'unit_price') final  String unitPrice;
@override@JsonKey() final  String subtotal;

/// Create a copy of SaleItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaleItemCopyWith<_SaleItem> get copyWith => __$SaleItemCopyWithImpl<_SaleItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SaleItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaleItem&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,inventoryItemId,name,quantity,unitPrice,subtotal);

@override
String toString() {
  return 'SaleItem(id: $id, kind: $kind, inventoryItemId: $inventoryItemId, name: $name, quantity: $quantity, unitPrice: $unitPrice, subtotal: $subtotal)';
}


}

/// @nodoc
abstract mixin class _$SaleItemCopyWith<$Res> implements $SaleItemCopyWith<$Res> {
  factory _$SaleItemCopyWith(_SaleItem value, $Res Function(_SaleItem) _then) = __$SaleItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind,@JsonKey(name: 'inventory_item_id') String? inventoryItemId, String name, String quantity,@JsonKey(name: 'unit_price') String unitPrice, String subtotal
});




}
/// @nodoc
class __$SaleItemCopyWithImpl<$Res>
    implements _$SaleItemCopyWith<$Res> {
  __$SaleItemCopyWithImpl(this._self, this._then);

  final _SaleItem _self;
  final $Res Function(_SaleItem) _then;

/// Create a copy of SaleItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? inventoryItemId = freezed,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? subtotal = null,}) {
  return _then(_SaleItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SalePage {

 List<Sale> get items; int get total; int get page; int get pageSize;
/// Create a copy of SalePage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SalePageCopyWith<SalePage> get copyWith => _$SalePageCopyWithImpl<SalePage>(this as SalePage, _$identity);

  /// Serializes this SalePage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SalePage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'SalePage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $SalePageCopyWith<$Res>  {
  factory $SalePageCopyWith(SalePage value, $Res Function(SalePage) _then) = _$SalePageCopyWithImpl;
@useResult
$Res call({
 List<Sale> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$SalePageCopyWithImpl<$Res>
    implements $SalePageCopyWith<$Res> {
  _$SalePageCopyWithImpl(this._self, this._then);

  final SalePage _self;
  final $Res Function(SalePage) _then;

/// Create a copy of SalePage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Sale>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SalePage].
extension SalePagePatterns on SalePage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SalePage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SalePage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SalePage value)  $default,){
final _that = this;
switch (_that) {
case _SalePage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SalePage value)?  $default,){
final _that = this;
switch (_that) {
case _SalePage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Sale> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SalePage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Sale> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _SalePage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Sale> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _SalePage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SalePage implements SalePage {
  const _SalePage({final  List<Sale> items = const <Sale>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _SalePage.fromJson(Map<String, dynamic> json) => _$SalePageFromJson(json);

 final  List<Sale> _items;
@override@JsonKey() List<Sale> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of SalePage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SalePageCopyWith<_SalePage> get copyWith => __$SalePageCopyWithImpl<_SalePage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SalePageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SalePage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'SalePage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$SalePageCopyWith<$Res> implements $SalePageCopyWith<$Res> {
  factory _$SalePageCopyWith(_SalePage value, $Res Function(_SalePage) _then) = __$SalePageCopyWithImpl;
@override @useResult
$Res call({
 List<Sale> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$SalePageCopyWithImpl<$Res>
    implements _$SalePageCopyWith<$Res> {
  __$SalePageCopyWithImpl(this._self, this._then);

  final _SalePage _self;
  final $Res Function(_SalePage) _then;

/// Create a copy of SalePage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_SalePage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Sale>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SaleFiscalResult {

 String get status; String? get externalId; String? get message;
/// Create a copy of SaleFiscalResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaleFiscalResultCopyWith<SaleFiscalResult> get copyWith => _$SaleFiscalResultCopyWithImpl<SaleFiscalResult>(this as SaleFiscalResult, _$identity);

  /// Serializes this SaleFiscalResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SaleFiscalResult&&(identical(other.status, status) || other.status == status)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,externalId,message);

@override
String toString() {
  return 'SaleFiscalResult(status: $status, externalId: $externalId, message: $message)';
}


}

/// @nodoc
abstract mixin class $SaleFiscalResultCopyWith<$Res>  {
  factory $SaleFiscalResultCopyWith(SaleFiscalResult value, $Res Function(SaleFiscalResult) _then) = _$SaleFiscalResultCopyWithImpl;
@useResult
$Res call({
 String status, String? externalId, String? message
});




}
/// @nodoc
class _$SaleFiscalResultCopyWithImpl<$Res>
    implements $SaleFiscalResultCopyWith<$Res> {
  _$SaleFiscalResultCopyWithImpl(this._self, this._then);

  final SaleFiscalResult _self;
  final $Res Function(SaleFiscalResult) _then;

/// Create a copy of SaleFiscalResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? externalId = freezed,Object? message = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,externalId: freezed == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SaleFiscalResult].
extension SaleFiscalResultPatterns on SaleFiscalResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SaleFiscalResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SaleFiscalResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SaleFiscalResult value)  $default,){
final _that = this;
switch (_that) {
case _SaleFiscalResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SaleFiscalResult value)?  $default,){
final _that = this;
switch (_that) {
case _SaleFiscalResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  String? externalId,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SaleFiscalResult() when $default != null:
return $default(_that.status,_that.externalId,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  String? externalId,  String? message)  $default,) {final _that = this;
switch (_that) {
case _SaleFiscalResult():
return $default(_that.status,_that.externalId,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  String? externalId,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _SaleFiscalResult() when $default != null:
return $default(_that.status,_that.externalId,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SaleFiscalResult implements SaleFiscalResult {
  const _SaleFiscalResult({this.status = 'nao_emitida', this.externalId, this.message});
  factory _SaleFiscalResult.fromJson(Map<String, dynamic> json) => _$SaleFiscalResultFromJson(json);

@override@JsonKey() final  String status;
@override final  String? externalId;
@override final  String? message;

/// Create a copy of SaleFiscalResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaleFiscalResultCopyWith<_SaleFiscalResult> get copyWith => __$SaleFiscalResultCopyWithImpl<_SaleFiscalResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SaleFiscalResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaleFiscalResult&&(identical(other.status, status) || other.status == status)&&(identical(other.externalId, externalId) || other.externalId == externalId)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,externalId,message);

@override
String toString() {
  return 'SaleFiscalResult(status: $status, externalId: $externalId, message: $message)';
}


}

/// @nodoc
abstract mixin class _$SaleFiscalResultCopyWith<$Res> implements $SaleFiscalResultCopyWith<$Res> {
  factory _$SaleFiscalResultCopyWith(_SaleFiscalResult value, $Res Function(_SaleFiscalResult) _then) = __$SaleFiscalResultCopyWithImpl;
@override @useResult
$Res call({
 String status, String? externalId, String? message
});




}
/// @nodoc
class __$SaleFiscalResultCopyWithImpl<$Res>
    implements _$SaleFiscalResultCopyWith<$Res> {
  __$SaleFiscalResultCopyWithImpl(this._self, this._then);

  final _SaleFiscalResult _self;
  final $Res Function(_SaleFiscalResult) _then;

/// Create a copy of SaleFiscalResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? externalId = freezed,Object? message = freezed,}) {
  return _then(_SaleFiscalResult(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,externalId: freezed == externalId ? _self.externalId : externalId // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
