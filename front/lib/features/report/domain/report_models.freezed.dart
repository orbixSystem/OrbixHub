// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'report_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SalesLedgerRow {

 String get id; String get date;// ISO
 String get type;// 'servico' | 'produto'
 String get origin;// 'os' | 'sale'
@JsonKey(name: 'originNumber') String get originNumber;@JsonKey(name: 'customerName') String? get customerName; num get value;@JsonKey(name: 'paymentStatus') String get paymentStatus;
/// Create a copy of SalesLedgerRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SalesLedgerRowCopyWith<SalesLedgerRow> get copyWith => _$SalesLedgerRowCopyWithImpl<SalesLedgerRow>(this as SalesLedgerRow, _$identity);

  /// Serializes this SalesLedgerRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SalesLedgerRow&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.type, type) || other.type == type)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.originNumber, originNumber) || other.originNumber == originNumber)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.value, value) || other.value == value)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,type,origin,originNumber,customerName,value,paymentStatus);

@override
String toString() {
  return 'SalesLedgerRow(id: $id, date: $date, type: $type, origin: $origin, originNumber: $originNumber, customerName: $customerName, value: $value, paymentStatus: $paymentStatus)';
}


}

/// @nodoc
abstract mixin class $SalesLedgerRowCopyWith<$Res>  {
  factory $SalesLedgerRowCopyWith(SalesLedgerRow value, $Res Function(SalesLedgerRow) _then) = _$SalesLedgerRowCopyWithImpl;
@useResult
$Res call({
 String id, String date, String type, String origin,@JsonKey(name: 'originNumber') String originNumber,@JsonKey(name: 'customerName') String? customerName, num value,@JsonKey(name: 'paymentStatus') String paymentStatus
});




}
/// @nodoc
class _$SalesLedgerRowCopyWithImpl<$Res>
    implements $SalesLedgerRowCopyWith<$Res> {
  _$SalesLedgerRowCopyWithImpl(this._self, this._then);

  final SalesLedgerRow _self;
  final $Res Function(SalesLedgerRow) _then;

/// Create a copy of SalesLedgerRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? date = null,Object? type = null,Object? origin = null,Object? originNumber = null,Object? customerName = freezed,Object? value = null,Object? paymentStatus = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,originNumber: null == originNumber ? _self.originNumber : originNumber // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as num,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SalesLedgerRow].
extension SalesLedgerRowPatterns on SalesLedgerRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SalesLedgerRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SalesLedgerRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SalesLedgerRow value)  $default,){
final _that = this;
switch (_that) {
case _SalesLedgerRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SalesLedgerRow value)?  $default,){
final _that = this;
switch (_that) {
case _SalesLedgerRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String date,  String type,  String origin, @JsonKey(name: 'originNumber')  String originNumber, @JsonKey(name: 'customerName')  String? customerName,  num value, @JsonKey(name: 'paymentStatus')  String paymentStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SalesLedgerRow() when $default != null:
return $default(_that.id,_that.date,_that.type,_that.origin,_that.originNumber,_that.customerName,_that.value,_that.paymentStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String date,  String type,  String origin, @JsonKey(name: 'originNumber')  String originNumber, @JsonKey(name: 'customerName')  String? customerName,  num value, @JsonKey(name: 'paymentStatus')  String paymentStatus)  $default,) {final _that = this;
switch (_that) {
case _SalesLedgerRow():
return $default(_that.id,_that.date,_that.type,_that.origin,_that.originNumber,_that.customerName,_that.value,_that.paymentStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String date,  String type,  String origin, @JsonKey(name: 'originNumber')  String originNumber, @JsonKey(name: 'customerName')  String? customerName,  num value, @JsonKey(name: 'paymentStatus')  String paymentStatus)?  $default,) {final _that = this;
switch (_that) {
case _SalesLedgerRow() when $default != null:
return $default(_that.id,_that.date,_that.type,_that.origin,_that.originNumber,_that.customerName,_that.value,_that.paymentStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SalesLedgerRow implements SalesLedgerRow {
  const _SalesLedgerRow({this.id = '', this.date = '', this.type = 'servico', this.origin = 'os', @JsonKey(name: 'originNumber') this.originNumber = '', @JsonKey(name: 'customerName') this.customerName, this.value = 0, @JsonKey(name: 'paymentStatus') this.paymentStatus = 'a_receber'});
  factory _SalesLedgerRow.fromJson(Map<String, dynamic> json) => _$SalesLedgerRowFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String date;
// ISO
@override@JsonKey() final  String type;
// 'servico' | 'produto'
@override@JsonKey() final  String origin;
// 'os' | 'sale'
@override@JsonKey(name: 'originNumber') final  String originNumber;
@override@JsonKey(name: 'customerName') final  String? customerName;
@override@JsonKey() final  num value;
@override@JsonKey(name: 'paymentStatus') final  String paymentStatus;

/// Create a copy of SalesLedgerRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SalesLedgerRowCopyWith<_SalesLedgerRow> get copyWith => __$SalesLedgerRowCopyWithImpl<_SalesLedgerRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SalesLedgerRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SalesLedgerRow&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.type, type) || other.type == type)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.originNumber, originNumber) || other.originNumber == originNumber)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.value, value) || other.value == value)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,type,origin,originNumber,customerName,value,paymentStatus);

@override
String toString() {
  return 'SalesLedgerRow(id: $id, date: $date, type: $type, origin: $origin, originNumber: $originNumber, customerName: $customerName, value: $value, paymentStatus: $paymentStatus)';
}


}

/// @nodoc
abstract mixin class _$SalesLedgerRowCopyWith<$Res> implements $SalesLedgerRowCopyWith<$Res> {
  factory _$SalesLedgerRowCopyWith(_SalesLedgerRow value, $Res Function(_SalesLedgerRow) _then) = __$SalesLedgerRowCopyWithImpl;
@override @useResult
$Res call({
 String id, String date, String type, String origin,@JsonKey(name: 'originNumber') String originNumber,@JsonKey(name: 'customerName') String? customerName, num value,@JsonKey(name: 'paymentStatus') String paymentStatus
});




}
/// @nodoc
class __$SalesLedgerRowCopyWithImpl<$Res>
    implements _$SalesLedgerRowCopyWith<$Res> {
  __$SalesLedgerRowCopyWithImpl(this._self, this._then);

  final _SalesLedgerRow _self;
  final $Res Function(_SalesLedgerRow) _then;

/// Create a copy of SalesLedgerRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? date = null,Object? type = null,Object? origin = null,Object? originNumber = null,Object? customerName = freezed,Object? value = null,Object? paymentStatus = null,}) {
  return _then(_SalesLedgerRow(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String,originNumber: null == originNumber ? _self.originNumber : originNumber // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as num,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SalesLedger {

 List<SalesLedgerRow> get rows;
/// Create a copy of SalesLedger
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SalesLedgerCopyWith<SalesLedger> get copyWith => _$SalesLedgerCopyWithImpl<SalesLedger>(this as SalesLedger, _$identity);

  /// Serializes this SalesLedger to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SalesLedger&&const DeepCollectionEquality().equals(other.rows, rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows));

@override
String toString() {
  return 'SalesLedger(rows: $rows)';
}


}

/// @nodoc
abstract mixin class $SalesLedgerCopyWith<$Res>  {
  factory $SalesLedgerCopyWith(SalesLedger value, $Res Function(SalesLedger) _then) = _$SalesLedgerCopyWithImpl;
@useResult
$Res call({
 List<SalesLedgerRow> rows
});




}
/// @nodoc
class _$SalesLedgerCopyWithImpl<$Res>
    implements $SalesLedgerCopyWith<$Res> {
  _$SalesLedgerCopyWithImpl(this._self, this._then);

  final SalesLedger _self;
  final $Res Function(SalesLedger) _then;

/// Create a copy of SalesLedger
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<SalesLedgerRow>,
  ));
}

}


/// Adds pattern-matching-related methods to [SalesLedger].
extension SalesLedgerPatterns on SalesLedger {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SalesLedger value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SalesLedger() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SalesLedger value)  $default,){
final _that = this;
switch (_that) {
case _SalesLedger():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SalesLedger value)?  $default,){
final _that = this;
switch (_that) {
case _SalesLedger() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SalesLedgerRow> rows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SalesLedger() when $default != null:
return $default(_that.rows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SalesLedgerRow> rows)  $default,) {final _that = this;
switch (_that) {
case _SalesLedger():
return $default(_that.rows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SalesLedgerRow> rows)?  $default,) {final _that = this;
switch (_that) {
case _SalesLedger() when $default != null:
return $default(_that.rows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SalesLedger implements SalesLedger {
  const _SalesLedger({final  List<SalesLedgerRow> rows = const <SalesLedgerRow>[]}): _rows = rows;
  factory _SalesLedger.fromJson(Map<String, dynamic> json) => _$SalesLedgerFromJson(json);

 final  List<SalesLedgerRow> _rows;
@override@JsonKey() List<SalesLedgerRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}


/// Create a copy of SalesLedger
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SalesLedgerCopyWith<_SalesLedger> get copyWith => __$SalesLedgerCopyWithImpl<_SalesLedger>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SalesLedgerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SalesLedger&&const DeepCollectionEquality().equals(other._rows, _rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows));

@override
String toString() {
  return 'SalesLedger(rows: $rows)';
}


}

/// @nodoc
abstract mixin class _$SalesLedgerCopyWith<$Res> implements $SalesLedgerCopyWith<$Res> {
  factory _$SalesLedgerCopyWith(_SalesLedger value, $Res Function(_SalesLedger) _then) = __$SalesLedgerCopyWithImpl;
@override @useResult
$Res call({
 List<SalesLedgerRow> rows
});




}
/// @nodoc
class __$SalesLedgerCopyWithImpl<$Res>
    implements _$SalesLedgerCopyWith<$Res> {
  __$SalesLedgerCopyWithImpl(this._self, this._then);

  final _SalesLedger _self;
  final $Res Function(_SalesLedger) _then;

/// Create a copy of SalesLedger
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,}) {
  return _then(_SalesLedger(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<SalesLedgerRow>,
  ));
}


}


/// @nodoc
mixin _$OsReportRow {

 String get number;@JsonKey(name: 'customer_name') String get customerName; String get status;@JsonKey(name: 'assigned_to') String? get assignedTo; num get total;@JsonKey(name: 'opened_at') String? get openedAt;@JsonKey(name: 'finished_at') String? get finishedAt;@JsonKey(name: 'cycleMs') num? get cycleMs;
/// Create a copy of OsReportRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OsReportRowCopyWith<OsReportRow> get copyWith => _$OsReportRowCopyWithImpl<OsReportRow>(this as OsReportRow, _$identity);

  /// Serializes this OsReportRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OsReportRow&&(identical(other.number, number) || other.number == number)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.status, status) || other.status == status)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.total, total) || other.total == total)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.cycleMs, cycleMs) || other.cycleMs == cycleMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,customerName,status,assignedTo,total,openedAt,finishedAt,cycleMs);

@override
String toString() {
  return 'OsReportRow(number: $number, customerName: $customerName, status: $status, assignedTo: $assignedTo, total: $total, openedAt: $openedAt, finishedAt: $finishedAt, cycleMs: $cycleMs)';
}


}

/// @nodoc
abstract mixin class $OsReportRowCopyWith<$Res>  {
  factory $OsReportRowCopyWith(OsReportRow value, $Res Function(OsReportRow) _then) = _$OsReportRowCopyWithImpl;
@useResult
$Res call({
 String number,@JsonKey(name: 'customer_name') String customerName, String status,@JsonKey(name: 'assigned_to') String? assignedTo, num total,@JsonKey(name: 'opened_at') String? openedAt,@JsonKey(name: 'finished_at') String? finishedAt,@JsonKey(name: 'cycleMs') num? cycleMs
});




}
/// @nodoc
class _$OsReportRowCopyWithImpl<$Res>
    implements $OsReportRowCopyWith<$Res> {
  _$OsReportRowCopyWithImpl(this._self, this._then);

  final OsReportRow _self;
  final $Res Function(OsReportRow) _then;

/// Create a copy of OsReportRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? customerName = null,Object? status = null,Object? assignedTo = freezed,Object? total = null,Object? openedAt = freezed,Object? finishedAt = freezed,Object? cycleMs = freezed,}) {
  return _then(_self.copyWith(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,openedAt: freezed == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String?,cycleMs: freezed == cycleMs ? _self.cycleMs : cycleMs // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}

}


/// Adds pattern-matching-related methods to [OsReportRow].
extension OsReportRowPatterns on OsReportRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OsReportRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OsReportRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OsReportRow value)  $default,){
final _that = this;
switch (_that) {
case _OsReportRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OsReportRow value)?  $default,){
final _that = this;
switch (_that) {
case _OsReportRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String number, @JsonKey(name: 'customer_name')  String customerName,  String status, @JsonKey(name: 'assigned_to')  String? assignedTo,  num total, @JsonKey(name: 'opened_at')  String? openedAt, @JsonKey(name: 'finished_at')  String? finishedAt, @JsonKey(name: 'cycleMs')  num? cycleMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OsReportRow() when $default != null:
return $default(_that.number,_that.customerName,_that.status,_that.assignedTo,_that.total,_that.openedAt,_that.finishedAt,_that.cycleMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String number, @JsonKey(name: 'customer_name')  String customerName,  String status, @JsonKey(name: 'assigned_to')  String? assignedTo,  num total, @JsonKey(name: 'opened_at')  String? openedAt, @JsonKey(name: 'finished_at')  String? finishedAt, @JsonKey(name: 'cycleMs')  num? cycleMs)  $default,) {final _that = this;
switch (_that) {
case _OsReportRow():
return $default(_that.number,_that.customerName,_that.status,_that.assignedTo,_that.total,_that.openedAt,_that.finishedAt,_that.cycleMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String number, @JsonKey(name: 'customer_name')  String customerName,  String status, @JsonKey(name: 'assigned_to')  String? assignedTo,  num total, @JsonKey(name: 'opened_at')  String? openedAt, @JsonKey(name: 'finished_at')  String? finishedAt, @JsonKey(name: 'cycleMs')  num? cycleMs)?  $default,) {final _that = this;
switch (_that) {
case _OsReportRow() when $default != null:
return $default(_that.number,_that.customerName,_that.status,_that.assignedTo,_that.total,_that.openedAt,_that.finishedAt,_that.cycleMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OsReportRow implements OsReportRow {
  const _OsReportRow({required this.number, @JsonKey(name: 'customer_name') this.customerName = '', this.status = '', @JsonKey(name: 'assigned_to') this.assignedTo, this.total = 0, @JsonKey(name: 'opened_at') this.openedAt, @JsonKey(name: 'finished_at') this.finishedAt, @JsonKey(name: 'cycleMs') this.cycleMs});
  factory _OsReportRow.fromJson(Map<String, dynamic> json) => _$OsReportRowFromJson(json);

@override final  String number;
@override@JsonKey(name: 'customer_name') final  String customerName;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'assigned_to') final  String? assignedTo;
@override@JsonKey() final  num total;
@override@JsonKey(name: 'opened_at') final  String? openedAt;
@override@JsonKey(name: 'finished_at') final  String? finishedAt;
@override@JsonKey(name: 'cycleMs') final  num? cycleMs;

/// Create a copy of OsReportRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OsReportRowCopyWith<_OsReportRow> get copyWith => __$OsReportRowCopyWithImpl<_OsReportRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OsReportRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OsReportRow&&(identical(other.number, number) || other.number == number)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.status, status) || other.status == status)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.total, total) || other.total == total)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.cycleMs, cycleMs) || other.cycleMs == cycleMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,customerName,status,assignedTo,total,openedAt,finishedAt,cycleMs);

@override
String toString() {
  return 'OsReportRow(number: $number, customerName: $customerName, status: $status, assignedTo: $assignedTo, total: $total, openedAt: $openedAt, finishedAt: $finishedAt, cycleMs: $cycleMs)';
}


}

/// @nodoc
abstract mixin class _$OsReportRowCopyWith<$Res> implements $OsReportRowCopyWith<$Res> {
  factory _$OsReportRowCopyWith(_OsReportRow value, $Res Function(_OsReportRow) _then) = __$OsReportRowCopyWithImpl;
@override @useResult
$Res call({
 String number,@JsonKey(name: 'customer_name') String customerName, String status,@JsonKey(name: 'assigned_to') String? assignedTo, num total,@JsonKey(name: 'opened_at') String? openedAt,@JsonKey(name: 'finished_at') String? finishedAt,@JsonKey(name: 'cycleMs') num? cycleMs
});




}
/// @nodoc
class __$OsReportRowCopyWithImpl<$Res>
    implements _$OsReportRowCopyWith<$Res> {
  __$OsReportRowCopyWithImpl(this._self, this._then);

  final _OsReportRow _self;
  final $Res Function(_OsReportRow) _then;

/// Create a copy of OsReportRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? customerName = null,Object? status = null,Object? assignedTo = freezed,Object? total = null,Object? openedAt = freezed,Object? finishedAt = freezed,Object? cycleMs = freezed,}) {
  return _then(_OsReportRow(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,openedAt: freezed == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as String?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as String?,cycleMs: freezed == cycleMs ? _self.cycleMs : cycleMs // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}


}


/// @nodoc
mixin _$CountRevenue {

 int get count; num get revenue;
/// Create a copy of CountRevenue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CountRevenueCopyWith<CountRevenue> get copyWith => _$CountRevenueCopyWithImpl<CountRevenue>(this as CountRevenue, _$identity);

  /// Serializes this CountRevenue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CountRevenue&&(identical(other.count, count) || other.count == count)&&(identical(other.revenue, revenue) || other.revenue == revenue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,count,revenue);

@override
String toString() {
  return 'CountRevenue(count: $count, revenue: $revenue)';
}


}

/// @nodoc
abstract mixin class $CountRevenueCopyWith<$Res>  {
  factory $CountRevenueCopyWith(CountRevenue value, $Res Function(CountRevenue) _then) = _$CountRevenueCopyWithImpl;
@useResult
$Res call({
 int count, num revenue
});




}
/// @nodoc
class _$CountRevenueCopyWithImpl<$Res>
    implements $CountRevenueCopyWith<$Res> {
  _$CountRevenueCopyWithImpl(this._self, this._then);

  final CountRevenue _self;
  final $Res Function(CountRevenue) _then;

/// Create a copy of CountRevenue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? count = null,Object? revenue = null,}) {
  return _then(_self.copyWith(
count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [CountRevenue].
extension CountRevenuePatterns on CountRevenue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CountRevenue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CountRevenue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CountRevenue value)  $default,){
final _that = this;
switch (_that) {
case _CountRevenue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CountRevenue value)?  $default,){
final _that = this;
switch (_that) {
case _CountRevenue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int count,  num revenue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CountRevenue() when $default != null:
return $default(_that.count,_that.revenue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int count,  num revenue)  $default,) {final _that = this;
switch (_that) {
case _CountRevenue():
return $default(_that.count,_that.revenue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int count,  num revenue)?  $default,) {final _that = this;
switch (_that) {
case _CountRevenue() when $default != null:
return $default(_that.count,_that.revenue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CountRevenue implements CountRevenue {
  const _CountRevenue({this.count = 0, this.revenue = 0});
  factory _CountRevenue.fromJson(Map<String, dynamic> json) => _$CountRevenueFromJson(json);

@override@JsonKey() final  int count;
@override@JsonKey() final  num revenue;

/// Create a copy of CountRevenue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CountRevenueCopyWith<_CountRevenue> get copyWith => __$CountRevenueCopyWithImpl<_CountRevenue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CountRevenueToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CountRevenue&&(identical(other.count, count) || other.count == count)&&(identical(other.revenue, revenue) || other.revenue == revenue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,count,revenue);

@override
String toString() {
  return 'CountRevenue(count: $count, revenue: $revenue)';
}


}

/// @nodoc
abstract mixin class _$CountRevenueCopyWith<$Res> implements $CountRevenueCopyWith<$Res> {
  factory _$CountRevenueCopyWith(_CountRevenue value, $Res Function(_CountRevenue) _then) = __$CountRevenueCopyWithImpl;
@override @useResult
$Res call({
 int count, num revenue
});




}
/// @nodoc
class __$CountRevenueCopyWithImpl<$Res>
    implements _$CountRevenueCopyWith<$Res> {
  __$CountRevenueCopyWithImpl(this._self, this._then);

  final _CountRevenue _self;
  final $Res Function(_CountRevenue) _then;

/// Create a copy of CountRevenue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? count = null,Object? revenue = null,}) {
  return _then(_CountRevenue(
count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$OsOperationalReport {

 List<OsReportRow> get rows; int get total; int get page;@JsonKey(name: 'pageSize') int get pageSize;@JsonKey(name: 'byStatus') Map<String, int> get byStatus;@JsonKey(name: 'byAssignedTo') Map<String, CountRevenue> get byAssignedTo;
/// Create a copy of OsOperationalReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OsOperationalReportCopyWith<OsOperationalReport> get copyWith => _$OsOperationalReportCopyWithImpl<OsOperationalReport>(this as OsOperationalReport, _$identity);

  /// Serializes this OsOperationalReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OsOperationalReport&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&const DeepCollectionEquality().equals(other.byStatus, byStatus)&&const DeepCollectionEquality().equals(other.byAssignedTo, byAssignedTo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),total,page,pageSize,const DeepCollectionEquality().hash(byStatus),const DeepCollectionEquality().hash(byAssignedTo));

@override
String toString() {
  return 'OsOperationalReport(rows: $rows, total: $total, page: $page, pageSize: $pageSize, byStatus: $byStatus, byAssignedTo: $byAssignedTo)';
}


}

/// @nodoc
abstract mixin class $OsOperationalReportCopyWith<$Res>  {
  factory $OsOperationalReportCopyWith(OsOperationalReport value, $Res Function(OsOperationalReport) _then) = _$OsOperationalReportCopyWithImpl;
@useResult
$Res call({
 List<OsReportRow> rows, int total, int page,@JsonKey(name: 'pageSize') int pageSize,@JsonKey(name: 'byStatus') Map<String, int> byStatus,@JsonKey(name: 'byAssignedTo') Map<String, CountRevenue> byAssignedTo
});




}
/// @nodoc
class _$OsOperationalReportCopyWithImpl<$Res>
    implements $OsOperationalReportCopyWith<$Res> {
  _$OsOperationalReportCopyWithImpl(this._self, this._then);

  final OsOperationalReport _self;
  final $Res Function(OsOperationalReport) _then;

/// Create a copy of OsOperationalReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? total = null,Object? page = null,Object? pageSize = null,Object? byStatus = null,Object? byAssignedTo = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<OsReportRow>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,byStatus: null == byStatus ? _self.byStatus : byStatus // ignore: cast_nullable_to_non_nullable
as Map<String, int>,byAssignedTo: null == byAssignedTo ? _self.byAssignedTo : byAssignedTo // ignore: cast_nullable_to_non_nullable
as Map<String, CountRevenue>,
  ));
}

}


/// Adds pattern-matching-related methods to [OsOperationalReport].
extension OsOperationalReportPatterns on OsOperationalReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OsOperationalReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OsOperationalReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OsOperationalReport value)  $default,){
final _that = this;
switch (_that) {
case _OsOperationalReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OsOperationalReport value)?  $default,){
final _that = this;
switch (_that) {
case _OsOperationalReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<OsReportRow> rows,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize, @JsonKey(name: 'byStatus')  Map<String, int> byStatus, @JsonKey(name: 'byAssignedTo')  Map<String, CountRevenue> byAssignedTo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OsOperationalReport() when $default != null:
return $default(_that.rows,_that.total,_that.page,_that.pageSize,_that.byStatus,_that.byAssignedTo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<OsReportRow> rows,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize, @JsonKey(name: 'byStatus')  Map<String, int> byStatus, @JsonKey(name: 'byAssignedTo')  Map<String, CountRevenue> byAssignedTo)  $default,) {final _that = this;
switch (_that) {
case _OsOperationalReport():
return $default(_that.rows,_that.total,_that.page,_that.pageSize,_that.byStatus,_that.byAssignedTo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<OsReportRow> rows,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize, @JsonKey(name: 'byStatus')  Map<String, int> byStatus, @JsonKey(name: 'byAssignedTo')  Map<String, CountRevenue> byAssignedTo)?  $default,) {final _that = this;
switch (_that) {
case _OsOperationalReport() when $default != null:
return $default(_that.rows,_that.total,_that.page,_that.pageSize,_that.byStatus,_that.byAssignedTo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OsOperationalReport implements OsOperationalReport {
  const _OsOperationalReport({final  List<OsReportRow> rows = const <OsReportRow>[], this.total = 0, this.page = 1, @JsonKey(name: 'pageSize') this.pageSize = 50, @JsonKey(name: 'byStatus') final  Map<String, int> byStatus = const <String, int>{}, @JsonKey(name: 'byAssignedTo') final  Map<String, CountRevenue> byAssignedTo = const <String, CountRevenue>{}}): _rows = rows,_byStatus = byStatus,_byAssignedTo = byAssignedTo;
  factory _OsOperationalReport.fromJson(Map<String, dynamic> json) => _$OsOperationalReportFromJson(json);

 final  List<OsReportRow> _rows;
@override@JsonKey() List<OsReportRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey(name: 'pageSize') final  int pageSize;
 final  Map<String, int> _byStatus;
@override@JsonKey(name: 'byStatus') Map<String, int> get byStatus {
  if (_byStatus is EqualUnmodifiableMapView) return _byStatus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_byStatus);
}

 final  Map<String, CountRevenue> _byAssignedTo;
@override@JsonKey(name: 'byAssignedTo') Map<String, CountRevenue> get byAssignedTo {
  if (_byAssignedTo is EqualUnmodifiableMapView) return _byAssignedTo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_byAssignedTo);
}


/// Create a copy of OsOperationalReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OsOperationalReportCopyWith<_OsOperationalReport> get copyWith => __$OsOperationalReportCopyWithImpl<_OsOperationalReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OsOperationalReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OsOperationalReport&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&const DeepCollectionEquality().equals(other._byStatus, _byStatus)&&const DeepCollectionEquality().equals(other._byAssignedTo, _byAssignedTo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),total,page,pageSize,const DeepCollectionEquality().hash(_byStatus),const DeepCollectionEquality().hash(_byAssignedTo));

@override
String toString() {
  return 'OsOperationalReport(rows: $rows, total: $total, page: $page, pageSize: $pageSize, byStatus: $byStatus, byAssignedTo: $byAssignedTo)';
}


}

/// @nodoc
abstract mixin class _$OsOperationalReportCopyWith<$Res> implements $OsOperationalReportCopyWith<$Res> {
  factory _$OsOperationalReportCopyWith(_OsOperationalReport value, $Res Function(_OsOperationalReport) _then) = __$OsOperationalReportCopyWithImpl;
@override @useResult
$Res call({
 List<OsReportRow> rows, int total, int page,@JsonKey(name: 'pageSize') int pageSize,@JsonKey(name: 'byStatus') Map<String, int> byStatus,@JsonKey(name: 'byAssignedTo') Map<String, CountRevenue> byAssignedTo
});




}
/// @nodoc
class __$OsOperationalReportCopyWithImpl<$Res>
    implements _$OsOperationalReportCopyWith<$Res> {
  __$OsOperationalReportCopyWithImpl(this._self, this._then);

  final _OsOperationalReport _self;
  final $Res Function(_OsOperationalReport) _then;

/// Create a copy of OsOperationalReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? total = null,Object? page = null,Object? pageSize = null,Object? byStatus = null,Object? byAssignedTo = null,}) {
  return _then(_OsOperationalReport(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<OsReportRow>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,byStatus: null == byStatus ? _self._byStatus : byStatus // ignore: cast_nullable_to_non_nullable
as Map<String, int>,byAssignedTo: null == byAssignedTo ? _self._byAssignedTo : byAssignedTo // ignore: cast_nullable_to_non_nullable
as Map<String, CountRevenue>,
  ));
}


}


/// @nodoc
mixin _$RevenueByDay {

 String get day; num get revenue; int get count;
/// Create a copy of RevenueByDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RevenueByDayCopyWith<RevenueByDay> get copyWith => _$RevenueByDayCopyWithImpl<RevenueByDay>(this as RevenueByDay, _$identity);

  /// Serializes this RevenueByDay to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RevenueByDay&&(identical(other.day, day) || other.day == day)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,revenue,count);

@override
String toString() {
  return 'RevenueByDay(day: $day, revenue: $revenue, count: $count)';
}


}

/// @nodoc
abstract mixin class $RevenueByDayCopyWith<$Res>  {
  factory $RevenueByDayCopyWith(RevenueByDay value, $Res Function(RevenueByDay) _then) = _$RevenueByDayCopyWithImpl;
@useResult
$Res call({
 String day, num revenue, int count
});




}
/// @nodoc
class _$RevenueByDayCopyWithImpl<$Res>
    implements $RevenueByDayCopyWith<$Res> {
  _$RevenueByDayCopyWithImpl(this._self, this._then);

  final RevenueByDay _self;
  final $Res Function(RevenueByDay) _then;

/// Create a copy of RevenueByDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? revenue = null,Object? count = null,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RevenueByDay].
extension RevenueByDayPatterns on RevenueByDay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RevenueByDay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RevenueByDay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RevenueByDay value)  $default,){
final _that = this;
switch (_that) {
case _RevenueByDay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RevenueByDay value)?  $default,){
final _that = this;
switch (_that) {
case _RevenueByDay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String day,  num revenue,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RevenueByDay() when $default != null:
return $default(_that.day,_that.revenue,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String day,  num revenue,  int count)  $default,) {final _that = this;
switch (_that) {
case _RevenueByDay():
return $default(_that.day,_that.revenue,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String day,  num revenue,  int count)?  $default,) {final _that = this;
switch (_that) {
case _RevenueByDay() when $default != null:
return $default(_that.day,_that.revenue,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RevenueByDay implements RevenueByDay {
  const _RevenueByDay({this.day = '', this.revenue = 0, this.count = 0});
  factory _RevenueByDay.fromJson(Map<String, dynamic> json) => _$RevenueByDayFromJson(json);

@override@JsonKey() final  String day;
@override@JsonKey() final  num revenue;
@override@JsonKey() final  int count;

/// Create a copy of RevenueByDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RevenueByDayCopyWith<_RevenueByDay> get copyWith => __$RevenueByDayCopyWithImpl<_RevenueByDay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RevenueByDayToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RevenueByDay&&(identical(other.day, day) || other.day == day)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,revenue,count);

@override
String toString() {
  return 'RevenueByDay(day: $day, revenue: $revenue, count: $count)';
}


}

/// @nodoc
abstract mixin class _$RevenueByDayCopyWith<$Res> implements $RevenueByDayCopyWith<$Res> {
  factory _$RevenueByDayCopyWith(_RevenueByDay value, $Res Function(_RevenueByDay) _then) = __$RevenueByDayCopyWithImpl;
@override @useResult
$Res call({
 String day, num revenue, int count
});




}
/// @nodoc
class __$RevenueByDayCopyWithImpl<$Res>
    implements _$RevenueByDayCopyWith<$Res> {
  __$RevenueByDayCopyWithImpl(this._self, this._then);

  final _RevenueByDay _self;
  final $Res Function(_RevenueByDay) _then;

/// Create a copy of RevenueByDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? revenue = null,Object? count = null,}) {
  return _then(_RevenueByDay(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$RevenueReport {

 num get total;@JsonKey(name: 'avgTicket') num get avgTicket;@JsonKey(name: 'byDay') List<RevenueByDay> get byDay;@JsonKey(name: 'byStatus') Map<String, CountRevenue> get byStatus;
/// Create a copy of RevenueReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RevenueReportCopyWith<RevenueReport> get copyWith => _$RevenueReportCopyWithImpl<RevenueReport>(this as RevenueReport, _$identity);

  /// Serializes this RevenueReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RevenueReport&&(identical(other.total, total) || other.total == total)&&(identical(other.avgTicket, avgTicket) || other.avgTicket == avgTicket)&&const DeepCollectionEquality().equals(other.byDay, byDay)&&const DeepCollectionEquality().equals(other.byStatus, byStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,avgTicket,const DeepCollectionEquality().hash(byDay),const DeepCollectionEquality().hash(byStatus));

@override
String toString() {
  return 'RevenueReport(total: $total, avgTicket: $avgTicket, byDay: $byDay, byStatus: $byStatus)';
}


}

/// @nodoc
abstract mixin class $RevenueReportCopyWith<$Res>  {
  factory $RevenueReportCopyWith(RevenueReport value, $Res Function(RevenueReport) _then) = _$RevenueReportCopyWithImpl;
@useResult
$Res call({
 num total,@JsonKey(name: 'avgTicket') num avgTicket,@JsonKey(name: 'byDay') List<RevenueByDay> byDay,@JsonKey(name: 'byStatus') Map<String, CountRevenue> byStatus
});




}
/// @nodoc
class _$RevenueReportCopyWithImpl<$Res>
    implements $RevenueReportCopyWith<$Res> {
  _$RevenueReportCopyWithImpl(this._self, this._then);

  final RevenueReport _self;
  final $Res Function(RevenueReport) _then;

/// Create a copy of RevenueReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? avgTicket = null,Object? byDay = null,Object? byStatus = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,avgTicket: null == avgTicket ? _self.avgTicket : avgTicket // ignore: cast_nullable_to_non_nullable
as num,byDay: null == byDay ? _self.byDay : byDay // ignore: cast_nullable_to_non_nullable
as List<RevenueByDay>,byStatus: null == byStatus ? _self.byStatus : byStatus // ignore: cast_nullable_to_non_nullable
as Map<String, CountRevenue>,
  ));
}

}


/// Adds pattern-matching-related methods to [RevenueReport].
extension RevenueReportPatterns on RevenueReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RevenueReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RevenueReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RevenueReport value)  $default,){
final _that = this;
switch (_that) {
case _RevenueReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RevenueReport value)?  $default,){
final _that = this;
switch (_that) {
case _RevenueReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( num total, @JsonKey(name: 'avgTicket')  num avgTicket, @JsonKey(name: 'byDay')  List<RevenueByDay> byDay, @JsonKey(name: 'byStatus')  Map<String, CountRevenue> byStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RevenueReport() when $default != null:
return $default(_that.total,_that.avgTicket,_that.byDay,_that.byStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( num total, @JsonKey(name: 'avgTicket')  num avgTicket, @JsonKey(name: 'byDay')  List<RevenueByDay> byDay, @JsonKey(name: 'byStatus')  Map<String, CountRevenue> byStatus)  $default,) {final _that = this;
switch (_that) {
case _RevenueReport():
return $default(_that.total,_that.avgTicket,_that.byDay,_that.byStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( num total, @JsonKey(name: 'avgTicket')  num avgTicket, @JsonKey(name: 'byDay')  List<RevenueByDay> byDay, @JsonKey(name: 'byStatus')  Map<String, CountRevenue> byStatus)?  $default,) {final _that = this;
switch (_that) {
case _RevenueReport() when $default != null:
return $default(_that.total,_that.avgTicket,_that.byDay,_that.byStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RevenueReport implements RevenueReport {
  const _RevenueReport({this.total = 0, @JsonKey(name: 'avgTicket') this.avgTicket = 0, @JsonKey(name: 'byDay') final  List<RevenueByDay> byDay = const <RevenueByDay>[], @JsonKey(name: 'byStatus') final  Map<String, CountRevenue> byStatus = const <String, CountRevenue>{}}): _byDay = byDay,_byStatus = byStatus;
  factory _RevenueReport.fromJson(Map<String, dynamic> json) => _$RevenueReportFromJson(json);

@override@JsonKey() final  num total;
@override@JsonKey(name: 'avgTicket') final  num avgTicket;
 final  List<RevenueByDay> _byDay;
@override@JsonKey(name: 'byDay') List<RevenueByDay> get byDay {
  if (_byDay is EqualUnmodifiableListView) return _byDay;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_byDay);
}

 final  Map<String, CountRevenue> _byStatus;
@override@JsonKey(name: 'byStatus') Map<String, CountRevenue> get byStatus {
  if (_byStatus is EqualUnmodifiableMapView) return _byStatus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_byStatus);
}


/// Create a copy of RevenueReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RevenueReportCopyWith<_RevenueReport> get copyWith => __$RevenueReportCopyWithImpl<_RevenueReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RevenueReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RevenueReport&&(identical(other.total, total) || other.total == total)&&(identical(other.avgTicket, avgTicket) || other.avgTicket == avgTicket)&&const DeepCollectionEquality().equals(other._byDay, _byDay)&&const DeepCollectionEquality().equals(other._byStatus, _byStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,avgTicket,const DeepCollectionEquality().hash(_byDay),const DeepCollectionEquality().hash(_byStatus));

@override
String toString() {
  return 'RevenueReport(total: $total, avgTicket: $avgTicket, byDay: $byDay, byStatus: $byStatus)';
}


}

/// @nodoc
abstract mixin class _$RevenueReportCopyWith<$Res> implements $RevenueReportCopyWith<$Res> {
  factory _$RevenueReportCopyWith(_RevenueReport value, $Res Function(_RevenueReport) _then) = __$RevenueReportCopyWithImpl;
@override @useResult
$Res call({
 num total,@JsonKey(name: 'avgTicket') num avgTicket,@JsonKey(name: 'byDay') List<RevenueByDay> byDay,@JsonKey(name: 'byStatus') Map<String, CountRevenue> byStatus
});




}
/// @nodoc
class __$RevenueReportCopyWithImpl<$Res>
    implements _$RevenueReportCopyWith<$Res> {
  __$RevenueReportCopyWithImpl(this._self, this._then);

  final _RevenueReport _self;
  final $Res Function(_RevenueReport) _then;

/// Create a copy of RevenueReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? avgTicket = null,Object? byDay = null,Object? byStatus = null,}) {
  return _then(_RevenueReport(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,avgTicket: null == avgTicket ? _self.avgTicket : avgTicket // ignore: cast_nullable_to_non_nullable
as num,byDay: null == byDay ? _self._byDay : byDay // ignore: cast_nullable_to_non_nullable
as List<RevenueByDay>,byStatus: null == byStatus ? _self._byStatus : byStatus // ignore: cast_nullable_to_non_nullable
as Map<String, CountRevenue>,
  ));
}


}


/// @nodoc
mixin _$TeamReportRow {

@JsonKey(name: 'assignedTo') String? get assignedTo; int get orders; int get completed; num get revenue;@JsonKey(name: 'avgTicket') num get avgTicket;@JsonKey(name: 'avgCycleMs') num? get avgCycleMs;
/// Create a copy of TeamReportRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamReportRowCopyWith<TeamReportRow> get copyWith => _$TeamReportRowCopyWithImpl<TeamReportRow>(this as TeamReportRow, _$identity);

  /// Serializes this TeamReportRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamReportRow&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.orders, orders) || other.orders == orders)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.avgTicket, avgTicket) || other.avgTicket == avgTicket)&&(identical(other.avgCycleMs, avgCycleMs) || other.avgCycleMs == avgCycleMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,assignedTo,orders,completed,revenue,avgTicket,avgCycleMs);

@override
String toString() {
  return 'TeamReportRow(assignedTo: $assignedTo, orders: $orders, completed: $completed, revenue: $revenue, avgTicket: $avgTicket, avgCycleMs: $avgCycleMs)';
}


}

/// @nodoc
abstract mixin class $TeamReportRowCopyWith<$Res>  {
  factory $TeamReportRowCopyWith(TeamReportRow value, $Res Function(TeamReportRow) _then) = _$TeamReportRowCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'assignedTo') String? assignedTo, int orders, int completed, num revenue,@JsonKey(name: 'avgTicket') num avgTicket,@JsonKey(name: 'avgCycleMs') num? avgCycleMs
});




}
/// @nodoc
class _$TeamReportRowCopyWithImpl<$Res>
    implements $TeamReportRowCopyWith<$Res> {
  _$TeamReportRowCopyWithImpl(this._self, this._then);

  final TeamReportRow _self;
  final $Res Function(TeamReportRow) _then;

/// Create a copy of TeamReportRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assignedTo = freezed,Object? orders = null,Object? completed = null,Object? revenue = null,Object? avgTicket = null,Object? avgCycleMs = freezed,}) {
  return _then(_self.copyWith(
assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,avgTicket: null == avgTicket ? _self.avgTicket : avgTicket // ignore: cast_nullable_to_non_nullable
as num,avgCycleMs: freezed == avgCycleMs ? _self.avgCycleMs : avgCycleMs // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}

}


/// Adds pattern-matching-related methods to [TeamReportRow].
extension TeamReportRowPatterns on TeamReportRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamReportRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamReportRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamReportRow value)  $default,){
final _that = this;
switch (_that) {
case _TeamReportRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamReportRow value)?  $default,){
final _that = this;
switch (_that) {
case _TeamReportRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'assignedTo')  String? assignedTo,  int orders,  int completed,  num revenue, @JsonKey(name: 'avgTicket')  num avgTicket, @JsonKey(name: 'avgCycleMs')  num? avgCycleMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamReportRow() when $default != null:
return $default(_that.assignedTo,_that.orders,_that.completed,_that.revenue,_that.avgTicket,_that.avgCycleMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'assignedTo')  String? assignedTo,  int orders,  int completed,  num revenue, @JsonKey(name: 'avgTicket')  num avgTicket, @JsonKey(name: 'avgCycleMs')  num? avgCycleMs)  $default,) {final _that = this;
switch (_that) {
case _TeamReportRow():
return $default(_that.assignedTo,_that.orders,_that.completed,_that.revenue,_that.avgTicket,_that.avgCycleMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'assignedTo')  String? assignedTo,  int orders,  int completed,  num revenue, @JsonKey(name: 'avgTicket')  num avgTicket, @JsonKey(name: 'avgCycleMs')  num? avgCycleMs)?  $default,) {final _that = this;
switch (_that) {
case _TeamReportRow() when $default != null:
return $default(_that.assignedTo,_that.orders,_that.completed,_that.revenue,_that.avgTicket,_that.avgCycleMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamReportRow implements TeamReportRow {
  const _TeamReportRow({@JsonKey(name: 'assignedTo') this.assignedTo, this.orders = 0, this.completed = 0, this.revenue = 0, @JsonKey(name: 'avgTicket') this.avgTicket = 0, @JsonKey(name: 'avgCycleMs') this.avgCycleMs});
  factory _TeamReportRow.fromJson(Map<String, dynamic> json) => _$TeamReportRowFromJson(json);

@override@JsonKey(name: 'assignedTo') final  String? assignedTo;
@override@JsonKey() final  int orders;
@override@JsonKey() final  int completed;
@override@JsonKey() final  num revenue;
@override@JsonKey(name: 'avgTicket') final  num avgTicket;
@override@JsonKey(name: 'avgCycleMs') final  num? avgCycleMs;

/// Create a copy of TeamReportRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamReportRowCopyWith<_TeamReportRow> get copyWith => __$TeamReportRowCopyWithImpl<_TeamReportRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamReportRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamReportRow&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.orders, orders) || other.orders == orders)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.avgTicket, avgTicket) || other.avgTicket == avgTicket)&&(identical(other.avgCycleMs, avgCycleMs) || other.avgCycleMs == avgCycleMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,assignedTo,orders,completed,revenue,avgTicket,avgCycleMs);

@override
String toString() {
  return 'TeamReportRow(assignedTo: $assignedTo, orders: $orders, completed: $completed, revenue: $revenue, avgTicket: $avgTicket, avgCycleMs: $avgCycleMs)';
}


}

/// @nodoc
abstract mixin class _$TeamReportRowCopyWith<$Res> implements $TeamReportRowCopyWith<$Res> {
  factory _$TeamReportRowCopyWith(_TeamReportRow value, $Res Function(_TeamReportRow) _then) = __$TeamReportRowCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'assignedTo') String? assignedTo, int orders, int completed, num revenue,@JsonKey(name: 'avgTicket') num avgTicket,@JsonKey(name: 'avgCycleMs') num? avgCycleMs
});




}
/// @nodoc
class __$TeamReportRowCopyWithImpl<$Res>
    implements _$TeamReportRowCopyWith<$Res> {
  __$TeamReportRowCopyWithImpl(this._self, this._then);

  final _TeamReportRow _self;
  final $Res Function(_TeamReportRow) _then;

/// Create a copy of TeamReportRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assignedTo = freezed,Object? orders = null,Object? completed = null,Object? revenue = null,Object? avgTicket = null,Object? avgCycleMs = freezed,}) {
  return _then(_TeamReportRow(
assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as int,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,avgTicket: null == avgTicket ? _self.avgTicket : avgTicket // ignore: cast_nullable_to_non_nullable
as num,avgCycleMs: freezed == avgCycleMs ? _self.avgCycleMs : avgCycleMs // ignore: cast_nullable_to_non_nullable
as num?,
  ));
}


}


/// @nodoc
mixin _$TeamReport {

 List<TeamReportRow> get rows;
/// Create a copy of TeamReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamReportCopyWith<TeamReport> get copyWith => _$TeamReportCopyWithImpl<TeamReport>(this as TeamReport, _$identity);

  /// Serializes this TeamReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamReport&&const DeepCollectionEquality().equals(other.rows, rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows));

@override
String toString() {
  return 'TeamReport(rows: $rows)';
}


}

/// @nodoc
abstract mixin class $TeamReportCopyWith<$Res>  {
  factory $TeamReportCopyWith(TeamReport value, $Res Function(TeamReport) _then) = _$TeamReportCopyWithImpl;
@useResult
$Res call({
 List<TeamReportRow> rows
});




}
/// @nodoc
class _$TeamReportCopyWithImpl<$Res>
    implements $TeamReportCopyWith<$Res> {
  _$TeamReportCopyWithImpl(this._self, this._then);

  final TeamReport _self;
  final $Res Function(TeamReport) _then;

/// Create a copy of TeamReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<TeamReportRow>,
  ));
}

}


/// Adds pattern-matching-related methods to [TeamReport].
extension TeamReportPatterns on TeamReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamReport value)  $default,){
final _that = this;
switch (_that) {
case _TeamReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamReport value)?  $default,){
final _that = this;
switch (_that) {
case _TeamReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TeamReportRow> rows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamReport() when $default != null:
return $default(_that.rows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TeamReportRow> rows)  $default,) {final _that = this;
switch (_that) {
case _TeamReport():
return $default(_that.rows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TeamReportRow> rows)?  $default,) {final _that = this;
switch (_that) {
case _TeamReport() when $default != null:
return $default(_that.rows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamReport implements TeamReport {
  const _TeamReport({final  List<TeamReportRow> rows = const <TeamReportRow>[]}): _rows = rows;
  factory _TeamReport.fromJson(Map<String, dynamic> json) => _$TeamReportFromJson(json);

 final  List<TeamReportRow> _rows;
@override@JsonKey() List<TeamReportRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}


/// Create a copy of TeamReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamReportCopyWith<_TeamReport> get copyWith => __$TeamReportCopyWithImpl<_TeamReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamReport&&const DeepCollectionEquality().equals(other._rows, _rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows));

@override
String toString() {
  return 'TeamReport(rows: $rows)';
}


}

/// @nodoc
abstract mixin class _$TeamReportCopyWith<$Res> implements $TeamReportCopyWith<$Res> {
  factory _$TeamReportCopyWith(_TeamReport value, $Res Function(_TeamReport) _then) = __$TeamReportCopyWithImpl;
@override @useResult
$Res call({
 List<TeamReportRow> rows
});




}
/// @nodoc
class __$TeamReportCopyWithImpl<$Res>
    implements _$TeamReportCopyWith<$Res> {
  __$TeamReportCopyWithImpl(this._self, this._then);

  final _TeamReport _self;
  final $Res Function(_TeamReport) _then;

/// Create a copy of TeamReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,}) {
  return _then(_TeamReport(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<TeamReportRow>,
  ));
}


}


/// @nodoc
mixin _$TopItemRow {

 String get name; String get kind;@JsonKey(name: 'inventoryItemId') String? get inventoryItemId; num get qty; num get revenue; int get orders;
/// Create a copy of TopItemRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopItemRowCopyWith<TopItemRow> get copyWith => _$TopItemRowCopyWithImpl<TopItemRow>(this as TopItemRow, _$identity);

  /// Serializes this TopItemRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopItemRow&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.qty, qty) || other.qty == qty)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.orders, orders) || other.orders == orders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,kind,inventoryItemId,qty,revenue,orders);

@override
String toString() {
  return 'TopItemRow(name: $name, kind: $kind, inventoryItemId: $inventoryItemId, qty: $qty, revenue: $revenue, orders: $orders)';
}


}

/// @nodoc
abstract mixin class $TopItemRowCopyWith<$Res>  {
  factory $TopItemRowCopyWith(TopItemRow value, $Res Function(TopItemRow) _then) = _$TopItemRowCopyWithImpl;
@useResult
$Res call({
 String name, String kind,@JsonKey(name: 'inventoryItemId') String? inventoryItemId, num qty, num revenue, int orders
});




}
/// @nodoc
class _$TopItemRowCopyWithImpl<$Res>
    implements $TopItemRowCopyWith<$Res> {
  _$TopItemRowCopyWithImpl(this._self, this._then);

  final TopItemRow _self;
  final $Res Function(TopItemRow) _then;

/// Create a copy of TopItemRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? kind = null,Object? inventoryItemId = freezed,Object? qty = null,Object? revenue = null,Object? orders = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as num,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TopItemRow].
extension TopItemRowPatterns on TopItemRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopItemRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopItemRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopItemRow value)  $default,){
final _that = this;
switch (_that) {
case _TopItemRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopItemRow value)?  $default,){
final _that = this;
switch (_that) {
case _TopItemRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String kind, @JsonKey(name: 'inventoryItemId')  String? inventoryItemId,  num qty,  num revenue,  int orders)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopItemRow() when $default != null:
return $default(_that.name,_that.kind,_that.inventoryItemId,_that.qty,_that.revenue,_that.orders);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String kind, @JsonKey(name: 'inventoryItemId')  String? inventoryItemId,  num qty,  num revenue,  int orders)  $default,) {final _that = this;
switch (_that) {
case _TopItemRow():
return $default(_that.name,_that.kind,_that.inventoryItemId,_that.qty,_that.revenue,_that.orders);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String kind, @JsonKey(name: 'inventoryItemId')  String? inventoryItemId,  num qty,  num revenue,  int orders)?  $default,) {final _that = this;
switch (_that) {
case _TopItemRow() when $default != null:
return $default(_that.name,_that.kind,_that.inventoryItemId,_that.qty,_that.revenue,_that.orders);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopItemRow implements TopItemRow {
  const _TopItemRow({this.name = '', this.kind = '', @JsonKey(name: 'inventoryItemId') this.inventoryItemId, this.qty = 0, this.revenue = 0, this.orders = 0});
  factory _TopItemRow.fromJson(Map<String, dynamic> json) => _$TopItemRowFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String kind;
@override@JsonKey(name: 'inventoryItemId') final  String? inventoryItemId;
@override@JsonKey() final  num qty;
@override@JsonKey() final  num revenue;
@override@JsonKey() final  int orders;

/// Create a copy of TopItemRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopItemRowCopyWith<_TopItemRow> get copyWith => __$TopItemRowCopyWithImpl<_TopItemRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopItemRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopItemRow&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.inventoryItemId, inventoryItemId) || other.inventoryItemId == inventoryItemId)&&(identical(other.qty, qty) || other.qty == qty)&&(identical(other.revenue, revenue) || other.revenue == revenue)&&(identical(other.orders, orders) || other.orders == orders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,kind,inventoryItemId,qty,revenue,orders);

@override
String toString() {
  return 'TopItemRow(name: $name, kind: $kind, inventoryItemId: $inventoryItemId, qty: $qty, revenue: $revenue, orders: $orders)';
}


}

/// @nodoc
abstract mixin class _$TopItemRowCopyWith<$Res> implements $TopItemRowCopyWith<$Res> {
  factory _$TopItemRowCopyWith(_TopItemRow value, $Res Function(_TopItemRow) _then) = __$TopItemRowCopyWithImpl;
@override @useResult
$Res call({
 String name, String kind,@JsonKey(name: 'inventoryItemId') String? inventoryItemId, num qty, num revenue, int orders
});




}
/// @nodoc
class __$TopItemRowCopyWithImpl<$Res>
    implements _$TopItemRowCopyWith<$Res> {
  __$TopItemRowCopyWithImpl(this._self, this._then);

  final _TopItemRow _self;
  final $Res Function(_TopItemRow) _then;

/// Create a copy of TopItemRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? kind = null,Object? inventoryItemId = freezed,Object? qty = null,Object? revenue = null,Object? orders = null,}) {
  return _then(_TopItemRow(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,inventoryItemId: freezed == inventoryItemId ? _self.inventoryItemId : inventoryItemId // ignore: cast_nullable_to_non_nullable
as String?,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as num,revenue: null == revenue ? _self.revenue : revenue // ignore: cast_nullable_to_non_nullable
as num,orders: null == orders ? _self.orders : orders // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TopItemsReport {

 String? get kind; List<TopItemRow> get rows;
/// Create a copy of TopItemsReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopItemsReportCopyWith<TopItemsReport> get copyWith => _$TopItemsReportCopyWithImpl<TopItemsReport>(this as TopItemsReport, _$identity);

  /// Serializes this TopItemsReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopItemsReport&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.rows, rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(rows));

@override
String toString() {
  return 'TopItemsReport(kind: $kind, rows: $rows)';
}


}

/// @nodoc
abstract mixin class $TopItemsReportCopyWith<$Res>  {
  factory $TopItemsReportCopyWith(TopItemsReport value, $Res Function(TopItemsReport) _then) = _$TopItemsReportCopyWithImpl;
@useResult
$Res call({
 String? kind, List<TopItemRow> rows
});




}
/// @nodoc
class _$TopItemsReportCopyWithImpl<$Res>
    implements $TopItemsReportCopyWith<$Res> {
  _$TopItemsReportCopyWithImpl(this._self, this._then);

  final TopItemsReport _self;
  final $Res Function(TopItemsReport) _then;

/// Create a copy of TopItemsReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = freezed,Object? rows = null,}) {
  return _then(_self.copyWith(
kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<TopItemRow>,
  ));
}

}


/// Adds pattern-matching-related methods to [TopItemsReport].
extension TopItemsReportPatterns on TopItemsReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopItemsReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopItemsReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopItemsReport value)  $default,){
final _that = this;
switch (_that) {
case _TopItemsReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopItemsReport value)?  $default,){
final _that = this;
switch (_that) {
case _TopItemsReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? kind,  List<TopItemRow> rows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopItemsReport() when $default != null:
return $default(_that.kind,_that.rows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? kind,  List<TopItemRow> rows)  $default,) {final _that = this;
switch (_that) {
case _TopItemsReport():
return $default(_that.kind,_that.rows);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? kind,  List<TopItemRow> rows)?  $default,) {final _that = this;
switch (_that) {
case _TopItemsReport() when $default != null:
return $default(_that.kind,_that.rows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopItemsReport implements TopItemsReport {
  const _TopItemsReport({this.kind, final  List<TopItemRow> rows = const <TopItemRow>[]}): _rows = rows;
  factory _TopItemsReport.fromJson(Map<String, dynamic> json) => _$TopItemsReportFromJson(json);

@override final  String? kind;
 final  List<TopItemRow> _rows;
@override@JsonKey() List<TopItemRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}


/// Create a copy of TopItemsReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopItemsReportCopyWith<_TopItemsReport> get copyWith => __$TopItemsReportCopyWithImpl<_TopItemsReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopItemsReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopItemsReport&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other._rows, _rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(_rows));

@override
String toString() {
  return 'TopItemsReport(kind: $kind, rows: $rows)';
}


}

/// @nodoc
abstract mixin class _$TopItemsReportCopyWith<$Res> implements $TopItemsReportCopyWith<$Res> {
  factory _$TopItemsReportCopyWith(_TopItemsReport value, $Res Function(_TopItemsReport) _then) = __$TopItemsReportCopyWithImpl;
@override @useResult
$Res call({
 String? kind, List<TopItemRow> rows
});




}
/// @nodoc
class __$TopItemsReportCopyWithImpl<$Res>
    implements _$TopItemsReportCopyWith<$Res> {
  __$TopItemsReportCopyWithImpl(this._self, this._then);

  final _TopItemsReport _self;
  final $Res Function(_TopItemsReport) _then;

/// Create a copy of TopItemsReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = freezed,Object? rows = null,}) {
  return _then(_TopItemsReport(
kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<TopItemRow>,
  ));
}


}


/// @nodoc
mixin _$InventoryReportRow {

 String get name; String? get sku;@JsonKey(name: 'current_stock') num get currentStock;@JsonKey(name: 'min_stock') num? get minStock;@JsonKey(name: 'cost_price') num? get costPrice;@JsonKey(name: 'sale_price') num? get salePrice;@JsonKey(name: 'stockValue') num get stockValue;@JsonKey(name: 'belowMin') bool get belowMin;
/// Create a copy of InventoryReportRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryReportRowCopyWith<InventoryReportRow> get copyWith => _$InventoryReportRowCopyWithImpl<InventoryReportRow>(this as InventoryReportRow, _$identity);

  /// Serializes this InventoryReportRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryReportRow&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock)&&(identical(other.minStock, minStock) || other.minStock == minStock)&&(identical(other.costPrice, costPrice) || other.costPrice == costPrice)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.stockValue, stockValue) || other.stockValue == stockValue)&&(identical(other.belowMin, belowMin) || other.belowMin == belowMin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,sku,currentStock,minStock,costPrice,salePrice,stockValue,belowMin);

@override
String toString() {
  return 'InventoryReportRow(name: $name, sku: $sku, currentStock: $currentStock, minStock: $minStock, costPrice: $costPrice, salePrice: $salePrice, stockValue: $stockValue, belowMin: $belowMin)';
}


}

/// @nodoc
abstract mixin class $InventoryReportRowCopyWith<$Res>  {
  factory $InventoryReportRowCopyWith(InventoryReportRow value, $Res Function(InventoryReportRow) _then) = _$InventoryReportRowCopyWithImpl;
@useResult
$Res call({
 String name, String? sku,@JsonKey(name: 'current_stock') num currentStock,@JsonKey(name: 'min_stock') num? minStock,@JsonKey(name: 'cost_price') num? costPrice,@JsonKey(name: 'sale_price') num? salePrice,@JsonKey(name: 'stockValue') num stockValue,@JsonKey(name: 'belowMin') bool belowMin
});




}
/// @nodoc
class _$InventoryReportRowCopyWithImpl<$Res>
    implements $InventoryReportRowCopyWith<$Res> {
  _$InventoryReportRowCopyWithImpl(this._self, this._then);

  final InventoryReportRow _self;
  final $Res Function(InventoryReportRow) _then;

/// Create a copy of InventoryReportRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? sku = freezed,Object? currentStock = null,Object? minStock = freezed,Object? costPrice = freezed,Object? salePrice = freezed,Object? stockValue = null,Object? belowMin = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,currentStock: null == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as num,minStock: freezed == minStock ? _self.minStock : minStock // ignore: cast_nullable_to_non_nullable
as num?,costPrice: freezed == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as num?,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as num?,stockValue: null == stockValue ? _self.stockValue : stockValue // ignore: cast_nullable_to_non_nullable
as num,belowMin: null == belowMin ? _self.belowMin : belowMin // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryReportRow].
extension InventoryReportRowPatterns on InventoryReportRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryReportRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryReportRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryReportRow value)  $default,){
final _that = this;
switch (_that) {
case _InventoryReportRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryReportRow value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryReportRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? sku, @JsonKey(name: 'current_stock')  num currentStock, @JsonKey(name: 'min_stock')  num? minStock, @JsonKey(name: 'cost_price')  num? costPrice, @JsonKey(name: 'sale_price')  num? salePrice, @JsonKey(name: 'stockValue')  num stockValue, @JsonKey(name: 'belowMin')  bool belowMin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryReportRow() when $default != null:
return $default(_that.name,_that.sku,_that.currentStock,_that.minStock,_that.costPrice,_that.salePrice,_that.stockValue,_that.belowMin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? sku, @JsonKey(name: 'current_stock')  num currentStock, @JsonKey(name: 'min_stock')  num? minStock, @JsonKey(name: 'cost_price')  num? costPrice, @JsonKey(name: 'sale_price')  num? salePrice, @JsonKey(name: 'stockValue')  num stockValue, @JsonKey(name: 'belowMin')  bool belowMin)  $default,) {final _that = this;
switch (_that) {
case _InventoryReportRow():
return $default(_that.name,_that.sku,_that.currentStock,_that.minStock,_that.costPrice,_that.salePrice,_that.stockValue,_that.belowMin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? sku, @JsonKey(name: 'current_stock')  num currentStock, @JsonKey(name: 'min_stock')  num? minStock, @JsonKey(name: 'cost_price')  num? costPrice, @JsonKey(name: 'sale_price')  num? salePrice, @JsonKey(name: 'stockValue')  num stockValue, @JsonKey(name: 'belowMin')  bool belowMin)?  $default,) {final _that = this;
switch (_that) {
case _InventoryReportRow() when $default != null:
return $default(_that.name,_that.sku,_that.currentStock,_that.minStock,_that.costPrice,_that.salePrice,_that.stockValue,_that.belowMin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryReportRow implements InventoryReportRow {
  const _InventoryReportRow({this.name = '', this.sku, @JsonKey(name: 'current_stock') this.currentStock = 0, @JsonKey(name: 'min_stock') this.minStock, @JsonKey(name: 'cost_price') this.costPrice, @JsonKey(name: 'sale_price') this.salePrice, @JsonKey(name: 'stockValue') this.stockValue = 0, @JsonKey(name: 'belowMin') this.belowMin = false});
  factory _InventoryReportRow.fromJson(Map<String, dynamic> json) => _$InventoryReportRowFromJson(json);

@override@JsonKey() final  String name;
@override final  String? sku;
@override@JsonKey(name: 'current_stock') final  num currentStock;
@override@JsonKey(name: 'min_stock') final  num? minStock;
@override@JsonKey(name: 'cost_price') final  num? costPrice;
@override@JsonKey(name: 'sale_price') final  num? salePrice;
@override@JsonKey(name: 'stockValue') final  num stockValue;
@override@JsonKey(name: 'belowMin') final  bool belowMin;

/// Create a copy of InventoryReportRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryReportRowCopyWith<_InventoryReportRow> get copyWith => __$InventoryReportRowCopyWithImpl<_InventoryReportRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryReportRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryReportRow&&(identical(other.name, name) || other.name == name)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.currentStock, currentStock) || other.currentStock == currentStock)&&(identical(other.minStock, minStock) || other.minStock == minStock)&&(identical(other.costPrice, costPrice) || other.costPrice == costPrice)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.stockValue, stockValue) || other.stockValue == stockValue)&&(identical(other.belowMin, belowMin) || other.belowMin == belowMin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,sku,currentStock,minStock,costPrice,salePrice,stockValue,belowMin);

@override
String toString() {
  return 'InventoryReportRow(name: $name, sku: $sku, currentStock: $currentStock, minStock: $minStock, costPrice: $costPrice, salePrice: $salePrice, stockValue: $stockValue, belowMin: $belowMin)';
}


}

/// @nodoc
abstract mixin class _$InventoryReportRowCopyWith<$Res> implements $InventoryReportRowCopyWith<$Res> {
  factory _$InventoryReportRowCopyWith(_InventoryReportRow value, $Res Function(_InventoryReportRow) _then) = __$InventoryReportRowCopyWithImpl;
@override @useResult
$Res call({
 String name, String? sku,@JsonKey(name: 'current_stock') num currentStock,@JsonKey(name: 'min_stock') num? minStock,@JsonKey(name: 'cost_price') num? costPrice,@JsonKey(name: 'sale_price') num? salePrice,@JsonKey(name: 'stockValue') num stockValue,@JsonKey(name: 'belowMin') bool belowMin
});




}
/// @nodoc
class __$InventoryReportRowCopyWithImpl<$Res>
    implements _$InventoryReportRowCopyWith<$Res> {
  __$InventoryReportRowCopyWithImpl(this._self, this._then);

  final _InventoryReportRow _self;
  final $Res Function(_InventoryReportRow) _then;

/// Create a copy of InventoryReportRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? sku = freezed,Object? currentStock = null,Object? minStock = freezed,Object? costPrice = freezed,Object? salePrice = freezed,Object? stockValue = null,Object? belowMin = null,}) {
  return _then(_InventoryReportRow(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,currentStock: null == currentStock ? _self.currentStock : currentStock // ignore: cast_nullable_to_non_nullable
as num,minStock: freezed == minStock ? _self.minStock : minStock // ignore: cast_nullable_to_non_nullable
as num?,costPrice: freezed == costPrice ? _self.costPrice : costPrice // ignore: cast_nullable_to_non_nullable
as num?,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as num?,stockValue: null == stockValue ? _self.stockValue : stockValue // ignore: cast_nullable_to_non_nullable
as num,belowMin: null == belowMin ? _self.belowMin : belowMin // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$InventoryReport {

 List<InventoryReportRow> get rows;@JsonKey(name: 'stockValue') num get stockValue; int get total; int get page;@JsonKey(name: 'pageSize') int get pageSize;
/// Create a copy of InventoryReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InventoryReportCopyWith<InventoryReport> get copyWith => _$InventoryReportCopyWithImpl<InventoryReport>(this as InventoryReport, _$identity);

  /// Serializes this InventoryReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InventoryReport&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.stockValue, stockValue) || other.stockValue == stockValue)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),stockValue,total,page,pageSize);

@override
String toString() {
  return 'InventoryReport(rows: $rows, stockValue: $stockValue, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $InventoryReportCopyWith<$Res>  {
  factory $InventoryReportCopyWith(InventoryReport value, $Res Function(InventoryReport) _then) = _$InventoryReportCopyWithImpl;
@useResult
$Res call({
 List<InventoryReportRow> rows,@JsonKey(name: 'stockValue') num stockValue, int total, int page,@JsonKey(name: 'pageSize') int pageSize
});




}
/// @nodoc
class _$InventoryReportCopyWithImpl<$Res>
    implements $InventoryReportCopyWith<$Res> {
  _$InventoryReportCopyWithImpl(this._self, this._then);

  final InventoryReport _self;
  final $Res Function(InventoryReport) _then;

/// Create a copy of InventoryReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? stockValue = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<InventoryReportRow>,stockValue: null == stockValue ? _self.stockValue : stockValue // ignore: cast_nullable_to_non_nullable
as num,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InventoryReport].
extension InventoryReportPatterns on InventoryReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InventoryReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InventoryReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InventoryReport value)  $default,){
final _that = this;
switch (_that) {
case _InventoryReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InventoryReport value)?  $default,){
final _that = this;
switch (_that) {
case _InventoryReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<InventoryReportRow> rows, @JsonKey(name: 'stockValue')  num stockValue,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InventoryReport() when $default != null:
return $default(_that.rows,_that.stockValue,_that.total,_that.page,_that.pageSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<InventoryReportRow> rows, @JsonKey(name: 'stockValue')  num stockValue,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _InventoryReport():
return $default(_that.rows,_that.stockValue,_that.total,_that.page,_that.pageSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<InventoryReportRow> rows, @JsonKey(name: 'stockValue')  num stockValue,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _InventoryReport() when $default != null:
return $default(_that.rows,_that.stockValue,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InventoryReport implements InventoryReport {
  const _InventoryReport({final  List<InventoryReportRow> rows = const <InventoryReportRow>[], @JsonKey(name: 'stockValue') this.stockValue = 0, this.total = 0, this.page = 1, @JsonKey(name: 'pageSize') this.pageSize = 50}): _rows = rows;
  factory _InventoryReport.fromJson(Map<String, dynamic> json) => _$InventoryReportFromJson(json);

 final  List<InventoryReportRow> _rows;
@override@JsonKey() List<InventoryReportRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override@JsonKey(name: 'stockValue') final  num stockValue;
@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey(name: 'pageSize') final  int pageSize;

/// Create a copy of InventoryReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InventoryReportCopyWith<_InventoryReport> get copyWith => __$InventoryReportCopyWithImpl<_InventoryReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InventoryReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InventoryReport&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.stockValue, stockValue) || other.stockValue == stockValue)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),stockValue,total,page,pageSize);

@override
String toString() {
  return 'InventoryReport(rows: $rows, stockValue: $stockValue, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$InventoryReportCopyWith<$Res> implements $InventoryReportCopyWith<$Res> {
  factory _$InventoryReportCopyWith(_InventoryReport value, $Res Function(_InventoryReport) _then) = __$InventoryReportCopyWithImpl;
@override @useResult
$Res call({
 List<InventoryReportRow> rows,@JsonKey(name: 'stockValue') num stockValue, int total, int page,@JsonKey(name: 'pageSize') int pageSize
});




}
/// @nodoc
class __$InventoryReportCopyWithImpl<$Res>
    implements _$InventoryReportCopyWith<$Res> {
  __$InventoryReportCopyWithImpl(this._self, this._then);

  final _InventoryReport _self;
  final $Res Function(_InventoryReport) _then;

/// Create a copy of InventoryReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? stockValue = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_InventoryReport(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<InventoryReportRow>,stockValue: null == stockValue ? _self.stockValue : stockValue // ignore: cast_nullable_to_non_nullable
as num,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CustomerReportRow {

 String get id; String get name; String get type;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of CustomerReportRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerReportRowCopyWith<CustomerReportRow> get copyWith => _$CustomerReportRowCopyWithImpl<CustomerReportRow>(this as CustomerReportRow, _$identity);

  /// Serializes this CustomerReportRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerReportRow&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,createdAt);

@override
String toString() {
  return 'CustomerReportRow(id: $id, name: $name, type: $type, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $CustomerReportRowCopyWith<$Res>  {
  factory $CustomerReportRowCopyWith(CustomerReportRow value, $Res Function(CustomerReportRow) _then) = _$CustomerReportRowCopyWithImpl;
@useResult
$Res call({
 String id, String name, String type,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$CustomerReportRowCopyWithImpl<$Res>
    implements $CustomerReportRowCopyWith<$Res> {
  _$CustomerReportRowCopyWithImpl(this._self, this._then);

  final CustomerReportRow _self;
  final $Res Function(CustomerReportRow) _then;

/// Create a copy of CustomerReportRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomerReportRow].
extension CustomerReportRowPatterns on CustomerReportRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomerReportRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerReportRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomerReportRow value)  $default,){
final _that = this;
switch (_that) {
case _CustomerReportRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomerReportRow value)?  $default,){
final _that = this;
switch (_that) {
case _CustomerReportRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String type, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerReportRow() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String type, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _CustomerReportRow():
return $default(_that.id,_that.name,_that.type,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String type, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _CustomerReportRow() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomerReportRow implements CustomerReportRow {
  const _CustomerReportRow({required this.id, this.name = '', this.type = '', @JsonKey(name: 'created_at') this.createdAt});
  factory _CustomerReportRow.fromJson(Map<String, dynamic> json) => _$CustomerReportRowFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String type;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of CustomerReportRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerReportRowCopyWith<_CustomerReportRow> get copyWith => __$CustomerReportRowCopyWithImpl<_CustomerReportRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerReportRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerReportRow&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,createdAt);

@override
String toString() {
  return 'CustomerReportRow(id: $id, name: $name, type: $type, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CustomerReportRowCopyWith<$Res> implements $CustomerReportRowCopyWith<$Res> {
  factory _$CustomerReportRowCopyWith(_CustomerReportRow value, $Res Function(_CustomerReportRow) _then) = __$CustomerReportRowCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String type,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$CustomerReportRowCopyWithImpl<$Res>
    implements _$CustomerReportRowCopyWith<$Res> {
  __$CustomerReportRowCopyWithImpl(this._self, this._then);

  final _CustomerReportRow _self;
  final $Res Function(_CustomerReportRow) _then;

/// Create a copy of CustomerReportRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? createdAt = freezed,}) {
  return _then(_CustomerReportRow(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CustomersSeriesPoint {

 String get day; String get type; int get count;
/// Create a copy of CustomersSeriesPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomersSeriesPointCopyWith<CustomersSeriesPoint> get copyWith => _$CustomersSeriesPointCopyWithImpl<CustomersSeriesPoint>(this as CustomersSeriesPoint, _$identity);

  /// Serializes this CustomersSeriesPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomersSeriesPoint&&(identical(other.day, day) || other.day == day)&&(identical(other.type, type) || other.type == type)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,type,count);

@override
String toString() {
  return 'CustomersSeriesPoint(day: $day, type: $type, count: $count)';
}


}

/// @nodoc
abstract mixin class $CustomersSeriesPointCopyWith<$Res>  {
  factory $CustomersSeriesPointCopyWith(CustomersSeriesPoint value, $Res Function(CustomersSeriesPoint) _then) = _$CustomersSeriesPointCopyWithImpl;
@useResult
$Res call({
 String day, String type, int count
});




}
/// @nodoc
class _$CustomersSeriesPointCopyWithImpl<$Res>
    implements $CustomersSeriesPointCopyWith<$Res> {
  _$CustomersSeriesPointCopyWithImpl(this._self, this._then);

  final CustomersSeriesPoint _self;
  final $Res Function(CustomersSeriesPoint) _then;

/// Create a copy of CustomersSeriesPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? type = null,Object? count = null,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomersSeriesPoint].
extension CustomersSeriesPointPatterns on CustomersSeriesPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomersSeriesPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomersSeriesPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomersSeriesPoint value)  $default,){
final _that = this;
switch (_that) {
case _CustomersSeriesPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomersSeriesPoint value)?  $default,){
final _that = this;
switch (_that) {
case _CustomersSeriesPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String day,  String type,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomersSeriesPoint() when $default != null:
return $default(_that.day,_that.type,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String day,  String type,  int count)  $default,) {final _that = this;
switch (_that) {
case _CustomersSeriesPoint():
return $default(_that.day,_that.type,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String day,  String type,  int count)?  $default,) {final _that = this;
switch (_that) {
case _CustomersSeriesPoint() when $default != null:
return $default(_that.day,_that.type,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomersSeriesPoint implements CustomersSeriesPoint {
  const _CustomersSeriesPoint({this.day = '', this.type = '', this.count = 0});
  factory _CustomersSeriesPoint.fromJson(Map<String, dynamic> json) => _$CustomersSeriesPointFromJson(json);

@override@JsonKey() final  String day;
@override@JsonKey() final  String type;
@override@JsonKey() final  int count;

/// Create a copy of CustomersSeriesPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomersSeriesPointCopyWith<_CustomersSeriesPoint> get copyWith => __$CustomersSeriesPointCopyWithImpl<_CustomersSeriesPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomersSeriesPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomersSeriesPoint&&(identical(other.day, day) || other.day == day)&&(identical(other.type, type) || other.type == type)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,day,type,count);

@override
String toString() {
  return 'CustomersSeriesPoint(day: $day, type: $type, count: $count)';
}


}

/// @nodoc
abstract mixin class _$CustomersSeriesPointCopyWith<$Res> implements $CustomersSeriesPointCopyWith<$Res> {
  factory _$CustomersSeriesPointCopyWith(_CustomersSeriesPoint value, $Res Function(_CustomersSeriesPoint) _then) = __$CustomersSeriesPointCopyWithImpl;
@override @useResult
$Res call({
 String day, String type, int count
});




}
/// @nodoc
class __$CustomersSeriesPointCopyWithImpl<$Res>
    implements _$CustomersSeriesPointCopyWith<$Res> {
  __$CustomersSeriesPointCopyWithImpl(this._self, this._then);

  final _CustomersSeriesPoint _self;
  final $Res Function(_CustomersSeriesPoint) _then;

/// Create a copy of CustomersSeriesPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? type = null,Object? count = null,}) {
  return _then(_CustomersSeriesPoint(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CustomersReport {

 List<CustomerReportRow> get rows; int get active;@JsonKey(name: 'newInRange') int get newInRange; int get total; int get page;@JsonKey(name: 'pageSize') int get pageSize; List<CustomersSeriesPoint> get series;
/// Create a copy of CustomersReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomersReportCopyWith<CustomersReport> get copyWith => _$CustomersReportCopyWithImpl<CustomersReport>(this as CustomersReport, _$identity);

  /// Serializes this CustomersReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomersReport&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.active, active) || other.active == active)&&(identical(other.newInRange, newInRange) || other.newInRange == newInRange)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&const DeepCollectionEquality().equals(other.series, series));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),active,newInRange,total,page,pageSize,const DeepCollectionEquality().hash(series));

@override
String toString() {
  return 'CustomersReport(rows: $rows, active: $active, newInRange: $newInRange, total: $total, page: $page, pageSize: $pageSize, series: $series)';
}


}

/// @nodoc
abstract mixin class $CustomersReportCopyWith<$Res>  {
  factory $CustomersReportCopyWith(CustomersReport value, $Res Function(CustomersReport) _then) = _$CustomersReportCopyWithImpl;
@useResult
$Res call({
 List<CustomerReportRow> rows, int active,@JsonKey(name: 'newInRange') int newInRange, int total, int page,@JsonKey(name: 'pageSize') int pageSize, List<CustomersSeriesPoint> series
});




}
/// @nodoc
class _$CustomersReportCopyWithImpl<$Res>
    implements $CustomersReportCopyWith<$Res> {
  _$CustomersReportCopyWithImpl(this._self, this._then);

  final CustomersReport _self;
  final $Res Function(CustomersReport) _then;

/// Create a copy of CustomersReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? active = null,Object? newInRange = null,Object? total = null,Object? page = null,Object? pageSize = null,Object? series = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<CustomerReportRow>,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as int,newInRange: null == newInRange ? _self.newInRange : newInRange // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as List<CustomersSeriesPoint>,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomersReport].
extension CustomersReportPatterns on CustomersReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomersReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomersReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomersReport value)  $default,){
final _that = this;
switch (_that) {
case _CustomersReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomersReport value)?  $default,){
final _that = this;
switch (_that) {
case _CustomersReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CustomerReportRow> rows,  int active, @JsonKey(name: 'newInRange')  int newInRange,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize,  List<CustomersSeriesPoint> series)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomersReport() when $default != null:
return $default(_that.rows,_that.active,_that.newInRange,_that.total,_that.page,_that.pageSize,_that.series);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CustomerReportRow> rows,  int active, @JsonKey(name: 'newInRange')  int newInRange,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize,  List<CustomersSeriesPoint> series)  $default,) {final _that = this;
switch (_that) {
case _CustomersReport():
return $default(_that.rows,_that.active,_that.newInRange,_that.total,_that.page,_that.pageSize,_that.series);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CustomerReportRow> rows,  int active, @JsonKey(name: 'newInRange')  int newInRange,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize,  List<CustomersSeriesPoint> series)?  $default,) {final _that = this;
switch (_that) {
case _CustomersReport() when $default != null:
return $default(_that.rows,_that.active,_that.newInRange,_that.total,_that.page,_that.pageSize,_that.series);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomersReport implements CustomersReport {
  const _CustomersReport({final  List<CustomerReportRow> rows = const <CustomerReportRow>[], this.active = 0, @JsonKey(name: 'newInRange') this.newInRange = 0, this.total = 0, this.page = 1, @JsonKey(name: 'pageSize') this.pageSize = 50, final  List<CustomersSeriesPoint> series = const <CustomersSeriesPoint>[]}): _rows = rows,_series = series;
  factory _CustomersReport.fromJson(Map<String, dynamic> json) => _$CustomersReportFromJson(json);

 final  List<CustomerReportRow> _rows;
@override@JsonKey() List<CustomerReportRow> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override@JsonKey() final  int active;
@override@JsonKey(name: 'newInRange') final  int newInRange;
@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey(name: 'pageSize') final  int pageSize;
 final  List<CustomersSeriesPoint> _series;
@override@JsonKey() List<CustomersSeriesPoint> get series {
  if (_series is EqualUnmodifiableListView) return _series;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_series);
}


/// Create a copy of CustomersReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomersReportCopyWith<_CustomersReport> get copyWith => __$CustomersReportCopyWithImpl<_CustomersReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomersReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomersReport&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.active, active) || other.active == active)&&(identical(other.newInRange, newInRange) || other.newInRange == newInRange)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize)&&const DeepCollectionEquality().equals(other._series, _series));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),active,newInRange,total,page,pageSize,const DeepCollectionEquality().hash(_series));

@override
String toString() {
  return 'CustomersReport(rows: $rows, active: $active, newInRange: $newInRange, total: $total, page: $page, pageSize: $pageSize, series: $series)';
}


}

/// @nodoc
abstract mixin class _$CustomersReportCopyWith<$Res> implements $CustomersReportCopyWith<$Res> {
  factory _$CustomersReportCopyWith(_CustomersReport value, $Res Function(_CustomersReport) _then) = __$CustomersReportCopyWithImpl;
@override @useResult
$Res call({
 List<CustomerReportRow> rows, int active,@JsonKey(name: 'newInRange') int newInRange, int total, int page,@JsonKey(name: 'pageSize') int pageSize, List<CustomersSeriesPoint> series
});




}
/// @nodoc
class __$CustomersReportCopyWithImpl<$Res>
    implements _$CustomersReportCopyWith<$Res> {
  __$CustomersReportCopyWithImpl(this._self, this._then);

  final _CustomersReport _self;
  final $Res Function(_CustomersReport) _then;

/// Create a copy of CustomersReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? active = null,Object? newInRange = null,Object? total = null,Object? page = null,Object? pageSize = null,Object? series = null,}) {
  return _then(_CustomersReport(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<CustomerReportRow>,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as int,newInRange: null == newInRange ? _self.newInRange : newInRange // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,series: null == series ? _self._series : series // ignore: cast_nullable_to_non_nullable
as List<CustomersSeriesPoint>,
  ));
}


}

// dart format on
