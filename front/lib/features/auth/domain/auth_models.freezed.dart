// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$User {

 String get id; String get email; String get fullName; bool get emailVerified;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,fullName,emailVerified);

@override
String toString() {
  return 'User(id: $id, email: $email, fullName: $fullName, emailVerified: $emailVerified)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String email, String fullName, bool emailVerified
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? fullName = null,Object? emailVerified = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email,  String fullName,  bool emailVerified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.fullName,_that.emailVerified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email,  String fullName,  bool emailVerified)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.email,_that.fullName,_that.emailVerified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email,  String fullName,  bool emailVerified)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.email,_that.fullName,_that.emailVerified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _User implements User {
  const _User({required this.id, required this.email, required this.fullName, this.emailVerified = false});
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

@override final  String id;
@override final  String email;
@override final  String fullName;
@override@JsonKey() final  bool emailVerified;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,fullName,emailVerified);

@override
String toString() {
  return 'User(id: $id, email: $email, fullName: $fullName, emailVerified: $emailVerified)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String email, String fullName, bool emailVerified
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? fullName = null,Object? emailVerified = null,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$Tenant {

 String get id; String get slug; String get name; String? get cnpj; String? get legalName; String? get tradeName;
/// Create a copy of Tenant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TenantCopyWith<Tenant> get copyWith => _$TenantCopyWithImpl<Tenant>(this as Tenant, _$identity);

  /// Serializes this Tenant to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tenant&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.cnpj, cnpj) || other.cnpj == cnpj)&&(identical(other.legalName, legalName) || other.legalName == legalName)&&(identical(other.tradeName, tradeName) || other.tradeName == tradeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,name,cnpj,legalName,tradeName);

@override
String toString() {
  return 'Tenant(id: $id, slug: $slug, name: $name, cnpj: $cnpj, legalName: $legalName, tradeName: $tradeName)';
}


}

/// @nodoc
abstract mixin class $TenantCopyWith<$Res>  {
  factory $TenantCopyWith(Tenant value, $Res Function(Tenant) _then) = _$TenantCopyWithImpl;
@useResult
$Res call({
 String id, String slug, String name, String? cnpj, String? legalName, String? tradeName
});




}
/// @nodoc
class _$TenantCopyWithImpl<$Res>
    implements $TenantCopyWith<$Res> {
  _$TenantCopyWithImpl(this._self, this._then);

  final Tenant _self;
  final $Res Function(Tenant) _then;

/// Create a copy of Tenant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? cnpj = freezed,Object? legalName = freezed,Object? tradeName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cnpj: freezed == cnpj ? _self.cnpj : cnpj // ignore: cast_nullable_to_non_nullable
as String?,legalName: freezed == legalName ? _self.legalName : legalName // ignore: cast_nullable_to_non_nullable
as String?,tradeName: freezed == tradeName ? _self.tradeName : tradeName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Tenant].
extension TenantPatterns on Tenant {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tenant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tenant() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tenant value)  $default,){
final _that = this;
switch (_that) {
case _Tenant():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tenant value)?  $default,){
final _that = this;
switch (_that) {
case _Tenant() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String slug,  String name,  String? cnpj,  String? legalName,  String? tradeName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tenant() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.cnpj,_that.legalName,_that.tradeName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String slug,  String name,  String? cnpj,  String? legalName,  String? tradeName)  $default,) {final _that = this;
switch (_that) {
case _Tenant():
return $default(_that.id,_that.slug,_that.name,_that.cnpj,_that.legalName,_that.tradeName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String slug,  String name,  String? cnpj,  String? legalName,  String? tradeName)?  $default,) {final _that = this;
switch (_that) {
case _Tenant() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.cnpj,_that.legalName,_that.tradeName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Tenant implements Tenant {
  const _Tenant({required this.id, required this.slug, required this.name, this.cnpj, this.legalName, this.tradeName});
  factory _Tenant.fromJson(Map<String, dynamic> json) => _$TenantFromJson(json);

@override final  String id;
@override final  String slug;
@override final  String name;
@override final  String? cnpj;
@override final  String? legalName;
@override final  String? tradeName;

/// Create a copy of Tenant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TenantCopyWith<_Tenant> get copyWith => __$TenantCopyWithImpl<_Tenant>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TenantToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tenant&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.cnpj, cnpj) || other.cnpj == cnpj)&&(identical(other.legalName, legalName) || other.legalName == legalName)&&(identical(other.tradeName, tradeName) || other.tradeName == tradeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,slug,name,cnpj,legalName,tradeName);

@override
String toString() {
  return 'Tenant(id: $id, slug: $slug, name: $name, cnpj: $cnpj, legalName: $legalName, tradeName: $tradeName)';
}


}

/// @nodoc
abstract mixin class _$TenantCopyWith<$Res> implements $TenantCopyWith<$Res> {
  factory _$TenantCopyWith(_Tenant value, $Res Function(_Tenant) _then) = __$TenantCopyWithImpl;
@override @useResult
$Res call({
 String id, String slug, String name, String? cnpj, String? legalName, String? tradeName
});




}
/// @nodoc
class __$TenantCopyWithImpl<$Res>
    implements _$TenantCopyWith<$Res> {
  __$TenantCopyWithImpl(this._self, this._then);

  final _Tenant _self;
  final $Res Function(_Tenant) _then;

/// Create a copy of Tenant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? cnpj = freezed,Object? legalName = freezed,Object? tradeName = freezed,}) {
  return _then(_Tenant(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cnpj: freezed == cnpj ? _self.cnpj : cnpj // ignore: cast_nullable_to_non_nullable
as String?,legalName: freezed == legalName ? _self.legalName : legalName // ignore: cast_nullable_to_non_nullable
as String?,tradeName: freezed == tradeName ? _self.tradeName : tradeName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Membership {

 String get tenantId; String get tenantSlug; String get role;
/// Create a copy of Membership
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MembershipCopyWith<Membership> get copyWith => _$MembershipCopyWithImpl<Membership>(this as Membership, _$identity);

  /// Serializes this Membership to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Membership&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.tenantSlug, tenantSlug) || other.tenantSlug == tenantSlug)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tenantId,tenantSlug,role);

@override
String toString() {
  return 'Membership(tenantId: $tenantId, tenantSlug: $tenantSlug, role: $role)';
}


}

/// @nodoc
abstract mixin class $MembershipCopyWith<$Res>  {
  factory $MembershipCopyWith(Membership value, $Res Function(Membership) _then) = _$MembershipCopyWithImpl;
@useResult
$Res call({
 String tenantId, String tenantSlug, String role
});




}
/// @nodoc
class _$MembershipCopyWithImpl<$Res>
    implements $MembershipCopyWith<$Res> {
  _$MembershipCopyWithImpl(this._self, this._then);

  final Membership _self;
  final $Res Function(Membership) _then;

/// Create a copy of Membership
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tenantId = null,Object? tenantSlug = null,Object? role = null,}) {
  return _then(_self.copyWith(
tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,tenantSlug: null == tenantSlug ? _self.tenantSlug : tenantSlug // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Membership].
extension MembershipPatterns on Membership {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Membership value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Membership() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Membership value)  $default,){
final _that = this;
switch (_that) {
case _Membership():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Membership value)?  $default,){
final _that = this;
switch (_that) {
case _Membership() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tenantId,  String tenantSlug,  String role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Membership() when $default != null:
return $default(_that.tenantId,_that.tenantSlug,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tenantId,  String tenantSlug,  String role)  $default,) {final _that = this;
switch (_that) {
case _Membership():
return $default(_that.tenantId,_that.tenantSlug,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tenantId,  String tenantSlug,  String role)?  $default,) {final _that = this;
switch (_that) {
case _Membership() when $default != null:
return $default(_that.tenantId,_that.tenantSlug,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Membership implements Membership {
  const _Membership({required this.tenantId, required this.tenantSlug, required this.role});
  factory _Membership.fromJson(Map<String, dynamic> json) => _$MembershipFromJson(json);

@override final  String tenantId;
@override final  String tenantSlug;
@override final  String role;

/// Create a copy of Membership
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MembershipCopyWith<_Membership> get copyWith => __$MembershipCopyWithImpl<_Membership>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MembershipToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Membership&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.tenantSlug, tenantSlug) || other.tenantSlug == tenantSlug)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tenantId,tenantSlug,role);

@override
String toString() {
  return 'Membership(tenantId: $tenantId, tenantSlug: $tenantSlug, role: $role)';
}


}

/// @nodoc
abstract mixin class _$MembershipCopyWith<$Res> implements $MembershipCopyWith<$Res> {
  factory _$MembershipCopyWith(_Membership value, $Res Function(_Membership) _then) = __$MembershipCopyWithImpl;
@override @useResult
$Res call({
 String tenantId, String tenantSlug, String role
});




}
/// @nodoc
class __$MembershipCopyWithImpl<$Res>
    implements _$MembershipCopyWith<$Res> {
  __$MembershipCopyWithImpl(this._self, this._then);

  final _Membership _self;
  final $Res Function(_Membership) _then;

/// Create a copy of Membership
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tenantId = null,Object? tenantSlug = null,Object? role = null,}) {
  return _then(_Membership(
tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,tenantSlug: null == tenantSlug ? _self.tenantSlug : tenantSlug // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Me {

 User get user; Tenant? get activeTenant; String get role; List<String> get permissions; List<String> get modules;/// Nicho do tenant ('veiculos', 'equipamentos'). Manda só no vocabulário.
 String? get vertical;/// Textos do nicho por chave ('objeto.singular', 'os.status.entregue').
/// Vem resolvido do backend: pacote padrão → pacote da vertical → override.
 Map<String, String> get vocab;/// Capacidades ligadas. Gateia a UI do mesmo jeito que [modules], porém
/// abaixo do módulo: 'customers.identifierLookup', 'os.trackingLink'.
 List<String> get features; List<Membership> get memberships;
/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MeCopyWith<Me> get copyWith => _$MeCopyWithImpl<Me>(this as Me, _$identity);

  /// Serializes this Me to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Me&&(identical(other.user, user) || other.user == user)&&(identical(other.activeTenant, activeTenant) || other.activeTenant == activeTenant)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other.permissions, permissions)&&const DeepCollectionEquality().equals(other.modules, modules)&&(identical(other.vertical, vertical) || other.vertical == vertical)&&const DeepCollectionEquality().equals(other.vocab, vocab)&&const DeepCollectionEquality().equals(other.features, features)&&const DeepCollectionEquality().equals(other.memberships, memberships));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user,activeTenant,role,const DeepCollectionEquality().hash(permissions),const DeepCollectionEquality().hash(modules),vertical,const DeepCollectionEquality().hash(vocab),const DeepCollectionEquality().hash(features),const DeepCollectionEquality().hash(memberships));

@override
String toString() {
  return 'Me(user: $user, activeTenant: $activeTenant, role: $role, permissions: $permissions, modules: $modules, vertical: $vertical, vocab: $vocab, features: $features, memberships: $memberships)';
}


}

/// @nodoc
abstract mixin class $MeCopyWith<$Res>  {
  factory $MeCopyWith(Me value, $Res Function(Me) _then) = _$MeCopyWithImpl;
@useResult
$Res call({
 User user, Tenant? activeTenant, String role, List<String> permissions, List<String> modules, String? vertical, Map<String, String> vocab, List<String> features, List<Membership> memberships
});


$UserCopyWith<$Res> get user;$TenantCopyWith<$Res>? get activeTenant;

}
/// @nodoc
class _$MeCopyWithImpl<$Res>
    implements $MeCopyWith<$Res> {
  _$MeCopyWithImpl(this._self, this._then);

  final Me _self;
  final $Res Function(Me) _then;

/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? activeTenant = freezed,Object? role = null,Object? permissions = null,Object? modules = null,Object? vertical = freezed,Object? vocab = null,Object? features = null,Object? memberships = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,activeTenant: freezed == activeTenant ? _self.activeTenant : activeTenant // ignore: cast_nullable_to_non_nullable
as Tenant?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,modules: null == modules ? _self.modules : modules // ignore: cast_nullable_to_non_nullable
as List<String>,vertical: freezed == vertical ? _self.vertical : vertical // ignore: cast_nullable_to_non_nullable
as String?,vocab: null == vocab ? _self.vocab : vocab // ignore: cast_nullable_to_non_nullable
as Map<String, String>,features: null == features ? _self.features : features // ignore: cast_nullable_to_non_nullable
as List<String>,memberships: null == memberships ? _self.memberships : memberships // ignore: cast_nullable_to_non_nullable
as List<Membership>,
  ));
}
/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TenantCopyWith<$Res>? get activeTenant {
    if (_self.activeTenant == null) {
    return null;
  }

  return $TenantCopyWith<$Res>(_self.activeTenant!, (value) {
    return _then(_self.copyWith(activeTenant: value));
  });
}
}


/// Adds pattern-matching-related methods to [Me].
extension MePatterns on Me {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Me value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Me() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Me value)  $default,){
final _that = this;
switch (_that) {
case _Me():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Me value)?  $default,){
final _that = this;
switch (_that) {
case _Me() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( User user,  Tenant? activeTenant,  String role,  List<String> permissions,  List<String> modules,  String? vertical,  Map<String, String> vocab,  List<String> features,  List<Membership> memberships)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Me() when $default != null:
return $default(_that.user,_that.activeTenant,_that.role,_that.permissions,_that.modules,_that.vertical,_that.vocab,_that.features,_that.memberships);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( User user,  Tenant? activeTenant,  String role,  List<String> permissions,  List<String> modules,  String? vertical,  Map<String, String> vocab,  List<String> features,  List<Membership> memberships)  $default,) {final _that = this;
switch (_that) {
case _Me():
return $default(_that.user,_that.activeTenant,_that.role,_that.permissions,_that.modules,_that.vertical,_that.vocab,_that.features,_that.memberships);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( User user,  Tenant? activeTenant,  String role,  List<String> permissions,  List<String> modules,  String? vertical,  Map<String, String> vocab,  List<String> features,  List<Membership> memberships)?  $default,) {final _that = this;
switch (_that) {
case _Me() when $default != null:
return $default(_that.user,_that.activeTenant,_that.role,_that.permissions,_that.modules,_that.vertical,_that.vocab,_that.features,_that.memberships);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Me extends Me {
  const _Me({required this.user, this.activeTenant, required this.role, final  List<String> permissions = const <String>[], final  List<String> modules = const <String>[], this.vertical, final  Map<String, String> vocab = const <String, String>{}, final  List<String> features = const <String>[], final  List<Membership> memberships = const <Membership>[]}): _permissions = permissions,_modules = modules,_vocab = vocab,_features = features,_memberships = memberships,super._();
  factory _Me.fromJson(Map<String, dynamic> json) => _$MeFromJson(json);

@override final  User user;
@override final  Tenant? activeTenant;
@override final  String role;
 final  List<String> _permissions;
@override@JsonKey() List<String> get permissions {
  if (_permissions is EqualUnmodifiableListView) return _permissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_permissions);
}

 final  List<String> _modules;
@override@JsonKey() List<String> get modules {
  if (_modules is EqualUnmodifiableListView) return _modules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modules);
}

/// Nicho do tenant ('veiculos', 'equipamentos'). Manda só no vocabulário.
@override final  String? vertical;
/// Textos do nicho por chave ('objeto.singular', 'os.status.entregue').
/// Vem resolvido do backend: pacote padrão → pacote da vertical → override.
 final  Map<String, String> _vocab;
/// Textos do nicho por chave ('objeto.singular', 'os.status.entregue').
/// Vem resolvido do backend: pacote padrão → pacote da vertical → override.
@override@JsonKey() Map<String, String> get vocab {
  if (_vocab is EqualUnmodifiableMapView) return _vocab;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_vocab);
}

/// Capacidades ligadas. Gateia a UI do mesmo jeito que [modules], porém
/// abaixo do módulo: 'customers.identifierLookup', 'os.trackingLink'.
 final  List<String> _features;
/// Capacidades ligadas. Gateia a UI do mesmo jeito que [modules], porém
/// abaixo do módulo: 'customers.identifierLookup', 'os.trackingLink'.
@override@JsonKey() List<String> get features {
  if (_features is EqualUnmodifiableListView) return _features;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_features);
}

 final  List<Membership> _memberships;
@override@JsonKey() List<Membership> get memberships {
  if (_memberships is EqualUnmodifiableListView) return _memberships;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_memberships);
}


/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MeCopyWith<_Me> get copyWith => __$MeCopyWithImpl<_Me>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Me&&(identical(other.user, user) || other.user == user)&&(identical(other.activeTenant, activeTenant) || other.activeTenant == activeTenant)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other._permissions, _permissions)&&const DeepCollectionEquality().equals(other._modules, _modules)&&(identical(other.vertical, vertical) || other.vertical == vertical)&&const DeepCollectionEquality().equals(other._vocab, _vocab)&&const DeepCollectionEquality().equals(other._features, _features)&&const DeepCollectionEquality().equals(other._memberships, _memberships));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user,activeTenant,role,const DeepCollectionEquality().hash(_permissions),const DeepCollectionEquality().hash(_modules),vertical,const DeepCollectionEquality().hash(_vocab),const DeepCollectionEquality().hash(_features),const DeepCollectionEquality().hash(_memberships));

@override
String toString() {
  return 'Me(user: $user, activeTenant: $activeTenant, role: $role, permissions: $permissions, modules: $modules, vertical: $vertical, vocab: $vocab, features: $features, memberships: $memberships)';
}


}

/// @nodoc
abstract mixin class _$MeCopyWith<$Res> implements $MeCopyWith<$Res> {
  factory _$MeCopyWith(_Me value, $Res Function(_Me) _then) = __$MeCopyWithImpl;
@override @useResult
$Res call({
 User user, Tenant? activeTenant, String role, List<String> permissions, List<String> modules, String? vertical, Map<String, String> vocab, List<String> features, List<Membership> memberships
});


@override $UserCopyWith<$Res> get user;@override $TenantCopyWith<$Res>? get activeTenant;

}
/// @nodoc
class __$MeCopyWithImpl<$Res>
    implements _$MeCopyWith<$Res> {
  __$MeCopyWithImpl(this._self, this._then);

  final _Me _self;
  final $Res Function(_Me) _then;

/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? activeTenant = freezed,Object? role = null,Object? permissions = null,Object? modules = null,Object? vertical = freezed,Object? vocab = null,Object? features = null,Object? memberships = null,}) {
  return _then(_Me(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,activeTenant: freezed == activeTenant ? _self.activeTenant : activeTenant // ignore: cast_nullable_to_non_nullable
as Tenant?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,permissions: null == permissions ? _self._permissions : permissions // ignore: cast_nullable_to_non_nullable
as List<String>,modules: null == modules ? _self._modules : modules // ignore: cast_nullable_to_non_nullable
as List<String>,vertical: freezed == vertical ? _self.vertical : vertical // ignore: cast_nullable_to_non_nullable
as String?,vocab: null == vocab ? _self._vocab : vocab // ignore: cast_nullable_to_non_nullable
as Map<String, String>,features: null == features ? _self._features : features // ignore: cast_nullable_to_non_nullable
as List<String>,memberships: null == memberships ? _self._memberships : memberships // ignore: cast_nullable_to_non_nullable
as List<Membership>,
  ));
}

/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of Me
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TenantCopyWith<$Res>? get activeTenant {
    if (_self.activeTenant == null) {
    return null;
  }

  return $TenantCopyWith<$Res>(_self.activeTenant!, (value) {
    return _then(_self.copyWith(activeTenant: value));
  });
}
}


/// @nodoc
mixin _$Tokens {

 String get accessToken; String get refreshToken;
/// Create a copy of Tokens
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokensCopyWith<Tokens> get copyWith => _$TokensCopyWithImpl<Tokens>(this as Tokens, _$identity);

  /// Serializes this Tokens to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tokens&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken);

@override
String toString() {
  return 'Tokens(accessToken: $accessToken, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class $TokensCopyWith<$Res>  {
  factory $TokensCopyWith(Tokens value, $Res Function(Tokens) _then) = _$TokensCopyWithImpl;
@useResult
$Res call({
 String accessToken, String refreshToken
});




}
/// @nodoc
class _$TokensCopyWithImpl<$Res>
    implements $TokensCopyWith<$Res> {
  _$TokensCopyWithImpl(this._self, this._then);

  final Tokens _self;
  final $Res Function(Tokens) _then;

/// Create a copy of Tokens
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? refreshToken = null,}) {
  return _then(_self.copyWith(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Tokens].
extension TokensPatterns on Tokens {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tokens value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tokens() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tokens value)  $default,){
final _that = this;
switch (_that) {
case _Tokens():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tokens value)?  $default,){
final _that = this;
switch (_that) {
case _Tokens() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tokens() when $default != null:
return $default(_that.accessToken,_that.refreshToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken)  $default,) {final _that = this;
switch (_that) {
case _Tokens():
return $default(_that.accessToken,_that.refreshToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accessToken,  String refreshToken)?  $default,) {final _that = this;
switch (_that) {
case _Tokens() when $default != null:
return $default(_that.accessToken,_that.refreshToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Tokens implements Tokens {
  const _Tokens({required this.accessToken, required this.refreshToken});
  factory _Tokens.fromJson(Map<String, dynamic> json) => _$TokensFromJson(json);

@override final  String accessToken;
@override final  String refreshToken;

/// Create a copy of Tokens
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokensCopyWith<_Tokens> get copyWith => __$TokensCopyWithImpl<_Tokens>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokensToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tokens&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken);

@override
String toString() {
  return 'Tokens(accessToken: $accessToken, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$TokensCopyWith<$Res> implements $TokensCopyWith<$Res> {
  factory _$TokensCopyWith(_Tokens value, $Res Function(_Tokens) _then) = __$TokensCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, String refreshToken
});




}
/// @nodoc
class __$TokensCopyWithImpl<$Res>
    implements _$TokensCopyWith<$Res> {
  __$TokensCopyWithImpl(this._self, this._then);

  final _Tokens _self;
  final $Res Function(_Tokens) _then;

/// Create a copy of Tokens
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,}) {
  return _then(_Tokens(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CnpjCompany {

 String get cnpj; String get razaoSocial; String? get nomeFantasia; String? get situacao; String? get municipio; String? get uf; bool get alreadyRegistered;
/// Create a copy of CnpjCompany
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CnpjCompanyCopyWith<CnpjCompany> get copyWith => _$CnpjCompanyCopyWithImpl<CnpjCompany>(this as CnpjCompany, _$identity);

  /// Serializes this CnpjCompany to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CnpjCompany&&(identical(other.cnpj, cnpj) || other.cnpj == cnpj)&&(identical(other.razaoSocial, razaoSocial) || other.razaoSocial == razaoSocial)&&(identical(other.nomeFantasia, nomeFantasia) || other.nomeFantasia == nomeFantasia)&&(identical(other.situacao, situacao) || other.situacao == situacao)&&(identical(other.municipio, municipio) || other.municipio == municipio)&&(identical(other.uf, uf) || other.uf == uf)&&(identical(other.alreadyRegistered, alreadyRegistered) || other.alreadyRegistered == alreadyRegistered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cnpj,razaoSocial,nomeFantasia,situacao,municipio,uf,alreadyRegistered);

@override
String toString() {
  return 'CnpjCompany(cnpj: $cnpj, razaoSocial: $razaoSocial, nomeFantasia: $nomeFantasia, situacao: $situacao, municipio: $municipio, uf: $uf, alreadyRegistered: $alreadyRegistered)';
}


}

/// @nodoc
abstract mixin class $CnpjCompanyCopyWith<$Res>  {
  factory $CnpjCompanyCopyWith(CnpjCompany value, $Res Function(CnpjCompany) _then) = _$CnpjCompanyCopyWithImpl;
@useResult
$Res call({
 String cnpj, String razaoSocial, String? nomeFantasia, String? situacao, String? municipio, String? uf, bool alreadyRegistered
});




}
/// @nodoc
class _$CnpjCompanyCopyWithImpl<$Res>
    implements $CnpjCompanyCopyWith<$Res> {
  _$CnpjCompanyCopyWithImpl(this._self, this._then);

  final CnpjCompany _self;
  final $Res Function(CnpjCompany) _then;

/// Create a copy of CnpjCompany
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cnpj = null,Object? razaoSocial = null,Object? nomeFantasia = freezed,Object? situacao = freezed,Object? municipio = freezed,Object? uf = freezed,Object? alreadyRegistered = null,}) {
  return _then(_self.copyWith(
cnpj: null == cnpj ? _self.cnpj : cnpj // ignore: cast_nullable_to_non_nullable
as String,razaoSocial: null == razaoSocial ? _self.razaoSocial : razaoSocial // ignore: cast_nullable_to_non_nullable
as String,nomeFantasia: freezed == nomeFantasia ? _self.nomeFantasia : nomeFantasia // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,municipio: freezed == municipio ? _self.municipio : municipio // ignore: cast_nullable_to_non_nullable
as String?,uf: freezed == uf ? _self.uf : uf // ignore: cast_nullable_to_non_nullable
as String?,alreadyRegistered: null == alreadyRegistered ? _self.alreadyRegistered : alreadyRegistered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CnpjCompany].
extension CnpjCompanyPatterns on CnpjCompany {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CnpjCompany value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CnpjCompany() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CnpjCompany value)  $default,){
final _that = this;
switch (_that) {
case _CnpjCompany():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CnpjCompany value)?  $default,){
final _that = this;
switch (_that) {
case _CnpjCompany() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String cnpj,  String razaoSocial,  String? nomeFantasia,  String? situacao,  String? municipio,  String? uf,  bool alreadyRegistered)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CnpjCompany() when $default != null:
return $default(_that.cnpj,_that.razaoSocial,_that.nomeFantasia,_that.situacao,_that.municipio,_that.uf,_that.alreadyRegistered);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String cnpj,  String razaoSocial,  String? nomeFantasia,  String? situacao,  String? municipio,  String? uf,  bool alreadyRegistered)  $default,) {final _that = this;
switch (_that) {
case _CnpjCompany():
return $default(_that.cnpj,_that.razaoSocial,_that.nomeFantasia,_that.situacao,_that.municipio,_that.uf,_that.alreadyRegistered);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String cnpj,  String razaoSocial,  String? nomeFantasia,  String? situacao,  String? municipio,  String? uf,  bool alreadyRegistered)?  $default,) {final _that = this;
switch (_that) {
case _CnpjCompany() when $default != null:
return $default(_that.cnpj,_that.razaoSocial,_that.nomeFantasia,_that.situacao,_that.municipio,_that.uf,_that.alreadyRegistered);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CnpjCompany implements CnpjCompany {
  const _CnpjCompany({required this.cnpj, required this.razaoSocial, this.nomeFantasia, this.situacao, this.municipio, this.uf, this.alreadyRegistered = false});
  factory _CnpjCompany.fromJson(Map<String, dynamic> json) => _$CnpjCompanyFromJson(json);

@override final  String cnpj;
@override final  String razaoSocial;
@override final  String? nomeFantasia;
@override final  String? situacao;
@override final  String? municipio;
@override final  String? uf;
@override@JsonKey() final  bool alreadyRegistered;

/// Create a copy of CnpjCompany
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CnpjCompanyCopyWith<_CnpjCompany> get copyWith => __$CnpjCompanyCopyWithImpl<_CnpjCompany>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CnpjCompanyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CnpjCompany&&(identical(other.cnpj, cnpj) || other.cnpj == cnpj)&&(identical(other.razaoSocial, razaoSocial) || other.razaoSocial == razaoSocial)&&(identical(other.nomeFantasia, nomeFantasia) || other.nomeFantasia == nomeFantasia)&&(identical(other.situacao, situacao) || other.situacao == situacao)&&(identical(other.municipio, municipio) || other.municipio == municipio)&&(identical(other.uf, uf) || other.uf == uf)&&(identical(other.alreadyRegistered, alreadyRegistered) || other.alreadyRegistered == alreadyRegistered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cnpj,razaoSocial,nomeFantasia,situacao,municipio,uf,alreadyRegistered);

@override
String toString() {
  return 'CnpjCompany(cnpj: $cnpj, razaoSocial: $razaoSocial, nomeFantasia: $nomeFantasia, situacao: $situacao, municipio: $municipio, uf: $uf, alreadyRegistered: $alreadyRegistered)';
}


}

/// @nodoc
abstract mixin class _$CnpjCompanyCopyWith<$Res> implements $CnpjCompanyCopyWith<$Res> {
  factory _$CnpjCompanyCopyWith(_CnpjCompany value, $Res Function(_CnpjCompany) _then) = __$CnpjCompanyCopyWithImpl;
@override @useResult
$Res call({
 String cnpj, String razaoSocial, String? nomeFantasia, String? situacao, String? municipio, String? uf, bool alreadyRegistered
});




}
/// @nodoc
class __$CnpjCompanyCopyWithImpl<$Res>
    implements _$CnpjCompanyCopyWith<$Res> {
  __$CnpjCompanyCopyWithImpl(this._self, this._then);

  final _CnpjCompany _self;
  final $Res Function(_CnpjCompany) _then;

/// Create a copy of CnpjCompany
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cnpj = null,Object? razaoSocial = null,Object? nomeFantasia = freezed,Object? situacao = freezed,Object? municipio = freezed,Object? uf = freezed,Object? alreadyRegistered = null,}) {
  return _then(_CnpjCompany(
cnpj: null == cnpj ? _self.cnpj : cnpj // ignore: cast_nullable_to_non_nullable
as String,razaoSocial: null == razaoSocial ? _self.razaoSocial : razaoSocial // ignore: cast_nullable_to_non_nullable
as String,nomeFantasia: freezed == nomeFantasia ? _self.nomeFantasia : nomeFantasia // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,municipio: freezed == municipio ? _self.municipio : municipio // ignore: cast_nullable_to_non_nullable
as String?,uf: freezed == uf ? _self.uf : uf // ignore: cast_nullable_to_non_nullable
as String?,alreadyRegistered: null == alreadyRegistered ? _self.alreadyRegistered : alreadyRegistered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LoginResult {

 String get accessToken; String get refreshToken; User get user; List<Membership> get memberships;
/// Create a copy of LoginResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginResultCopyWith<LoginResult> get copyWith => _$LoginResultCopyWithImpl<LoginResult>(this as LoginResult, _$identity);

  /// Serializes this LoginResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginResult&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.user, user) || other.user == user)&&const DeepCollectionEquality().equals(other.memberships, memberships));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,user,const DeepCollectionEquality().hash(memberships));

@override
String toString() {
  return 'LoginResult(accessToken: $accessToken, refreshToken: $refreshToken, user: $user, memberships: $memberships)';
}


}

/// @nodoc
abstract mixin class $LoginResultCopyWith<$Res>  {
  factory $LoginResultCopyWith(LoginResult value, $Res Function(LoginResult) _then) = _$LoginResultCopyWithImpl;
@useResult
$Res call({
 String accessToken, String refreshToken, User user, List<Membership> memberships
});


$UserCopyWith<$Res> get user;

}
/// @nodoc
class _$LoginResultCopyWithImpl<$Res>
    implements $LoginResultCopyWith<$Res> {
  _$LoginResultCopyWithImpl(this._self, this._then);

  final LoginResult _self;
  final $Res Function(LoginResult) _then;

/// Create a copy of LoginResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? refreshToken = null,Object? user = null,Object? memberships = null,}) {
  return _then(_self.copyWith(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,memberships: null == memberships ? _self.memberships : memberships // ignore: cast_nullable_to_non_nullable
as List<Membership>,
  ));
}
/// Create a copy of LoginResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [LoginResult].
extension LoginResultPatterns on LoginResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginResult value)  $default,){
final _that = this;
switch (_that) {
case _LoginResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginResult value)?  $default,){
final _that = this;
switch (_that) {
case _LoginResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken,  User user,  List<Membership> memberships)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginResult() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.user,_that.memberships);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken,  User user,  List<Membership> memberships)  $default,) {final _that = this;
switch (_that) {
case _LoginResult():
return $default(_that.accessToken,_that.refreshToken,_that.user,_that.memberships);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accessToken,  String refreshToken,  User user,  List<Membership> memberships)?  $default,) {final _that = this;
switch (_that) {
case _LoginResult() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.user,_that.memberships);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginResult implements LoginResult {
  const _LoginResult({required this.accessToken, required this.refreshToken, required this.user, final  List<Membership> memberships = const <Membership>[]}): _memberships = memberships;
  factory _LoginResult.fromJson(Map<String, dynamic> json) => _$LoginResultFromJson(json);

@override final  String accessToken;
@override final  String refreshToken;
@override final  User user;
 final  List<Membership> _memberships;
@override@JsonKey() List<Membership> get memberships {
  if (_memberships is EqualUnmodifiableListView) return _memberships;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_memberships);
}


/// Create a copy of LoginResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginResultCopyWith<_LoginResult> get copyWith => __$LoginResultCopyWithImpl<_LoginResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginResult&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.user, user) || other.user == user)&&const DeepCollectionEquality().equals(other._memberships, _memberships));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,user,const DeepCollectionEquality().hash(_memberships));

@override
String toString() {
  return 'LoginResult(accessToken: $accessToken, refreshToken: $refreshToken, user: $user, memberships: $memberships)';
}


}

/// @nodoc
abstract mixin class _$LoginResultCopyWith<$Res> implements $LoginResultCopyWith<$Res> {
  factory _$LoginResultCopyWith(_LoginResult value, $Res Function(_LoginResult) _then) = __$LoginResultCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, String refreshToken, User user, List<Membership> memberships
});


@override $UserCopyWith<$Res> get user;

}
/// @nodoc
class __$LoginResultCopyWithImpl<$Res>
    implements _$LoginResultCopyWith<$Res> {
  __$LoginResultCopyWithImpl(this._self, this._then);

  final _LoginResult _self;
  final $Res Function(_LoginResult) _then;

/// Create a copy of LoginResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,Object? user = null,Object? memberships = null,}) {
  return _then(_LoginResult(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,memberships: null == memberships ? _self._memberships : memberships // ignore: cast_nullable_to_non_nullable
as List<Membership>,
  ));
}

/// Create a copy of LoginResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// @nodoc
mixin _$RegisterResult {

 String get accessToken; String get refreshToken; User get user; Tenant get tenant;
/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterResultCopyWith<RegisterResult> get copyWith => _$RegisterResultCopyWithImpl<RegisterResult>(this as RegisterResult, _$identity);

  /// Serializes this RegisterResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterResult&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.user, user) || other.user == user)&&(identical(other.tenant, tenant) || other.tenant == tenant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,user,tenant);

@override
String toString() {
  return 'RegisterResult(accessToken: $accessToken, refreshToken: $refreshToken, user: $user, tenant: $tenant)';
}


}

/// @nodoc
abstract mixin class $RegisterResultCopyWith<$Res>  {
  factory $RegisterResultCopyWith(RegisterResult value, $Res Function(RegisterResult) _then) = _$RegisterResultCopyWithImpl;
@useResult
$Res call({
 String accessToken, String refreshToken, User user, Tenant tenant
});


$UserCopyWith<$Res> get user;$TenantCopyWith<$Res> get tenant;

}
/// @nodoc
class _$RegisterResultCopyWithImpl<$Res>
    implements $RegisterResultCopyWith<$Res> {
  _$RegisterResultCopyWithImpl(this._self, this._then);

  final RegisterResult _self;
  final $Res Function(RegisterResult) _then;

/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? refreshToken = null,Object? user = null,Object? tenant = null,}) {
  return _then(_self.copyWith(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,tenant: null == tenant ? _self.tenant : tenant // ignore: cast_nullable_to_non_nullable
as Tenant,
  ));
}
/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TenantCopyWith<$Res> get tenant {
  
  return $TenantCopyWith<$Res>(_self.tenant, (value) {
    return _then(_self.copyWith(tenant: value));
  });
}
}


/// Adds pattern-matching-related methods to [RegisterResult].
extension RegisterResultPatterns on RegisterResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RegisterResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RegisterResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RegisterResult value)  $default,){
final _that = this;
switch (_that) {
case _RegisterResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RegisterResult value)?  $default,){
final _that = this;
switch (_that) {
case _RegisterResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken,  User user,  Tenant tenant)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RegisterResult() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.user,_that.tenant);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accessToken,  String refreshToken,  User user,  Tenant tenant)  $default,) {final _that = this;
switch (_that) {
case _RegisterResult():
return $default(_that.accessToken,_that.refreshToken,_that.user,_that.tenant);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accessToken,  String refreshToken,  User user,  Tenant tenant)?  $default,) {final _that = this;
switch (_that) {
case _RegisterResult() when $default != null:
return $default(_that.accessToken,_that.refreshToken,_that.user,_that.tenant);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RegisterResult implements RegisterResult {
  const _RegisterResult({required this.accessToken, required this.refreshToken, required this.user, required this.tenant});
  factory _RegisterResult.fromJson(Map<String, dynamic> json) => _$RegisterResultFromJson(json);

@override final  String accessToken;
@override final  String refreshToken;
@override final  User user;
@override final  Tenant tenant;

/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterResultCopyWith<_RegisterResult> get copyWith => __$RegisterResultCopyWithImpl<_RegisterResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterResult&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.user, user) || other.user == user)&&(identical(other.tenant, tenant) || other.tenant == tenant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken,refreshToken,user,tenant);

@override
String toString() {
  return 'RegisterResult(accessToken: $accessToken, refreshToken: $refreshToken, user: $user, tenant: $tenant)';
}


}

/// @nodoc
abstract mixin class _$RegisterResultCopyWith<$Res> implements $RegisterResultCopyWith<$Res> {
  factory _$RegisterResultCopyWith(_RegisterResult value, $Res Function(_RegisterResult) _then) = __$RegisterResultCopyWithImpl;
@override @useResult
$Res call({
 String accessToken, String refreshToken, User user, Tenant tenant
});


@override $UserCopyWith<$Res> get user;@override $TenantCopyWith<$Res> get tenant;

}
/// @nodoc
class __$RegisterResultCopyWithImpl<$Res>
    implements _$RegisterResultCopyWith<$Res> {
  __$RegisterResultCopyWithImpl(this._self, this._then);

  final _RegisterResult _self;
  final $Res Function(_RegisterResult) _then;

/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? refreshToken = null,Object? user = null,Object? tenant = null,}) {
  return _then(_RegisterResult(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,tenant: null == tenant ? _self.tenant : tenant // ignore: cast_nullable_to_non_nullable
as Tenant,
  ));
}

/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of RegisterResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TenantCopyWith<$Res> get tenant {
  
  return $TenantCopyWith<$Res>(_self.tenant, (value) {
    return _then(_self.copyWith(tenant: value));
  });
}
}


/// @nodoc
mixin _$VerticalOption {

 String get key; String get nome; bool get isDefault;
/// Create a copy of VerticalOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerticalOptionCopyWith<VerticalOption> get copyWith => _$VerticalOptionCopyWithImpl<VerticalOption>(this as VerticalOption, _$identity);

  /// Serializes this VerticalOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerticalOption&&(identical(other.key, key) || other.key == key)&&(identical(other.nome, nome) || other.nome == nome)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,nome,isDefault);

@override
String toString() {
  return 'VerticalOption(key: $key, nome: $nome, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $VerticalOptionCopyWith<$Res>  {
  factory $VerticalOptionCopyWith(VerticalOption value, $Res Function(VerticalOption) _then) = _$VerticalOptionCopyWithImpl;
@useResult
$Res call({
 String key, String nome, bool isDefault
});




}
/// @nodoc
class _$VerticalOptionCopyWithImpl<$Res>
    implements $VerticalOptionCopyWith<$Res> {
  _$VerticalOptionCopyWithImpl(this._self, this._then);

  final VerticalOption _self;
  final $Res Function(VerticalOption) _then;

/// Create a copy of VerticalOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? nome = null,Object? isDefault = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,nome: null == nome ? _self.nome : nome // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VerticalOption].
extension VerticalOptionPatterns on VerticalOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerticalOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerticalOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerticalOption value)  $default,){
final _that = this;
switch (_that) {
case _VerticalOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerticalOption value)?  $default,){
final _that = this;
switch (_that) {
case _VerticalOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String nome,  bool isDefault)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerticalOption() when $default != null:
return $default(_that.key,_that.nome,_that.isDefault);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String nome,  bool isDefault)  $default,) {final _that = this;
switch (_that) {
case _VerticalOption():
return $default(_that.key,_that.nome,_that.isDefault);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String nome,  bool isDefault)?  $default,) {final _that = this;
switch (_that) {
case _VerticalOption() when $default != null:
return $default(_that.key,_that.nome,_that.isDefault);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VerticalOption implements VerticalOption {
  const _VerticalOption({required this.key, required this.nome, this.isDefault = false});
  factory _VerticalOption.fromJson(Map<String, dynamic> json) => _$VerticalOptionFromJson(json);

@override final  String key;
@override final  String nome;
@override@JsonKey() final  bool isDefault;

/// Create a copy of VerticalOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerticalOptionCopyWith<_VerticalOption> get copyWith => __$VerticalOptionCopyWithImpl<_VerticalOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerticalOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerticalOption&&(identical(other.key, key) || other.key == key)&&(identical(other.nome, nome) || other.nome == nome)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,nome,isDefault);

@override
String toString() {
  return 'VerticalOption(key: $key, nome: $nome, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$VerticalOptionCopyWith<$Res> implements $VerticalOptionCopyWith<$Res> {
  factory _$VerticalOptionCopyWith(_VerticalOption value, $Res Function(_VerticalOption) _then) = __$VerticalOptionCopyWithImpl;
@override @useResult
$Res call({
 String key, String nome, bool isDefault
});




}
/// @nodoc
class __$VerticalOptionCopyWithImpl<$Res>
    implements _$VerticalOptionCopyWith<$Res> {
  __$VerticalOptionCopyWithImpl(this._self, this._then);

  final _VerticalOption _self;
  final $Res Function(_VerticalOption) _then;

/// Create a copy of VerticalOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? nome = null,Object? isDefault = null,}) {
  return _then(_VerticalOption(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,nome: null == nome ? _self.nome : nome // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
