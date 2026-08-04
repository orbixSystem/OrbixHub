// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cashier_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CashSession {

 String get id; String get status;// 'open' | 'closed'
@JsonKey(name: 'opening_amount') String get openingAmount;@JsonKey(name: 'opened_at') String? get openedAt;@JsonKey(name: 'closed_at') String? get closedAt;@JsonKey(name: 'closing_amount_counted') String? get closingAmountCounted;@JsonKey(name: 'closing_amount_expected') String? get closingAmountExpected; String? get difference; String? get notes; List<MethodTotal> get byMethod; SessionTotals? get totals;
/// Create a copy of CashSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CashSessionCopyWith<CashSession> get copyWith => _$CashSessionCopyWithImpl<CashSession>(this as CashSession, _$identity);

  /// Serializes this CashSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CashSession&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.openingAmount, openingAmount) || other.openingAmount == openingAmount)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.closingAmountCounted, closingAmountCounted) || other.closingAmountCounted == closingAmountCounted)&&(identical(other.closingAmountExpected, closingAmountExpected) || other.closingAmountExpected == closingAmountExpected)&&(identical(other.difference, difference) || other.difference == difference)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.byMethod, byMethod)&&(identical(other.totals, totals) || other.totals == totals));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,openingAmount,openedAt,closedAt,closingAmountCounted,closingAmountExpected,difference,notes,const DeepCollectionEquality().hash(byMethod),totals);

@override
String toString() {
  return 'CashSession(id: $id, status: $status, openingAmount: $openingAmount, openedAt: $openedAt, closedAt: $closedAt, closingAmountCounted: $closingAmountCounted, closingAmountExpected: $closingAmountExpected, difference: $difference, notes: $notes, byMethod: $byMethod, totals: $totals)';
}


}

/// @nodoc
abstract mixin class $CashSessionCopyWith<$Res>  {
  factory $CashSessionCopyWith(CashSession value, $Res Function(CashSession) _then) = _$CashSessionCopyWithImpl;
@useResult
$Res call({
 String id, String status,@JsonKey(name: 'opening_amount') String openingAmount,@JsonKey(name: 'opened_at') String? openedAt,@JsonKey(name: 'closed_at') String? closedAt,@JsonKey(name: 'closing_amount_counted') String? closingAmountCounted,@JsonKey(name: 'closing_amount_expected') String? closingAmountExpected, String? difference, String? notes, List<MethodTotal> byMethod, SessionTotals? totals
});


$SessionTotalsCopyWith<$Res>? get totals;

}
/// @nodoc
class _$CashSessionCopyWithImpl<$Res>
    implements $CashSessionCopyWith<$Res> {
  _$CashSessionCopyWithImpl(this._self, this._then);

  final CashSession _self;
  final $Res Function(CashSession) _then;

/// Create a copy of CashSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? openingAmount = null,Object? openedAt = freezed,Object? closedAt = freezed,Object? closingAmountCounted = freezed,Object? closingAmountExpected = freezed,Object? difference = freezed,Object? notes = freezed,Object? byMethod = null,Object? totals = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,openingAmount: null == openingAmount ? _self.openingAmount : openingAmount // ignore: cast_nullable_to_non_nullable
as String,openedAt: freezed == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as String?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as String?,closingAmountCounted: freezed == closingAmountCounted ? _self.closingAmountCounted : closingAmountCounted // ignore: cast_nullable_to_non_nullable
as String?,closingAmountExpected: freezed == closingAmountExpected ? _self.closingAmountExpected : closingAmountExpected // ignore: cast_nullable_to_non_nullable
as String?,difference: freezed == difference ? _self.difference : difference // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,byMethod: null == byMethod ? _self.byMethod : byMethod // ignore: cast_nullable_to_non_nullable
as List<MethodTotal>,totals: freezed == totals ? _self.totals : totals // ignore: cast_nullable_to_non_nullable
as SessionTotals?,
  ));
}
/// Create a copy of CashSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTotalsCopyWith<$Res>? get totals {
    if (_self.totals == null) {
    return null;
  }

  return $SessionTotalsCopyWith<$Res>(_self.totals!, (value) {
    return _then(_self.copyWith(totals: value));
  });
}
}


/// Adds pattern-matching-related methods to [CashSession].
extension CashSessionPatterns on CashSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CashSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CashSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CashSession value)  $default,){
final _that = this;
switch (_that) {
case _CashSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CashSession value)?  $default,){
final _that = this;
switch (_that) {
case _CashSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String status, @JsonKey(name: 'opening_amount')  String openingAmount, @JsonKey(name: 'opened_at')  String? openedAt, @JsonKey(name: 'closed_at')  String? closedAt, @JsonKey(name: 'closing_amount_counted')  String? closingAmountCounted, @JsonKey(name: 'closing_amount_expected')  String? closingAmountExpected,  String? difference,  String? notes,  List<MethodTotal> byMethod,  SessionTotals? totals)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CashSession() when $default != null:
return $default(_that.id,_that.status,_that.openingAmount,_that.openedAt,_that.closedAt,_that.closingAmountCounted,_that.closingAmountExpected,_that.difference,_that.notes,_that.byMethod,_that.totals);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String status, @JsonKey(name: 'opening_amount')  String openingAmount, @JsonKey(name: 'opened_at')  String? openedAt, @JsonKey(name: 'closed_at')  String? closedAt, @JsonKey(name: 'closing_amount_counted')  String? closingAmountCounted, @JsonKey(name: 'closing_amount_expected')  String? closingAmountExpected,  String? difference,  String? notes,  List<MethodTotal> byMethod,  SessionTotals? totals)  $default,) {final _that = this;
switch (_that) {
case _CashSession():
return $default(_that.id,_that.status,_that.openingAmount,_that.openedAt,_that.closedAt,_that.closingAmountCounted,_that.closingAmountExpected,_that.difference,_that.notes,_that.byMethod,_that.totals);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String status, @JsonKey(name: 'opening_amount')  String openingAmount, @JsonKey(name: 'opened_at')  String? openedAt, @JsonKey(name: 'closed_at')  String? closedAt, @JsonKey(name: 'closing_amount_counted')  String? closingAmountCounted, @JsonKey(name: 'closing_amount_expected')  String? closingAmountExpected,  String? difference,  String? notes,  List<MethodTotal> byMethod,  SessionTotals? totals)?  $default,) {final _that = this;
switch (_that) {
case _CashSession() when $default != null:
return $default(_that.id,_that.status,_that.openingAmount,_that.openedAt,_that.closedAt,_that.closingAmountCounted,_that.closingAmountExpected,_that.difference,_that.notes,_that.byMethod,_that.totals);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CashSession implements CashSession {
  const _CashSession({required this.id, this.status = 'open', @JsonKey(name: 'opening_amount') this.openingAmount = '0', @JsonKey(name: 'opened_at') this.openedAt, @JsonKey(name: 'closed_at') this.closedAt, @JsonKey(name: 'closing_amount_counted') this.closingAmountCounted, @JsonKey(name: 'closing_amount_expected') this.closingAmountExpected, this.difference, this.notes, final  List<MethodTotal> byMethod = const <MethodTotal>[], this.totals}): _byMethod = byMethod;
  factory _CashSession.fromJson(Map<String, dynamic> json) => _$CashSessionFromJson(json);

@override final  String id;
@override@JsonKey() final  String status;
// 'open' | 'closed'
@override@JsonKey(name: 'opening_amount') final  String openingAmount;
@override@JsonKey(name: 'opened_at') final  String? openedAt;
@override@JsonKey(name: 'closed_at') final  String? closedAt;
@override@JsonKey(name: 'closing_amount_counted') final  String? closingAmountCounted;
@override@JsonKey(name: 'closing_amount_expected') final  String? closingAmountExpected;
@override final  String? difference;
@override final  String? notes;
 final  List<MethodTotal> _byMethod;
@override@JsonKey() List<MethodTotal> get byMethod {
  if (_byMethod is EqualUnmodifiableListView) return _byMethod;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_byMethod);
}

@override final  SessionTotals? totals;

/// Create a copy of CashSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CashSessionCopyWith<_CashSession> get copyWith => __$CashSessionCopyWithImpl<_CashSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CashSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CashSession&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.openingAmount, openingAmount) || other.openingAmount == openingAmount)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.closingAmountCounted, closingAmountCounted) || other.closingAmountCounted == closingAmountCounted)&&(identical(other.closingAmountExpected, closingAmountExpected) || other.closingAmountExpected == closingAmountExpected)&&(identical(other.difference, difference) || other.difference == difference)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other._byMethod, _byMethod)&&(identical(other.totals, totals) || other.totals == totals));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,openingAmount,openedAt,closedAt,closingAmountCounted,closingAmountExpected,difference,notes,const DeepCollectionEquality().hash(_byMethod),totals);

@override
String toString() {
  return 'CashSession(id: $id, status: $status, openingAmount: $openingAmount, openedAt: $openedAt, closedAt: $closedAt, closingAmountCounted: $closingAmountCounted, closingAmountExpected: $closingAmountExpected, difference: $difference, notes: $notes, byMethod: $byMethod, totals: $totals)';
}


}

/// @nodoc
abstract mixin class _$CashSessionCopyWith<$Res> implements $CashSessionCopyWith<$Res> {
  factory _$CashSessionCopyWith(_CashSession value, $Res Function(_CashSession) _then) = __$CashSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String status,@JsonKey(name: 'opening_amount') String openingAmount,@JsonKey(name: 'opened_at') String? openedAt,@JsonKey(name: 'closed_at') String? closedAt,@JsonKey(name: 'closing_amount_counted') String? closingAmountCounted,@JsonKey(name: 'closing_amount_expected') String? closingAmountExpected, String? difference, String? notes, List<MethodTotal> byMethod, SessionTotals? totals
});


@override $SessionTotalsCopyWith<$Res>? get totals;

}
/// @nodoc
class __$CashSessionCopyWithImpl<$Res>
    implements _$CashSessionCopyWith<$Res> {
  __$CashSessionCopyWithImpl(this._self, this._then);

  final _CashSession _self;
  final $Res Function(_CashSession) _then;

/// Create a copy of CashSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? openingAmount = null,Object? openedAt = freezed,Object? closedAt = freezed,Object? closingAmountCounted = freezed,Object? closingAmountExpected = freezed,Object? difference = freezed,Object? notes = freezed,Object? byMethod = null,Object? totals = freezed,}) {
  return _then(_CashSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,openingAmount: null == openingAmount ? _self.openingAmount : openingAmount // ignore: cast_nullable_to_non_nullable
as String,openedAt: freezed == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as String?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as String?,closingAmountCounted: freezed == closingAmountCounted ? _self.closingAmountCounted : closingAmountCounted // ignore: cast_nullable_to_non_nullable
as String?,closingAmountExpected: freezed == closingAmountExpected ? _self.closingAmountExpected : closingAmountExpected // ignore: cast_nullable_to_non_nullable
as String?,difference: freezed == difference ? _self.difference : difference // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,byMethod: null == byMethod ? _self._byMethod : byMethod // ignore: cast_nullable_to_non_nullable
as List<MethodTotal>,totals: freezed == totals ? _self.totals : totals // ignore: cast_nullable_to_non_nullable
as SessionTotals?,
  ));
}

/// Create a copy of CashSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTotalsCopyWith<$Res>? get totals {
    if (_self.totals == null) {
    return null;
  }

  return $SessionTotalsCopyWith<$Res>(_self.totals!, (value) {
    return _then(_self.copyWith(totals: value));
  });
}
}


/// @nodoc
mixin _$SessionTotals {

@JsonKey(name: 'in') num get inTotal;@JsonKey(name: 'out') num get outTotal; num get expected;
/// Create a copy of SessionTotals
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionTotalsCopyWith<SessionTotals> get copyWith => _$SessionTotalsCopyWithImpl<SessionTotals>(this as SessionTotals, _$identity);

  /// Serializes this SessionTotals to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionTotals&&(identical(other.inTotal, inTotal) || other.inTotal == inTotal)&&(identical(other.outTotal, outTotal) || other.outTotal == outTotal)&&(identical(other.expected, expected) || other.expected == expected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inTotal,outTotal,expected);

@override
String toString() {
  return 'SessionTotals(inTotal: $inTotal, outTotal: $outTotal, expected: $expected)';
}


}

/// @nodoc
abstract mixin class $SessionTotalsCopyWith<$Res>  {
  factory $SessionTotalsCopyWith(SessionTotals value, $Res Function(SessionTotals) _then) = _$SessionTotalsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'in') num inTotal,@JsonKey(name: 'out') num outTotal, num expected
});




}
/// @nodoc
class _$SessionTotalsCopyWithImpl<$Res>
    implements $SessionTotalsCopyWith<$Res> {
  _$SessionTotalsCopyWithImpl(this._self, this._then);

  final SessionTotals _self;
  final $Res Function(SessionTotals) _then;

/// Create a copy of SessionTotals
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? inTotal = null,Object? outTotal = null,Object? expected = null,}) {
  return _then(_self.copyWith(
inTotal: null == inTotal ? _self.inTotal : inTotal // ignore: cast_nullable_to_non_nullable
as num,outTotal: null == outTotal ? _self.outTotal : outTotal // ignore: cast_nullable_to_non_nullable
as num,expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionTotals].
extension SessionTotalsPatterns on SessionTotals {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionTotals value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionTotals() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionTotals value)  $default,){
final _that = this;
switch (_that) {
case _SessionTotals():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionTotals value)?  $default,){
final _that = this;
switch (_that) {
case _SessionTotals() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'in')  num inTotal, @JsonKey(name: 'out')  num outTotal,  num expected)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionTotals() when $default != null:
return $default(_that.inTotal,_that.outTotal,_that.expected);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'in')  num inTotal, @JsonKey(name: 'out')  num outTotal,  num expected)  $default,) {final _that = this;
switch (_that) {
case _SessionTotals():
return $default(_that.inTotal,_that.outTotal,_that.expected);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'in')  num inTotal, @JsonKey(name: 'out')  num outTotal,  num expected)?  $default,) {final _that = this;
switch (_that) {
case _SessionTotals() when $default != null:
return $default(_that.inTotal,_that.outTotal,_that.expected);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionTotals implements SessionTotals {
  const _SessionTotals({@JsonKey(name: 'in') this.inTotal = 0, @JsonKey(name: 'out') this.outTotal = 0, this.expected = 0});
  factory _SessionTotals.fromJson(Map<String, dynamic> json) => _$SessionTotalsFromJson(json);

@override@JsonKey(name: 'in') final  num inTotal;
@override@JsonKey(name: 'out') final  num outTotal;
@override@JsonKey() final  num expected;

/// Create a copy of SessionTotals
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionTotalsCopyWith<_SessionTotals> get copyWith => __$SessionTotalsCopyWithImpl<_SessionTotals>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionTotalsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionTotals&&(identical(other.inTotal, inTotal) || other.inTotal == inTotal)&&(identical(other.outTotal, outTotal) || other.outTotal == outTotal)&&(identical(other.expected, expected) || other.expected == expected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inTotal,outTotal,expected);

@override
String toString() {
  return 'SessionTotals(inTotal: $inTotal, outTotal: $outTotal, expected: $expected)';
}


}

/// @nodoc
abstract mixin class _$SessionTotalsCopyWith<$Res> implements $SessionTotalsCopyWith<$Res> {
  factory _$SessionTotalsCopyWith(_SessionTotals value, $Res Function(_SessionTotals) _then) = __$SessionTotalsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'in') num inTotal,@JsonKey(name: 'out') num outTotal, num expected
});




}
/// @nodoc
class __$SessionTotalsCopyWithImpl<$Res>
    implements _$SessionTotalsCopyWith<$Res> {
  __$SessionTotalsCopyWithImpl(this._self, this._then);

  final _SessionTotals _self;
  final $Res Function(_SessionTotals) _then;

/// Create a copy of SessionTotals
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? inTotal = null,Object? outTotal = null,Object? expected = null,}) {
  return _then(_SessionTotals(
inTotal: null == inTotal ? _self.inTotal : inTotal // ignore: cast_nullable_to_non_nullable
as num,outTotal: null == outTotal ? _self.outTotal : outTotal // ignore: cast_nullable_to_non_nullable
as num,expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$MethodTotal {

 String get method;@JsonKey(name: 'in') num get inAmount;@JsonKey(name: 'out') num get outAmount;
/// Create a copy of MethodTotal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MethodTotalCopyWith<MethodTotal> get copyWith => _$MethodTotalCopyWithImpl<MethodTotal>(this as MethodTotal, _$identity);

  /// Serializes this MethodTotal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MethodTotal&&(identical(other.method, method) || other.method == method)&&(identical(other.inAmount, inAmount) || other.inAmount == inAmount)&&(identical(other.outAmount, outAmount) || other.outAmount == outAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,inAmount,outAmount);

@override
String toString() {
  return 'MethodTotal(method: $method, inAmount: $inAmount, outAmount: $outAmount)';
}


}

/// @nodoc
abstract mixin class $MethodTotalCopyWith<$Res>  {
  factory $MethodTotalCopyWith(MethodTotal value, $Res Function(MethodTotal) _then) = _$MethodTotalCopyWithImpl;
@useResult
$Res call({
 String method,@JsonKey(name: 'in') num inAmount,@JsonKey(name: 'out') num outAmount
});




}
/// @nodoc
class _$MethodTotalCopyWithImpl<$Res>
    implements $MethodTotalCopyWith<$Res> {
  _$MethodTotalCopyWithImpl(this._self, this._then);

  final MethodTotal _self;
  final $Res Function(MethodTotal) _then;

/// Create a copy of MethodTotal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = null,Object? inAmount = null,Object? outAmount = null,}) {
  return _then(_self.copyWith(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,inAmount: null == inAmount ? _self.inAmount : inAmount // ignore: cast_nullable_to_non_nullable
as num,outAmount: null == outAmount ? _self.outAmount : outAmount // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [MethodTotal].
extension MethodTotalPatterns on MethodTotal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MethodTotal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MethodTotal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MethodTotal value)  $default,){
final _that = this;
switch (_that) {
case _MethodTotal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MethodTotal value)?  $default,){
final _that = this;
switch (_that) {
case _MethodTotal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String method, @JsonKey(name: 'in')  num inAmount, @JsonKey(name: 'out')  num outAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MethodTotal() when $default != null:
return $default(_that.method,_that.inAmount,_that.outAmount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String method, @JsonKey(name: 'in')  num inAmount, @JsonKey(name: 'out')  num outAmount)  $default,) {final _that = this;
switch (_that) {
case _MethodTotal():
return $default(_that.method,_that.inAmount,_that.outAmount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String method, @JsonKey(name: 'in')  num inAmount, @JsonKey(name: 'out')  num outAmount)?  $default,) {final _that = this;
switch (_that) {
case _MethodTotal() when $default != null:
return $default(_that.method,_that.inAmount,_that.outAmount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MethodTotal implements MethodTotal {
  const _MethodTotal({required this.method, @JsonKey(name: 'in') this.inAmount = 0, @JsonKey(name: 'out') this.outAmount = 0});
  factory _MethodTotal.fromJson(Map<String, dynamic> json) => _$MethodTotalFromJson(json);

@override final  String method;
@override@JsonKey(name: 'in') final  num inAmount;
@override@JsonKey(name: 'out') final  num outAmount;

/// Create a copy of MethodTotal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MethodTotalCopyWith<_MethodTotal> get copyWith => __$MethodTotalCopyWithImpl<_MethodTotal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MethodTotalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MethodTotal&&(identical(other.method, method) || other.method == method)&&(identical(other.inAmount, inAmount) || other.inAmount == inAmount)&&(identical(other.outAmount, outAmount) || other.outAmount == outAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,inAmount,outAmount);

@override
String toString() {
  return 'MethodTotal(method: $method, inAmount: $inAmount, outAmount: $outAmount)';
}


}

/// @nodoc
abstract mixin class _$MethodTotalCopyWith<$Res> implements $MethodTotalCopyWith<$Res> {
  factory _$MethodTotalCopyWith(_MethodTotal value, $Res Function(_MethodTotal) _then) = __$MethodTotalCopyWithImpl;
@override @useResult
$Res call({
 String method,@JsonKey(name: 'in') num inAmount,@JsonKey(name: 'out') num outAmount
});




}
/// @nodoc
class __$MethodTotalCopyWithImpl<$Res>
    implements _$MethodTotalCopyWith<$Res> {
  __$MethodTotalCopyWithImpl(this._self, this._then);

  final _MethodTotal _self;
  final $Res Function(_MethodTotal) _then;

/// Create a copy of MethodTotal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? inAmount = null,Object? outAmount = null,}) {
  return _then(_MethodTotal(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,inAmount: null == inAmount ? _self.inAmount : inAmount // ignore: cast_nullable_to_non_nullable
as num,outAmount: null == outAmount ? _self.outAmount : outAmount // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$KeyedTotal {

 String get key;@JsonKey(name: 'in') num get inAmount;@JsonKey(name: 'out') num get outAmount;
/// Create a copy of KeyedTotal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyedTotalCopyWith<KeyedTotal> get copyWith => _$KeyedTotalCopyWithImpl<KeyedTotal>(this as KeyedTotal, _$identity);

  /// Serializes this KeyedTotal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyedTotal&&(identical(other.key, key) || other.key == key)&&(identical(other.inAmount, inAmount) || other.inAmount == inAmount)&&(identical(other.outAmount, outAmount) || other.outAmount == outAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,inAmount,outAmount);

@override
String toString() {
  return 'KeyedTotal(key: $key, inAmount: $inAmount, outAmount: $outAmount)';
}


}

/// @nodoc
abstract mixin class $KeyedTotalCopyWith<$Res>  {
  factory $KeyedTotalCopyWith(KeyedTotal value, $Res Function(KeyedTotal) _then) = _$KeyedTotalCopyWithImpl;
@useResult
$Res call({
 String key,@JsonKey(name: 'in') num inAmount,@JsonKey(name: 'out') num outAmount
});




}
/// @nodoc
class _$KeyedTotalCopyWithImpl<$Res>
    implements $KeyedTotalCopyWith<$Res> {
  _$KeyedTotalCopyWithImpl(this._self, this._then);

  final KeyedTotal _self;
  final $Res Function(KeyedTotal) _then;

/// Create a copy of KeyedTotal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? inAmount = null,Object? outAmount = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,inAmount: null == inAmount ? _self.inAmount : inAmount // ignore: cast_nullable_to_non_nullable
as num,outAmount: null == outAmount ? _self.outAmount : outAmount // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [KeyedTotal].
extension KeyedTotalPatterns on KeyedTotal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KeyedTotal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KeyedTotal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KeyedTotal value)  $default,){
final _that = this;
switch (_that) {
case _KeyedTotal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KeyedTotal value)?  $default,){
final _that = this;
switch (_that) {
case _KeyedTotal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key, @JsonKey(name: 'in')  num inAmount, @JsonKey(name: 'out')  num outAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KeyedTotal() when $default != null:
return $default(_that.key,_that.inAmount,_that.outAmount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key, @JsonKey(name: 'in')  num inAmount, @JsonKey(name: 'out')  num outAmount)  $default,) {final _that = this;
switch (_that) {
case _KeyedTotal():
return $default(_that.key,_that.inAmount,_that.outAmount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key, @JsonKey(name: 'in')  num inAmount, @JsonKey(name: 'out')  num outAmount)?  $default,) {final _that = this;
switch (_that) {
case _KeyedTotal() when $default != null:
return $default(_that.key,_that.inAmount,_that.outAmount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KeyedTotal implements KeyedTotal {
  const _KeyedTotal({required this.key, @JsonKey(name: 'in') this.inAmount = 0, @JsonKey(name: 'out') this.outAmount = 0});
  factory _KeyedTotal.fromJson(Map<String, dynamic> json) => _$KeyedTotalFromJson(json);

@override final  String key;
@override@JsonKey(name: 'in') final  num inAmount;
@override@JsonKey(name: 'out') final  num outAmount;

/// Create a copy of KeyedTotal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KeyedTotalCopyWith<_KeyedTotal> get copyWith => __$KeyedTotalCopyWithImpl<_KeyedTotal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KeyedTotalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KeyedTotal&&(identical(other.key, key) || other.key == key)&&(identical(other.inAmount, inAmount) || other.inAmount == inAmount)&&(identical(other.outAmount, outAmount) || other.outAmount == outAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,inAmount,outAmount);

@override
String toString() {
  return 'KeyedTotal(key: $key, inAmount: $inAmount, outAmount: $outAmount)';
}


}

/// @nodoc
abstract mixin class _$KeyedTotalCopyWith<$Res> implements $KeyedTotalCopyWith<$Res> {
  factory _$KeyedTotalCopyWith(_KeyedTotal value, $Res Function(_KeyedTotal) _then) = __$KeyedTotalCopyWithImpl;
@override @useResult
$Res call({
 String key,@JsonKey(name: 'in') num inAmount,@JsonKey(name: 'out') num outAmount
});




}
/// @nodoc
class __$KeyedTotalCopyWithImpl<$Res>
    implements _$KeyedTotalCopyWith<$Res> {
  __$KeyedTotalCopyWithImpl(this._self, this._then);

  final _KeyedTotal _self;
  final $Res Function(_KeyedTotal) _then;

/// Create a copy of KeyedTotal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? inAmount = null,Object? outAmount = null,}) {
  return _then(_KeyedTotal(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,inAmount: null == inAmount ? _self.inAmount : inAmount // ignore: cast_nullable_to_non_nullable
as num,outAmount: null == outAmount ? _self.outAmount : outAmount // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$CashEntry {

 String get id; String get direction;// 'in' | 'out'
 String get amount; String get method; String get category;@JsonKey(name: 'sale_kind') String? get saleKind;@JsonKey(name: 'sale_id') String? get saleId; String? get description;@JsonKey(name: 'reversed_at') String? get reversedAt;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of CashEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CashEntryCopyWith<CashEntry> get copyWith => _$CashEntryCopyWithImpl<CashEntry>(this as CashEntry, _$identity);

  /// Serializes this CashEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CashEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.method, method) || other.method == method)&&(identical(other.category, category) || other.category == category)&&(identical(other.saleKind, saleKind) || other.saleKind == saleKind)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.description, description) || other.description == description)&&(identical(other.reversedAt, reversedAt) || other.reversedAt == reversedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,direction,amount,method,category,saleKind,saleId,description,reversedAt,createdAt);

@override
String toString() {
  return 'CashEntry(id: $id, direction: $direction, amount: $amount, method: $method, category: $category, saleKind: $saleKind, saleId: $saleId, description: $description, reversedAt: $reversedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $CashEntryCopyWith<$Res>  {
  factory $CashEntryCopyWith(CashEntry value, $Res Function(CashEntry) _then) = _$CashEntryCopyWithImpl;
@useResult
$Res call({
 String id, String direction, String amount, String method, String category,@JsonKey(name: 'sale_kind') String? saleKind,@JsonKey(name: 'sale_id') String? saleId, String? description,@JsonKey(name: 'reversed_at') String? reversedAt,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$CashEntryCopyWithImpl<$Res>
    implements $CashEntryCopyWith<$Res> {
  _$CashEntryCopyWithImpl(this._self, this._then);

  final CashEntry _self;
  final $Res Function(CashEntry) _then;

/// Create a copy of CashEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? direction = null,Object? amount = null,Object? method = null,Object? category = null,Object? saleKind = freezed,Object? saleId = freezed,Object? description = freezed,Object? reversedAt = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,saleKind: freezed == saleKind ? _self.saleKind : saleKind // ignore: cast_nullable_to_non_nullable
as String?,saleId: freezed == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,reversedAt: freezed == reversedAt ? _self.reversedAt : reversedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CashEntry].
extension CashEntryPatterns on CashEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CashEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CashEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CashEntry value)  $default,){
final _that = this;
switch (_that) {
case _CashEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CashEntry value)?  $default,){
final _that = this;
switch (_that) {
case _CashEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String direction,  String amount,  String method,  String category, @JsonKey(name: 'sale_kind')  String? saleKind, @JsonKey(name: 'sale_id')  String? saleId,  String? description, @JsonKey(name: 'reversed_at')  String? reversedAt, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CashEntry() when $default != null:
return $default(_that.id,_that.direction,_that.amount,_that.method,_that.category,_that.saleKind,_that.saleId,_that.description,_that.reversedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String direction,  String amount,  String method,  String category, @JsonKey(name: 'sale_kind')  String? saleKind, @JsonKey(name: 'sale_id')  String? saleId,  String? description, @JsonKey(name: 'reversed_at')  String? reversedAt, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _CashEntry():
return $default(_that.id,_that.direction,_that.amount,_that.method,_that.category,_that.saleKind,_that.saleId,_that.description,_that.reversedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String direction,  String amount,  String method,  String category, @JsonKey(name: 'sale_kind')  String? saleKind, @JsonKey(name: 'sale_id')  String? saleId,  String? description, @JsonKey(name: 'reversed_at')  String? reversedAt, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _CashEntry() when $default != null:
return $default(_that.id,_that.direction,_that.amount,_that.method,_that.category,_that.saleKind,_that.saleId,_that.description,_that.reversedAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CashEntry implements CashEntry {
  const _CashEntry({required this.id, required this.direction, this.amount = '0', required this.method, required this.category, @JsonKey(name: 'sale_kind') this.saleKind, @JsonKey(name: 'sale_id') this.saleId, this.description, @JsonKey(name: 'reversed_at') this.reversedAt, @JsonKey(name: 'created_at') this.createdAt});
  factory _CashEntry.fromJson(Map<String, dynamic> json) => _$CashEntryFromJson(json);

@override final  String id;
@override final  String direction;
// 'in' | 'out'
@override@JsonKey() final  String amount;
@override final  String method;
@override final  String category;
@override@JsonKey(name: 'sale_kind') final  String? saleKind;
@override@JsonKey(name: 'sale_id') final  String? saleId;
@override final  String? description;
@override@JsonKey(name: 'reversed_at') final  String? reversedAt;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of CashEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CashEntryCopyWith<_CashEntry> get copyWith => __$CashEntryCopyWithImpl<_CashEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CashEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CashEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.method, method) || other.method == method)&&(identical(other.category, category) || other.category == category)&&(identical(other.saleKind, saleKind) || other.saleKind == saleKind)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.description, description) || other.description == description)&&(identical(other.reversedAt, reversedAt) || other.reversedAt == reversedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,direction,amount,method,category,saleKind,saleId,description,reversedAt,createdAt);

@override
String toString() {
  return 'CashEntry(id: $id, direction: $direction, amount: $amount, method: $method, category: $category, saleKind: $saleKind, saleId: $saleId, description: $description, reversedAt: $reversedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CashEntryCopyWith<$Res> implements $CashEntryCopyWith<$Res> {
  factory _$CashEntryCopyWith(_CashEntry value, $Res Function(_CashEntry) _then) = __$CashEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String direction, String amount, String method, String category,@JsonKey(name: 'sale_kind') String? saleKind,@JsonKey(name: 'sale_id') String? saleId, String? description,@JsonKey(name: 'reversed_at') String? reversedAt,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$CashEntryCopyWithImpl<$Res>
    implements _$CashEntryCopyWith<$Res> {
  __$CashEntryCopyWithImpl(this._self, this._then);

  final _CashEntry _self;
  final $Res Function(_CashEntry) _then;

/// Create a copy of CashEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? direction = null,Object? amount = null,Object? method = null,Object? category = null,Object? saleKind = freezed,Object? saleId = freezed,Object? description = freezed,Object? reversedAt = freezed,Object? createdAt = freezed,}) {
  return _then(_CashEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,saleKind: freezed == saleKind ? _self.saleKind : saleKind // ignore: cast_nullable_to_non_nullable
as String?,saleId: freezed == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,reversedAt: freezed == reversedAt ? _self.reversedAt : reversedAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$EntryPage {

 List<CashEntry> get items; int get total; int get page; int get pageSize;
/// Create a copy of EntryPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntryPageCopyWith<EntryPage> get copyWith => _$EntryPageCopyWithImpl<EntryPage>(this as EntryPage, _$identity);

  /// Serializes this EntryPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntryPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'EntryPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $EntryPageCopyWith<$Res>  {
  factory $EntryPageCopyWith(EntryPage value, $Res Function(EntryPage) _then) = _$EntryPageCopyWithImpl;
@useResult
$Res call({
 List<CashEntry> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$EntryPageCopyWithImpl<$Res>
    implements $EntryPageCopyWith<$Res> {
  _$EntryPageCopyWithImpl(this._self, this._then);

  final EntryPage _self;
  final $Res Function(EntryPage) _then;

/// Create a copy of EntryPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<CashEntry>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [EntryPage].
extension EntryPagePatterns on EntryPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntryPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntryPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntryPage value)  $default,){
final _that = this;
switch (_that) {
case _EntryPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntryPage value)?  $default,){
final _that = this;
switch (_that) {
case _EntryPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CashEntry> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntryPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CashEntry> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _EntryPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CashEntry> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _EntryPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EntryPage implements EntryPage {
  const _EntryPage({final  List<CashEntry> items = const <CashEntry>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _EntryPage.fromJson(Map<String, dynamic> json) => _$EntryPageFromJson(json);

 final  List<CashEntry> _items;
@override@JsonKey() List<CashEntry> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of EntryPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntryPageCopyWith<_EntryPage> get copyWith => __$EntryPageCopyWithImpl<_EntryPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EntryPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntryPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'EntryPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$EntryPageCopyWith<$Res> implements $EntryPageCopyWith<$Res> {
  factory _$EntryPageCopyWith(_EntryPage value, $Res Function(_EntryPage) _then) = __$EntryPageCopyWithImpl;
@override @useResult
$Res call({
 List<CashEntry> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$EntryPageCopyWithImpl<$Res>
    implements _$EntryPageCopyWith<$Res> {
  __$EntryPageCopyWithImpl(this._self, this._then);

  final _EntryPage _self;
  final $Res Function(_EntryPage) _then;

/// Create a copy of EntryPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_EntryPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<CashEntry>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SessionPage {

 List<CashSession> get items; int get total; int get page; int get pageSize;
/// Create a copy of SessionPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionPageCopyWith<SessionPage> get copyWith => _$SessionPageCopyWithImpl<SessionPage>(this as SessionPage, _$identity);

  /// Serializes this SessionPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'SessionPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $SessionPageCopyWith<$Res>  {
  factory $SessionPageCopyWith(SessionPage value, $Res Function(SessionPage) _then) = _$SessionPageCopyWithImpl;
@useResult
$Res call({
 List<CashSession> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$SessionPageCopyWithImpl<$Res>
    implements $SessionPageCopyWith<$Res> {
  _$SessionPageCopyWithImpl(this._self, this._then);

  final SessionPage _self;
  final $Res Function(SessionPage) _then;

/// Create a copy of SessionPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<CashSession>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionPage].
extension SessionPagePatterns on SessionPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionPage value)  $default,){
final _that = this;
switch (_that) {
case _SessionPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionPage value)?  $default,){
final _that = this;
switch (_that) {
case _SessionPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CashSession> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CashSession> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _SessionPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CashSession> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _SessionPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionPage implements SessionPage {
  const _SessionPage({final  List<CashSession> items = const <CashSession>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _SessionPage.fromJson(Map<String, dynamic> json) => _$SessionPageFromJson(json);

 final  List<CashSession> _items;
@override@JsonKey() List<CashSession> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of SessionPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionPageCopyWith<_SessionPage> get copyWith => __$SessionPageCopyWithImpl<_SessionPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'SessionPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$SessionPageCopyWith<$Res> implements $SessionPageCopyWith<$Res> {
  factory _$SessionPageCopyWith(_SessionPage value, $Res Function(_SessionPage) _then) = __$SessionPageCopyWithImpl;
@override @useResult
$Res call({
 List<CashSession> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$SessionPageCopyWithImpl<$Res>
    implements _$SessionPageCopyWith<$Res> {
  __$SessionPageCopyWithImpl(this._self, this._then);

  final _SessionPage _self;
  final $Res Function(_SessionPage) _then;

/// Create a copy of SessionPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_SessionPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<CashSession>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CashSummary {

 List<MethodTotal> get byMethod; List<KeyedTotal> get byCategory; List<KeyedTotal> get byOrigin; num get totalIn; num get totalOut; num get net;
/// Create a copy of CashSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CashSummaryCopyWith<CashSummary> get copyWith => _$CashSummaryCopyWithImpl<CashSummary>(this as CashSummary, _$identity);

  /// Serializes this CashSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CashSummary&&const DeepCollectionEquality().equals(other.byMethod, byMethod)&&const DeepCollectionEquality().equals(other.byCategory, byCategory)&&const DeepCollectionEquality().equals(other.byOrigin, byOrigin)&&(identical(other.totalIn, totalIn) || other.totalIn == totalIn)&&(identical(other.totalOut, totalOut) || other.totalOut == totalOut)&&(identical(other.net, net) || other.net == net));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(byMethod),const DeepCollectionEquality().hash(byCategory),const DeepCollectionEquality().hash(byOrigin),totalIn,totalOut,net);

@override
String toString() {
  return 'CashSummary(byMethod: $byMethod, byCategory: $byCategory, byOrigin: $byOrigin, totalIn: $totalIn, totalOut: $totalOut, net: $net)';
}


}

/// @nodoc
abstract mixin class $CashSummaryCopyWith<$Res>  {
  factory $CashSummaryCopyWith(CashSummary value, $Res Function(CashSummary) _then) = _$CashSummaryCopyWithImpl;
@useResult
$Res call({
 List<MethodTotal> byMethod, List<KeyedTotal> byCategory, List<KeyedTotal> byOrigin, num totalIn, num totalOut, num net
});




}
/// @nodoc
class _$CashSummaryCopyWithImpl<$Res>
    implements $CashSummaryCopyWith<$Res> {
  _$CashSummaryCopyWithImpl(this._self, this._then);

  final CashSummary _self;
  final $Res Function(CashSummary) _then;

/// Create a copy of CashSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? byMethod = null,Object? byCategory = null,Object? byOrigin = null,Object? totalIn = null,Object? totalOut = null,Object? net = null,}) {
  return _then(_self.copyWith(
byMethod: null == byMethod ? _self.byMethod : byMethod // ignore: cast_nullable_to_non_nullable
as List<MethodTotal>,byCategory: null == byCategory ? _self.byCategory : byCategory // ignore: cast_nullable_to_non_nullable
as List<KeyedTotal>,byOrigin: null == byOrigin ? _self.byOrigin : byOrigin // ignore: cast_nullable_to_non_nullable
as List<KeyedTotal>,totalIn: null == totalIn ? _self.totalIn : totalIn // ignore: cast_nullable_to_non_nullable
as num,totalOut: null == totalOut ? _self.totalOut : totalOut // ignore: cast_nullable_to_non_nullable
as num,net: null == net ? _self.net : net // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [CashSummary].
extension CashSummaryPatterns on CashSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CashSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CashSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CashSummary value)  $default,){
final _that = this;
switch (_that) {
case _CashSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CashSummary value)?  $default,){
final _that = this;
switch (_that) {
case _CashSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MethodTotal> byMethod,  List<KeyedTotal> byCategory,  List<KeyedTotal> byOrigin,  num totalIn,  num totalOut,  num net)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CashSummary() when $default != null:
return $default(_that.byMethod,_that.byCategory,_that.byOrigin,_that.totalIn,_that.totalOut,_that.net);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MethodTotal> byMethod,  List<KeyedTotal> byCategory,  List<KeyedTotal> byOrigin,  num totalIn,  num totalOut,  num net)  $default,) {final _that = this;
switch (_that) {
case _CashSummary():
return $default(_that.byMethod,_that.byCategory,_that.byOrigin,_that.totalIn,_that.totalOut,_that.net);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MethodTotal> byMethod,  List<KeyedTotal> byCategory,  List<KeyedTotal> byOrigin,  num totalIn,  num totalOut,  num net)?  $default,) {final _that = this;
switch (_that) {
case _CashSummary() when $default != null:
return $default(_that.byMethod,_that.byCategory,_that.byOrigin,_that.totalIn,_that.totalOut,_that.net);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CashSummary implements CashSummary {
  const _CashSummary({final  List<MethodTotal> byMethod = const <MethodTotal>[], final  List<KeyedTotal> byCategory = const <KeyedTotal>[], final  List<KeyedTotal> byOrigin = const <KeyedTotal>[], this.totalIn = 0, this.totalOut = 0, this.net = 0}): _byMethod = byMethod,_byCategory = byCategory,_byOrigin = byOrigin;
  factory _CashSummary.fromJson(Map<String, dynamic> json) => _$CashSummaryFromJson(json);

 final  List<MethodTotal> _byMethod;
@override@JsonKey() List<MethodTotal> get byMethod {
  if (_byMethod is EqualUnmodifiableListView) return _byMethod;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_byMethod);
}

 final  List<KeyedTotal> _byCategory;
@override@JsonKey() List<KeyedTotal> get byCategory {
  if (_byCategory is EqualUnmodifiableListView) return _byCategory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_byCategory);
}

 final  List<KeyedTotal> _byOrigin;
@override@JsonKey() List<KeyedTotal> get byOrigin {
  if (_byOrigin is EqualUnmodifiableListView) return _byOrigin;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_byOrigin);
}

@override@JsonKey() final  num totalIn;
@override@JsonKey() final  num totalOut;
@override@JsonKey() final  num net;

/// Create a copy of CashSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CashSummaryCopyWith<_CashSummary> get copyWith => __$CashSummaryCopyWithImpl<_CashSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CashSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CashSummary&&const DeepCollectionEquality().equals(other._byMethod, _byMethod)&&const DeepCollectionEquality().equals(other._byCategory, _byCategory)&&const DeepCollectionEquality().equals(other._byOrigin, _byOrigin)&&(identical(other.totalIn, totalIn) || other.totalIn == totalIn)&&(identical(other.totalOut, totalOut) || other.totalOut == totalOut)&&(identical(other.net, net) || other.net == net));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_byMethod),const DeepCollectionEquality().hash(_byCategory),const DeepCollectionEquality().hash(_byOrigin),totalIn,totalOut,net);

@override
String toString() {
  return 'CashSummary(byMethod: $byMethod, byCategory: $byCategory, byOrigin: $byOrigin, totalIn: $totalIn, totalOut: $totalOut, net: $net)';
}


}

/// @nodoc
abstract mixin class _$CashSummaryCopyWith<$Res> implements $CashSummaryCopyWith<$Res> {
  factory _$CashSummaryCopyWith(_CashSummary value, $Res Function(_CashSummary) _then) = __$CashSummaryCopyWithImpl;
@override @useResult
$Res call({
 List<MethodTotal> byMethod, List<KeyedTotal> byCategory, List<KeyedTotal> byOrigin, num totalIn, num totalOut, num net
});




}
/// @nodoc
class __$CashSummaryCopyWithImpl<$Res>
    implements _$CashSummaryCopyWith<$Res> {
  __$CashSummaryCopyWithImpl(this._self, this._then);

  final _CashSummary _self;
  final $Res Function(_CashSummary) _then;

/// Create a copy of CashSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? byMethod = null,Object? byCategory = null,Object? byOrigin = null,Object? totalIn = null,Object? totalOut = null,Object? net = null,}) {
  return _then(_CashSummary(
byMethod: null == byMethod ? _self._byMethod : byMethod // ignore: cast_nullable_to_non_nullable
as List<MethodTotal>,byCategory: null == byCategory ? _self._byCategory : byCategory // ignore: cast_nullable_to_non_nullable
as List<KeyedTotal>,byOrigin: null == byOrigin ? _self._byOrigin : byOrigin // ignore: cast_nullable_to_non_nullable
as List<KeyedTotal>,totalIn: null == totalIn ? _self.totalIn : totalIn // ignore: cast_nullable_to_non_nullable
as num,totalOut: null == totalOut ? _self.totalOut : totalOut // ignore: cast_nullable_to_non_nullable
as num,net: null == net ? _self.net : net // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$PaymentDetail {

 num get total; num get paid; num get balance; String get status; List<CashEntry> get entries;
/// Create a copy of PaymentDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentDetailCopyWith<PaymentDetail> get copyWith => _$PaymentDetailCopyWithImpl<PaymentDetail>(this as PaymentDetail, _$identity);

  /// Serializes this PaymentDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentDetail&&(identical(other.total, total) || other.total == total)&&(identical(other.paid, paid) || other.paid == paid)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.entries, entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,paid,balance,status,const DeepCollectionEquality().hash(entries));

@override
String toString() {
  return 'PaymentDetail(total: $total, paid: $paid, balance: $balance, status: $status, entries: $entries)';
}


}

/// @nodoc
abstract mixin class $PaymentDetailCopyWith<$Res>  {
  factory $PaymentDetailCopyWith(PaymentDetail value, $Res Function(PaymentDetail) _then) = _$PaymentDetailCopyWithImpl;
@useResult
$Res call({
 num total, num paid, num balance, String status, List<CashEntry> entries
});




}
/// @nodoc
class _$PaymentDetailCopyWithImpl<$Res>
    implements $PaymentDetailCopyWith<$Res> {
  _$PaymentDetailCopyWithImpl(this._self, this._then);

  final PaymentDetail _self;
  final $Res Function(PaymentDetail) _then;

/// Create a copy of PaymentDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? total = null,Object? paid = null,Object? balance = null,Object? status = null,Object? entries = null,}) {
  return _then(_self.copyWith(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,paid: null == paid ? _self.paid : paid // ignore: cast_nullable_to_non_nullable
as num,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as num,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<CashEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentDetail].
extension PaymentDetailPatterns on PaymentDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentDetail value)  $default,){
final _that = this;
switch (_that) {
case _PaymentDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentDetail value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( num total,  num paid,  num balance,  String status,  List<CashEntry> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentDetail() when $default != null:
return $default(_that.total,_that.paid,_that.balance,_that.status,_that.entries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( num total,  num paid,  num balance,  String status,  List<CashEntry> entries)  $default,) {final _that = this;
switch (_that) {
case _PaymentDetail():
return $default(_that.total,_that.paid,_that.balance,_that.status,_that.entries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( num total,  num paid,  num balance,  String status,  List<CashEntry> entries)?  $default,) {final _that = this;
switch (_that) {
case _PaymentDetail() when $default != null:
return $default(_that.total,_that.paid,_that.balance,_that.status,_that.entries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentDetail implements PaymentDetail {
  const _PaymentDetail({this.total = 0, this.paid = 0, this.balance = 0, this.status = 'a_receber', final  List<CashEntry> entries = const <CashEntry>[]}): _entries = entries;
  factory _PaymentDetail.fromJson(Map<String, dynamic> json) => _$PaymentDetailFromJson(json);

@override@JsonKey() final  num total;
@override@JsonKey() final  num paid;
@override@JsonKey() final  num balance;
@override@JsonKey() final  String status;
 final  List<CashEntry> _entries;
@override@JsonKey() List<CashEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of PaymentDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentDetailCopyWith<_PaymentDetail> get copyWith => __$PaymentDetailCopyWithImpl<_PaymentDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentDetail&&(identical(other.total, total) || other.total == total)&&(identical(other.paid, paid) || other.paid == paid)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,total,paid,balance,status,const DeepCollectionEquality().hash(_entries));

@override
String toString() {
  return 'PaymentDetail(total: $total, paid: $paid, balance: $balance, status: $status, entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$PaymentDetailCopyWith<$Res> implements $PaymentDetailCopyWith<$Res> {
  factory _$PaymentDetailCopyWith(_PaymentDetail value, $Res Function(_PaymentDetail) _then) = __$PaymentDetailCopyWithImpl;
@override @useResult
$Res call({
 num total, num paid, num balance, String status, List<CashEntry> entries
});




}
/// @nodoc
class __$PaymentDetailCopyWithImpl<$Res>
    implements _$PaymentDetailCopyWith<$Res> {
  __$PaymentDetailCopyWithImpl(this._self, this._then);

  final _PaymentDetail _self;
  final $Res Function(_PaymentDetail) _then;

/// Create a copy of PaymentDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? total = null,Object? paid = null,Object? balance = null,Object? status = null,Object? entries = null,}) {
  return _then(_PaymentDetail(
total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,paid: null == paid ? _self.paid : paid // ignore: cast_nullable_to_non_nullable
as num,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as num,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<CashEntry>,
  ));
}


}


/// @nodoc
mixin _$CashierConfig {

 List<String> get paymentMethods;/// **Sempre `false`.** A cerimônia de abrir/fechar caixa saiu do produto e o
/// servidor normaliza este campo. O default aqui era `true`, e essa
/// divergência era um bug de verdade: quando a config não carregava, o app
/// achava que precisava de caixa aberto, exigia abertura e a venda criava
/// mas o recebimento falhava com "Abra o caixa antes de lançar".
 bool get requireOpenSession; bool get countCashOnly;
/// Create a copy of CashierConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CashierConfigCopyWith<CashierConfig> get copyWith => _$CashierConfigCopyWithImpl<CashierConfig>(this as CashierConfig, _$identity);

  /// Serializes this CashierConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CashierConfig&&const DeepCollectionEquality().equals(other.paymentMethods, paymentMethods)&&(identical(other.requireOpenSession, requireOpenSession) || other.requireOpenSession == requireOpenSession)&&(identical(other.countCashOnly, countCashOnly) || other.countCashOnly == countCashOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(paymentMethods),requireOpenSession,countCashOnly);

@override
String toString() {
  return 'CashierConfig(paymentMethods: $paymentMethods, requireOpenSession: $requireOpenSession, countCashOnly: $countCashOnly)';
}


}

/// @nodoc
abstract mixin class $CashierConfigCopyWith<$Res>  {
  factory $CashierConfigCopyWith(CashierConfig value, $Res Function(CashierConfig) _then) = _$CashierConfigCopyWithImpl;
@useResult
$Res call({
 List<String> paymentMethods, bool requireOpenSession, bool countCashOnly
});




}
/// @nodoc
class _$CashierConfigCopyWithImpl<$Res>
    implements $CashierConfigCopyWith<$Res> {
  _$CashierConfigCopyWithImpl(this._self, this._then);

  final CashierConfig _self;
  final $Res Function(CashierConfig) _then;

/// Create a copy of CashierConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentMethods = null,Object? requireOpenSession = null,Object? countCashOnly = null,}) {
  return _then(_self.copyWith(
paymentMethods: null == paymentMethods ? _self.paymentMethods : paymentMethods // ignore: cast_nullable_to_non_nullable
as List<String>,requireOpenSession: null == requireOpenSession ? _self.requireOpenSession : requireOpenSession // ignore: cast_nullable_to_non_nullable
as bool,countCashOnly: null == countCashOnly ? _self.countCashOnly : countCashOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CashierConfig].
extension CashierConfigPatterns on CashierConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CashierConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CashierConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CashierConfig value)  $default,){
final _that = this;
switch (_that) {
case _CashierConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CashierConfig value)?  $default,){
final _that = this;
switch (_that) {
case _CashierConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> paymentMethods,  bool requireOpenSession,  bool countCashOnly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CashierConfig() when $default != null:
return $default(_that.paymentMethods,_that.requireOpenSession,_that.countCashOnly);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> paymentMethods,  bool requireOpenSession,  bool countCashOnly)  $default,) {final _that = this;
switch (_that) {
case _CashierConfig():
return $default(_that.paymentMethods,_that.requireOpenSession,_that.countCashOnly);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> paymentMethods,  bool requireOpenSession,  bool countCashOnly)?  $default,) {final _that = this;
switch (_that) {
case _CashierConfig() when $default != null:
return $default(_that.paymentMethods,_that.requireOpenSession,_that.countCashOnly);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CashierConfig implements CashierConfig {
  const _CashierConfig({final  List<String> paymentMethods = const <String>['pix', 'dinheiro', 'cartao_credito', 'cartao_debito', 'outro'], this.requireOpenSession = false, this.countCashOnly = true}): _paymentMethods = paymentMethods;
  factory _CashierConfig.fromJson(Map<String, dynamic> json) => _$CashierConfigFromJson(json);

 final  List<String> _paymentMethods;
@override@JsonKey() List<String> get paymentMethods {
  if (_paymentMethods is EqualUnmodifiableListView) return _paymentMethods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paymentMethods);
}

/// **Sempre `false`.** A cerimônia de abrir/fechar caixa saiu do produto e o
/// servidor normaliza este campo. O default aqui era `true`, e essa
/// divergência era um bug de verdade: quando a config não carregava, o app
/// achava que precisava de caixa aberto, exigia abertura e a venda criava
/// mas o recebimento falhava com "Abra o caixa antes de lançar".
@override@JsonKey() final  bool requireOpenSession;
@override@JsonKey() final  bool countCashOnly;

/// Create a copy of CashierConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CashierConfigCopyWith<_CashierConfig> get copyWith => __$CashierConfigCopyWithImpl<_CashierConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CashierConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CashierConfig&&const DeepCollectionEquality().equals(other._paymentMethods, _paymentMethods)&&(identical(other.requireOpenSession, requireOpenSession) || other.requireOpenSession == requireOpenSession)&&(identical(other.countCashOnly, countCashOnly) || other.countCashOnly == countCashOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_paymentMethods),requireOpenSession,countCashOnly);

@override
String toString() {
  return 'CashierConfig(paymentMethods: $paymentMethods, requireOpenSession: $requireOpenSession, countCashOnly: $countCashOnly)';
}


}

/// @nodoc
abstract mixin class _$CashierConfigCopyWith<$Res> implements $CashierConfigCopyWith<$Res> {
  factory _$CashierConfigCopyWith(_CashierConfig value, $Res Function(_CashierConfig) _then) = __$CashierConfigCopyWithImpl;
@override @useResult
$Res call({
 List<String> paymentMethods, bool requireOpenSession, bool countCashOnly
});




}
/// @nodoc
class __$CashierConfigCopyWithImpl<$Res>
    implements _$CashierConfigCopyWith<$Res> {
  __$CashierConfigCopyWithImpl(this._self, this._then);

  final _CashierConfig _self;
  final $Res Function(_CashierConfig) _then;

/// Create a copy of CashierConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentMethods = null,Object? requireOpenSession = null,Object? countCashOnly = null,}) {
  return _then(_CashierConfig(
paymentMethods: null == paymentMethods ? _self._paymentMethods : paymentMethods // ignore: cast_nullable_to_non_nullable
as List<String>,requireOpenSession: null == requireOpenSession ? _self.requireOpenSession : requireOpenSession // ignore: cast_nullable_to_non_nullable
as bool,countCashOnly: null == countCashOnly ? _self.countCashOnly : countCashOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ExpenseTemplate {

 String get id; String get name; String get amount; String get category;// 'despesa' | 'sangria'
/// Forma sugerida; null = usar o default do caixa (não chutar).
 String? get method; String get status;
/// Create a copy of ExpenseTemplate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseTemplateCopyWith<ExpenseTemplate> get copyWith => _$ExpenseTemplateCopyWithImpl<ExpenseTemplate>(this as ExpenseTemplate, _$identity);

  /// Serializes this ExpenseTemplate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.method, method) || other.method == method)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,amount,category,method,status);

@override
String toString() {
  return 'ExpenseTemplate(id: $id, name: $name, amount: $amount, category: $category, method: $method, status: $status)';
}


}

/// @nodoc
abstract mixin class $ExpenseTemplateCopyWith<$Res>  {
  factory $ExpenseTemplateCopyWith(ExpenseTemplate value, $Res Function(ExpenseTemplate) _then) = _$ExpenseTemplateCopyWithImpl;
@useResult
$Res call({
 String id, String name, String amount, String category, String? method, String status
});




}
/// @nodoc
class _$ExpenseTemplateCopyWithImpl<$Res>
    implements $ExpenseTemplateCopyWith<$Res> {
  _$ExpenseTemplateCopyWithImpl(this._self, this._then);

  final ExpenseTemplate _self;
  final $Res Function(ExpenseTemplate) _then;

/// Create a copy of ExpenseTemplate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? amount = null,Object? category = null,Object? method = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseTemplate].
extension ExpenseTemplatePatterns on ExpenseTemplate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseTemplate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseTemplate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseTemplate value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseTemplate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseTemplate value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseTemplate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String amount,  String category,  String? method,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseTemplate() when $default != null:
return $default(_that.id,_that.name,_that.amount,_that.category,_that.method,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String amount,  String category,  String? method,  String status)  $default,) {final _that = this;
switch (_that) {
case _ExpenseTemplate():
return $default(_that.id,_that.name,_that.amount,_that.category,_that.method,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String amount,  String category,  String? method,  String status)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseTemplate() when $default != null:
return $default(_that.id,_that.name,_that.amount,_that.category,_that.method,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseTemplate implements ExpenseTemplate {
  const _ExpenseTemplate({required this.id, required this.name, this.amount = '0', this.category = 'despesa', this.method, this.status = 'active'});
  factory _ExpenseTemplate.fromJson(Map<String, dynamic> json) => _$ExpenseTemplateFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String amount;
@override@JsonKey() final  String category;
// 'despesa' | 'sangria'
/// Forma sugerida; null = usar o default do caixa (não chutar).
@override final  String? method;
@override@JsonKey() final  String status;

/// Create a copy of ExpenseTemplate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseTemplateCopyWith<_ExpenseTemplate> get copyWith => __$ExpenseTemplateCopyWithImpl<_ExpenseTemplate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseTemplateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseTemplate&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.method, method) || other.method == method)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,amount,category,method,status);

@override
String toString() {
  return 'ExpenseTemplate(id: $id, name: $name, amount: $amount, category: $category, method: $method, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ExpenseTemplateCopyWith<$Res> implements $ExpenseTemplateCopyWith<$Res> {
  factory _$ExpenseTemplateCopyWith(_ExpenseTemplate value, $Res Function(_ExpenseTemplate) _then) = __$ExpenseTemplateCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String amount, String category, String? method, String status
});




}
/// @nodoc
class __$ExpenseTemplateCopyWithImpl<$Res>
    implements _$ExpenseTemplateCopyWith<$Res> {
  __$ExpenseTemplateCopyWithImpl(this._self, this._then);

  final _ExpenseTemplate _self;
  final $Res Function(_ExpenseTemplate) _then;

/// Create a copy of ExpenseTemplate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? amount = null,Object? category = null,Object? method = freezed,Object? status = null,}) {
  return _then(_ExpenseTemplate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
