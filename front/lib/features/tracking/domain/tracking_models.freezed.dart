// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tracking_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrackingStep {

 String get label; bool get done;
/// Create a copy of TrackingStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackingStepCopyWith<TrackingStep> get copyWith => _$TrackingStepCopyWithImpl<TrackingStep>(this as TrackingStep, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackingStep&&(identical(other.label, label) || other.label == label)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode => Object.hash(runtimeType,label,done);

@override
String toString() {
  return 'TrackingStep(label: $label, done: $done)';
}


}

/// @nodoc
abstract mixin class $TrackingStepCopyWith<$Res>  {
  factory $TrackingStepCopyWith(TrackingStep value, $Res Function(TrackingStep) _then) = _$TrackingStepCopyWithImpl;
@useResult
$Res call({
 String label, bool done
});




}
/// @nodoc
class _$TrackingStepCopyWithImpl<$Res>
    implements $TrackingStepCopyWith<$Res> {
  _$TrackingStepCopyWithImpl(this._self, this._then);

  final TrackingStep _self;
  final $Res Function(TrackingStep) _then;

/// Create a copy of TrackingStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? done = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackingStep].
extension TrackingStepPatterns on TrackingStep {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackingStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackingStep() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackingStep value)  $default,){
final _that = this;
switch (_that) {
case _TrackingStep():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackingStep value)?  $default,){
final _that = this;
switch (_that) {
case _TrackingStep() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  bool done)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackingStep() when $default != null:
return $default(_that.label,_that.done);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  bool done)  $default,) {final _that = this;
switch (_that) {
case _TrackingStep():
return $default(_that.label,_that.done);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  bool done)?  $default,) {final _that = this;
switch (_that) {
case _TrackingStep() when $default != null:
return $default(_that.label,_that.done);case _:
  return null;

}
}

}

/// @nodoc


class _TrackingStep implements TrackingStep {
  const _TrackingStep({required this.label, required this.done});
  

@override final  String label;
@override final  bool done;

/// Create a copy of TrackingStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackingStepCopyWith<_TrackingStep> get copyWith => __$TrackingStepCopyWithImpl<_TrackingStep>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackingStep&&(identical(other.label, label) || other.label == label)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode => Object.hash(runtimeType,label,done);

@override
String toString() {
  return 'TrackingStep(label: $label, done: $done)';
}


}

/// @nodoc
abstract mixin class _$TrackingStepCopyWith<$Res> implements $TrackingStepCopyWith<$Res> {
  factory _$TrackingStepCopyWith(_TrackingStep value, $Res Function(_TrackingStep) _then) = __$TrackingStepCopyWithImpl;
@override @useResult
$Res call({
 String label, bool done
});




}
/// @nodoc
class __$TrackingStepCopyWithImpl<$Res>
    implements _$TrackingStepCopyWith<$Res> {
  __$TrackingStepCopyWithImpl(this._self, this._then);

  final _TrackingStep _self;
  final $Res Function(_TrackingStep) _then;

/// Create a copy of TrackingStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? done = null,}) {
  return _then(_TrackingStep(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$TrackingStatus {

 String get token; String get vehicle; String get statusLabel; List<TrackingStep> get steps;
/// Create a copy of TrackingStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackingStatusCopyWith<TrackingStatus> get copyWith => _$TrackingStatusCopyWithImpl<TrackingStatus>(this as TrackingStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackingStatus&&(identical(other.token, token) || other.token == token)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&const DeepCollectionEquality().equals(other.steps, steps));
}


@override
int get hashCode => Object.hash(runtimeType,token,vehicle,statusLabel,const DeepCollectionEquality().hash(steps));

@override
String toString() {
  return 'TrackingStatus(token: $token, vehicle: $vehicle, statusLabel: $statusLabel, steps: $steps)';
}


}

/// @nodoc
abstract mixin class $TrackingStatusCopyWith<$Res>  {
  factory $TrackingStatusCopyWith(TrackingStatus value, $Res Function(TrackingStatus) _then) = _$TrackingStatusCopyWithImpl;
@useResult
$Res call({
 String token, String vehicle, String statusLabel, List<TrackingStep> steps
});




}
/// @nodoc
class _$TrackingStatusCopyWithImpl<$Res>
    implements $TrackingStatusCopyWith<$Res> {
  _$TrackingStatusCopyWithImpl(this._self, this._then);

  final TrackingStatus _self;
  final $Res Function(TrackingStatus) _then;

/// Create a copy of TrackingStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? vehicle = null,Object? statusLabel = null,Object? steps = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,statusLabel: null == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as List<TrackingStep>,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackingStatus].
extension TrackingStatusPatterns on TrackingStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackingStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackingStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackingStatus value)  $default,){
final _that = this;
switch (_that) {
case _TrackingStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackingStatus value)?  $default,){
final _that = this;
switch (_that) {
case _TrackingStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  String vehicle,  String statusLabel,  List<TrackingStep> steps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackingStatus() when $default != null:
return $default(_that.token,_that.vehicle,_that.statusLabel,_that.steps);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  String vehicle,  String statusLabel,  List<TrackingStep> steps)  $default,) {final _that = this;
switch (_that) {
case _TrackingStatus():
return $default(_that.token,_that.vehicle,_that.statusLabel,_that.steps);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  String vehicle,  String statusLabel,  List<TrackingStep> steps)?  $default,) {final _that = this;
switch (_that) {
case _TrackingStatus() when $default != null:
return $default(_that.token,_that.vehicle,_that.statusLabel,_that.steps);case _:
  return null;

}
}

}

/// @nodoc


class _TrackingStatus implements TrackingStatus {
  const _TrackingStatus({required this.token, required this.vehicle, required this.statusLabel, final  List<TrackingStep> steps = const <TrackingStep>[]}): _steps = steps;
  

@override final  String token;
@override final  String vehicle;
@override final  String statusLabel;
 final  List<TrackingStep> _steps;
@override@JsonKey() List<TrackingStep> get steps {
  if (_steps is EqualUnmodifiableListView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_steps);
}


/// Create a copy of TrackingStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackingStatusCopyWith<_TrackingStatus> get copyWith => __$TrackingStatusCopyWithImpl<_TrackingStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackingStatus&&(identical(other.token, token) || other.token == token)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&const DeepCollectionEquality().equals(other._steps, _steps));
}


@override
int get hashCode => Object.hash(runtimeType,token,vehicle,statusLabel,const DeepCollectionEquality().hash(_steps));

@override
String toString() {
  return 'TrackingStatus(token: $token, vehicle: $vehicle, statusLabel: $statusLabel, steps: $steps)';
}


}

/// @nodoc
abstract mixin class _$TrackingStatusCopyWith<$Res> implements $TrackingStatusCopyWith<$Res> {
  factory _$TrackingStatusCopyWith(_TrackingStatus value, $Res Function(_TrackingStatus) _then) = __$TrackingStatusCopyWithImpl;
@override @useResult
$Res call({
 String token, String vehicle, String statusLabel, List<TrackingStep> steps
});




}
/// @nodoc
class __$TrackingStatusCopyWithImpl<$Res>
    implements _$TrackingStatusCopyWith<$Res> {
  __$TrackingStatusCopyWithImpl(this._self, this._then);

  final _TrackingStatus _self;
  final $Res Function(_TrackingStatus) _then;

/// Create a copy of TrackingStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? vehicle = null,Object? statusLabel = null,Object? steps = null,}) {
  return _then(_TrackingStatus(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,statusLabel: null == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String,steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as List<TrackingStep>,
  ));
}


}

// dart format on
