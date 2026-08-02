// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppUpdate {

 bool get enabled; String? get platform; String? get version; int? get buildNumber;/// Menor versão que o servidor ainda atende. Abaixo disso o app precisa
/// atualizar para continuar funcionando.
 String? get minSupported;/// Build mínimo aceito DENTRO da mesma versão. Necessário porque o número
/// da versão não muda a cada publicação: sem isto, 1.0.0+13 não seria
/// reconhecido como mais novo que 1.0.0+12.
 int? get minSupportedBuild; String? get notes; String? get url;/// Hash do arquivo; conferido antes de instalar.
 String? get sha256; int? get sizeBytes; String? get publishedAt;
/// Create a copy of AppUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppUpdateCopyWith<AppUpdate> get copyWith => _$AppUpdateCopyWithImpl<AppUpdate>(this as AppUpdate, _$identity);

  /// Serializes this AppUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppUpdate&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.version, version) || other.version == version)&&(identical(other.buildNumber, buildNumber) || other.buildNumber == buildNumber)&&(identical(other.minSupported, minSupported) || other.minSupported == minSupported)&&(identical(other.minSupportedBuild, minSupportedBuild) || other.minSupportedBuild == minSupportedBuild)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.url, url) || other.url == url)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,platform,version,buildNumber,minSupported,minSupportedBuild,notes,url,sha256,sizeBytes,publishedAt);

@override
String toString() {
  return 'AppUpdate(enabled: $enabled, platform: $platform, version: $version, buildNumber: $buildNumber, minSupported: $minSupported, minSupportedBuild: $minSupportedBuild, notes: $notes, url: $url, sha256: $sha256, sizeBytes: $sizeBytes, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class $AppUpdateCopyWith<$Res>  {
  factory $AppUpdateCopyWith(AppUpdate value, $Res Function(AppUpdate) _then) = _$AppUpdateCopyWithImpl;
@useResult
$Res call({
 bool enabled, String? platform, String? version, int? buildNumber, String? minSupported, int? minSupportedBuild, String? notes, String? url, String? sha256, int? sizeBytes, String? publishedAt
});




}
/// @nodoc
class _$AppUpdateCopyWithImpl<$Res>
    implements $AppUpdateCopyWith<$Res> {
  _$AppUpdateCopyWithImpl(this._self, this._then);

  final AppUpdate _self;
  final $Res Function(AppUpdate) _then;

/// Create a copy of AppUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? platform = freezed,Object? version = freezed,Object? buildNumber = freezed,Object? minSupported = freezed,Object? minSupportedBuild = freezed,Object? notes = freezed,Object? url = freezed,Object? sha256 = freezed,Object? sizeBytes = freezed,Object? publishedAt = freezed,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,buildNumber: freezed == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as int?,minSupported: freezed == minSupported ? _self.minSupported : minSupported // ignore: cast_nullable_to_non_nullable
as String?,minSupportedBuild: freezed == minSupportedBuild ? _self.minSupportedBuild : minSupportedBuild // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,sizeBytes: freezed == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int?,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppUpdate].
extension AppUpdatePatterns on AppUpdate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppUpdate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppUpdate value)  $default,){
final _that = this;
switch (_that) {
case _AppUpdate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _AppUpdate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  String? platform,  String? version,  int? buildNumber,  String? minSupported,  int? minSupportedBuild,  String? notes,  String? url,  String? sha256,  int? sizeBytes,  String? publishedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppUpdate() when $default != null:
return $default(_that.enabled,_that.platform,_that.version,_that.buildNumber,_that.minSupported,_that.minSupportedBuild,_that.notes,_that.url,_that.sha256,_that.sizeBytes,_that.publishedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  String? platform,  String? version,  int? buildNumber,  String? minSupported,  int? minSupportedBuild,  String? notes,  String? url,  String? sha256,  int? sizeBytes,  String? publishedAt)  $default,) {final _that = this;
switch (_that) {
case _AppUpdate():
return $default(_that.enabled,_that.platform,_that.version,_that.buildNumber,_that.minSupported,_that.minSupportedBuild,_that.notes,_that.url,_that.sha256,_that.sizeBytes,_that.publishedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  String? platform,  String? version,  int? buildNumber,  String? minSupported,  int? minSupportedBuild,  String? notes,  String? url,  String? sha256,  int? sizeBytes,  String? publishedAt)?  $default,) {final _that = this;
switch (_that) {
case _AppUpdate() when $default != null:
return $default(_that.enabled,_that.platform,_that.version,_that.buildNumber,_that.minSupported,_that.minSupportedBuild,_that.notes,_that.url,_that.sha256,_that.sizeBytes,_that.publishedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppUpdate extends AppUpdate {
  const _AppUpdate({this.enabled = false, this.platform, this.version, this.buildNumber, this.minSupported, this.minSupportedBuild, this.notes, this.url, this.sha256, this.sizeBytes, this.publishedAt}): super._();
  factory _AppUpdate.fromJson(Map<String, dynamic> json) => _$AppUpdateFromJson(json);

@override@JsonKey() final  bool enabled;
@override final  String? platform;
@override final  String? version;
@override final  int? buildNumber;
/// Menor versão que o servidor ainda atende. Abaixo disso o app precisa
/// atualizar para continuar funcionando.
@override final  String? minSupported;
/// Build mínimo aceito DENTRO da mesma versão. Necessário porque o número
/// da versão não muda a cada publicação: sem isto, 1.0.0+13 não seria
/// reconhecido como mais novo que 1.0.0+12.
@override final  int? minSupportedBuild;
@override final  String? notes;
@override final  String? url;
/// Hash do arquivo; conferido antes de instalar.
@override final  String? sha256;
@override final  int? sizeBytes;
@override final  String? publishedAt;

/// Create a copy of AppUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppUpdateCopyWith<_AppUpdate> get copyWith => __$AppUpdateCopyWithImpl<_AppUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppUpdate&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.version, version) || other.version == version)&&(identical(other.buildNumber, buildNumber) || other.buildNumber == buildNumber)&&(identical(other.minSupported, minSupported) || other.minSupported == minSupported)&&(identical(other.minSupportedBuild, minSupportedBuild) || other.minSupportedBuild == minSupportedBuild)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.url, url) || other.url == url)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,platform,version,buildNumber,minSupported,minSupportedBuild,notes,url,sha256,sizeBytes,publishedAt);

@override
String toString() {
  return 'AppUpdate(enabled: $enabled, platform: $platform, version: $version, buildNumber: $buildNumber, minSupported: $minSupported, minSupportedBuild: $minSupportedBuild, notes: $notes, url: $url, sha256: $sha256, sizeBytes: $sizeBytes, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class _$AppUpdateCopyWith<$Res> implements $AppUpdateCopyWith<$Res> {
  factory _$AppUpdateCopyWith(_AppUpdate value, $Res Function(_AppUpdate) _then) = __$AppUpdateCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, String? platform, String? version, int? buildNumber, String? minSupported, int? minSupportedBuild, String? notes, String? url, String? sha256, int? sizeBytes, String? publishedAt
});




}
/// @nodoc
class __$AppUpdateCopyWithImpl<$Res>
    implements _$AppUpdateCopyWith<$Res> {
  __$AppUpdateCopyWithImpl(this._self, this._then);

  final _AppUpdate _self;
  final $Res Function(_AppUpdate) _then;

/// Create a copy of AppUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? platform = freezed,Object? version = freezed,Object? buildNumber = freezed,Object? minSupported = freezed,Object? minSupportedBuild = freezed,Object? notes = freezed,Object? url = freezed,Object? sha256 = freezed,Object? sizeBytes = freezed,Object? publishedAt = freezed,}) {
  return _then(_AppUpdate(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,buildNumber: freezed == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as int?,minSupported: freezed == minSupported ? _self.minSupported : minSupported // ignore: cast_nullable_to_non_nullable
as String?,minSupportedBuild: freezed == minSupportedBuild ? _self.minSupportedBuild : minSupportedBuild // ignore: cast_nullable_to_non_nullable
as int?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,sizeBytes: freezed == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int?,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
