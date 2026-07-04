// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'messages_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Conversation {

 String get id; String? get title;@JsonKey(name: 'ref_label') String? get refLabel;@JsonKey(name: 'ref_type') String? get refType;@JsonKey(name: 'ref_id') String? get refId;@JsonKey(name: 'staff_unread') int get staffUnread;@JsonKey(name: 'last_message_at') String? get lastMessageAt;@JsonKey(name: 'last_message') String? get lastMessage;@JsonKey(name: 'last_message_sender') String? get lastMessageSender;@JsonKey(name: 'last_message_read') bool get lastMessageRead;
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationCopyWith<Conversation> get copyWith => _$ConversationCopyWithImpl<Conversation>(this as Conversation, _$identity);

  /// Serializes this Conversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.refLabel, refLabel) || other.refLabel == refLabel)&&(identical(other.refType, refType) || other.refType == refType)&&(identical(other.refId, refId) || other.refId == refId)&&(identical(other.staffUnread, staffUnread) || other.staffUnread == staffUnread)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.lastMessageSender, lastMessageSender) || other.lastMessageSender == lastMessageSender)&&(identical(other.lastMessageRead, lastMessageRead) || other.lastMessageRead == lastMessageRead));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,refLabel,refType,refId,staffUnread,lastMessageAt,lastMessage,lastMessageSender,lastMessageRead);

@override
String toString() {
  return 'Conversation(id: $id, title: $title, refLabel: $refLabel, refType: $refType, refId: $refId, staffUnread: $staffUnread, lastMessageAt: $lastMessageAt, lastMessage: $lastMessage, lastMessageSender: $lastMessageSender, lastMessageRead: $lastMessageRead)';
}


}

/// @nodoc
abstract mixin class $ConversationCopyWith<$Res>  {
  factory $ConversationCopyWith(Conversation value, $Res Function(Conversation) _then) = _$ConversationCopyWithImpl;
@useResult
$Res call({
 String id, String? title,@JsonKey(name: 'ref_label') String? refLabel,@JsonKey(name: 'ref_type') String? refType,@JsonKey(name: 'ref_id') String? refId,@JsonKey(name: 'staff_unread') int staffUnread,@JsonKey(name: 'last_message_at') String? lastMessageAt,@JsonKey(name: 'last_message') String? lastMessage,@JsonKey(name: 'last_message_sender') String? lastMessageSender,@JsonKey(name: 'last_message_read') bool lastMessageRead
});




}
/// @nodoc
class _$ConversationCopyWithImpl<$Res>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._self, this._then);

  final Conversation _self;
  final $Res Function(Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = freezed,Object? refLabel = freezed,Object? refType = freezed,Object? refId = freezed,Object? staffUnread = null,Object? lastMessageAt = freezed,Object? lastMessage = freezed,Object? lastMessageSender = freezed,Object? lastMessageRead = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,refLabel: freezed == refLabel ? _self.refLabel : refLabel // ignore: cast_nullable_to_non_nullable
as String?,refType: freezed == refType ? _self.refType : refType // ignore: cast_nullable_to_non_nullable
as String?,refId: freezed == refId ? _self.refId : refId // ignore: cast_nullable_to_non_nullable
as String?,staffUnread: null == staffUnread ? _self.staffUnread : staffUnread // ignore: cast_nullable_to_non_nullable
as int,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as String?,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSender: freezed == lastMessageSender ? _self.lastMessageSender : lastMessageSender // ignore: cast_nullable_to_non_nullable
as String?,lastMessageRead: null == lastMessageRead ? _self.lastMessageRead : lastMessageRead // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Conversation].
extension ConversationPatterns on Conversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Conversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Conversation value)  $default,){
final _that = this;
switch (_that) {
case _Conversation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Conversation value)?  $default,){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? title, @JsonKey(name: 'ref_label')  String? refLabel, @JsonKey(name: 'ref_type')  String? refType, @JsonKey(name: 'ref_id')  String? refId, @JsonKey(name: 'staff_unread')  int staffUnread, @JsonKey(name: 'last_message_at')  String? lastMessageAt, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_sender')  String? lastMessageSender, @JsonKey(name: 'last_message_read')  bool lastMessageRead)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.title,_that.refLabel,_that.refType,_that.refId,_that.staffUnread,_that.lastMessageAt,_that.lastMessage,_that.lastMessageSender,_that.lastMessageRead);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? title, @JsonKey(name: 'ref_label')  String? refLabel, @JsonKey(name: 'ref_type')  String? refType, @JsonKey(name: 'ref_id')  String? refId, @JsonKey(name: 'staff_unread')  int staffUnread, @JsonKey(name: 'last_message_at')  String? lastMessageAt, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_sender')  String? lastMessageSender, @JsonKey(name: 'last_message_read')  bool lastMessageRead)  $default,) {final _that = this;
switch (_that) {
case _Conversation():
return $default(_that.id,_that.title,_that.refLabel,_that.refType,_that.refId,_that.staffUnread,_that.lastMessageAt,_that.lastMessage,_that.lastMessageSender,_that.lastMessageRead);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? title, @JsonKey(name: 'ref_label')  String? refLabel, @JsonKey(name: 'ref_type')  String? refType, @JsonKey(name: 'ref_id')  String? refId, @JsonKey(name: 'staff_unread')  int staffUnread, @JsonKey(name: 'last_message_at')  String? lastMessageAt, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_sender')  String? lastMessageSender, @JsonKey(name: 'last_message_read')  bool lastMessageRead)?  $default,) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.title,_that.refLabel,_that.refType,_that.refId,_that.staffUnread,_that.lastMessageAt,_that.lastMessage,_that.lastMessageSender,_that.lastMessageRead);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Conversation implements Conversation {
  const _Conversation({required this.id, this.title, @JsonKey(name: 'ref_label') this.refLabel, @JsonKey(name: 'ref_type') this.refType, @JsonKey(name: 'ref_id') this.refId, @JsonKey(name: 'staff_unread') this.staffUnread = 0, @JsonKey(name: 'last_message_at') this.lastMessageAt, @JsonKey(name: 'last_message') this.lastMessage, @JsonKey(name: 'last_message_sender') this.lastMessageSender, @JsonKey(name: 'last_message_read') this.lastMessageRead = false});
  factory _Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);

@override final  String id;
@override final  String? title;
@override@JsonKey(name: 'ref_label') final  String? refLabel;
@override@JsonKey(name: 'ref_type') final  String? refType;
@override@JsonKey(name: 'ref_id') final  String? refId;
@override@JsonKey(name: 'staff_unread') final  int staffUnread;
@override@JsonKey(name: 'last_message_at') final  String? lastMessageAt;
@override@JsonKey(name: 'last_message') final  String? lastMessage;
@override@JsonKey(name: 'last_message_sender') final  String? lastMessageSender;
@override@JsonKey(name: 'last_message_read') final  bool lastMessageRead;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationCopyWith<_Conversation> get copyWith => __$ConversationCopyWithImpl<_Conversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.refLabel, refLabel) || other.refLabel == refLabel)&&(identical(other.refType, refType) || other.refType == refType)&&(identical(other.refId, refId) || other.refId == refId)&&(identical(other.staffUnread, staffUnread) || other.staffUnread == staffUnread)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.lastMessageSender, lastMessageSender) || other.lastMessageSender == lastMessageSender)&&(identical(other.lastMessageRead, lastMessageRead) || other.lastMessageRead == lastMessageRead));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,refLabel,refType,refId,staffUnread,lastMessageAt,lastMessage,lastMessageSender,lastMessageRead);

@override
String toString() {
  return 'Conversation(id: $id, title: $title, refLabel: $refLabel, refType: $refType, refId: $refId, staffUnread: $staffUnread, lastMessageAt: $lastMessageAt, lastMessage: $lastMessage, lastMessageSender: $lastMessageSender, lastMessageRead: $lastMessageRead)';
}


}

/// @nodoc
abstract mixin class _$ConversationCopyWith<$Res> implements $ConversationCopyWith<$Res> {
  factory _$ConversationCopyWith(_Conversation value, $Res Function(_Conversation) _then) = __$ConversationCopyWithImpl;
@override @useResult
$Res call({
 String id, String? title,@JsonKey(name: 'ref_label') String? refLabel,@JsonKey(name: 'ref_type') String? refType,@JsonKey(name: 'ref_id') String? refId,@JsonKey(name: 'staff_unread') int staffUnread,@JsonKey(name: 'last_message_at') String? lastMessageAt,@JsonKey(name: 'last_message') String? lastMessage,@JsonKey(name: 'last_message_sender') String? lastMessageSender,@JsonKey(name: 'last_message_read') bool lastMessageRead
});




}
/// @nodoc
class __$ConversationCopyWithImpl<$Res>
    implements _$ConversationCopyWith<$Res> {
  __$ConversationCopyWithImpl(this._self, this._then);

  final _Conversation _self;
  final $Res Function(_Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = freezed,Object? refLabel = freezed,Object? refType = freezed,Object? refId = freezed,Object? staffUnread = null,Object? lastMessageAt = freezed,Object? lastMessage = freezed,Object? lastMessageSender = freezed,Object? lastMessageRead = null,}) {
  return _then(_Conversation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,refLabel: freezed == refLabel ? _self.refLabel : refLabel // ignore: cast_nullable_to_non_nullable
as String?,refType: freezed == refType ? _self.refType : refType // ignore: cast_nullable_to_non_nullable
as String?,refId: freezed == refId ? _self.refId : refId // ignore: cast_nullable_to_non_nullable
as String?,staffUnread: null == staffUnread ? _self.staffUnread : staffUnread // ignore: cast_nullable_to_non_nullable
as int,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as String?,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String?,lastMessageSender: freezed == lastMessageSender ? _self.lastMessageSender : lastMessageSender // ignore: cast_nullable_to_non_nullable
as String?,lastMessageRead: null == lastMessageRead ? _self.lastMessageRead : lastMessageRead // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$Message {

 String get id; String get sender;// 'customer' | 'staff'
@JsonKey(name: 'author_name') String? get authorName; String get body;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'read_at') String? get readAt;
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCopyWith<Message> get copyWith => _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Message&&(identical(other.id, id) || other.id == id)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.readAt, readAt) || other.readAt == readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sender,authorName,body,createdAt,readAt);

@override
String toString() {
  return 'Message(id: $id, sender: $sender, authorName: $authorName, body: $body, createdAt: $createdAt, readAt: $readAt)';
}


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res>  {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) = _$MessageCopyWithImpl;
@useResult
$Res call({
 String id, String sender,@JsonKey(name: 'author_name') String? authorName, String body,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'read_at') String? readAt
});




}
/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sender = null,Object? authorName = freezed,Object? body = null,Object? createdAt = freezed,Object? readAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Message].
extension MessagePatterns on Message {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Message value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Message value)  $default,){
final _that = this;
switch (_that) {
case _Message():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Message value)?  $default,){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String sender, @JsonKey(name: 'author_name')  String? authorName,  String body, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'read_at')  String? readAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.sender,_that.authorName,_that.body,_that.createdAt,_that.readAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String sender, @JsonKey(name: 'author_name')  String? authorName,  String body, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'read_at')  String? readAt)  $default,) {final _that = this;
switch (_that) {
case _Message():
return $default(_that.id,_that.sender,_that.authorName,_that.body,_that.createdAt,_that.readAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String sender, @JsonKey(name: 'author_name')  String? authorName,  String body, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'read_at')  String? readAt)?  $default,) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.sender,_that.authorName,_that.body,_that.createdAt,_that.readAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Message implements Message {
  const _Message({required this.id, this.sender = 'customer', @JsonKey(name: 'author_name') this.authorName, this.body = '', @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'read_at') this.readAt});
  factory _Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

@override final  String id;
@override@JsonKey() final  String sender;
// 'customer' | 'staff'
@override@JsonKey(name: 'author_name') final  String? authorName;
@override@JsonKey() final  String body;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'read_at') final  String? readAt;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageCopyWith<_Message> get copyWith => __$MessageCopyWithImpl<_Message>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Message&&(identical(other.id, id) || other.id == id)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.readAt, readAt) || other.readAt == readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sender,authorName,body,createdAt,readAt);

@override
String toString() {
  return 'Message(id: $id, sender: $sender, authorName: $authorName, body: $body, createdAt: $createdAt, readAt: $readAt)';
}


}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) = __$MessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String sender,@JsonKey(name: 'author_name') String? authorName, String body,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'read_at') String? readAt
});




}
/// @nodoc
class __$MessageCopyWithImpl<$Res>
    implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sender = null,Object? authorName = freezed,Object? body = null,Object? createdAt = freezed,Object? readAt = freezed,}) {
  return _then(_Message(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ConversationThread {

 Conversation get conversation; List<Message> get messages; bool get hasMore;
/// Create a copy of ConversationThread
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationThreadCopyWith<ConversationThread> get copyWith => _$ConversationThreadCopyWithImpl<ConversationThread>(this as ConversationThread, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationThread&&(identical(other.conversation, conversation) || other.conversation == conversation)&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}


@override
int get hashCode => Object.hash(runtimeType,conversation,const DeepCollectionEquality().hash(messages),hasMore);

@override
String toString() {
  return 'ConversationThread(conversation: $conversation, messages: $messages, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class $ConversationThreadCopyWith<$Res>  {
  factory $ConversationThreadCopyWith(ConversationThread value, $Res Function(ConversationThread) _then) = _$ConversationThreadCopyWithImpl;
@useResult
$Res call({
 Conversation conversation, List<Message> messages, bool hasMore
});


$ConversationCopyWith<$Res> get conversation;

}
/// @nodoc
class _$ConversationThreadCopyWithImpl<$Res>
    implements $ConversationThreadCopyWith<$Res> {
  _$ConversationThreadCopyWithImpl(this._self, this._then);

  final ConversationThread _self;
  final $Res Function(ConversationThread) _then;

/// Create a copy of ConversationThread
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? conversation = null,Object? messages = null,Object? hasMore = null,}) {
  return _then(_self.copyWith(
conversation: null == conversation ? _self.conversation : conversation // ignore: cast_nullable_to_non_nullable
as Conversation,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ConversationThread
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConversationCopyWith<$Res> get conversation {
  
  return $ConversationCopyWith<$Res>(_self.conversation, (value) {
    return _then(_self.copyWith(conversation: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConversationThread].
extension ConversationThreadPatterns on ConversationThread {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationThread value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationThread() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationThread value)  $default,){
final _that = this;
switch (_that) {
case _ConversationThread():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationThread value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationThread() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Conversation conversation,  List<Message> messages,  bool hasMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationThread() when $default != null:
return $default(_that.conversation,_that.messages,_that.hasMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Conversation conversation,  List<Message> messages,  bool hasMore)  $default,) {final _that = this;
switch (_that) {
case _ConversationThread():
return $default(_that.conversation,_that.messages,_that.hasMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Conversation conversation,  List<Message> messages,  bool hasMore)?  $default,) {final _that = this;
switch (_that) {
case _ConversationThread() when $default != null:
return $default(_that.conversation,_that.messages,_that.hasMore);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationThread implements ConversationThread {
  const _ConversationThread({required this.conversation, final  List<Message> messages = const <Message>[], this.hasMore = false}): _messages = messages;
  

@override final  Conversation conversation;
 final  List<Message> _messages;
@override@JsonKey() List<Message> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override@JsonKey() final  bool hasMore;

/// Create a copy of ConversationThread
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationThreadCopyWith<_ConversationThread> get copyWith => __$ConversationThreadCopyWithImpl<_ConversationThread>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationThread&&(identical(other.conversation, conversation) || other.conversation == conversation)&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}


@override
int get hashCode => Object.hash(runtimeType,conversation,const DeepCollectionEquality().hash(_messages),hasMore);

@override
String toString() {
  return 'ConversationThread(conversation: $conversation, messages: $messages, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class _$ConversationThreadCopyWith<$Res> implements $ConversationThreadCopyWith<$Res> {
  factory _$ConversationThreadCopyWith(_ConversationThread value, $Res Function(_ConversationThread) _then) = __$ConversationThreadCopyWithImpl;
@override @useResult
$Res call({
 Conversation conversation, List<Message> messages, bool hasMore
});


@override $ConversationCopyWith<$Res> get conversation;

}
/// @nodoc
class __$ConversationThreadCopyWithImpl<$Res>
    implements _$ConversationThreadCopyWith<$Res> {
  __$ConversationThreadCopyWithImpl(this._self, this._then);

  final _ConversationThread _self;
  final $Res Function(_ConversationThread) _then;

/// Create a copy of ConversationThread
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? conversation = null,Object? messages = null,Object? hasMore = null,}) {
  return _then(_ConversationThread(
conversation: null == conversation ? _self.conversation : conversation // ignore: cast_nullable_to_non_nullable
as Conversation,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ConversationThread
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConversationCopyWith<$Res> get conversation {
  
  return $ConversationCopyWith<$Res>(_self.conversation, (value) {
    return _then(_self.copyWith(conversation: value));
  });
}
}


/// @nodoc
mixin _$ConversationPage {

 List<Conversation> get items; int get total; int get page;@JsonKey(name: 'pageSize') int get pageSize;
/// Create a copy of ConversationPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationPageCopyWith<ConversationPage> get copyWith => _$ConversationPageCopyWithImpl<ConversationPage>(this as ConversationPage, _$identity);

  /// Serializes this ConversationPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'ConversationPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $ConversationPageCopyWith<$Res>  {
  factory $ConversationPageCopyWith(ConversationPage value, $Res Function(ConversationPage) _then) = _$ConversationPageCopyWithImpl;
@useResult
$Res call({
 List<Conversation> items, int total, int page,@JsonKey(name: 'pageSize') int pageSize
});




}
/// @nodoc
class _$ConversationPageCopyWithImpl<$Res>
    implements $ConversationPageCopyWith<$Res> {
  _$ConversationPageCopyWithImpl(this._self, this._then);

  final ConversationPage _self;
  final $Res Function(ConversationPage) _then;

/// Create a copy of ConversationPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Conversation>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationPage].
extension ConversationPagePatterns on ConversationPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationPage value)  $default,){
final _that = this;
switch (_that) {
case _ConversationPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationPage value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Conversation> items,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Conversation> items,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _ConversationPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Conversation> items,  int total,  int page, @JsonKey(name: 'pageSize')  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _ConversationPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ConversationPage implements ConversationPage {
  const _ConversationPage({final  List<Conversation> items = const <Conversation>[], this.total = 0, this.page = 1, @JsonKey(name: 'pageSize') this.pageSize = 30}): _items = items;
  factory _ConversationPage.fromJson(Map<String, dynamic> json) => _$ConversationPageFromJson(json);

 final  List<Conversation> _items;
@override@JsonKey() List<Conversation> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey(name: 'pageSize') final  int pageSize;

/// Create a copy of ConversationPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationPageCopyWith<_ConversationPage> get copyWith => __$ConversationPageCopyWithImpl<_ConversationPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'ConversationPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$ConversationPageCopyWith<$Res> implements $ConversationPageCopyWith<$Res> {
  factory _$ConversationPageCopyWith(_ConversationPage value, $Res Function(_ConversationPage) _then) = __$ConversationPageCopyWithImpl;
@override @useResult
$Res call({
 List<Conversation> items, int total, int page,@JsonKey(name: 'pageSize') int pageSize
});




}
/// @nodoc
class __$ConversationPageCopyWithImpl<$Res>
    implements _$ConversationPageCopyWith<$Res> {
  __$ConversationPageCopyWithImpl(this._self, this._then);

  final _ConversationPage _self;
  final $Res Function(_ConversationPage) _then;

/// Create a copy of ConversationPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_ConversationPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Conversation>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
