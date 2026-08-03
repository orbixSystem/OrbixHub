// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'receivables_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Debtor {

/// `null` = venda de balcão sem cliente identificado.
@JsonKey(name: 'customerId') String? get customerId;@JsonKey(name: 'customerName') String get customerName;@JsonKey(name: 'totalDue') num get totalDue;@JsonKey(name: 'titleCount') int get titleCount;/// Título mais antigo em aberto — "deve desde quando".
@JsonKey(name: 'oldestAt') String? get oldestAt;
/// Create a copy of Debtor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DebtorCopyWith<Debtor> get copyWith => _$DebtorCopyWithImpl<Debtor>(this as Debtor, _$identity);

  /// Serializes this Debtor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Debtor&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.totalDue, totalDue) || other.totalDue == totalDue)&&(identical(other.titleCount, titleCount) || other.titleCount == titleCount)&&(identical(other.oldestAt, oldestAt) || other.oldestAt == oldestAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerId,customerName,totalDue,titleCount,oldestAt);

@override
String toString() {
  return 'Debtor(customerId: $customerId, customerName: $customerName, totalDue: $totalDue, titleCount: $titleCount, oldestAt: $oldestAt)';
}


}

/// @nodoc
abstract mixin class $DebtorCopyWith<$Res>  {
  factory $DebtorCopyWith(Debtor value, $Res Function(Debtor) _then) = _$DebtorCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'customerId') String? customerId,@JsonKey(name: 'customerName') String customerName,@JsonKey(name: 'totalDue') num totalDue,@JsonKey(name: 'titleCount') int titleCount,@JsonKey(name: 'oldestAt') String? oldestAt
});




}
/// @nodoc
class _$DebtorCopyWithImpl<$Res>
    implements $DebtorCopyWith<$Res> {
  _$DebtorCopyWithImpl(this._self, this._then);

  final Debtor _self;
  final $Res Function(Debtor) _then;

/// Create a copy of Debtor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? customerId = freezed,Object? customerName = null,Object? totalDue = null,Object? titleCount = null,Object? oldestAt = freezed,}) {
  return _then(_self.copyWith(
customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,totalDue: null == totalDue ? _self.totalDue : totalDue // ignore: cast_nullable_to_non_nullable
as num,titleCount: null == titleCount ? _self.titleCount : titleCount // ignore: cast_nullable_to_non_nullable
as int,oldestAt: freezed == oldestAt ? _self.oldestAt : oldestAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Debtor].
extension DebtorPatterns on Debtor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Debtor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Debtor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Debtor value)  $default,){
final _that = this;
switch (_that) {
case _Debtor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Debtor value)?  $default,){
final _that = this;
switch (_that) {
case _Debtor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'customerId')  String? customerId, @JsonKey(name: 'customerName')  String customerName, @JsonKey(name: 'totalDue')  num totalDue, @JsonKey(name: 'titleCount')  int titleCount, @JsonKey(name: 'oldestAt')  String? oldestAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Debtor() when $default != null:
return $default(_that.customerId,_that.customerName,_that.totalDue,_that.titleCount,_that.oldestAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'customerId')  String? customerId, @JsonKey(name: 'customerName')  String customerName, @JsonKey(name: 'totalDue')  num totalDue, @JsonKey(name: 'titleCount')  int titleCount, @JsonKey(name: 'oldestAt')  String? oldestAt)  $default,) {final _that = this;
switch (_that) {
case _Debtor():
return $default(_that.customerId,_that.customerName,_that.totalDue,_that.titleCount,_that.oldestAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'customerId')  String? customerId, @JsonKey(name: 'customerName')  String customerName, @JsonKey(name: 'totalDue')  num totalDue, @JsonKey(name: 'titleCount')  int titleCount, @JsonKey(name: 'oldestAt')  String? oldestAt)?  $default,) {final _that = this;
switch (_that) {
case _Debtor() when $default != null:
return $default(_that.customerId,_that.customerName,_that.totalDue,_that.titleCount,_that.oldestAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Debtor implements Debtor {
  const _Debtor({@JsonKey(name: 'customerId') this.customerId, @JsonKey(name: 'customerName') this.customerName = 'Sem cliente', @JsonKey(name: 'totalDue') this.totalDue = 0, @JsonKey(name: 'titleCount') this.titleCount = 0, @JsonKey(name: 'oldestAt') this.oldestAt});
  factory _Debtor.fromJson(Map<String, dynamic> json) => _$DebtorFromJson(json);

/// `null` = venda de balcão sem cliente identificado.
@override@JsonKey(name: 'customerId') final  String? customerId;
@override@JsonKey(name: 'customerName') final  String customerName;
@override@JsonKey(name: 'totalDue') final  num totalDue;
@override@JsonKey(name: 'titleCount') final  int titleCount;
/// Título mais antigo em aberto — "deve desde quando".
@override@JsonKey(name: 'oldestAt') final  String? oldestAt;

/// Create a copy of Debtor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DebtorCopyWith<_Debtor> get copyWith => __$DebtorCopyWithImpl<_Debtor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DebtorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Debtor&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.totalDue, totalDue) || other.totalDue == totalDue)&&(identical(other.titleCount, titleCount) || other.titleCount == titleCount)&&(identical(other.oldestAt, oldestAt) || other.oldestAt == oldestAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerId,customerName,totalDue,titleCount,oldestAt);

@override
String toString() {
  return 'Debtor(customerId: $customerId, customerName: $customerName, totalDue: $totalDue, titleCount: $titleCount, oldestAt: $oldestAt)';
}


}

/// @nodoc
abstract mixin class _$DebtorCopyWith<$Res> implements $DebtorCopyWith<$Res> {
  factory _$DebtorCopyWith(_Debtor value, $Res Function(_Debtor) _then) = __$DebtorCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'customerId') String? customerId,@JsonKey(name: 'customerName') String customerName,@JsonKey(name: 'totalDue') num totalDue,@JsonKey(name: 'titleCount') int titleCount,@JsonKey(name: 'oldestAt') String? oldestAt
});




}
/// @nodoc
class __$DebtorCopyWithImpl<$Res>
    implements _$DebtorCopyWith<$Res> {
  __$DebtorCopyWithImpl(this._self, this._then);

  final _Debtor _self;
  final $Res Function(_Debtor) _then;

/// Create a copy of Debtor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? customerId = freezed,Object? customerName = null,Object? totalDue = null,Object? titleCount = null,Object? oldestAt = freezed,}) {
  return _then(_Debtor(
customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,totalDue: null == totalDue ? _self.totalDue : totalDue // ignore: cast_nullable_to_non_nullable
as num,titleCount: null == titleCount ? _self.titleCount : titleCount // ignore: cast_nullable_to_non_nullable
as int,oldestAt: freezed == oldestAt ? _self.oldestAt : oldestAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DebtorsPage {

 List<Debtor> get items;@JsonKey(name: 'totalDue') num get totalDue;/// A varredura bateu no teto do servidor: há dívida não listada. A tela avisa
/// em vez de deixar o usuário achar que viu tudo.
 bool get truncated;
/// Create a copy of DebtorsPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DebtorsPageCopyWith<DebtorsPage> get copyWith => _$DebtorsPageCopyWithImpl<DebtorsPage>(this as DebtorsPage, _$identity);

  /// Serializes this DebtorsPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DebtorsPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.totalDue, totalDue) || other.totalDue == totalDue)&&(identical(other.truncated, truncated) || other.truncated == truncated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),totalDue,truncated);

@override
String toString() {
  return 'DebtorsPage(items: $items, totalDue: $totalDue, truncated: $truncated)';
}


}

/// @nodoc
abstract mixin class $DebtorsPageCopyWith<$Res>  {
  factory $DebtorsPageCopyWith(DebtorsPage value, $Res Function(DebtorsPage) _then) = _$DebtorsPageCopyWithImpl;
@useResult
$Res call({
 List<Debtor> items,@JsonKey(name: 'totalDue') num totalDue, bool truncated
});




}
/// @nodoc
class _$DebtorsPageCopyWithImpl<$Res>
    implements $DebtorsPageCopyWith<$Res> {
  _$DebtorsPageCopyWithImpl(this._self, this._then);

  final DebtorsPage _self;
  final $Res Function(DebtorsPage) _then;

/// Create a copy of DebtorsPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? totalDue = null,Object? truncated = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Debtor>,totalDue: null == totalDue ? _self.totalDue : totalDue // ignore: cast_nullable_to_non_nullable
as num,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DebtorsPage].
extension DebtorsPagePatterns on DebtorsPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DebtorsPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DebtorsPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DebtorsPage value)  $default,){
final _that = this;
switch (_that) {
case _DebtorsPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DebtorsPage value)?  $default,){
final _that = this;
switch (_that) {
case _DebtorsPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Debtor> items, @JsonKey(name: 'totalDue')  num totalDue,  bool truncated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DebtorsPage() when $default != null:
return $default(_that.items,_that.totalDue,_that.truncated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Debtor> items, @JsonKey(name: 'totalDue')  num totalDue,  bool truncated)  $default,) {final _that = this;
switch (_that) {
case _DebtorsPage():
return $default(_that.items,_that.totalDue,_that.truncated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Debtor> items, @JsonKey(name: 'totalDue')  num totalDue,  bool truncated)?  $default,) {final _that = this;
switch (_that) {
case _DebtorsPage() when $default != null:
return $default(_that.items,_that.totalDue,_that.truncated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DebtorsPage implements DebtorsPage {
  const _DebtorsPage({final  List<Debtor> items = const <Debtor>[], @JsonKey(name: 'totalDue') this.totalDue = 0, this.truncated = false}): _items = items;
  factory _DebtorsPage.fromJson(Map<String, dynamic> json) => _$DebtorsPageFromJson(json);

 final  List<Debtor> _items;
@override@JsonKey() List<Debtor> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey(name: 'totalDue') final  num totalDue;
/// A varredura bateu no teto do servidor: há dívida não listada. A tela avisa
/// em vez de deixar o usuário achar que viu tudo.
@override@JsonKey() final  bool truncated;

/// Create a copy of DebtorsPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DebtorsPageCopyWith<_DebtorsPage> get copyWith => __$DebtorsPageCopyWithImpl<_DebtorsPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DebtorsPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DebtorsPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.totalDue, totalDue) || other.totalDue == totalDue)&&(identical(other.truncated, truncated) || other.truncated == truncated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),totalDue,truncated);

@override
String toString() {
  return 'DebtorsPage(items: $items, totalDue: $totalDue, truncated: $truncated)';
}


}

/// @nodoc
abstract mixin class _$DebtorsPageCopyWith<$Res> implements $DebtorsPageCopyWith<$Res> {
  factory _$DebtorsPageCopyWith(_DebtorsPage value, $Res Function(_DebtorsPage) _then) = __$DebtorsPageCopyWithImpl;
@override @useResult
$Res call({
 List<Debtor> items,@JsonKey(name: 'totalDue') num totalDue, bool truncated
});




}
/// @nodoc
class __$DebtorsPageCopyWithImpl<$Res>
    implements _$DebtorsPageCopyWith<$Res> {
  __$DebtorsPageCopyWithImpl(this._self, this._then);

  final _DebtorsPage _self;
  final $Res Function(_DebtorsPage) _then;

/// Create a copy of DebtorsPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? totalDue = null,Object? truncated = null,}) {
  return _then(_DebtorsPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Debtor>,totalDue: null == totalDue ? _self.totalDue : totalDue // ignore: cast_nullable_to_non_nullable
as num,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ReceivableItem {

 String get name; String? get kind;// 'product' | 'service'
 num get quantity;@JsonKey(name: 'unitPrice') num get unitPrice; num get total;
/// Create a copy of ReceivableItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceivableItemCopyWith<ReceivableItem> get copyWith => _$ReceivableItemCopyWithImpl<ReceivableItem>(this as ReceivableItem, _$identity);

  /// Serializes this ReceivableItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReceivableItem&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,kind,quantity,unitPrice,total);

@override
String toString() {
  return 'ReceivableItem(name: $name, kind: $kind, quantity: $quantity, unitPrice: $unitPrice, total: $total)';
}


}

/// @nodoc
abstract mixin class $ReceivableItemCopyWith<$Res>  {
  factory $ReceivableItemCopyWith(ReceivableItem value, $Res Function(ReceivableItem) _then) = _$ReceivableItemCopyWithImpl;
@useResult
$Res call({
 String name, String? kind, num quantity,@JsonKey(name: 'unitPrice') num unitPrice, num total
});




}
/// @nodoc
class _$ReceivableItemCopyWithImpl<$Res>
    implements $ReceivableItemCopyWith<$Res> {
  _$ReceivableItemCopyWithImpl(this._self, this._then);

  final ReceivableItem _self;
  final $Res Function(ReceivableItem) _then;

/// Create a copy of ReceivableItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? kind = freezed,Object? quantity = null,Object? unitPrice = null,Object? total = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as num,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as num,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [ReceivableItem].
extension ReceivableItemPatterns on ReceivableItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReceivableItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReceivableItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReceivableItem value)  $default,){
final _that = this;
switch (_that) {
case _ReceivableItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReceivableItem value)?  $default,){
final _that = this;
switch (_that) {
case _ReceivableItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? kind,  num quantity, @JsonKey(name: 'unitPrice')  num unitPrice,  num total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReceivableItem() when $default != null:
return $default(_that.name,_that.kind,_that.quantity,_that.unitPrice,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? kind,  num quantity, @JsonKey(name: 'unitPrice')  num unitPrice,  num total)  $default,) {final _that = this;
switch (_that) {
case _ReceivableItem():
return $default(_that.name,_that.kind,_that.quantity,_that.unitPrice,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? kind,  num quantity, @JsonKey(name: 'unitPrice')  num unitPrice,  num total)?  $default,) {final _that = this;
switch (_that) {
case _ReceivableItem() when $default != null:
return $default(_that.name,_that.kind,_that.quantity,_that.unitPrice,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReceivableItem implements ReceivableItem {
  const _ReceivableItem({this.name = '', this.kind, this.quantity = 0, @JsonKey(name: 'unitPrice') this.unitPrice = 0, this.total = 0});
  factory _ReceivableItem.fromJson(Map<String, dynamic> json) => _$ReceivableItemFromJson(json);

@override@JsonKey() final  String name;
@override final  String? kind;
// 'product' | 'service'
@override@JsonKey() final  num quantity;
@override@JsonKey(name: 'unitPrice') final  num unitPrice;
@override@JsonKey() final  num total;

/// Create a copy of ReceivableItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceivableItemCopyWith<_ReceivableItem> get copyWith => __$ReceivableItemCopyWithImpl<_ReceivableItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceivableItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReceivableItem&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,kind,quantity,unitPrice,total);

@override
String toString() {
  return 'ReceivableItem(name: $name, kind: $kind, quantity: $quantity, unitPrice: $unitPrice, total: $total)';
}


}

/// @nodoc
abstract mixin class _$ReceivableItemCopyWith<$Res> implements $ReceivableItemCopyWith<$Res> {
  factory _$ReceivableItemCopyWith(_ReceivableItem value, $Res Function(_ReceivableItem) _then) = __$ReceivableItemCopyWithImpl;
@override @useResult
$Res call({
 String name, String? kind, num quantity,@JsonKey(name: 'unitPrice') num unitPrice, num total
});




}
/// @nodoc
class __$ReceivableItemCopyWithImpl<$Res>
    implements _$ReceivableItemCopyWith<$Res> {
  __$ReceivableItemCopyWithImpl(this._self, this._then);

  final _ReceivableItem _self;
  final $Res Function(_ReceivableItem) _then;

/// Create a copy of ReceivableItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? kind = freezed,Object? quantity = null,Object? unitPrice = null,Object? total = null,}) {
  return _then(_ReceivableItem(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as num,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as num,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$ReceivableTitle {

 String get id;/// 'os' | 'sale' — decide qual tela abrir no drill-down.
 String get origin; String get number;@JsonKey(name: 'createdAt') String? get createdAt; num get total; num get paid; num get balance;/// 'a_receber' | 'parcial'
 String get status; List<ReceivableItem> get items;
/// Create a copy of ReceivableTitle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceivableTitleCopyWith<ReceivableTitle> get copyWith => _$ReceivableTitleCopyWithImpl<ReceivableTitle>(this as ReceivableTitle, _$identity);

  /// Serializes this ReceivableTitle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReceivableTitle&&(identical(other.id, id) || other.id == id)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.number, number) || other.number == number)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.total, total) || other.total == total)&&(identical(other.paid, paid) || other.paid == paid)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,origin,number,createdAt,total,paid,balance,status,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'ReceivableTitle(id: $id, origin: $origin, number: $number, createdAt: $createdAt, total: $total, paid: $paid, balance: $balance, status: $status, items: $items)';
}


}

/// @nodoc
abstract mixin class $ReceivableTitleCopyWith<$Res>  {
  factory $ReceivableTitleCopyWith(ReceivableTitle value, $Res Function(ReceivableTitle) _then) = _$ReceivableTitleCopyWithImpl;
@useResult
$Res call({
 String id, String origin, String number,@JsonKey(name: 'createdAt') String? createdAt, num total, num paid, num balance, String status, List<ReceivableItem> items
});




}
/// @nodoc
class _$ReceivableTitleCopyWithImpl<$Res>
    implements $ReceivableTitleCopyWith<$Res> {
  _$ReceivableTitleCopyWithImpl(this._self, this._then);

  final ReceivableTitle _self;
  final $Res Function(ReceivableTitle) _then;

/// Create a copy of ReceivableTitle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? origin = null,Object? number = null,Object? createdAt = freezed,Object? total = null,Object? paid = null,Object? balance = null,Object? status = null,Object? items = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,paid: null == paid ? _self.paid : paid // ignore: cast_nullable_to_non_nullable
as num,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as num,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ReceivableItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [ReceivableTitle].
extension ReceivableTitlePatterns on ReceivableTitle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReceivableTitle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReceivableTitle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReceivableTitle value)  $default,){
final _that = this;
switch (_that) {
case _ReceivableTitle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReceivableTitle value)?  $default,){
final _that = this;
switch (_that) {
case _ReceivableTitle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String origin,  String number, @JsonKey(name: 'createdAt')  String? createdAt,  num total,  num paid,  num balance,  String status,  List<ReceivableItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReceivableTitle() when $default != null:
return $default(_that.id,_that.origin,_that.number,_that.createdAt,_that.total,_that.paid,_that.balance,_that.status,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String origin,  String number, @JsonKey(name: 'createdAt')  String? createdAt,  num total,  num paid,  num balance,  String status,  List<ReceivableItem> items)  $default,) {final _that = this;
switch (_that) {
case _ReceivableTitle():
return $default(_that.id,_that.origin,_that.number,_that.createdAt,_that.total,_that.paid,_that.balance,_that.status,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String origin,  String number, @JsonKey(name: 'createdAt')  String? createdAt,  num total,  num paid,  num balance,  String status,  List<ReceivableItem> items)?  $default,) {final _that = this;
switch (_that) {
case _ReceivableTitle() when $default != null:
return $default(_that.id,_that.origin,_that.number,_that.createdAt,_that.total,_that.paid,_that.balance,_that.status,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReceivableTitle implements ReceivableTitle {
  const _ReceivableTitle({required this.id, this.origin = 'sale', this.number = '', @JsonKey(name: 'createdAt') this.createdAt, this.total = 0, this.paid = 0, this.balance = 0, this.status = 'a_receber', final  List<ReceivableItem> items = const <ReceivableItem>[]}): _items = items;
  factory _ReceivableTitle.fromJson(Map<String, dynamic> json) => _$ReceivableTitleFromJson(json);

@override final  String id;
/// 'os' | 'sale' — decide qual tela abrir no drill-down.
@override@JsonKey() final  String origin;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'createdAt') final  String? createdAt;
@override@JsonKey() final  num total;
@override@JsonKey() final  num paid;
@override@JsonKey() final  num balance;
/// 'a_receber' | 'parcial'
@override@JsonKey() final  String status;
 final  List<ReceivableItem> _items;
@override@JsonKey() List<ReceivableItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of ReceivableTitle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceivableTitleCopyWith<_ReceivableTitle> get copyWith => __$ReceivableTitleCopyWithImpl<_ReceivableTitle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceivableTitleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReceivableTitle&&(identical(other.id, id) || other.id == id)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.number, number) || other.number == number)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.total, total) || other.total == total)&&(identical(other.paid, paid) || other.paid == paid)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,origin,number,createdAt,total,paid,balance,status,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'ReceivableTitle(id: $id, origin: $origin, number: $number, createdAt: $createdAt, total: $total, paid: $paid, balance: $balance, status: $status, items: $items)';
}


}

/// @nodoc
abstract mixin class _$ReceivableTitleCopyWith<$Res> implements $ReceivableTitleCopyWith<$Res> {
  factory _$ReceivableTitleCopyWith(_ReceivableTitle value, $Res Function(_ReceivableTitle) _then) = __$ReceivableTitleCopyWithImpl;
@override @useResult
$Res call({
 String id, String origin, String number,@JsonKey(name: 'createdAt') String? createdAt, num total, num paid, num balance, String status, List<ReceivableItem> items
});




}
/// @nodoc
class __$ReceivableTitleCopyWithImpl<$Res>
    implements _$ReceivableTitleCopyWith<$Res> {
  __$ReceivableTitleCopyWithImpl(this._self, this._then);

  final _ReceivableTitle _self;
  final $Res Function(_ReceivableTitle) _then;

/// Create a copy of ReceivableTitle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? origin = null,Object? number = null,Object? createdAt = freezed,Object? total = null,Object? paid = null,Object? balance = null,Object? status = null,Object? items = null,}) {
  return _then(_ReceivableTitle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,paid: null == paid ? _self.paid : paid // ignore: cast_nullable_to_non_nullable
as num,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as num,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ReceivableItem>,
  ));
}


}


/// @nodoc
mixin _$DebtorDetail {

@JsonKey(name: 'customerName') String get customerName;@JsonKey(name: 'totalDue') num get totalDue; List<ReceivableTitle> get items;
/// Create a copy of DebtorDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DebtorDetailCopyWith<DebtorDetail> get copyWith => _$DebtorDetailCopyWithImpl<DebtorDetail>(this as DebtorDetail, _$identity);

  /// Serializes this DebtorDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DebtorDetail&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.totalDue, totalDue) || other.totalDue == totalDue)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerName,totalDue,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'DebtorDetail(customerName: $customerName, totalDue: $totalDue, items: $items)';
}


}

/// @nodoc
abstract mixin class $DebtorDetailCopyWith<$Res>  {
  factory $DebtorDetailCopyWith(DebtorDetail value, $Res Function(DebtorDetail) _then) = _$DebtorDetailCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'customerName') String customerName,@JsonKey(name: 'totalDue') num totalDue, List<ReceivableTitle> items
});




}
/// @nodoc
class _$DebtorDetailCopyWithImpl<$Res>
    implements $DebtorDetailCopyWith<$Res> {
  _$DebtorDetailCopyWithImpl(this._self, this._then);

  final DebtorDetail _self;
  final $Res Function(DebtorDetail) _then;

/// Create a copy of DebtorDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? customerName = null,Object? totalDue = null,Object? items = null,}) {
  return _then(_self.copyWith(
customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,totalDue: null == totalDue ? _self.totalDue : totalDue // ignore: cast_nullable_to_non_nullable
as num,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ReceivableTitle>,
  ));
}

}


/// Adds pattern-matching-related methods to [DebtorDetail].
extension DebtorDetailPatterns on DebtorDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DebtorDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DebtorDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DebtorDetail value)  $default,){
final _that = this;
switch (_that) {
case _DebtorDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DebtorDetail value)?  $default,){
final _that = this;
switch (_that) {
case _DebtorDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'customerName')  String customerName, @JsonKey(name: 'totalDue')  num totalDue,  List<ReceivableTitle> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DebtorDetail() when $default != null:
return $default(_that.customerName,_that.totalDue,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'customerName')  String customerName, @JsonKey(name: 'totalDue')  num totalDue,  List<ReceivableTitle> items)  $default,) {final _that = this;
switch (_that) {
case _DebtorDetail():
return $default(_that.customerName,_that.totalDue,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'customerName')  String customerName, @JsonKey(name: 'totalDue')  num totalDue,  List<ReceivableTitle> items)?  $default,) {final _that = this;
switch (_that) {
case _DebtorDetail() when $default != null:
return $default(_that.customerName,_that.totalDue,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DebtorDetail implements DebtorDetail {
  const _DebtorDetail({@JsonKey(name: 'customerName') this.customerName = 'Sem cliente', @JsonKey(name: 'totalDue') this.totalDue = 0, final  List<ReceivableTitle> items = const <ReceivableTitle>[]}): _items = items;
  factory _DebtorDetail.fromJson(Map<String, dynamic> json) => _$DebtorDetailFromJson(json);

@override@JsonKey(name: 'customerName') final  String customerName;
@override@JsonKey(name: 'totalDue') final  num totalDue;
 final  List<ReceivableTitle> _items;
@override@JsonKey() List<ReceivableTitle> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of DebtorDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DebtorDetailCopyWith<_DebtorDetail> get copyWith => __$DebtorDetailCopyWithImpl<_DebtorDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DebtorDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DebtorDetail&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.totalDue, totalDue) || other.totalDue == totalDue)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,customerName,totalDue,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'DebtorDetail(customerName: $customerName, totalDue: $totalDue, items: $items)';
}


}

/// @nodoc
abstract mixin class _$DebtorDetailCopyWith<$Res> implements $DebtorDetailCopyWith<$Res> {
  factory _$DebtorDetailCopyWith(_DebtorDetail value, $Res Function(_DebtorDetail) _then) = __$DebtorDetailCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'customerName') String customerName,@JsonKey(name: 'totalDue') num totalDue, List<ReceivableTitle> items
});




}
/// @nodoc
class __$DebtorDetailCopyWithImpl<$Res>
    implements _$DebtorDetailCopyWith<$Res> {
  __$DebtorDetailCopyWithImpl(this._self, this._then);

  final _DebtorDetail _self;
  final $Res Function(_DebtorDetail) _then;

/// Create a copy of DebtorDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? customerName = null,Object? totalDue = null,Object? items = null,}) {
  return _then(_DebtorDetail(
customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,totalDue: null == totalDue ? _self.totalDue : totalDue // ignore: cast_nullable_to_non_nullable
as num,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ReceivableTitle>,
  ));
}


}

// dart format on
