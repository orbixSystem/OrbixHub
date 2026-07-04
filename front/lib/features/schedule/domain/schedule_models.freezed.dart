// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BusinessHours {

 String get id;@JsonKey(name: 'dayOfWeek') int get dayOfWeek;@JsonKey(name: 'dayLabel') String get dayLabel;@JsonKey(name: 'isOpen') bool get isOpen;@JsonKey(name: 'openTime') String get openTime;@JsonKey(name: 'closeTime') String get closeTime;
/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessHoursCopyWith<BusinessHours> get copyWith => _$BusinessHoursCopyWithImpl<BusinessHours>(this as BusinessHours, _$identity);

  /// Serializes this BusinessHours to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessHours&&(identical(other.id, id) || other.id == id)&&(identical(other.dayOfWeek, dayOfWeek) || other.dayOfWeek == dayOfWeek)&&(identical(other.dayLabel, dayLabel) || other.dayLabel == dayLabel)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.openTime, openTime) || other.openTime == openTime)&&(identical(other.closeTime, closeTime) || other.closeTime == closeTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,dayOfWeek,dayLabel,isOpen,openTime,closeTime);

@override
String toString() {
  return 'BusinessHours(id: $id, dayOfWeek: $dayOfWeek, dayLabel: $dayLabel, isOpen: $isOpen, openTime: $openTime, closeTime: $closeTime)';
}


}

/// @nodoc
abstract mixin class $BusinessHoursCopyWith<$Res>  {
  factory $BusinessHoursCopyWith(BusinessHours value, $Res Function(BusinessHours) _then) = _$BusinessHoursCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'dayOfWeek') int dayOfWeek,@JsonKey(name: 'dayLabel') String dayLabel,@JsonKey(name: 'isOpen') bool isOpen,@JsonKey(name: 'openTime') String openTime,@JsonKey(name: 'closeTime') String closeTime
});




}
/// @nodoc
class _$BusinessHoursCopyWithImpl<$Res>
    implements $BusinessHoursCopyWith<$Res> {
  _$BusinessHoursCopyWithImpl(this._self, this._then);

  final BusinessHours _self;
  final $Res Function(BusinessHours) _then;

/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? dayOfWeek = null,Object? dayLabel = null,Object? isOpen = null,Object? openTime = null,Object? closeTime = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,dayOfWeek: null == dayOfWeek ? _self.dayOfWeek : dayOfWeek // ignore: cast_nullable_to_non_nullable
as int,dayLabel: null == dayLabel ? _self.dayLabel : dayLabel // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,openTime: null == openTime ? _self.openTime : openTime // ignore: cast_nullable_to_non_nullable
as String,closeTime: null == closeTime ? _self.closeTime : closeTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessHours].
extension BusinessHoursPatterns on BusinessHours {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessHours value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessHours value)  $default,){
final _that = this;
switch (_that) {
case _BusinessHours():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessHours value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'dayOfWeek')  int dayOfWeek, @JsonKey(name: 'dayLabel')  String dayLabel, @JsonKey(name: 'isOpen')  bool isOpen, @JsonKey(name: 'openTime')  String openTime, @JsonKey(name: 'closeTime')  String closeTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
return $default(_that.id,_that.dayOfWeek,_that.dayLabel,_that.isOpen,_that.openTime,_that.closeTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'dayOfWeek')  int dayOfWeek, @JsonKey(name: 'dayLabel')  String dayLabel, @JsonKey(name: 'isOpen')  bool isOpen, @JsonKey(name: 'openTime')  String openTime, @JsonKey(name: 'closeTime')  String closeTime)  $default,) {final _that = this;
switch (_that) {
case _BusinessHours():
return $default(_that.id,_that.dayOfWeek,_that.dayLabel,_that.isOpen,_that.openTime,_that.closeTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'dayOfWeek')  int dayOfWeek, @JsonKey(name: 'dayLabel')  String dayLabel, @JsonKey(name: 'isOpen')  bool isOpen, @JsonKey(name: 'openTime')  String openTime, @JsonKey(name: 'closeTime')  String closeTime)?  $default,) {final _that = this;
switch (_that) {
case _BusinessHours() when $default != null:
return $default(_that.id,_that.dayOfWeek,_that.dayLabel,_that.isOpen,_that.openTime,_that.closeTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusinessHours implements BusinessHours {
  const _BusinessHours({required this.id, @JsonKey(name: 'dayOfWeek') required this.dayOfWeek, @JsonKey(name: 'dayLabel') required this.dayLabel, @JsonKey(name: 'isOpen') this.isOpen = true, @JsonKey(name: 'openTime') this.openTime = '08:00', @JsonKey(name: 'closeTime') this.closeTime = '18:00'});
  factory _BusinessHours.fromJson(Map<String, dynamic> json) => _$BusinessHoursFromJson(json);

@override final  String id;
@override@JsonKey(name: 'dayOfWeek') final  int dayOfWeek;
@override@JsonKey(name: 'dayLabel') final  String dayLabel;
@override@JsonKey(name: 'isOpen') final  bool isOpen;
@override@JsonKey(name: 'openTime') final  String openTime;
@override@JsonKey(name: 'closeTime') final  String closeTime;

/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessHoursCopyWith<_BusinessHours> get copyWith => __$BusinessHoursCopyWithImpl<_BusinessHours>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusinessHoursToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessHours&&(identical(other.id, id) || other.id == id)&&(identical(other.dayOfWeek, dayOfWeek) || other.dayOfWeek == dayOfWeek)&&(identical(other.dayLabel, dayLabel) || other.dayLabel == dayLabel)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.openTime, openTime) || other.openTime == openTime)&&(identical(other.closeTime, closeTime) || other.closeTime == closeTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,dayOfWeek,dayLabel,isOpen,openTime,closeTime);

@override
String toString() {
  return 'BusinessHours(id: $id, dayOfWeek: $dayOfWeek, dayLabel: $dayLabel, isOpen: $isOpen, openTime: $openTime, closeTime: $closeTime)';
}


}

/// @nodoc
abstract mixin class _$BusinessHoursCopyWith<$Res> implements $BusinessHoursCopyWith<$Res> {
  factory _$BusinessHoursCopyWith(_BusinessHours value, $Res Function(_BusinessHours) _then) = __$BusinessHoursCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'dayOfWeek') int dayOfWeek,@JsonKey(name: 'dayLabel') String dayLabel,@JsonKey(name: 'isOpen') bool isOpen,@JsonKey(name: 'openTime') String openTime,@JsonKey(name: 'closeTime') String closeTime
});




}
/// @nodoc
class __$BusinessHoursCopyWithImpl<$Res>
    implements _$BusinessHoursCopyWith<$Res> {
  __$BusinessHoursCopyWithImpl(this._self, this._then);

  final _BusinessHours _self;
  final $Res Function(_BusinessHours) _then;

/// Create a copy of BusinessHours
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? dayOfWeek = null,Object? dayLabel = null,Object? isOpen = null,Object? openTime = null,Object? closeTime = null,}) {
  return _then(_BusinessHours(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,dayOfWeek: null == dayOfWeek ? _self.dayOfWeek : dayOfWeek // ignore: cast_nullable_to_non_nullable
as int,dayLabel: null == dayLabel ? _self.dayLabel : dayLabel // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,openTime: null == openTime ? _self.openTime : openTime // ignore: cast_nullable_to_non_nullable
as String,closeTime: null == closeTime ? _self.closeTime : closeTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AgendaOrderRef {

 String get id; String get number; String get status;@JsonKey(name: 'customer_name') String? get customerName;@JsonKey(name: 'subject_label') String? get subjectLabel;
/// Create a copy of AgendaOrderRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaOrderRefCopyWith<AgendaOrderRef> get copyWith => _$AgendaOrderRefCopyWithImpl<AgendaOrderRef>(this as AgendaOrderRef, _$identity);

  /// Serializes this AgendaOrderRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgendaOrderRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.status, status) || other.status == status)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,status,customerName,subjectLabel);

@override
String toString() {
  return 'AgendaOrderRef(id: $id, number: $number, status: $status, customerName: $customerName, subjectLabel: $subjectLabel)';
}


}

/// @nodoc
abstract mixin class $AgendaOrderRefCopyWith<$Res>  {
  factory $AgendaOrderRefCopyWith(AgendaOrderRef value, $Res Function(AgendaOrderRef) _then) = _$AgendaOrderRefCopyWithImpl;
@useResult
$Res call({
 String id, String number, String status,@JsonKey(name: 'customer_name') String? customerName,@JsonKey(name: 'subject_label') String? subjectLabel
});




}
/// @nodoc
class _$AgendaOrderRefCopyWithImpl<$Res>
    implements $AgendaOrderRefCopyWith<$Res> {
  _$AgendaOrderRefCopyWithImpl(this._self, this._then);

  final AgendaOrderRef _self;
  final $Res Function(AgendaOrderRef) _then;

/// Create a copy of AgendaOrderRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? status = null,Object? customerName = freezed,Object? subjectLabel = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgendaOrderRef].
extension AgendaOrderRefPatterns on AgendaOrderRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgendaOrderRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgendaOrderRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgendaOrderRef value)  $default,){
final _that = this;
switch (_that) {
case _AgendaOrderRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgendaOrderRef value)?  $default,){
final _that = this;
switch (_that) {
case _AgendaOrderRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  String status, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'subject_label')  String? subjectLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgendaOrderRef() when $default != null:
return $default(_that.id,_that.number,_that.status,_that.customerName,_that.subjectLabel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  String status, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'subject_label')  String? subjectLabel)  $default,) {final _that = this;
switch (_that) {
case _AgendaOrderRef():
return $default(_that.id,_that.number,_that.status,_that.customerName,_that.subjectLabel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  String status, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'subject_label')  String? subjectLabel)?  $default,) {final _that = this;
switch (_that) {
case _AgendaOrderRef() when $default != null:
return $default(_that.id,_that.number,_that.status,_that.customerName,_that.subjectLabel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgendaOrderRef implements AgendaOrderRef {
  const _AgendaOrderRef({required this.id, required this.number, this.status = 'aberta', @JsonKey(name: 'customer_name') this.customerName, @JsonKey(name: 'subject_label') this.subjectLabel});
  factory _AgendaOrderRef.fromJson(Map<String, dynamic> json) => _$AgendaOrderRefFromJson(json);

@override final  String id;
@override final  String number;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'customer_name') final  String? customerName;
@override@JsonKey(name: 'subject_label') final  String? subjectLabel;

/// Create a copy of AgendaOrderRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaOrderRefCopyWith<_AgendaOrderRef> get copyWith => __$AgendaOrderRefCopyWithImpl<_AgendaOrderRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgendaOrderRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgendaOrderRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.status, status) || other.status == status)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,status,customerName,subjectLabel);

@override
String toString() {
  return 'AgendaOrderRef(id: $id, number: $number, status: $status, customerName: $customerName, subjectLabel: $subjectLabel)';
}


}

/// @nodoc
abstract mixin class _$AgendaOrderRefCopyWith<$Res> implements $AgendaOrderRefCopyWith<$Res> {
  factory _$AgendaOrderRefCopyWith(_AgendaOrderRef value, $Res Function(_AgendaOrderRef) _then) = __$AgendaOrderRefCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, String status,@JsonKey(name: 'customer_name') String? customerName,@JsonKey(name: 'subject_label') String? subjectLabel
});




}
/// @nodoc
class __$AgendaOrderRefCopyWithImpl<$Res>
    implements _$AgendaOrderRefCopyWith<$Res> {
  __$AgendaOrderRefCopyWithImpl(this._self, this._then);

  final _AgendaOrderRef _self;
  final $Res Function(_AgendaOrderRef) _then;

/// Create a copy of AgendaOrderRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? status = null,Object? customerName = freezed,Object? subjectLabel = freezed,}) {
  return _then(_AgendaOrderRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AgendaItem {

 String get id; String get name; String get kind;@JsonKey(name: 'assigned_to') String? get assignedTo;@JsonKey(name: 'assigned_to_name') String? get assignedToName;@JsonKey(name: 'scheduled_start') String? get scheduledStart;@JsonKey(name: 'scheduled_end') String? get scheduledEnd;@JsonKey(name: 'estimated_duration') int? get estimatedDuration;@JsonKey(name: 'order_id') String get orderId; AgendaOrderRef get order;
/// Create a copy of AgendaItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaItemCopyWith<AgendaItem> get copyWith => _$AgendaItemCopyWithImpl<AgendaItem>(this as AgendaItem, _$identity);

  /// Serializes this AgendaItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgendaItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.assignedToName, assignedToName) || other.assignedToName == assignedToName)&&(identical(other.scheduledStart, scheduledStart) || other.scheduledStart == scheduledStart)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd)&&(identical(other.estimatedDuration, estimatedDuration) || other.estimatedDuration == estimatedDuration)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.order, order) || other.order == order));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,assignedTo,assignedToName,scheduledStart,scheduledEnd,estimatedDuration,orderId,order);

@override
String toString() {
  return 'AgendaItem(id: $id, name: $name, kind: $kind, assignedTo: $assignedTo, assignedToName: $assignedToName, scheduledStart: $scheduledStart, scheduledEnd: $scheduledEnd, estimatedDuration: $estimatedDuration, orderId: $orderId, order: $order)';
}


}

/// @nodoc
abstract mixin class $AgendaItemCopyWith<$Res>  {
  factory $AgendaItemCopyWith(AgendaItem value, $Res Function(AgendaItem) _then) = _$AgendaItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, String kind,@JsonKey(name: 'assigned_to') String? assignedTo,@JsonKey(name: 'assigned_to_name') String? assignedToName,@JsonKey(name: 'scheduled_start') String? scheduledStart,@JsonKey(name: 'scheduled_end') String? scheduledEnd,@JsonKey(name: 'estimated_duration') int? estimatedDuration,@JsonKey(name: 'order_id') String orderId, AgendaOrderRef order
});


$AgendaOrderRefCopyWith<$Res> get order;

}
/// @nodoc
class _$AgendaItemCopyWithImpl<$Res>
    implements $AgendaItemCopyWith<$Res> {
  _$AgendaItemCopyWithImpl(this._self, this._then);

  final AgendaItem _self;
  final $Res Function(AgendaItem) _then;

/// Create a copy of AgendaItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? assignedTo = freezed,Object? assignedToName = freezed,Object? scheduledStart = freezed,Object? scheduledEnd = freezed,Object? estimatedDuration = freezed,Object? orderId = null,Object? order = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,assignedToName: freezed == assignedToName ? _self.assignedToName : assignedToName // ignore: cast_nullable_to_non_nullable
as String?,scheduledStart: freezed == scheduledStart ? _self.scheduledStart : scheduledStart // ignore: cast_nullable_to_non_nullable
as String?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,estimatedDuration: freezed == estimatedDuration ? _self.estimatedDuration : estimatedDuration // ignore: cast_nullable_to_non_nullable
as int?,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as AgendaOrderRef,
  ));
}
/// Create a copy of AgendaItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgendaOrderRefCopyWith<$Res> get order {
  
  return $AgendaOrderRefCopyWith<$Res>(_self.order, (value) {
    return _then(_self.copyWith(order: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgendaItem].
extension AgendaItemPatterns on AgendaItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgendaItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgendaItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgendaItem value)  $default,){
final _that = this;
switch (_that) {
case _AgendaItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgendaItem value)?  $default,){
final _that = this;
switch (_that) {
case _AgendaItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String kind, @JsonKey(name: 'assigned_to')  String? assignedTo, @JsonKey(name: 'assigned_to_name')  String? assignedToName, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'scheduled_end')  String? scheduledEnd, @JsonKey(name: 'estimated_duration')  int? estimatedDuration, @JsonKey(name: 'order_id')  String orderId,  AgendaOrderRef order)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgendaItem() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.assignedTo,_that.assignedToName,_that.scheduledStart,_that.scheduledEnd,_that.estimatedDuration,_that.orderId,_that.order);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String kind, @JsonKey(name: 'assigned_to')  String? assignedTo, @JsonKey(name: 'assigned_to_name')  String? assignedToName, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'scheduled_end')  String? scheduledEnd, @JsonKey(name: 'estimated_duration')  int? estimatedDuration, @JsonKey(name: 'order_id')  String orderId,  AgendaOrderRef order)  $default,) {final _that = this;
switch (_that) {
case _AgendaItem():
return $default(_that.id,_that.name,_that.kind,_that.assignedTo,_that.assignedToName,_that.scheduledStart,_that.scheduledEnd,_that.estimatedDuration,_that.orderId,_that.order);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String kind, @JsonKey(name: 'assigned_to')  String? assignedTo, @JsonKey(name: 'assigned_to_name')  String? assignedToName, @JsonKey(name: 'scheduled_start')  String? scheduledStart, @JsonKey(name: 'scheduled_end')  String? scheduledEnd, @JsonKey(name: 'estimated_duration')  int? estimatedDuration, @JsonKey(name: 'order_id')  String orderId,  AgendaOrderRef order)?  $default,) {final _that = this;
switch (_that) {
case _AgendaItem() when $default != null:
return $default(_that.id,_that.name,_that.kind,_that.assignedTo,_that.assignedToName,_that.scheduledStart,_that.scheduledEnd,_that.estimatedDuration,_that.orderId,_that.order);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgendaItem implements AgendaItem {
  const _AgendaItem({required this.id, required this.name, this.kind = 'service', @JsonKey(name: 'assigned_to') this.assignedTo, @JsonKey(name: 'assigned_to_name') this.assignedToName, @JsonKey(name: 'scheduled_start') this.scheduledStart, @JsonKey(name: 'scheduled_end') this.scheduledEnd, @JsonKey(name: 'estimated_duration') this.estimatedDuration, @JsonKey(name: 'order_id') required this.orderId, required this.order});
  factory _AgendaItem.fromJson(Map<String, dynamic> json) => _$AgendaItemFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String kind;
@override@JsonKey(name: 'assigned_to') final  String? assignedTo;
@override@JsonKey(name: 'assigned_to_name') final  String? assignedToName;
@override@JsonKey(name: 'scheduled_start') final  String? scheduledStart;
@override@JsonKey(name: 'scheduled_end') final  String? scheduledEnd;
@override@JsonKey(name: 'estimated_duration') final  int? estimatedDuration;
@override@JsonKey(name: 'order_id') final  String orderId;
@override final  AgendaOrderRef order;

/// Create a copy of AgendaItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaItemCopyWith<_AgendaItem> get copyWith => __$AgendaItemCopyWithImpl<_AgendaItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgendaItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgendaItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.assignedToName, assignedToName) || other.assignedToName == assignedToName)&&(identical(other.scheduledStart, scheduledStart) || other.scheduledStart == scheduledStart)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd)&&(identical(other.estimatedDuration, estimatedDuration) || other.estimatedDuration == estimatedDuration)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.order, order) || other.order == order));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,kind,assignedTo,assignedToName,scheduledStart,scheduledEnd,estimatedDuration,orderId,order);

@override
String toString() {
  return 'AgendaItem(id: $id, name: $name, kind: $kind, assignedTo: $assignedTo, assignedToName: $assignedToName, scheduledStart: $scheduledStart, scheduledEnd: $scheduledEnd, estimatedDuration: $estimatedDuration, orderId: $orderId, order: $order)';
}


}

/// @nodoc
abstract mixin class _$AgendaItemCopyWith<$Res> implements $AgendaItemCopyWith<$Res> {
  factory _$AgendaItemCopyWith(_AgendaItem value, $Res Function(_AgendaItem) _then) = __$AgendaItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String kind,@JsonKey(name: 'assigned_to') String? assignedTo,@JsonKey(name: 'assigned_to_name') String? assignedToName,@JsonKey(name: 'scheduled_start') String? scheduledStart,@JsonKey(name: 'scheduled_end') String? scheduledEnd,@JsonKey(name: 'estimated_duration') int? estimatedDuration,@JsonKey(name: 'order_id') String orderId, AgendaOrderRef order
});


@override $AgendaOrderRefCopyWith<$Res> get order;

}
/// @nodoc
class __$AgendaItemCopyWithImpl<$Res>
    implements _$AgendaItemCopyWith<$Res> {
  __$AgendaItemCopyWithImpl(this._self, this._then);

  final _AgendaItem _self;
  final $Res Function(_AgendaItem) _then;

/// Create a copy of AgendaItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? kind = null,Object? assignedTo = freezed,Object? assignedToName = freezed,Object? scheduledStart = freezed,Object? scheduledEnd = freezed,Object? estimatedDuration = freezed,Object? orderId = null,Object? order = null,}) {
  return _then(_AgendaItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,assignedToName: freezed == assignedToName ? _self.assignedToName : assignedToName // ignore: cast_nullable_to_non_nullable
as String?,scheduledStart: freezed == scheduledStart ? _self.scheduledStart : scheduledStart // ignore: cast_nullable_to_non_nullable
as String?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,estimatedDuration: freezed == estimatedDuration ? _self.estimatedDuration : estimatedDuration // ignore: cast_nullable_to_non_nullable
as int?,orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as AgendaOrderRef,
  ));
}

/// Create a copy of AgendaItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgendaOrderRefCopyWith<$Res> get order {
  
  return $AgendaOrderRefCopyWith<$Res>(_self.order, (value) {
    return _then(_self.copyWith(order: value));
  });
}
}


/// @nodoc
mixin _$AgendaResult {

 List<AgendaItem> get items;
/// Create a copy of AgendaResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaResultCopyWith<AgendaResult> get copyWith => _$AgendaResultCopyWithImpl<AgendaResult>(this as AgendaResult, _$identity);

  /// Serializes this AgendaResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgendaResult&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'AgendaResult(items: $items)';
}


}

/// @nodoc
abstract mixin class $AgendaResultCopyWith<$Res>  {
  factory $AgendaResultCopyWith(AgendaResult value, $Res Function(AgendaResult) _then) = _$AgendaResultCopyWithImpl;
@useResult
$Res call({
 List<AgendaItem> items
});




}
/// @nodoc
class _$AgendaResultCopyWithImpl<$Res>
    implements $AgendaResultCopyWith<$Res> {
  _$AgendaResultCopyWithImpl(this._self, this._then);

  final AgendaResult _self;
  final $Res Function(AgendaResult) _then;

/// Create a copy of AgendaResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<AgendaItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [AgendaResult].
extension AgendaResultPatterns on AgendaResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgendaResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgendaResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgendaResult value)  $default,){
final _that = this;
switch (_that) {
case _AgendaResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgendaResult value)?  $default,){
final _that = this;
switch (_that) {
case _AgendaResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AgendaItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgendaResult() when $default != null:
return $default(_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AgendaItem> items)  $default,) {final _that = this;
switch (_that) {
case _AgendaResult():
return $default(_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AgendaItem> items)?  $default,) {final _that = this;
switch (_that) {
case _AgendaResult() when $default != null:
return $default(_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgendaResult implements AgendaResult {
  const _AgendaResult({final  List<AgendaItem> items = const <AgendaItem>[]}): _items = items;
  factory _AgendaResult.fromJson(Map<String, dynamic> json) => _$AgendaResultFromJson(json);

 final  List<AgendaItem> _items;
@override@JsonKey() List<AgendaItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of AgendaResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaResultCopyWith<_AgendaResult> get copyWith => __$AgendaResultCopyWithImpl<_AgendaResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgendaResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgendaResult&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'AgendaResult(items: $items)';
}


}

/// @nodoc
abstract mixin class _$AgendaResultCopyWith<$Res> implements $AgendaResultCopyWith<$Res> {
  factory _$AgendaResultCopyWith(_AgendaResult value, $Res Function(_AgendaResult) _then) = __$AgendaResultCopyWithImpl;
@override @useResult
$Res call({
 List<AgendaItem> items
});




}
/// @nodoc
class __$AgendaResultCopyWithImpl<$Res>
    implements _$AgendaResultCopyWith<$Res> {
  __$AgendaResultCopyWithImpl(this._self, this._then);

  final _AgendaResult _self;
  final $Res Function(_AgendaResult) _then;

/// Create a copy of AgendaResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_AgendaResult(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<AgendaItem>,
  ));
}


}

// dart format on
