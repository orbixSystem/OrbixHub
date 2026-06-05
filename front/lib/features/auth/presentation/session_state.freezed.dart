// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionState()';
}


}

/// @nodoc
class $SessionStateCopyWith<$Res>  {
$SessionStateCopyWith(SessionState _, $Res Function(SessionState) __);
}


/// Adds pattern-matching-related methods to [SessionState].
extension SessionStatePatterns on SessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionLoading value)?  loading,TResult Function( SessionAuthenticated value)?  authenticated,TResult Function( SessionUnauthenticated value)?  unauthenticated,TResult Function( SessionError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionLoading() when loading != null:
return loading(_that);case SessionAuthenticated() when authenticated != null:
return authenticated(_that);case SessionUnauthenticated() when unauthenticated != null:
return unauthenticated(_that);case SessionError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionLoading value)  loading,required TResult Function( SessionAuthenticated value)  authenticated,required TResult Function( SessionUnauthenticated value)  unauthenticated,required TResult Function( SessionError value)  error,}){
final _that = this;
switch (_that) {
case SessionLoading():
return loading(_that);case SessionAuthenticated():
return authenticated(_that);case SessionUnauthenticated():
return unauthenticated(_that);case SessionError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionLoading value)?  loading,TResult? Function( SessionAuthenticated value)?  authenticated,TResult? Function( SessionUnauthenticated value)?  unauthenticated,TResult? Function( SessionError value)?  error,}){
final _that = this;
switch (_that) {
case SessionLoading() when loading != null:
return loading(_that);case SessionAuthenticated() when authenticated != null:
return authenticated(_that);case SessionUnauthenticated() when unauthenticated != null:
return unauthenticated(_that);case SessionError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( Me me)?  authenticated,TResult Function()?  unauthenticated,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionLoading() when loading != null:
return loading();case SessionAuthenticated() when authenticated != null:
return authenticated(_that.me);case SessionUnauthenticated() when unauthenticated != null:
return unauthenticated();case SessionError() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( Me me)  authenticated,required TResult Function()  unauthenticated,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case SessionLoading():
return loading();case SessionAuthenticated():
return authenticated(_that.me);case SessionUnauthenticated():
return unauthenticated();case SessionError():
return error(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( Me me)?  authenticated,TResult? Function()?  unauthenticated,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case SessionLoading() when loading != null:
return loading();case SessionAuthenticated() when authenticated != null:
return authenticated(_that.me);case SessionUnauthenticated() when unauthenticated != null:
return unauthenticated();case SessionError() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class SessionLoading implements SessionState {
  const SessionLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionState.loading()';
}


}




/// @nodoc


class SessionAuthenticated implements SessionState {
  const SessionAuthenticated(this.me);
  

 final  Me me;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAuthenticatedCopyWith<SessionAuthenticated> get copyWith => _$SessionAuthenticatedCopyWithImpl<SessionAuthenticated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAuthenticated&&(identical(other.me, me) || other.me == me));
}


@override
int get hashCode => Object.hash(runtimeType,me);

@override
String toString() {
  return 'SessionState.authenticated(me: $me)';
}


}

/// @nodoc
abstract mixin class $SessionAuthenticatedCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionAuthenticatedCopyWith(SessionAuthenticated value, $Res Function(SessionAuthenticated) _then) = _$SessionAuthenticatedCopyWithImpl;
@useResult
$Res call({
 Me me
});


$MeCopyWith<$Res> get me;

}
/// @nodoc
class _$SessionAuthenticatedCopyWithImpl<$Res>
    implements $SessionAuthenticatedCopyWith<$Res> {
  _$SessionAuthenticatedCopyWithImpl(this._self, this._then);

  final SessionAuthenticated _self;
  final $Res Function(SessionAuthenticated) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? me = null,}) {
  return _then(SessionAuthenticated(
null == me ? _self.me : me // ignore: cast_nullable_to_non_nullable
as Me,
  ));
}

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MeCopyWith<$Res> get me {
  
  return $MeCopyWith<$Res>(_self.me, (value) {
    return _then(_self.copyWith(me: value));
  });
}
}

/// @nodoc


class SessionUnauthenticated implements SessionState {
  const SessionUnauthenticated();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionUnauthenticated);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionState.unauthenticated()';
}


}




/// @nodoc


class SessionError implements SessionState {
  const SessionError(this.message);
  

 final  String message;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionErrorCopyWith<SessionError> get copyWith => _$SessionErrorCopyWithImpl<SessionError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'SessionState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $SessionErrorCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory $SessionErrorCopyWith(SessionError value, $Res Function(SessionError) _then) = _$SessionErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$SessionErrorCopyWithImpl<$Res>
    implements $SessionErrorCopyWith<$Res> {
  _$SessionErrorCopyWithImpl(this._self, this._then);

  final SessionError _self;
  final $Res Function(SessionError) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(SessionError(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
