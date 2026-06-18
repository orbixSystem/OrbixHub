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
mixin _$PublicCompany {

 String get name; String? get logoUrl; String? get primaryColor;
/// Create a copy of PublicCompany
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicCompanyCopyWith<PublicCompany> get copyWith => _$PublicCompanyCopyWithImpl<PublicCompany>(this as PublicCompany, _$identity);

  /// Serializes this PublicCompany to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicCompany&&(identical(other.name, name) || other.name == name)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.primaryColor, primaryColor) || other.primaryColor == primaryColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,logoUrl,primaryColor);

@override
String toString() {
  return 'PublicCompany(name: $name, logoUrl: $logoUrl, primaryColor: $primaryColor)';
}


}

/// @nodoc
abstract mixin class $PublicCompanyCopyWith<$Res>  {
  factory $PublicCompanyCopyWith(PublicCompany value, $Res Function(PublicCompany) _then) = _$PublicCompanyCopyWithImpl;
@useResult
$Res call({
 String name, String? logoUrl, String? primaryColor
});




}
/// @nodoc
class _$PublicCompanyCopyWithImpl<$Res>
    implements $PublicCompanyCopyWith<$Res> {
  _$PublicCompanyCopyWithImpl(this._self, this._then);

  final PublicCompany _self;
  final $Res Function(PublicCompany) _then;

/// Create a copy of PublicCompany
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? logoUrl = freezed,Object? primaryColor = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,primaryColor: freezed == primaryColor ? _self.primaryColor : primaryColor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicCompany].
extension PublicCompanyPatterns on PublicCompany {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicCompany value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicCompany() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicCompany value)  $default,){
final _that = this;
switch (_that) {
case _PublicCompany():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicCompany value)?  $default,){
final _that = this;
switch (_that) {
case _PublicCompany() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? logoUrl,  String? primaryColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicCompany() when $default != null:
return $default(_that.name,_that.logoUrl,_that.primaryColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? logoUrl,  String? primaryColor)  $default,) {final _that = this;
switch (_that) {
case _PublicCompany():
return $default(_that.name,_that.logoUrl,_that.primaryColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? logoUrl,  String? primaryColor)?  $default,) {final _that = this;
switch (_that) {
case _PublicCompany() when $default != null:
return $default(_that.name,_that.logoUrl,_that.primaryColor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicCompany implements PublicCompany {
  const _PublicCompany({this.name = '', this.logoUrl, this.primaryColor});
  factory _PublicCompany.fromJson(Map<String, dynamic> json) => _$PublicCompanyFromJson(json);

@override@JsonKey() final  String name;
@override final  String? logoUrl;
@override final  String? primaryColor;

/// Create a copy of PublicCompany
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicCompanyCopyWith<_PublicCompany> get copyWith => __$PublicCompanyCopyWithImpl<_PublicCompany>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicCompanyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicCompany&&(identical(other.name, name) || other.name == name)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.primaryColor, primaryColor) || other.primaryColor == primaryColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,logoUrl,primaryColor);

@override
String toString() {
  return 'PublicCompany(name: $name, logoUrl: $logoUrl, primaryColor: $primaryColor)';
}


}

/// @nodoc
abstract mixin class _$PublicCompanyCopyWith<$Res> implements $PublicCompanyCopyWith<$Res> {
  factory _$PublicCompanyCopyWith(_PublicCompany value, $Res Function(_PublicCompany) _then) = __$PublicCompanyCopyWithImpl;
@override @useResult
$Res call({
 String name, String? logoUrl, String? primaryColor
});




}
/// @nodoc
class __$PublicCompanyCopyWithImpl<$Res>
    implements _$PublicCompanyCopyWith<$Res> {
  __$PublicCompanyCopyWithImpl(this._self, this._then);

  final _PublicCompany _self;
  final $Res Function(_PublicCompany) _then;

/// Create a copy of PublicCompany
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? logoUrl = freezed,Object? primaryColor = freezed,}) {
  return _then(_PublicCompany(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,primaryColor: freezed == primaryColor ? _self.primaryColor : primaryColor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PublicPhoto {

 String get url; String? get caption;
/// Create a copy of PublicPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicPhotoCopyWith<PublicPhoto> get copyWith => _$PublicPhotoCopyWithImpl<PublicPhoto>(this as PublicPhoto, _$identity);

  /// Serializes this PublicPhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicPhoto&&(identical(other.url, url) || other.url == url)&&(identical(other.caption, caption) || other.caption == caption));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,caption);

@override
String toString() {
  return 'PublicPhoto(url: $url, caption: $caption)';
}


}

/// @nodoc
abstract mixin class $PublicPhotoCopyWith<$Res>  {
  factory $PublicPhotoCopyWith(PublicPhoto value, $Res Function(PublicPhoto) _then) = _$PublicPhotoCopyWithImpl;
@useResult
$Res call({
 String url, String? caption
});




}
/// @nodoc
class _$PublicPhotoCopyWithImpl<$Res>
    implements $PublicPhotoCopyWith<$Res> {
  _$PublicPhotoCopyWithImpl(this._self, this._then);

  final PublicPhoto _self;
  final $Res Function(PublicPhoto) _then;

/// Create a copy of PublicPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? caption = freezed,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicPhoto].
extension PublicPhotoPatterns on PublicPhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicPhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicPhoto value)  $default,){
final _that = this;
switch (_that) {
case _PublicPhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _PublicPhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String? caption)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicPhoto() when $default != null:
return $default(_that.url,_that.caption);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String? caption)  $default,) {final _that = this;
switch (_that) {
case _PublicPhoto():
return $default(_that.url,_that.caption);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String? caption)?  $default,) {final _that = this;
switch (_that) {
case _PublicPhoto() when $default != null:
return $default(_that.url,_that.caption);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicPhoto implements PublicPhoto {
  const _PublicPhoto({required this.url, this.caption});
  factory _PublicPhoto.fromJson(Map<String, dynamic> json) => _$PublicPhotoFromJson(json);

@override final  String url;
@override final  String? caption;

/// Create a copy of PublicPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicPhotoCopyWith<_PublicPhoto> get copyWith => __$PublicPhotoCopyWithImpl<_PublicPhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicPhotoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicPhoto&&(identical(other.url, url) || other.url == url)&&(identical(other.caption, caption) || other.caption == caption));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,caption);

@override
String toString() {
  return 'PublicPhoto(url: $url, caption: $caption)';
}


}

/// @nodoc
abstract mixin class _$PublicPhotoCopyWith<$Res> implements $PublicPhotoCopyWith<$Res> {
  factory _$PublicPhotoCopyWith(_PublicPhoto value, $Res Function(_PublicPhoto) _then) = __$PublicPhotoCopyWithImpl;
@override @useResult
$Res call({
 String url, String? caption
});




}
/// @nodoc
class __$PublicPhotoCopyWithImpl<$Res>
    implements _$PublicPhotoCopyWith<$Res> {
  __$PublicPhotoCopyWithImpl(this._self, this._then);

  final _PublicPhoto _self;
  final $Res Function(_PublicPhoto) _then;

/// Create a copy of PublicPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? caption = freezed,}) {
  return _then(_PublicPhoto(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PublicEvent {

 String get kind; String? get message; String? get statusSnapshot; String? get createdAt;
/// Create a copy of PublicEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicEventCopyWith<PublicEvent> get copyWith => _$PublicEventCopyWithImpl<PublicEvent>(this as PublicEvent, _$identity);

  /// Serializes this PublicEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicEvent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message)&&(identical(other.statusSnapshot, statusSnapshot) || other.statusSnapshot == statusSnapshot)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,message,statusSnapshot,createdAt);

@override
String toString() {
  return 'PublicEvent(kind: $kind, message: $message, statusSnapshot: $statusSnapshot, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PublicEventCopyWith<$Res>  {
  factory $PublicEventCopyWith(PublicEvent value, $Res Function(PublicEvent) _then) = _$PublicEventCopyWithImpl;
@useResult
$Res call({
 String kind, String? message, String? statusSnapshot, String? createdAt
});




}
/// @nodoc
class _$PublicEventCopyWithImpl<$Res>
    implements $PublicEventCopyWith<$Res> {
  _$PublicEventCopyWithImpl(this._self, this._then);

  final PublicEvent _self;
  final $Res Function(PublicEvent) _then;

/// Create a copy of PublicEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? message = freezed,Object? statusSnapshot = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,statusSnapshot: freezed == statusSnapshot ? _self.statusSnapshot : statusSnapshot // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicEvent].
extension PublicEventPatterns on PublicEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicEvent value)  $default,){
final _that = this;
switch (_that) {
case _PublicEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicEvent value)?  $default,){
final _that = this;
switch (_that) {
case _PublicEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String? message,  String? statusSnapshot,  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicEvent() when $default != null:
return $default(_that.kind,_that.message,_that.statusSnapshot,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String? message,  String? statusSnapshot,  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _PublicEvent():
return $default(_that.kind,_that.message,_that.statusSnapshot,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String? message,  String? statusSnapshot,  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PublicEvent() when $default != null:
return $default(_that.kind,_that.message,_that.statusSnapshot,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicEvent implements PublicEvent {
  const _PublicEvent({this.kind = 'note', this.message, this.statusSnapshot, this.createdAt});
  factory _PublicEvent.fromJson(Map<String, dynamic> json) => _$PublicEventFromJson(json);

@override@JsonKey() final  String kind;
@override final  String? message;
@override final  String? statusSnapshot;
@override final  String? createdAt;

/// Create a copy of PublicEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicEventCopyWith<_PublicEvent> get copyWith => __$PublicEventCopyWithImpl<_PublicEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicEvent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message)&&(identical(other.statusSnapshot, statusSnapshot) || other.statusSnapshot == statusSnapshot)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,message,statusSnapshot,createdAt);

@override
String toString() {
  return 'PublicEvent(kind: $kind, message: $message, statusSnapshot: $statusSnapshot, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PublicEventCopyWith<$Res> implements $PublicEventCopyWith<$Res> {
  factory _$PublicEventCopyWith(_PublicEvent value, $Res Function(_PublicEvent) _then) = __$PublicEventCopyWithImpl;
@override @useResult
$Res call({
 String kind, String? message, String? statusSnapshot, String? createdAt
});




}
/// @nodoc
class __$PublicEventCopyWithImpl<$Res>
    implements _$PublicEventCopyWith<$Res> {
  __$PublicEventCopyWithImpl(this._self, this._then);

  final _PublicEvent _self;
  final $Res Function(_PublicEvent) _then;

/// Create a copy of PublicEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? message = freezed,Object? statusSnapshot = freezed,Object? createdAt = freezed,}) {
  return _then(_PublicEvent(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,statusSnapshot: freezed == statusSnapshot ? _self.statusSnapshot : statusSnapshot // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PublicTrack {

 String get number; String get status; String get statusLabel; String? get subjectLabel; String? get scheduledEnd; String? get diagnosis; List<PublicPhoto> get photos; List<PublicEvent> get timeline; PublicCompany get company;
/// Create a copy of PublicTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicTrackCopyWith<PublicTrack> get copyWith => _$PublicTrackCopyWithImpl<PublicTrack>(this as PublicTrack, _$identity);

  /// Serializes this PublicTrack to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicTrack&&(identical(other.number, number) || other.number == number)&&(identical(other.status, status) || other.status == status)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd)&&(identical(other.diagnosis, diagnosis) || other.diagnosis == diagnosis)&&const DeepCollectionEquality().equals(other.photos, photos)&&const DeepCollectionEquality().equals(other.timeline, timeline)&&(identical(other.company, company) || other.company == company));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,status,statusLabel,subjectLabel,scheduledEnd,diagnosis,const DeepCollectionEquality().hash(photos),const DeepCollectionEquality().hash(timeline),company);

@override
String toString() {
  return 'PublicTrack(number: $number, status: $status, statusLabel: $statusLabel, subjectLabel: $subjectLabel, scheduledEnd: $scheduledEnd, diagnosis: $diagnosis, photos: $photos, timeline: $timeline, company: $company)';
}


}

/// @nodoc
abstract mixin class $PublicTrackCopyWith<$Res>  {
  factory $PublicTrackCopyWith(PublicTrack value, $Res Function(PublicTrack) _then) = _$PublicTrackCopyWithImpl;
@useResult
$Res call({
 String number, String status, String statusLabel, String? subjectLabel, String? scheduledEnd, String? diagnosis, List<PublicPhoto> photos, List<PublicEvent> timeline, PublicCompany company
});


$PublicCompanyCopyWith<$Res> get company;

}
/// @nodoc
class _$PublicTrackCopyWithImpl<$Res>
    implements $PublicTrackCopyWith<$Res> {
  _$PublicTrackCopyWithImpl(this._self, this._then);

  final PublicTrack _self;
  final $Res Function(PublicTrack) _then;

/// Create a copy of PublicTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? status = null,Object? statusLabel = null,Object? subjectLabel = freezed,Object? scheduledEnd = freezed,Object? diagnosis = freezed,Object? photos = null,Object? timeline = null,Object? company = null,}) {
  return _then(_self.copyWith(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,statusLabel: null == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,diagnosis: freezed == diagnosis ? _self.diagnosis : diagnosis // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<PublicPhoto>,timeline: null == timeline ? _self.timeline : timeline // ignore: cast_nullable_to_non_nullable
as List<PublicEvent>,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as PublicCompany,
  ));
}
/// Create a copy of PublicTrack
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicCompanyCopyWith<$Res> get company {
  
  return $PublicCompanyCopyWith<$Res>(_self.company, (value) {
    return _then(_self.copyWith(company: value));
  });
}
}


/// Adds pattern-matching-related methods to [PublicTrack].
extension PublicTrackPatterns on PublicTrack {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicTrack() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicTrack value)  $default,){
final _that = this;
switch (_that) {
case _PublicTrack():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicTrack value)?  $default,){
final _that = this;
switch (_that) {
case _PublicTrack() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String number,  String status,  String statusLabel,  String? subjectLabel,  String? scheduledEnd,  String? diagnosis,  List<PublicPhoto> photos,  List<PublicEvent> timeline,  PublicCompany company)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicTrack() when $default != null:
return $default(_that.number,_that.status,_that.statusLabel,_that.subjectLabel,_that.scheduledEnd,_that.diagnosis,_that.photos,_that.timeline,_that.company);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String number,  String status,  String statusLabel,  String? subjectLabel,  String? scheduledEnd,  String? diagnosis,  List<PublicPhoto> photos,  List<PublicEvent> timeline,  PublicCompany company)  $default,) {final _that = this;
switch (_that) {
case _PublicTrack():
return $default(_that.number,_that.status,_that.statusLabel,_that.subjectLabel,_that.scheduledEnd,_that.diagnosis,_that.photos,_that.timeline,_that.company);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String number,  String status,  String statusLabel,  String? subjectLabel,  String? scheduledEnd,  String? diagnosis,  List<PublicPhoto> photos,  List<PublicEvent> timeline,  PublicCompany company)?  $default,) {final _that = this;
switch (_that) {
case _PublicTrack() when $default != null:
return $default(_that.number,_that.status,_that.statusLabel,_that.subjectLabel,_that.scheduledEnd,_that.diagnosis,_that.photos,_that.timeline,_that.company);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicTrack implements PublicTrack {
  const _PublicTrack({this.number = '', this.status = '', this.statusLabel = '', this.subjectLabel, this.scheduledEnd, this.diagnosis, final  List<PublicPhoto> photos = const <PublicPhoto>[], final  List<PublicEvent> timeline = const <PublicEvent>[], this.company = const PublicCompany()}): _photos = photos,_timeline = timeline;
  factory _PublicTrack.fromJson(Map<String, dynamic> json) => _$PublicTrackFromJson(json);

@override@JsonKey() final  String number;
@override@JsonKey() final  String status;
@override@JsonKey() final  String statusLabel;
@override final  String? subjectLabel;
@override final  String? scheduledEnd;
@override final  String? diagnosis;
 final  List<PublicPhoto> _photos;
@override@JsonKey() List<PublicPhoto> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

 final  List<PublicEvent> _timeline;
@override@JsonKey() List<PublicEvent> get timeline {
  if (_timeline is EqualUnmodifiableListView) return _timeline;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_timeline);
}

@override@JsonKey() final  PublicCompany company;

/// Create a copy of PublicTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicTrackCopyWith<_PublicTrack> get copyWith => __$PublicTrackCopyWithImpl<_PublicTrack>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicTrackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicTrack&&(identical(other.number, number) || other.number == number)&&(identical(other.status, status) || other.status == status)&&(identical(other.statusLabel, statusLabel) || other.statusLabel == statusLabel)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel)&&(identical(other.scheduledEnd, scheduledEnd) || other.scheduledEnd == scheduledEnd)&&(identical(other.diagnosis, diagnosis) || other.diagnosis == diagnosis)&&const DeepCollectionEquality().equals(other._photos, _photos)&&const DeepCollectionEquality().equals(other._timeline, _timeline)&&(identical(other.company, company) || other.company == company));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,status,statusLabel,subjectLabel,scheduledEnd,diagnosis,const DeepCollectionEquality().hash(_photos),const DeepCollectionEquality().hash(_timeline),company);

@override
String toString() {
  return 'PublicTrack(number: $number, status: $status, statusLabel: $statusLabel, subjectLabel: $subjectLabel, scheduledEnd: $scheduledEnd, diagnosis: $diagnosis, photos: $photos, timeline: $timeline, company: $company)';
}


}

/// @nodoc
abstract mixin class _$PublicTrackCopyWith<$Res> implements $PublicTrackCopyWith<$Res> {
  factory _$PublicTrackCopyWith(_PublicTrack value, $Res Function(_PublicTrack) _then) = __$PublicTrackCopyWithImpl;
@override @useResult
$Res call({
 String number, String status, String statusLabel, String? subjectLabel, String? scheduledEnd, String? diagnosis, List<PublicPhoto> photos, List<PublicEvent> timeline, PublicCompany company
});


@override $PublicCompanyCopyWith<$Res> get company;

}
/// @nodoc
class __$PublicTrackCopyWithImpl<$Res>
    implements _$PublicTrackCopyWith<$Res> {
  __$PublicTrackCopyWithImpl(this._self, this._then);

  final _PublicTrack _self;
  final $Res Function(_PublicTrack) _then;

/// Create a copy of PublicTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? status = null,Object? statusLabel = null,Object? subjectLabel = freezed,Object? scheduledEnd = freezed,Object? diagnosis = freezed,Object? photos = null,Object? timeline = null,Object? company = null,}) {
  return _then(_PublicTrack(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,statusLabel: null == statusLabel ? _self.statusLabel : statusLabel // ignore: cast_nullable_to_non_nullable
as String,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,scheduledEnd: freezed == scheduledEnd ? _self.scheduledEnd : scheduledEnd // ignore: cast_nullable_to_non_nullable
as String?,diagnosis: freezed == diagnosis ? _self.diagnosis : diagnosis // ignore: cast_nullable_to_non_nullable
as String?,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<PublicPhoto>,timeline: null == timeline ? _self._timeline : timeline // ignore: cast_nullable_to_non_nullable
as List<PublicEvent>,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as PublicCompany,
  ));
}

/// Create a copy of PublicTrack
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicCompanyCopyWith<$Res> get company {
  
  return $PublicCompanyCopyWith<$Res>(_self.company, (value) {
    return _then(_self.copyWith(company: value));
  });
}
}


/// @nodoc
mixin _$PublicMessage {

 String get sender; String? get authorName; String get body; String? get createdAt;
/// Create a copy of PublicMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicMessageCopyWith<PublicMessage> get copyWith => _$PublicMessageCopyWithImpl<PublicMessage>(this as PublicMessage, _$identity);

  /// Serializes this PublicMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicMessage&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sender,authorName,body,createdAt);

@override
String toString() {
  return 'PublicMessage(sender: $sender, authorName: $authorName, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PublicMessageCopyWith<$Res>  {
  factory $PublicMessageCopyWith(PublicMessage value, $Res Function(PublicMessage) _then) = _$PublicMessageCopyWithImpl;
@useResult
$Res call({
 String sender, String? authorName, String body, String? createdAt
});




}
/// @nodoc
class _$PublicMessageCopyWithImpl<$Res>
    implements $PublicMessageCopyWith<$Res> {
  _$PublicMessageCopyWithImpl(this._self, this._then);

  final PublicMessage _self;
  final $Res Function(PublicMessage) _then;

/// Create a copy of PublicMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sender = null,Object? authorName = freezed,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicMessage].
extension PublicMessagePatterns on PublicMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicMessage value)  $default,){
final _that = this;
switch (_that) {
case _PublicMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicMessage value)?  $default,){
final _that = this;
switch (_that) {
case _PublicMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sender,  String? authorName,  String body,  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicMessage() when $default != null:
return $default(_that.sender,_that.authorName,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sender,  String? authorName,  String body,  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _PublicMessage():
return $default(_that.sender,_that.authorName,_that.body,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sender,  String? authorName,  String body,  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PublicMessage() when $default != null:
return $default(_that.sender,_that.authorName,_that.body,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicMessage implements PublicMessage {
  const _PublicMessage({this.sender = 'staff', this.authorName, this.body = '', this.createdAt});
  factory _PublicMessage.fromJson(Map<String, dynamic> json) => _$PublicMessageFromJson(json);

@override@JsonKey() final  String sender;
@override final  String? authorName;
@override@JsonKey() final  String body;
@override final  String? createdAt;

/// Create a copy of PublicMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicMessageCopyWith<_PublicMessage> get copyWith => __$PublicMessageCopyWithImpl<_PublicMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicMessage&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sender,authorName,body,createdAt);

@override
String toString() {
  return 'PublicMessage(sender: $sender, authorName: $authorName, body: $body, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PublicMessageCopyWith<$Res> implements $PublicMessageCopyWith<$Res> {
  factory _$PublicMessageCopyWith(_PublicMessage value, $Res Function(_PublicMessage) _then) = __$PublicMessageCopyWithImpl;
@override @useResult
$Res call({
 String sender, String? authorName, String body, String? createdAt
});




}
/// @nodoc
class __$PublicMessageCopyWithImpl<$Res>
    implements _$PublicMessageCopyWith<$Res> {
  __$PublicMessageCopyWithImpl(this._self, this._then);

  final _PublicMessage _self;
  final $Res Function(_PublicMessage) _then;

/// Create a copy of PublicMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sender = null,Object? authorName = freezed,Object? body = null,Object? createdAt = freezed,}) {
  return _then(_PublicMessage(
sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,authorName: freezed == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String?,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
