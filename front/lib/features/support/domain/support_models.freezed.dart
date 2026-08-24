// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SupportMessage {

 String get id; String get body; bool get fromOrbix; String? get authorName; DateTime get createdAt;
/// Create a copy of SupportMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportMessageCopyWith<SupportMessage> get copyWith => _$SupportMessageCopyWithImpl<SupportMessage>(this as SupportMessage, _$identity);

  /// Serializes this SupportMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.body, body) || other.body == body)&&(identical(other.fromOrbix, fromOrbix) || other.fromOrbix == fromOrbix)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,body,fromOrbix,authorName,createdAt);

@override
String toString() {
  return 'SupportMessage(id: $id, body: $body, fromOrbix: $fromOrbix, authorName: $authorName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SupportMessageCopyWith<$Res>  {
  factory $SupportMessageCopyWith(SupportMessage value, $Res Function(SupportMessage) _then) = _$SupportMessageCopyWithImpl;
@useResult
$Res call({
 String id, String body, bool fromOrbix, String? authorName, DateTime createdAt
});




}
/// @nodoc
class _$SupportMessageCopyWithImpl<$Res>
    implements $SupportMessageCopyWith<$Res> {
  _$SupportMessageCopyWithImpl(this._self, this._then);

  final SupportMessage _self;
  final $Res Function(SupportMessage) _then;

/// Create a copy of SupportMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? body = null,Object? fromOrbix = null,Object? authorName = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,fromOrbix: null == fromOrbix ? _self.fromOrbix : fromOrbix // ignore: cast_nullable_to_non_nullable
as bool,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportMessage].
extension SupportMessagePatterns on SupportMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportMessage value)  $default,){
final _that = this;
switch (_that) {
case _SupportMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportMessage value)?  $default,){
final _that = this;
switch (_that) {
case _SupportMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String body,  bool fromOrbix,  String? authorName,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportMessage() when $default != null:
return $default(_that.id,_that.body,_that.fromOrbix,_that.authorName,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String body,  bool fromOrbix,  String? authorName,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SupportMessage():
return $default(_that.id,_that.body,_that.fromOrbix,_that.authorName,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String body,  bool fromOrbix,  String? authorName,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SupportMessage() when $default != null:
return $default(_that.id,_that.body,_that.fromOrbix,_that.authorName,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupportMessage implements SupportMessage {
  const _SupportMessage({required this.id, required this.body, this.fromOrbix = false, this.authorName, required this.createdAt});
  factory _SupportMessage.fromJson(Map<String, dynamic> json) => _$SupportMessageFromJson(json);

@override final  String id;
@override final  String body;
@override@JsonKey() final  bool fromOrbix;
@override final  String? authorName;
@override final  DateTime createdAt;

/// Create a copy of SupportMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportMessageCopyWith<_SupportMessage> get copyWith => __$SupportMessageCopyWithImpl<_SupportMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupportMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.body, body) || other.body == body)&&(identical(other.fromOrbix, fromOrbix) || other.fromOrbix == fromOrbix)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,body,fromOrbix,authorName,createdAt);

@override
String toString() {
  return 'SupportMessage(id: $id, body: $body, fromOrbix: $fromOrbix, authorName: $authorName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SupportMessageCopyWith<$Res> implements $SupportMessageCopyWith<$Res> {
  factory _$SupportMessageCopyWith(_SupportMessage value, $Res Function(_SupportMessage) _then) = __$SupportMessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String body, bool fromOrbix, String? authorName, DateTime createdAt
});




}
/// @nodoc
class __$SupportMessageCopyWithImpl<$Res>
    implements _$SupportMessageCopyWith<$Res> {
  __$SupportMessageCopyWithImpl(this._self, this._then);

  final _SupportMessage _self;
  final $Res Function(_SupportMessage) _then;

/// Create a copy of SupportMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? body = null,Object? fromOrbix = null,Object? authorName = freezed,Object? createdAt = null,}) {
  return _then(_SupportMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,fromOrbix: null == fromOrbix ? _self.fromOrbix : fromOrbix // ignore: cast_nullable_to_non_nullable
as bool,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$SupportTicket {

 String get id; String get subject;/// 'aberto' | 'resolvido'
 String get status; DateTime get lastMessageAt; DateTime get createdAt;/// Respostas da Orbix ainda não lidas neste chamado.
 int get naoLidas;
/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<SupportTicket> get copyWith => _$SupportTicketCopyWithImpl<SupportTicket>(this as SupportTicket, _$identity);

  /// Serializes this SupportTicket to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportTicket&&(identical(other.id, id) || other.id == id)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.naoLidas, naoLidas) || other.naoLidas == naoLidas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subject,status,lastMessageAt,createdAt,naoLidas);

@override
String toString() {
  return 'SupportTicket(id: $id, subject: $subject, status: $status, lastMessageAt: $lastMessageAt, createdAt: $createdAt, naoLidas: $naoLidas)';
}


}

/// @nodoc
abstract mixin class $SupportTicketCopyWith<$Res>  {
  factory $SupportTicketCopyWith(SupportTicket value, $Res Function(SupportTicket) _then) = _$SupportTicketCopyWithImpl;
@useResult
$Res call({
 String id, String subject, String status, DateTime lastMessageAt, DateTime createdAt, int naoLidas
});




}
/// @nodoc
class _$SupportTicketCopyWithImpl<$Res>
    implements $SupportTicketCopyWith<$Res> {
  _$SupportTicketCopyWithImpl(this._self, this._then);

  final SupportTicket _self;
  final $Res Function(SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? subject = null,Object? status = null,Object? lastMessageAt = null,Object? createdAt = null,Object? naoLidas = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lastMessageAt: null == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,naoLidas: null == naoLidas ? _self.naoLidas : naoLidas // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportTicket].
extension SupportTicketPatterns on SupportTicket {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportTicket value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportTicket value)  $default,){
final _that = this;
switch (_that) {
case _SupportTicket():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportTicket value)?  $default,){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String subject,  String status,  DateTime lastMessageAt,  DateTime createdAt,  int naoLidas)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.subject,_that.status,_that.lastMessageAt,_that.createdAt,_that.naoLidas);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String subject,  String status,  DateTime lastMessageAt,  DateTime createdAt,  int naoLidas)  $default,) {final _that = this;
switch (_that) {
case _SupportTicket():
return $default(_that.id,_that.subject,_that.status,_that.lastMessageAt,_that.createdAt,_that.naoLidas);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String subject,  String status,  DateTime lastMessageAt,  DateTime createdAt,  int naoLidas)?  $default,) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.subject,_that.status,_that.lastMessageAt,_that.createdAt,_that.naoLidas);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SupportTicket extends SupportTicket {
  const _SupportTicket({required this.id, required this.subject, this.status = 'aberto', required this.lastMessageAt, required this.createdAt, this.naoLidas = 0}): super._();
  factory _SupportTicket.fromJson(Map<String, dynamic> json) => _$SupportTicketFromJson(json);

@override final  String id;
@override final  String subject;
/// 'aberto' | 'resolvido'
@override@JsonKey() final  String status;
@override final  DateTime lastMessageAt;
@override final  DateTime createdAt;
/// Respostas da Orbix ainda não lidas neste chamado.
@override@JsonKey() final  int naoLidas;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportTicketCopyWith<_SupportTicket> get copyWith => __$SupportTicketCopyWithImpl<_SupportTicket>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupportTicketToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportTicket&&(identical(other.id, id) || other.id == id)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.naoLidas, naoLidas) || other.naoLidas == naoLidas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subject,status,lastMessageAt,createdAt,naoLidas);

@override
String toString() {
  return 'SupportTicket(id: $id, subject: $subject, status: $status, lastMessageAt: $lastMessageAt, createdAt: $createdAt, naoLidas: $naoLidas)';
}


}

/// @nodoc
abstract mixin class _$SupportTicketCopyWith<$Res> implements $SupportTicketCopyWith<$Res> {
  factory _$SupportTicketCopyWith(_SupportTicket value, $Res Function(_SupportTicket) _then) = __$SupportTicketCopyWithImpl;
@override @useResult
$Res call({
 String id, String subject, String status, DateTime lastMessageAt, DateTime createdAt, int naoLidas
});




}
/// @nodoc
class __$SupportTicketCopyWithImpl<$Res>
    implements _$SupportTicketCopyWith<$Res> {
  __$SupportTicketCopyWithImpl(this._self, this._then);

  final _SupportTicket _self;
  final $Res Function(_SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? subject = null,Object? status = null,Object? lastMessageAt = null,Object? createdAt = null,Object? naoLidas = null,}) {
  return _then(_SupportTicket(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,lastMessageAt: null == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,naoLidas: null == naoLidas ? _self.naoLidas : naoLidas // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
