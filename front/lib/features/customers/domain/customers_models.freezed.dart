// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'customers_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Customer {

 String get id; String get name; String get type; String? get document; String? get phone; String? get email; String? get address; String? get notes; String get status;
/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerCopyWith<Customer> get copyWith => _$CustomerCopyWithImpl<Customer>(this as Customer, _$identity);

  /// Serializes this Customer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Customer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.document, document) || other.document == document)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.address, address) || other.address == address)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,document,phone,email,address,notes,status);

@override
String toString() {
  return 'Customer(id: $id, name: $name, type: $type, document: $document, phone: $phone, email: $email, address: $address, notes: $notes, status: $status)';
}


}

/// @nodoc
abstract mixin class $CustomerCopyWith<$Res>  {
  factory $CustomerCopyWith(Customer value, $Res Function(Customer) _then) = _$CustomerCopyWithImpl;
@useResult
$Res call({
 String id, String name, String type, String? document, String? phone, String? email, String? address, String? notes, String status
});




}
/// @nodoc
class _$CustomerCopyWithImpl<$Res>
    implements $CustomerCopyWith<$Res> {
  _$CustomerCopyWithImpl(this._self, this._then);

  final Customer _self;
  final $Res Function(Customer) _then;

/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? document = freezed,Object? phone = freezed,Object? email = freezed,Object? address = freezed,Object? notes = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,document: freezed == document ? _self.document : document // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Customer].
extension CustomerPatterns on Customer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Customer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Customer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Customer value)  $default,){
final _that = this;
switch (_that) {
case _Customer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Customer value)?  $default,){
final _that = this;
switch (_that) {
case _Customer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String? document,  String? phone,  String? email,  String? address,  String? notes,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Customer() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.document,_that.phone,_that.email,_that.address,_that.notes,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String? document,  String? phone,  String? email,  String? address,  String? notes,  String status)  $default,) {final _that = this;
switch (_that) {
case _Customer():
return $default(_that.id,_that.name,_that.type,_that.document,_that.phone,_that.email,_that.address,_that.notes,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String type,  String? document,  String? phone,  String? email,  String? address,  String? notes,  String status)?  $default,) {final _that = this;
switch (_that) {
case _Customer() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.document,_that.phone,_that.email,_that.address,_that.notes,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Customer implements Customer {
  const _Customer({required this.id, required this.name, this.type = 'PF', this.document, this.phone, this.email, this.address, this.notes, this.status = 'active'});
  factory _Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  String type;
@override final  String? document;
@override final  String? phone;
@override final  String? email;
@override final  String? address;
@override final  String? notes;
@override@JsonKey() final  String status;

/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerCopyWith<_Customer> get copyWith => __$CustomerCopyWithImpl<_Customer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Customer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.document, document) || other.document == document)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.email, email) || other.email == email)&&(identical(other.address, address) || other.address == address)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,document,phone,email,address,notes,status);

@override
String toString() {
  return 'Customer(id: $id, name: $name, type: $type, document: $document, phone: $phone, email: $email, address: $address, notes: $notes, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CustomerCopyWith<$Res> implements $CustomerCopyWith<$Res> {
  factory _$CustomerCopyWith(_Customer value, $Res Function(_Customer) _then) = __$CustomerCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String type, String? document, String? phone, String? email, String? address, String? notes, String status
});




}
/// @nodoc
class __$CustomerCopyWithImpl<$Res>
    implements _$CustomerCopyWith<$Res> {
  __$CustomerCopyWithImpl(this._self, this._then);

  final _Customer _self;
  final $Res Function(_Customer) _then;

/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? document = freezed,Object? phone = freezed,Object? email = freezed,Object? address = freezed,Object? notes = freezed,Object? status = null,}) {
  return _then(_Customer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,document: freezed == document ? _self.document : document // ignore: cast_nullable_to_non_nullable
as String?,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Subject {

 String get id;@JsonKey(name: 'customer_id') String get customerId; String? get label; String? get identifier; String? get tipo; String? get marca; String? get modelo;@JsonKey(name: 'numero_serie') String? get numeroSerie; Map<String, dynamic> get attributes;@JsonKey(name: 'photo_url') String? get photoUrl; String get status;/// Retorno da consulta por placa (colunas exclusivas dela no banco).
/// Mapa cru — o contrato é jsonb livre; use `plateInfo` para tipar com
/// segurança. Null = veículo cadastrado à mão, sem consulta.
@JsonKey(name: 'plate_data') Map<String, dynamic>? get plateData;@JsonKey(name: 'plate_data_at') String? get plateDataAt;
/// Create a copy of Subject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubjectCopyWith<Subject> get copyWith => _$SubjectCopyWithImpl<Subject>(this as Subject, _$identity);

  /// Serializes this Subject to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subject&&(identical(other.id, id) || other.id == id)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.label, label) || other.label == label)&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.numeroSerie, numeroSerie) || other.numeroSerie == numeroSerie)&&const DeepCollectionEquality().equals(other.attributes, attributes)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.plateData, plateData)&&(identical(other.plateDataAt, plateDataAt) || other.plateDataAt == plateDataAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,customerId,label,identifier,tipo,marca,modelo,numeroSerie,const DeepCollectionEquality().hash(attributes),photoUrl,status,const DeepCollectionEquality().hash(plateData),plateDataAt);

@override
String toString() {
  return 'Subject(id: $id, customerId: $customerId, label: $label, identifier: $identifier, tipo: $tipo, marca: $marca, modelo: $modelo, numeroSerie: $numeroSerie, attributes: $attributes, photoUrl: $photoUrl, status: $status, plateData: $plateData, plateDataAt: $plateDataAt)';
}


}

/// @nodoc
abstract mixin class $SubjectCopyWith<$Res>  {
  factory $SubjectCopyWith(Subject value, $Res Function(Subject) _then) = _$SubjectCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'customer_id') String customerId, String? label, String? identifier, String? tipo, String? marca, String? modelo,@JsonKey(name: 'numero_serie') String? numeroSerie, Map<String, dynamic> attributes,@JsonKey(name: 'photo_url') String? photoUrl, String status,@JsonKey(name: 'plate_data') Map<String, dynamic>? plateData,@JsonKey(name: 'plate_data_at') String? plateDataAt
});




}
/// @nodoc
class _$SubjectCopyWithImpl<$Res>
    implements $SubjectCopyWith<$Res> {
  _$SubjectCopyWithImpl(this._self, this._then);

  final Subject _self;
  final $Res Function(Subject) _then;

/// Create a copy of Subject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? customerId = null,Object? label = freezed,Object? identifier = freezed,Object? tipo = freezed,Object? marca = freezed,Object? modelo = freezed,Object? numeroSerie = freezed,Object? attributes = null,Object? photoUrl = freezed,Object? status = null,Object? plateData = freezed,Object? plateDataAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,tipo: freezed == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String?,marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as String?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as String?,numeroSerie: freezed == numeroSerie ? _self.numeroSerie : numeroSerie // ignore: cast_nullable_to_non_nullable
as String?,attributes: null == attributes ? _self.attributes : attributes // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,plateData: freezed == plateData ? _self.plateData : plateData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,plateDataAt: freezed == plateDataAt ? _self.plateDataAt : plateDataAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Subject].
extension SubjectPatterns on Subject {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Subject value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Subject() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Subject value)  $default,){
final _that = this;
switch (_that) {
case _Subject():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Subject value)?  $default,){
final _that = this;
switch (_that) {
case _Subject() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'customer_id')  String customerId,  String? label,  String? identifier,  String? tipo,  String? marca,  String? modelo, @JsonKey(name: 'numero_serie')  String? numeroSerie,  Map<String, dynamic> attributes, @JsonKey(name: 'photo_url')  String? photoUrl,  String status, @JsonKey(name: 'plate_data')  Map<String, dynamic>? plateData, @JsonKey(name: 'plate_data_at')  String? plateDataAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Subject() when $default != null:
return $default(_that.id,_that.customerId,_that.label,_that.identifier,_that.tipo,_that.marca,_that.modelo,_that.numeroSerie,_that.attributes,_that.photoUrl,_that.status,_that.plateData,_that.plateDataAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'customer_id')  String customerId,  String? label,  String? identifier,  String? tipo,  String? marca,  String? modelo, @JsonKey(name: 'numero_serie')  String? numeroSerie,  Map<String, dynamic> attributes, @JsonKey(name: 'photo_url')  String? photoUrl,  String status, @JsonKey(name: 'plate_data')  Map<String, dynamic>? plateData, @JsonKey(name: 'plate_data_at')  String? plateDataAt)  $default,) {final _that = this;
switch (_that) {
case _Subject():
return $default(_that.id,_that.customerId,_that.label,_that.identifier,_that.tipo,_that.marca,_that.modelo,_that.numeroSerie,_that.attributes,_that.photoUrl,_that.status,_that.plateData,_that.plateDataAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'customer_id')  String customerId,  String? label,  String? identifier,  String? tipo,  String? marca,  String? modelo, @JsonKey(name: 'numero_serie')  String? numeroSerie,  Map<String, dynamic> attributes, @JsonKey(name: 'photo_url')  String? photoUrl,  String status, @JsonKey(name: 'plate_data')  Map<String, dynamic>? plateData, @JsonKey(name: 'plate_data_at')  String? plateDataAt)?  $default,) {final _that = this;
switch (_that) {
case _Subject() when $default != null:
return $default(_that.id,_that.customerId,_that.label,_that.identifier,_that.tipo,_that.marca,_that.modelo,_that.numeroSerie,_that.attributes,_that.photoUrl,_that.status,_that.plateData,_that.plateDataAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Subject implements Subject {
  const _Subject({required this.id, @JsonKey(name: 'customer_id') required this.customerId, this.label, this.identifier, this.tipo, this.marca, this.modelo, @JsonKey(name: 'numero_serie') this.numeroSerie, final  Map<String, dynamic> attributes = const <String, dynamic>{}, @JsonKey(name: 'photo_url') this.photoUrl, this.status = 'active', @JsonKey(name: 'plate_data') final  Map<String, dynamic>? plateData, @JsonKey(name: 'plate_data_at') this.plateDataAt}): _attributes = attributes,_plateData = plateData;
  factory _Subject.fromJson(Map<String, dynamic> json) => _$SubjectFromJson(json);

@override final  String id;
@override@JsonKey(name: 'customer_id') final  String customerId;
@override final  String? label;
@override final  String? identifier;
@override final  String? tipo;
@override final  String? marca;
@override final  String? modelo;
@override@JsonKey(name: 'numero_serie') final  String? numeroSerie;
 final  Map<String, dynamic> _attributes;
@override@JsonKey() Map<String, dynamic> get attributes {
  if (_attributes is EqualUnmodifiableMapView) return _attributes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_attributes);
}

@override@JsonKey(name: 'photo_url') final  String? photoUrl;
@override@JsonKey() final  String status;
/// Retorno da consulta por placa (colunas exclusivas dela no banco).
/// Mapa cru — o contrato é jsonb livre; use `plateInfo` para tipar com
/// segurança. Null = veículo cadastrado à mão, sem consulta.
 final  Map<String, dynamic>? _plateData;
/// Retorno da consulta por placa (colunas exclusivas dela no banco).
/// Mapa cru — o contrato é jsonb livre; use `plateInfo` para tipar com
/// segurança. Null = veículo cadastrado à mão, sem consulta.
@override@JsonKey(name: 'plate_data') Map<String, dynamic>? get plateData {
  final value = _plateData;
  if (value == null) return null;
  if (_plateData is EqualUnmodifiableMapView) return _plateData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'plate_data_at') final  String? plateDataAt;

/// Create a copy of Subject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubjectCopyWith<_Subject> get copyWith => __$SubjectCopyWithImpl<_Subject>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubjectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subject&&(identical(other.id, id) || other.id == id)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.label, label) || other.label == label)&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.numeroSerie, numeroSerie) || other.numeroSerie == numeroSerie)&&const DeepCollectionEquality().equals(other._attributes, _attributes)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._plateData, _plateData)&&(identical(other.plateDataAt, plateDataAt) || other.plateDataAt == plateDataAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,customerId,label,identifier,tipo,marca,modelo,numeroSerie,const DeepCollectionEquality().hash(_attributes),photoUrl,status,const DeepCollectionEquality().hash(_plateData),plateDataAt);

@override
String toString() {
  return 'Subject(id: $id, customerId: $customerId, label: $label, identifier: $identifier, tipo: $tipo, marca: $marca, modelo: $modelo, numeroSerie: $numeroSerie, attributes: $attributes, photoUrl: $photoUrl, status: $status, plateData: $plateData, plateDataAt: $plateDataAt)';
}


}

/// @nodoc
abstract mixin class _$SubjectCopyWith<$Res> implements $SubjectCopyWith<$Res> {
  factory _$SubjectCopyWith(_Subject value, $Res Function(_Subject) _then) = __$SubjectCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'customer_id') String customerId, String? label, String? identifier, String? tipo, String? marca, String? modelo,@JsonKey(name: 'numero_serie') String? numeroSerie, Map<String, dynamic> attributes,@JsonKey(name: 'photo_url') String? photoUrl, String status,@JsonKey(name: 'plate_data') Map<String, dynamic>? plateData,@JsonKey(name: 'plate_data_at') String? plateDataAt
});




}
/// @nodoc
class __$SubjectCopyWithImpl<$Res>
    implements _$SubjectCopyWith<$Res> {
  __$SubjectCopyWithImpl(this._self, this._then);

  final _Subject _self;
  final $Res Function(_Subject) _then;

/// Create a copy of Subject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? customerId = null,Object? label = freezed,Object? identifier = freezed,Object? tipo = freezed,Object? marca = freezed,Object? modelo = freezed,Object? numeroSerie = freezed,Object? attributes = null,Object? photoUrl = freezed,Object? status = null,Object? plateData = freezed,Object? plateDataAt = freezed,}) {
  return _then(_Subject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,tipo: freezed == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String?,marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as String?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as String?,numeroSerie: freezed == numeroSerie ? _self.numeroSerie : numeroSerie // ignore: cast_nullable_to_non_nullable
as String?,attributes: null == attributes ? _self._attributes : attributes // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,plateData: freezed == plateData ? _self._plateData : plateData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,plateDataAt: freezed == plateDataAt ? _self.plateDataAt : plateDataAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubjectLabel {

 String get singular; String get plural;
/// Create a copy of SubjectLabel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubjectLabelCopyWith<SubjectLabel> get copyWith => _$SubjectLabelCopyWithImpl<SubjectLabel>(this as SubjectLabel, _$identity);

  /// Serializes this SubjectLabel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubjectLabel&&(identical(other.singular, singular) || other.singular == singular)&&(identical(other.plural, plural) || other.plural == plural));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,singular,plural);

@override
String toString() {
  return 'SubjectLabel(singular: $singular, plural: $plural)';
}


}

/// @nodoc
abstract mixin class $SubjectLabelCopyWith<$Res>  {
  factory $SubjectLabelCopyWith(SubjectLabel value, $Res Function(SubjectLabel) _then) = _$SubjectLabelCopyWithImpl;
@useResult
$Res call({
 String singular, String plural
});




}
/// @nodoc
class _$SubjectLabelCopyWithImpl<$Res>
    implements $SubjectLabelCopyWith<$Res> {
  _$SubjectLabelCopyWithImpl(this._self, this._then);

  final SubjectLabel _self;
  final $Res Function(SubjectLabel) _then;

/// Create a copy of SubjectLabel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? singular = null,Object? plural = null,}) {
  return _then(_self.copyWith(
singular: null == singular ? _self.singular : singular // ignore: cast_nullable_to_non_nullable
as String,plural: null == plural ? _self.plural : plural // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SubjectLabel].
extension SubjectLabelPatterns on SubjectLabel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubjectLabel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubjectLabel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubjectLabel value)  $default,){
final _that = this;
switch (_that) {
case _SubjectLabel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubjectLabel value)?  $default,){
final _that = this;
switch (_that) {
case _SubjectLabel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String singular,  String plural)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubjectLabel() when $default != null:
return $default(_that.singular,_that.plural);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String singular,  String plural)  $default,) {final _that = this;
switch (_that) {
case _SubjectLabel():
return $default(_that.singular,_that.plural);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String singular,  String plural)?  $default,) {final _that = this;
switch (_that) {
case _SubjectLabel() when $default != null:
return $default(_that.singular,_that.plural);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubjectLabel implements SubjectLabel {
  const _SubjectLabel({this.singular = 'Objeto', this.plural = 'Objetos'});
  factory _SubjectLabel.fromJson(Map<String, dynamic> json) => _$SubjectLabelFromJson(json);

@override@JsonKey() final  String singular;
@override@JsonKey() final  String plural;

/// Create a copy of SubjectLabel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubjectLabelCopyWith<_SubjectLabel> get copyWith => __$SubjectLabelCopyWithImpl<_SubjectLabel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubjectLabelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubjectLabel&&(identical(other.singular, singular) || other.singular == singular)&&(identical(other.plural, plural) || other.plural == plural));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,singular,plural);

@override
String toString() {
  return 'SubjectLabel(singular: $singular, plural: $plural)';
}


}

/// @nodoc
abstract mixin class _$SubjectLabelCopyWith<$Res> implements $SubjectLabelCopyWith<$Res> {
  factory _$SubjectLabelCopyWith(_SubjectLabel value, $Res Function(_SubjectLabel) _then) = __$SubjectLabelCopyWithImpl;
@override @useResult
$Res call({
 String singular, String plural
});




}
/// @nodoc
class __$SubjectLabelCopyWithImpl<$Res>
    implements _$SubjectLabelCopyWith<$Res> {
  __$SubjectLabelCopyWithImpl(this._self, this._then);

  final _SubjectLabel _self;
  final $Res Function(_SubjectLabel) _then;

/// Create a copy of SubjectLabel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? singular = null,Object? plural = null,}) {
  return _then(_SubjectLabel(
singular: null == singular ? _self.singular : singular // ignore: cast_nullable_to_non_nullable
as String,plural: null == plural ? _self.plural : plural // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SubjectFieldConfig {

 String get chave; String get rotulo; String get tipo;// 'text' | 'number'
 bool get obrigatorio; String? get fonte;// ex.: 'fipe.marcas' — null = campo manual
 String? get dependeDe;
/// Create a copy of SubjectFieldConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubjectFieldConfigCopyWith<SubjectFieldConfig> get copyWith => _$SubjectFieldConfigCopyWithImpl<SubjectFieldConfig>(this as SubjectFieldConfig, _$identity);

  /// Serializes this SubjectFieldConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubjectFieldConfig&&(identical(other.chave, chave) || other.chave == chave)&&(identical(other.rotulo, rotulo) || other.rotulo == rotulo)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.obrigatorio, obrigatorio) || other.obrigatorio == obrigatorio)&&(identical(other.fonte, fonte) || other.fonte == fonte)&&(identical(other.dependeDe, dependeDe) || other.dependeDe == dependeDe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chave,rotulo,tipo,obrigatorio,fonte,dependeDe);

@override
String toString() {
  return 'SubjectFieldConfig(chave: $chave, rotulo: $rotulo, tipo: $tipo, obrigatorio: $obrigatorio, fonte: $fonte, dependeDe: $dependeDe)';
}


}

/// @nodoc
abstract mixin class $SubjectFieldConfigCopyWith<$Res>  {
  factory $SubjectFieldConfigCopyWith(SubjectFieldConfig value, $Res Function(SubjectFieldConfig) _then) = _$SubjectFieldConfigCopyWithImpl;
@useResult
$Res call({
 String chave, String rotulo, String tipo, bool obrigatorio, String? fonte, String? dependeDe
});




}
/// @nodoc
class _$SubjectFieldConfigCopyWithImpl<$Res>
    implements $SubjectFieldConfigCopyWith<$Res> {
  _$SubjectFieldConfigCopyWithImpl(this._self, this._then);

  final SubjectFieldConfig _self;
  final $Res Function(SubjectFieldConfig) _then;

/// Create a copy of SubjectFieldConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chave = null,Object? rotulo = null,Object? tipo = null,Object? obrigatorio = null,Object? fonte = freezed,Object? dependeDe = freezed,}) {
  return _then(_self.copyWith(
chave: null == chave ? _self.chave : chave // ignore: cast_nullable_to_non_nullable
as String,rotulo: null == rotulo ? _self.rotulo : rotulo // ignore: cast_nullable_to_non_nullable
as String,tipo: null == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String,obrigatorio: null == obrigatorio ? _self.obrigatorio : obrigatorio // ignore: cast_nullable_to_non_nullable
as bool,fonte: freezed == fonte ? _self.fonte : fonte // ignore: cast_nullable_to_non_nullable
as String?,dependeDe: freezed == dependeDe ? _self.dependeDe : dependeDe // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubjectFieldConfig].
extension SubjectFieldConfigPatterns on SubjectFieldConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubjectFieldConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubjectFieldConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubjectFieldConfig value)  $default,){
final _that = this;
switch (_that) {
case _SubjectFieldConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubjectFieldConfig value)?  $default,){
final _that = this;
switch (_that) {
case _SubjectFieldConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chave,  String rotulo,  String tipo,  bool obrigatorio,  String? fonte,  String? dependeDe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubjectFieldConfig() when $default != null:
return $default(_that.chave,_that.rotulo,_that.tipo,_that.obrigatorio,_that.fonte,_that.dependeDe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chave,  String rotulo,  String tipo,  bool obrigatorio,  String? fonte,  String? dependeDe)  $default,) {final _that = this;
switch (_that) {
case _SubjectFieldConfig():
return $default(_that.chave,_that.rotulo,_that.tipo,_that.obrigatorio,_that.fonte,_that.dependeDe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chave,  String rotulo,  String tipo,  bool obrigatorio,  String? fonte,  String? dependeDe)?  $default,) {final _that = this;
switch (_that) {
case _SubjectFieldConfig() when $default != null:
return $default(_that.chave,_that.rotulo,_that.tipo,_that.obrigatorio,_that.fonte,_that.dependeDe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubjectFieldConfig implements SubjectFieldConfig {
  const _SubjectFieldConfig({required this.chave, required this.rotulo, this.tipo = 'text', this.obrigatorio = false, this.fonte, this.dependeDe});
  factory _SubjectFieldConfig.fromJson(Map<String, dynamic> json) => _$SubjectFieldConfigFromJson(json);

@override final  String chave;
@override final  String rotulo;
@override@JsonKey() final  String tipo;
// 'text' | 'number'
@override@JsonKey() final  bool obrigatorio;
@override final  String? fonte;
// ex.: 'fipe.marcas' — null = campo manual
@override final  String? dependeDe;

/// Create a copy of SubjectFieldConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubjectFieldConfigCopyWith<_SubjectFieldConfig> get copyWith => __$SubjectFieldConfigCopyWithImpl<_SubjectFieldConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubjectFieldConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubjectFieldConfig&&(identical(other.chave, chave) || other.chave == chave)&&(identical(other.rotulo, rotulo) || other.rotulo == rotulo)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.obrigatorio, obrigatorio) || other.obrigatorio == obrigatorio)&&(identical(other.fonte, fonte) || other.fonte == fonte)&&(identical(other.dependeDe, dependeDe) || other.dependeDe == dependeDe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chave,rotulo,tipo,obrigatorio,fonte,dependeDe);

@override
String toString() {
  return 'SubjectFieldConfig(chave: $chave, rotulo: $rotulo, tipo: $tipo, obrigatorio: $obrigatorio, fonte: $fonte, dependeDe: $dependeDe)';
}


}

/// @nodoc
abstract mixin class _$SubjectFieldConfigCopyWith<$Res> implements $SubjectFieldConfigCopyWith<$Res> {
  factory _$SubjectFieldConfigCopyWith(_SubjectFieldConfig value, $Res Function(_SubjectFieldConfig) _then) = __$SubjectFieldConfigCopyWithImpl;
@override @useResult
$Res call({
 String chave, String rotulo, String tipo, bool obrigatorio, String? fonte, String? dependeDe
});




}
/// @nodoc
class __$SubjectFieldConfigCopyWithImpl<$Res>
    implements _$SubjectFieldConfigCopyWith<$Res> {
  __$SubjectFieldConfigCopyWithImpl(this._self, this._then);

  final _SubjectFieldConfig _self;
  final $Res Function(_SubjectFieldConfig) _then;

/// Create a copy of SubjectFieldConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chave = null,Object? rotulo = null,Object? tipo = null,Object? obrigatorio = null,Object? fonte = freezed,Object? dependeDe = freezed,}) {
  return _then(_SubjectFieldConfig(
chave: null == chave ? _self.chave : chave // ignore: cast_nullable_to_non_nullable
as String,rotulo: null == rotulo ? _self.rotulo : rotulo // ignore: cast_nullable_to_non_nullable
as String,tipo: null == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String,obrigatorio: null == obrigatorio ? _self.obrigatorio : obrigatorio // ignore: cast_nullable_to_non_nullable
as bool,fonte: freezed == fonte ? _self.fonte : fonte // ignore: cast_nullable_to_non_nullable
as String?,dependeDe: freezed == dependeDe ? _self.dependeDe : dependeDe // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CustomersConfig {

 bool get usaSubjects; SubjectLabel get subjectLabel; List<SubjectFieldConfig> get subjectFields; bool get documentRequired;
/// Create a copy of CustomersConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomersConfigCopyWith<CustomersConfig> get copyWith => _$CustomersConfigCopyWithImpl<CustomersConfig>(this as CustomersConfig, _$identity);

  /// Serializes this CustomersConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomersConfig&&(identical(other.usaSubjects, usaSubjects) || other.usaSubjects == usaSubjects)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel)&&const DeepCollectionEquality().equals(other.subjectFields, subjectFields)&&(identical(other.documentRequired, documentRequired) || other.documentRequired == documentRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,usaSubjects,subjectLabel,const DeepCollectionEquality().hash(subjectFields),documentRequired);

@override
String toString() {
  return 'CustomersConfig(usaSubjects: $usaSubjects, subjectLabel: $subjectLabel, subjectFields: $subjectFields, documentRequired: $documentRequired)';
}


}

/// @nodoc
abstract mixin class $CustomersConfigCopyWith<$Res>  {
  factory $CustomersConfigCopyWith(CustomersConfig value, $Res Function(CustomersConfig) _then) = _$CustomersConfigCopyWithImpl;
@useResult
$Res call({
 bool usaSubjects, SubjectLabel subjectLabel, List<SubjectFieldConfig> subjectFields, bool documentRequired
});


$SubjectLabelCopyWith<$Res> get subjectLabel;

}
/// @nodoc
class _$CustomersConfigCopyWithImpl<$Res>
    implements $CustomersConfigCopyWith<$Res> {
  _$CustomersConfigCopyWithImpl(this._self, this._then);

  final CustomersConfig _self;
  final $Res Function(CustomersConfig) _then;

/// Create a copy of CustomersConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? usaSubjects = null,Object? subjectLabel = null,Object? subjectFields = null,Object? documentRequired = null,}) {
  return _then(_self.copyWith(
usaSubjects: null == usaSubjects ? _self.usaSubjects : usaSubjects // ignore: cast_nullable_to_non_nullable
as bool,subjectLabel: null == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as SubjectLabel,subjectFields: null == subjectFields ? _self.subjectFields : subjectFields // ignore: cast_nullable_to_non_nullable
as List<SubjectFieldConfig>,documentRequired: null == documentRequired ? _self.documentRequired : documentRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of CustomersConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubjectLabelCopyWith<$Res> get subjectLabel {
  
  return $SubjectLabelCopyWith<$Res>(_self.subjectLabel, (value) {
    return _then(_self.copyWith(subjectLabel: value));
  });
}
}


/// Adds pattern-matching-related methods to [CustomersConfig].
extension CustomersConfigPatterns on CustomersConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomersConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomersConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomersConfig value)  $default,){
final _that = this;
switch (_that) {
case _CustomersConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomersConfig value)?  $default,){
final _that = this;
switch (_that) {
case _CustomersConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool usaSubjects,  SubjectLabel subjectLabel,  List<SubjectFieldConfig> subjectFields,  bool documentRequired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomersConfig() when $default != null:
return $default(_that.usaSubjects,_that.subjectLabel,_that.subjectFields,_that.documentRequired);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool usaSubjects,  SubjectLabel subjectLabel,  List<SubjectFieldConfig> subjectFields,  bool documentRequired)  $default,) {final _that = this;
switch (_that) {
case _CustomersConfig():
return $default(_that.usaSubjects,_that.subjectLabel,_that.subjectFields,_that.documentRequired);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool usaSubjects,  SubjectLabel subjectLabel,  List<SubjectFieldConfig> subjectFields,  bool documentRequired)?  $default,) {final _that = this;
switch (_that) {
case _CustomersConfig() when $default != null:
return $default(_that.usaSubjects,_that.subjectLabel,_that.subjectFields,_that.documentRequired);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomersConfig implements CustomersConfig {
  const _CustomersConfig({this.usaSubjects = true, this.subjectLabel = const SubjectLabel(), final  List<SubjectFieldConfig> subjectFields = const <SubjectFieldConfig>[], this.documentRequired = false}): _subjectFields = subjectFields;
  factory _CustomersConfig.fromJson(Map<String, dynamic> json) => _$CustomersConfigFromJson(json);

@override@JsonKey() final  bool usaSubjects;
@override@JsonKey() final  SubjectLabel subjectLabel;
 final  List<SubjectFieldConfig> _subjectFields;
@override@JsonKey() List<SubjectFieldConfig> get subjectFields {
  if (_subjectFields is EqualUnmodifiableListView) return _subjectFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subjectFields);
}

@override@JsonKey() final  bool documentRequired;

/// Create a copy of CustomersConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomersConfigCopyWith<_CustomersConfig> get copyWith => __$CustomersConfigCopyWithImpl<_CustomersConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomersConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomersConfig&&(identical(other.usaSubjects, usaSubjects) || other.usaSubjects == usaSubjects)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel)&&const DeepCollectionEquality().equals(other._subjectFields, _subjectFields)&&(identical(other.documentRequired, documentRequired) || other.documentRequired == documentRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,usaSubjects,subjectLabel,const DeepCollectionEquality().hash(_subjectFields),documentRequired);

@override
String toString() {
  return 'CustomersConfig(usaSubjects: $usaSubjects, subjectLabel: $subjectLabel, subjectFields: $subjectFields, documentRequired: $documentRequired)';
}


}

/// @nodoc
abstract mixin class _$CustomersConfigCopyWith<$Res> implements $CustomersConfigCopyWith<$Res> {
  factory _$CustomersConfigCopyWith(_CustomersConfig value, $Res Function(_CustomersConfig) _then) = __$CustomersConfigCopyWithImpl;
@override @useResult
$Res call({
 bool usaSubjects, SubjectLabel subjectLabel, List<SubjectFieldConfig> subjectFields, bool documentRequired
});


@override $SubjectLabelCopyWith<$Res> get subjectLabel;

}
/// @nodoc
class __$CustomersConfigCopyWithImpl<$Res>
    implements _$CustomersConfigCopyWith<$Res> {
  __$CustomersConfigCopyWithImpl(this._self, this._then);

  final _CustomersConfig _self;
  final $Res Function(_CustomersConfig) _then;

/// Create a copy of CustomersConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? usaSubjects = null,Object? subjectLabel = null,Object? subjectFields = null,Object? documentRequired = null,}) {
  return _then(_CustomersConfig(
usaSubjects: null == usaSubjects ? _self.usaSubjects : usaSubjects // ignore: cast_nullable_to_non_nullable
as bool,subjectLabel: null == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as SubjectLabel,subjectFields: null == subjectFields ? _self._subjectFields : subjectFields // ignore: cast_nullable_to_non_nullable
as List<SubjectFieldConfig>,documentRequired: null == documentRequired ? _self.documentRequired : documentRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of CustomersConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubjectLabelCopyWith<$Res> get subjectLabel {
  
  return $SubjectLabelCopyWith<$Res>(_self.subjectLabel, (value) {
    return _then(_self.copyWith(subjectLabel: value));
  });
}
}


/// @nodoc
mixin _$SubjectHistoryEntry {

 String get id; String get kind; String get title; String get status; String get occurredAt; String? get subjectId; String? get subjectLabel;
/// Create a copy of SubjectHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubjectHistoryEntryCopyWith<SubjectHistoryEntry> get copyWith => _$SubjectHistoryEntryCopyWithImpl<SubjectHistoryEntry>(this as SubjectHistoryEntry, _$identity);

  /// Serializes this SubjectHistoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubjectHistoryEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,title,status,occurredAt,subjectId,subjectLabel);

@override
String toString() {
  return 'SubjectHistoryEntry(id: $id, kind: $kind, title: $title, status: $status, occurredAt: $occurredAt, subjectId: $subjectId, subjectLabel: $subjectLabel)';
}


}

/// @nodoc
abstract mixin class $SubjectHistoryEntryCopyWith<$Res>  {
  factory $SubjectHistoryEntryCopyWith(SubjectHistoryEntry value, $Res Function(SubjectHistoryEntry) _then) = _$SubjectHistoryEntryCopyWithImpl;
@useResult
$Res call({
 String id, String kind, String title, String status, String occurredAt, String? subjectId, String? subjectLabel
});




}
/// @nodoc
class _$SubjectHistoryEntryCopyWithImpl<$Res>
    implements $SubjectHistoryEntryCopyWith<$Res> {
  _$SubjectHistoryEntryCopyWithImpl(this._self, this._then);

  final SubjectHistoryEntry _self;
  final $Res Function(SubjectHistoryEntry) _then;

/// Create a copy of SubjectHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? title = null,Object? status = null,Object? occurredAt = null,Object? subjectId = freezed,Object? subjectLabel = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as String,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubjectHistoryEntry].
extension SubjectHistoryEntryPatterns on SubjectHistoryEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubjectHistoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubjectHistoryEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubjectHistoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _SubjectHistoryEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubjectHistoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _SubjectHistoryEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String kind,  String title,  String status,  String occurredAt,  String? subjectId,  String? subjectLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubjectHistoryEntry() when $default != null:
return $default(_that.id,_that.kind,_that.title,_that.status,_that.occurredAt,_that.subjectId,_that.subjectLabel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String kind,  String title,  String status,  String occurredAt,  String? subjectId,  String? subjectLabel)  $default,) {final _that = this;
switch (_that) {
case _SubjectHistoryEntry():
return $default(_that.id,_that.kind,_that.title,_that.status,_that.occurredAt,_that.subjectId,_that.subjectLabel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String kind,  String title,  String status,  String occurredAt,  String? subjectId,  String? subjectLabel)?  $default,) {final _that = this;
switch (_that) {
case _SubjectHistoryEntry() when $default != null:
return $default(_that.id,_that.kind,_that.title,_that.status,_that.occurredAt,_that.subjectId,_that.subjectLabel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubjectHistoryEntry implements SubjectHistoryEntry {
  const _SubjectHistoryEntry({required this.id, required this.kind, required this.title, required this.status, required this.occurredAt, this.subjectId, this.subjectLabel});
  factory _SubjectHistoryEntry.fromJson(Map<String, dynamic> json) => _$SubjectHistoryEntryFromJson(json);

@override final  String id;
@override final  String kind;
@override final  String title;
@override final  String status;
@override final  String occurredAt;
@override final  String? subjectId;
@override final  String? subjectLabel;

/// Create a copy of SubjectHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubjectHistoryEntryCopyWith<_SubjectHistoryEntry> get copyWith => __$SubjectHistoryEntryCopyWithImpl<_SubjectHistoryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubjectHistoryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubjectHistoryEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.subjectLabel, subjectLabel) || other.subjectLabel == subjectLabel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,title,status,occurredAt,subjectId,subjectLabel);

@override
String toString() {
  return 'SubjectHistoryEntry(id: $id, kind: $kind, title: $title, status: $status, occurredAt: $occurredAt, subjectId: $subjectId, subjectLabel: $subjectLabel)';
}


}

/// @nodoc
abstract mixin class _$SubjectHistoryEntryCopyWith<$Res> implements $SubjectHistoryEntryCopyWith<$Res> {
  factory _$SubjectHistoryEntryCopyWith(_SubjectHistoryEntry value, $Res Function(_SubjectHistoryEntry) _then) = __$SubjectHistoryEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String kind, String title, String status, String occurredAt, String? subjectId, String? subjectLabel
});




}
/// @nodoc
class __$SubjectHistoryEntryCopyWithImpl<$Res>
    implements _$SubjectHistoryEntryCopyWith<$Res> {
  __$SubjectHistoryEntryCopyWithImpl(this._self, this._then);

  final _SubjectHistoryEntry _self;
  final $Res Function(_SubjectHistoryEntry) _then;

/// Create a copy of SubjectHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? title = null,Object? status = null,Object? occurredAt = null,Object? subjectId = freezed,Object? subjectLabel = freezed,}) {
  return _then(_SubjectHistoryEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as String,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,subjectLabel: freezed == subjectLabel ? _self.subjectLabel : subjectLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CustomerPage {

 List<Customer> get items; int get total; int get page; int get pageSize;
/// Create a copy of CustomerPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerPageCopyWith<CustomerPage> get copyWith => _$CustomerPageCopyWithImpl<CustomerPage>(this as CustomerPage, _$identity);

  /// Serializes this CustomerPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'CustomerPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $CustomerPageCopyWith<$Res>  {
  factory $CustomerPageCopyWith(CustomerPage value, $Res Function(CustomerPage) _then) = _$CustomerPageCopyWithImpl;
@useResult
$Res call({
 List<Customer> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$CustomerPageCopyWithImpl<$Res>
    implements $CustomerPageCopyWith<$Res> {
  _$CustomerPageCopyWithImpl(this._self, this._then);

  final CustomerPage _self;
  final $Res Function(CustomerPage) _then;

/// Create a copy of CustomerPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Customer>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomerPage].
extension CustomerPagePatterns on CustomerPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomerPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomerPage value)  $default,){
final _that = this;
switch (_that) {
case _CustomerPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomerPage value)?  $default,){
final _that = this;
switch (_that) {
case _CustomerPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Customer> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Customer> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _CustomerPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Customer> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _CustomerPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomerPage implements CustomerPage {
  const _CustomerPage({final  List<Customer> items = const <Customer>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _CustomerPage.fromJson(Map<String, dynamic> json) => _$CustomerPageFromJson(json);

 final  List<Customer> _items;
@override@JsonKey() List<Customer> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of CustomerPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerPageCopyWith<_CustomerPage> get copyWith => __$CustomerPageCopyWithImpl<_CustomerPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'CustomerPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$CustomerPageCopyWith<$Res> implements $CustomerPageCopyWith<$Res> {
  factory _$CustomerPageCopyWith(_CustomerPage value, $Res Function(_CustomerPage) _then) = __$CustomerPageCopyWithImpl;
@override @useResult
$Res call({
 List<Customer> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$CustomerPageCopyWithImpl<$Res>
    implements _$CustomerPageCopyWith<$Res> {
  __$CustomerPageCopyWithImpl(this._self, this._then);

  final _CustomerPage _self;
  final $Res Function(_CustomerPage) _then;

/// Create a copy of CustomerPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_CustomerPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Customer>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SubjectPage {

 List<Subject> get items; int get total; int get page; int get pageSize;
/// Create a copy of SubjectPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubjectPageCopyWith<SubjectPage> get copyWith => _$SubjectPageCopyWithImpl<SubjectPage>(this as SubjectPage, _$identity);

  /// Serializes this SubjectPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubjectPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'SubjectPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $SubjectPageCopyWith<$Res>  {
  factory $SubjectPageCopyWith(SubjectPage value, $Res Function(SubjectPage) _then) = _$SubjectPageCopyWithImpl;
@useResult
$Res call({
 List<Subject> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$SubjectPageCopyWithImpl<$Res>
    implements $SubjectPageCopyWith<$Res> {
  _$SubjectPageCopyWithImpl(this._self, this._then);

  final SubjectPage _self;
  final $Res Function(SubjectPage) _then;

/// Create a copy of SubjectPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Subject>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SubjectPage].
extension SubjectPagePatterns on SubjectPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubjectPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubjectPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubjectPage value)  $default,){
final _that = this;
switch (_that) {
case _SubjectPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubjectPage value)?  $default,){
final _that = this;
switch (_that) {
case _SubjectPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Subject> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubjectPage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Subject> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _SubjectPage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Subject> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _SubjectPage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubjectPage implements SubjectPage {
  const _SubjectPage({final  List<Subject> items = const <Subject>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _SubjectPage.fromJson(Map<String, dynamic> json) => _$SubjectPageFromJson(json);

 final  List<Subject> _items;
@override@JsonKey() List<Subject> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of SubjectPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubjectPageCopyWith<_SubjectPage> get copyWith => __$SubjectPageCopyWithImpl<_SubjectPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubjectPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubjectPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'SubjectPage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$SubjectPageCopyWith<$Res> implements $SubjectPageCopyWith<$Res> {
  factory _$SubjectPageCopyWith(_SubjectPage value, $Res Function(_SubjectPage) _then) = __$SubjectPageCopyWithImpl;
@override @useResult
$Res call({
 List<Subject> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$SubjectPageCopyWithImpl<$Res>
    implements _$SubjectPageCopyWith<$Res> {
  __$SubjectPageCopyWithImpl(this._self, this._then);

  final _SubjectPage _self;
  final $Res Function(_SubjectPage) _then;

/// Create a copy of SubjectPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_SubjectPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Subject>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$LookupOption {

 String get value; String get label; Map<String, dynamic> get meta;
/// Create a copy of LookupOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LookupOptionCopyWith<LookupOption> get copyWith => _$LookupOptionCopyWithImpl<LookupOption>(this as LookupOption, _$identity);

  /// Serializes this LookupOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LookupOption&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other.meta, meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,label,const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LookupOption(value: $value, label: $label, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LookupOptionCopyWith<$Res>  {
  factory $LookupOptionCopyWith(LookupOption value, $Res Function(LookupOption) _then) = _$LookupOptionCopyWithImpl;
@useResult
$Res call({
 String value, String label, Map<String, dynamic> meta
});




}
/// @nodoc
class _$LookupOptionCopyWithImpl<$Res>
    implements $LookupOptionCopyWith<$Res> {
  _$LookupOptionCopyWithImpl(this._self, this._then);

  final LookupOption _self;
  final $Res Function(LookupOption) _then;

/// Create a copy of LookupOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? label = null,Object? meta = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [LookupOption].
extension LookupOptionPatterns on LookupOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LookupOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LookupOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LookupOption value)  $default,){
final _that = this;
switch (_that) {
case _LookupOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LookupOption value)?  $default,){
final _that = this;
switch (_that) {
case _LookupOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value,  String label,  Map<String, dynamic> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LookupOption() when $default != null:
return $default(_that.value,_that.label,_that.meta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value,  String label,  Map<String, dynamic> meta)  $default,) {final _that = this;
switch (_that) {
case _LookupOption():
return $default(_that.value,_that.label,_that.meta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value,  String label,  Map<String, dynamic> meta)?  $default,) {final _that = this;
switch (_that) {
case _LookupOption() when $default != null:
return $default(_that.value,_that.label,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LookupOption implements LookupOption {
  const _LookupOption({required this.value, required this.label, final  Map<String, dynamic> meta = const <String, dynamic>{}}): _meta = meta;
  factory _LookupOption.fromJson(Map<String, dynamic> json) => _$LookupOptionFromJson(json);

@override final  String value;
@override final  String label;
 final  Map<String, dynamic> _meta;
@override@JsonKey() Map<String, dynamic> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LookupOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LookupOptionCopyWith<_LookupOption> get copyWith => __$LookupOptionCopyWithImpl<_LookupOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LookupOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LookupOption&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other._meta, _meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,label,const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LookupOption(value: $value, label: $label, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LookupOptionCopyWith<$Res> implements $LookupOptionCopyWith<$Res> {
  factory _$LookupOptionCopyWith(_LookupOption value, $Res Function(_LookupOption) _then) = __$LookupOptionCopyWithImpl;
@override @useResult
$Res call({
 String value, String label, Map<String, dynamic> meta
});




}
/// @nodoc
class __$LookupOptionCopyWithImpl<$Res>
    implements _$LookupOptionCopyWith<$Res> {
  __$LookupOptionCopyWithImpl(this._self, this._then);

  final _LookupOption _self;
  final $Res Function(_LookupOption) _then;

/// Create a copy of LookupOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? label = null,Object? meta = null,}) {
  return _then(_LookupOption(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$PlateFipeRef {

 String get value; String? get codigo;
/// Create a copy of PlateFipeRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlateFipeRefCopyWith<PlateFipeRef> get copyWith => _$PlateFipeRefCopyWithImpl<PlateFipeRef>(this as PlateFipeRef, _$identity);

  /// Serializes this PlateFipeRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlateFipeRef&&(identical(other.value, value) || other.value == value)&&(identical(other.codigo, codigo) || other.codigo == codigo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,codigo);

@override
String toString() {
  return 'PlateFipeRef(value: $value, codigo: $codigo)';
}


}

/// @nodoc
abstract mixin class $PlateFipeRefCopyWith<$Res>  {
  factory $PlateFipeRefCopyWith(PlateFipeRef value, $Res Function(PlateFipeRef) _then) = _$PlateFipeRefCopyWithImpl;
@useResult
$Res call({
 String value, String? codigo
});




}
/// @nodoc
class _$PlateFipeRefCopyWithImpl<$Res>
    implements $PlateFipeRefCopyWith<$Res> {
  _$PlateFipeRefCopyWithImpl(this._self, this._then);

  final PlateFipeRef _self;
  final $Res Function(PlateFipeRef) _then;

/// Create a copy of PlateFipeRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? codigo = freezed,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlateFipeRef].
extension PlateFipeRefPatterns on PlateFipeRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlateFipeRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlateFipeRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlateFipeRef value)  $default,){
final _that = this;
switch (_that) {
case _PlateFipeRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlateFipeRef value)?  $default,){
final _that = this;
switch (_that) {
case _PlateFipeRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value,  String? codigo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlateFipeRef() when $default != null:
return $default(_that.value,_that.codigo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value,  String? codigo)  $default,) {final _that = this;
switch (_that) {
case _PlateFipeRef():
return $default(_that.value,_that.codigo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value,  String? codigo)?  $default,) {final _that = this;
switch (_that) {
case _PlateFipeRef() when $default != null:
return $default(_that.value,_that.codigo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlateFipeRef implements PlateFipeRef {
  const _PlateFipeRef({required this.value, this.codigo});
  factory _PlateFipeRef.fromJson(Map<String, dynamic> json) => _$PlateFipeRefFromJson(json);

@override final  String value;
@override final  String? codigo;

/// Create a copy of PlateFipeRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlateFipeRefCopyWith<_PlateFipeRef> get copyWith => __$PlateFipeRefCopyWithImpl<_PlateFipeRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlateFipeRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlateFipeRef&&(identical(other.value, value) || other.value == value)&&(identical(other.codigo, codigo) || other.codigo == codigo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,codigo);

@override
String toString() {
  return 'PlateFipeRef(value: $value, codigo: $codigo)';
}


}

/// @nodoc
abstract mixin class _$PlateFipeRefCopyWith<$Res> implements $PlateFipeRefCopyWith<$Res> {
  factory _$PlateFipeRefCopyWith(_PlateFipeRef value, $Res Function(_PlateFipeRef) _then) = __$PlateFipeRefCopyWithImpl;
@override @useResult
$Res call({
 String value, String? codigo
});




}
/// @nodoc
class __$PlateFipeRefCopyWithImpl<$Res>
    implements _$PlateFipeRefCopyWith<$Res> {
  __$PlateFipeRefCopyWithImpl(this._self, this._then);

  final _PlateFipeRef _self;
  final $Res Function(_PlateFipeRef) _then;

/// Create a copy of PlateFipeRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? codigo = freezed,}) {
  return _then(_PlateFipeRef(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PlateFipeMatch {

 PlateFipeRef? get marca; PlateFipeRef? get modelo; PlateFipeRef? get ano;
/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlateFipeMatchCopyWith<PlateFipeMatch> get copyWith => _$PlateFipeMatchCopyWithImpl<PlateFipeMatch>(this as PlateFipeMatch, _$identity);

  /// Serializes this PlateFipeMatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlateFipeMatch&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.ano, ano) || other.ano == ano));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,marca,modelo,ano);

@override
String toString() {
  return 'PlateFipeMatch(marca: $marca, modelo: $modelo, ano: $ano)';
}


}

/// @nodoc
abstract mixin class $PlateFipeMatchCopyWith<$Res>  {
  factory $PlateFipeMatchCopyWith(PlateFipeMatch value, $Res Function(PlateFipeMatch) _then) = _$PlateFipeMatchCopyWithImpl;
@useResult
$Res call({
 PlateFipeRef? marca, PlateFipeRef? modelo, PlateFipeRef? ano
});


$PlateFipeRefCopyWith<$Res>? get marca;$PlateFipeRefCopyWith<$Res>? get modelo;$PlateFipeRefCopyWith<$Res>? get ano;

}
/// @nodoc
class _$PlateFipeMatchCopyWithImpl<$Res>
    implements $PlateFipeMatchCopyWith<$Res> {
  _$PlateFipeMatchCopyWithImpl(this._self, this._then);

  final PlateFipeMatch _self;
  final $Res Function(PlateFipeMatch) _then;

/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? marca = freezed,Object? modelo = freezed,Object? ano = freezed,}) {
  return _then(_self.copyWith(
marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as PlateFipeRef?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as PlateFipeRef?,ano: freezed == ano ? _self.ano : ano // ignore: cast_nullable_to_non_nullable
as PlateFipeRef?,
  ));
}
/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeRefCopyWith<$Res>? get marca {
    if (_self.marca == null) {
    return null;
  }

  return $PlateFipeRefCopyWith<$Res>(_self.marca!, (value) {
    return _then(_self.copyWith(marca: value));
  });
}/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeRefCopyWith<$Res>? get modelo {
    if (_self.modelo == null) {
    return null;
  }

  return $PlateFipeRefCopyWith<$Res>(_self.modelo!, (value) {
    return _then(_self.copyWith(modelo: value));
  });
}/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeRefCopyWith<$Res>? get ano {
    if (_self.ano == null) {
    return null;
  }

  return $PlateFipeRefCopyWith<$Res>(_self.ano!, (value) {
    return _then(_self.copyWith(ano: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlateFipeMatch].
extension PlateFipeMatchPatterns on PlateFipeMatch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlateFipeMatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlateFipeMatch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlateFipeMatch value)  $default,){
final _that = this;
switch (_that) {
case _PlateFipeMatch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlateFipeMatch value)?  $default,){
final _that = this;
switch (_that) {
case _PlateFipeMatch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PlateFipeRef? marca,  PlateFipeRef? modelo,  PlateFipeRef? ano)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlateFipeMatch() when $default != null:
return $default(_that.marca,_that.modelo,_that.ano);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PlateFipeRef? marca,  PlateFipeRef? modelo,  PlateFipeRef? ano)  $default,) {final _that = this;
switch (_that) {
case _PlateFipeMatch():
return $default(_that.marca,_that.modelo,_that.ano);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PlateFipeRef? marca,  PlateFipeRef? modelo,  PlateFipeRef? ano)?  $default,) {final _that = this;
switch (_that) {
case _PlateFipeMatch() when $default != null:
return $default(_that.marca,_that.modelo,_that.ano);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlateFipeMatch implements PlateFipeMatch {
  const _PlateFipeMatch({this.marca, this.modelo, this.ano});
  factory _PlateFipeMatch.fromJson(Map<String, dynamic> json) => _$PlateFipeMatchFromJson(json);

@override final  PlateFipeRef? marca;
@override final  PlateFipeRef? modelo;
@override final  PlateFipeRef? ano;

/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlateFipeMatchCopyWith<_PlateFipeMatch> get copyWith => __$PlateFipeMatchCopyWithImpl<_PlateFipeMatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlateFipeMatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlateFipeMatch&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.ano, ano) || other.ano == ano));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,marca,modelo,ano);

@override
String toString() {
  return 'PlateFipeMatch(marca: $marca, modelo: $modelo, ano: $ano)';
}


}

/// @nodoc
abstract mixin class _$PlateFipeMatchCopyWith<$Res> implements $PlateFipeMatchCopyWith<$Res> {
  factory _$PlateFipeMatchCopyWith(_PlateFipeMatch value, $Res Function(_PlateFipeMatch) _then) = __$PlateFipeMatchCopyWithImpl;
@override @useResult
$Res call({
 PlateFipeRef? marca, PlateFipeRef? modelo, PlateFipeRef? ano
});


@override $PlateFipeRefCopyWith<$Res>? get marca;@override $PlateFipeRefCopyWith<$Res>? get modelo;@override $PlateFipeRefCopyWith<$Res>? get ano;

}
/// @nodoc
class __$PlateFipeMatchCopyWithImpl<$Res>
    implements _$PlateFipeMatchCopyWith<$Res> {
  __$PlateFipeMatchCopyWithImpl(this._self, this._then);

  final _PlateFipeMatch _self;
  final $Res Function(_PlateFipeMatch) _then;

/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? marca = freezed,Object? modelo = freezed,Object? ano = freezed,}) {
  return _then(_PlateFipeMatch(
marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as PlateFipeRef?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as PlateFipeRef?,ano: freezed == ano ? _self.ano : ano // ignore: cast_nullable_to_non_nullable
as PlateFipeRef?,
  ));
}

/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeRefCopyWith<$Res>? get marca {
    if (_self.marca == null) {
    return null;
  }

  return $PlateFipeRefCopyWith<$Res>(_self.marca!, (value) {
    return _then(_self.copyWith(marca: value));
  });
}/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeRefCopyWith<$Res>? get modelo {
    if (_self.modelo == null) {
    return null;
  }

  return $PlateFipeRefCopyWith<$Res>(_self.modelo!, (value) {
    return _then(_self.copyWith(modelo: value));
  });
}/// Create a copy of PlateFipeMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeRefCopyWith<$Res>? get ano {
    if (_self.ano == null) {
    return null;
  }

  return $PlateFipeRefCopyWith<$Res>(_self.ano!, (value) {
    return _then(_self.copyWith(ano: value));
  });
}
}


/// @nodoc
mixin _$PlateFipe {

 String? get codigoFipe; String? get marca; String? get modelo; String? get valor; String? get combustivel; String? get anoModelo; String? get mesReferencia; int? get score;
/// Create a copy of PlateFipe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlateFipeCopyWith<PlateFipe> get copyWith => _$PlateFipeCopyWithImpl<PlateFipe>(this as PlateFipe, _$identity);

  /// Serializes this PlateFipe to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlateFipe&&(identical(other.codigoFipe, codigoFipe) || other.codigoFipe == codigoFipe)&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.valor, valor) || other.valor == valor)&&(identical(other.combustivel, combustivel) || other.combustivel == combustivel)&&(identical(other.anoModelo, anoModelo) || other.anoModelo == anoModelo)&&(identical(other.mesReferencia, mesReferencia) || other.mesReferencia == mesReferencia)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,codigoFipe,marca,modelo,valor,combustivel,anoModelo,mesReferencia,score);

@override
String toString() {
  return 'PlateFipe(codigoFipe: $codigoFipe, marca: $marca, modelo: $modelo, valor: $valor, combustivel: $combustivel, anoModelo: $anoModelo, mesReferencia: $mesReferencia, score: $score)';
}


}

/// @nodoc
abstract mixin class $PlateFipeCopyWith<$Res>  {
  factory $PlateFipeCopyWith(PlateFipe value, $Res Function(PlateFipe) _then) = _$PlateFipeCopyWithImpl;
@useResult
$Res call({
 String? codigoFipe, String? marca, String? modelo, String? valor, String? combustivel, String? anoModelo, String? mesReferencia, int? score
});




}
/// @nodoc
class _$PlateFipeCopyWithImpl<$Res>
    implements $PlateFipeCopyWith<$Res> {
  _$PlateFipeCopyWithImpl(this._self, this._then);

  final PlateFipe _self;
  final $Res Function(PlateFipe) _then;

/// Create a copy of PlateFipe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? codigoFipe = freezed,Object? marca = freezed,Object? modelo = freezed,Object? valor = freezed,Object? combustivel = freezed,Object? anoModelo = freezed,Object? mesReferencia = freezed,Object? score = freezed,}) {
  return _then(_self.copyWith(
codigoFipe: freezed == codigoFipe ? _self.codigoFipe : codigoFipe // ignore: cast_nullable_to_non_nullable
as String?,marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as String?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as String?,valor: freezed == valor ? _self.valor : valor // ignore: cast_nullable_to_non_nullable
as String?,combustivel: freezed == combustivel ? _self.combustivel : combustivel // ignore: cast_nullable_to_non_nullable
as String?,anoModelo: freezed == anoModelo ? _self.anoModelo : anoModelo // ignore: cast_nullable_to_non_nullable
as String?,mesReferencia: freezed == mesReferencia ? _self.mesReferencia : mesReferencia // ignore: cast_nullable_to_non_nullable
as String?,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlateFipe].
extension PlateFipePatterns on PlateFipe {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlateFipe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlateFipe() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlateFipe value)  $default,){
final _that = this;
switch (_that) {
case _PlateFipe():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlateFipe value)?  $default,){
final _that = this;
switch (_that) {
case _PlateFipe() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? codigoFipe,  String? marca,  String? modelo,  String? valor,  String? combustivel,  String? anoModelo,  String? mesReferencia,  int? score)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlateFipe() when $default != null:
return $default(_that.codigoFipe,_that.marca,_that.modelo,_that.valor,_that.combustivel,_that.anoModelo,_that.mesReferencia,_that.score);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? codigoFipe,  String? marca,  String? modelo,  String? valor,  String? combustivel,  String? anoModelo,  String? mesReferencia,  int? score)  $default,) {final _that = this;
switch (_that) {
case _PlateFipe():
return $default(_that.codigoFipe,_that.marca,_that.modelo,_that.valor,_that.combustivel,_that.anoModelo,_that.mesReferencia,_that.score);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? codigoFipe,  String? marca,  String? modelo,  String? valor,  String? combustivel,  String? anoModelo,  String? mesReferencia,  int? score)?  $default,) {final _that = this;
switch (_that) {
case _PlateFipe() when $default != null:
return $default(_that.codigoFipe,_that.marca,_that.modelo,_that.valor,_that.combustivel,_that.anoModelo,_that.mesReferencia,_that.score);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlateFipe implements PlateFipe {
  const _PlateFipe({this.codigoFipe, this.marca, this.modelo, this.valor, this.combustivel, this.anoModelo, this.mesReferencia, this.score});
  factory _PlateFipe.fromJson(Map<String, dynamic> json) => _$PlateFipeFromJson(json);

@override final  String? codigoFipe;
@override final  String? marca;
@override final  String? modelo;
@override final  String? valor;
@override final  String? combustivel;
@override final  String? anoModelo;
@override final  String? mesReferencia;
@override final  int? score;

/// Create a copy of PlateFipe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlateFipeCopyWith<_PlateFipe> get copyWith => __$PlateFipeCopyWithImpl<_PlateFipe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlateFipeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlateFipe&&(identical(other.codigoFipe, codigoFipe) || other.codigoFipe == codigoFipe)&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.valor, valor) || other.valor == valor)&&(identical(other.combustivel, combustivel) || other.combustivel == combustivel)&&(identical(other.anoModelo, anoModelo) || other.anoModelo == anoModelo)&&(identical(other.mesReferencia, mesReferencia) || other.mesReferencia == mesReferencia)&&(identical(other.score, score) || other.score == score));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,codigoFipe,marca,modelo,valor,combustivel,anoModelo,mesReferencia,score);

@override
String toString() {
  return 'PlateFipe(codigoFipe: $codigoFipe, marca: $marca, modelo: $modelo, valor: $valor, combustivel: $combustivel, anoModelo: $anoModelo, mesReferencia: $mesReferencia, score: $score)';
}


}

/// @nodoc
abstract mixin class _$PlateFipeCopyWith<$Res> implements $PlateFipeCopyWith<$Res> {
  factory _$PlateFipeCopyWith(_PlateFipe value, $Res Function(_PlateFipe) _then) = __$PlateFipeCopyWithImpl;
@override @useResult
$Res call({
 String? codigoFipe, String? marca, String? modelo, String? valor, String? combustivel, String? anoModelo, String? mesReferencia, int? score
});




}
/// @nodoc
class __$PlateFipeCopyWithImpl<$Res>
    implements _$PlateFipeCopyWith<$Res> {
  __$PlateFipeCopyWithImpl(this._self, this._then);

  final _PlateFipe _self;
  final $Res Function(_PlateFipe) _then;

/// Create a copy of PlateFipe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? codigoFipe = freezed,Object? marca = freezed,Object? modelo = freezed,Object? valor = freezed,Object? combustivel = freezed,Object? anoModelo = freezed,Object? mesReferencia = freezed,Object? score = freezed,}) {
  return _then(_PlateFipe(
codigoFipe: freezed == codigoFipe ? _self.codigoFipe : codigoFipe // ignore: cast_nullable_to_non_nullable
as String?,marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as String?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as String?,valor: freezed == valor ? _self.valor : valor // ignore: cast_nullable_to_non_nullable
as String?,combustivel: freezed == combustivel ? _self.combustivel : combustivel // ignore: cast_nullable_to_non_nullable
as String?,anoModelo: freezed == anoModelo ? _self.anoModelo : anoModelo // ignore: cast_nullable_to_non_nullable
as String?,mesReferencia: freezed == mesReferencia ? _self.mesReferencia : mesReferencia // ignore: cast_nullable_to_non_nullable
as String?,score: freezed == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$PlateQuota {

 String get period; int get used; int get limit; int get remaining; bool get enabled;
/// Create a copy of PlateQuota
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlateQuotaCopyWith<PlateQuota> get copyWith => _$PlateQuotaCopyWithImpl<PlateQuota>(this as PlateQuota, _$identity);

  /// Serializes this PlateQuota to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlateQuota&&(identical(other.period, period) || other.period == period)&&(identical(other.used, used) || other.used == used)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,period,used,limit,remaining,enabled);

@override
String toString() {
  return 'PlateQuota(period: $period, used: $used, limit: $limit, remaining: $remaining, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $PlateQuotaCopyWith<$Res>  {
  factory $PlateQuotaCopyWith(PlateQuota value, $Res Function(PlateQuota) _then) = _$PlateQuotaCopyWithImpl;
@useResult
$Res call({
 String period, int used, int limit, int remaining, bool enabled
});




}
/// @nodoc
class _$PlateQuotaCopyWithImpl<$Res>
    implements $PlateQuotaCopyWith<$Res> {
  _$PlateQuotaCopyWithImpl(this._self, this._then);

  final PlateQuota _self;
  final $Res Function(PlateQuota) _then;

/// Create a copy of PlateQuota
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? used = null,Object? limit = null,Object? remaining = null,Object? enabled = null,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlateQuota].
extension PlateQuotaPatterns on PlateQuota {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlateQuota value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlateQuota() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlateQuota value)  $default,){
final _that = this;
switch (_that) {
case _PlateQuota():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlateQuota value)?  $default,){
final _that = this;
switch (_that) {
case _PlateQuota() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String period,  int used,  int limit,  int remaining,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlateQuota() when $default != null:
return $default(_that.period,_that.used,_that.limit,_that.remaining,_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String period,  int used,  int limit,  int remaining,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _PlateQuota():
return $default(_that.period,_that.used,_that.limit,_that.remaining,_that.enabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String period,  int used,  int limit,  int remaining,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _PlateQuota() when $default != null:
return $default(_that.period,_that.used,_that.limit,_that.remaining,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlateQuota implements PlateQuota {
  const _PlateQuota({required this.period, required this.used, required this.limit, required this.remaining, this.enabled = false});
  factory _PlateQuota.fromJson(Map<String, dynamic> json) => _$PlateQuotaFromJson(json);

@override final  String period;
@override final  int used;
@override final  int limit;
@override final  int remaining;
@override@JsonKey() final  bool enabled;

/// Create a copy of PlateQuota
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlateQuotaCopyWith<_PlateQuota> get copyWith => __$PlateQuotaCopyWithImpl<_PlateQuota>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlateQuotaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlateQuota&&(identical(other.period, period) || other.period == period)&&(identical(other.used, used) || other.used == used)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,period,used,limit,remaining,enabled);

@override
String toString() {
  return 'PlateQuota(period: $period, used: $used, limit: $limit, remaining: $remaining, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$PlateQuotaCopyWith<$Res> implements $PlateQuotaCopyWith<$Res> {
  factory _$PlateQuotaCopyWith(_PlateQuota value, $Res Function(_PlateQuota) _then) = __$PlateQuotaCopyWithImpl;
@override @useResult
$Res call({
 String period, int used, int limit, int remaining, bool enabled
});




}
/// @nodoc
class __$PlateQuotaCopyWithImpl<$Res>
    implements _$PlateQuotaCopyWith<$Res> {
  __$PlateQuotaCopyWithImpl(this._self, this._then);

  final _PlateQuota _self;
  final $Res Function(_PlateQuota) _then;

/// Create a copy of PlateQuota
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? period = null,Object? used = null,Object? limit = null,Object? remaining = null,Object? enabled = null,}) {
  return _then(_PlateQuota(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$PlateInfo {

 String get placa; String? get placaAlternativa; String? get marca; String? get modelo; String? get marcaModelo; String? get versao; String? get ano; String? get anoModelo; String? get cor; String? get chassi; String? get municipio; String? get uf; String? get situacao; String? get origem; String? get combustivel; String? get cilindradas; String? get especie; String? get tipoVeiculo; String? get passageiros; String? get segmento; String? get nacionalidade; String? get logoUrl; String? get consultadoEm; PlateFipe? get fipe;/// Todas as correspondências FIPE (ficha detalhada), maior score primeiro.
 List<PlateFipe> get fipeTodos;/// Equivalente no catálogo do cadastro (autofill + cascata).
 PlateFipeMatch? get fipeMatch;/// Bloco técnico completo da consulta (chave crua → valor). Rótulos em
/// `plate_labels.dart`; pode vir vazio (a API não garante este bloco).
 Map<String, String> get extra; bool get cached; PlateQuota? get usage;
/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlateInfoCopyWith<PlateInfo> get copyWith => _$PlateInfoCopyWithImpl<PlateInfo>(this as PlateInfo, _$identity);

  /// Serializes this PlateInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlateInfo&&(identical(other.placa, placa) || other.placa == placa)&&(identical(other.placaAlternativa, placaAlternativa) || other.placaAlternativa == placaAlternativa)&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.marcaModelo, marcaModelo) || other.marcaModelo == marcaModelo)&&(identical(other.versao, versao) || other.versao == versao)&&(identical(other.ano, ano) || other.ano == ano)&&(identical(other.anoModelo, anoModelo) || other.anoModelo == anoModelo)&&(identical(other.cor, cor) || other.cor == cor)&&(identical(other.chassi, chassi) || other.chassi == chassi)&&(identical(other.municipio, municipio) || other.municipio == municipio)&&(identical(other.uf, uf) || other.uf == uf)&&(identical(other.situacao, situacao) || other.situacao == situacao)&&(identical(other.origem, origem) || other.origem == origem)&&(identical(other.combustivel, combustivel) || other.combustivel == combustivel)&&(identical(other.cilindradas, cilindradas) || other.cilindradas == cilindradas)&&(identical(other.especie, especie) || other.especie == especie)&&(identical(other.tipoVeiculo, tipoVeiculo) || other.tipoVeiculo == tipoVeiculo)&&(identical(other.passageiros, passageiros) || other.passageiros == passageiros)&&(identical(other.segmento, segmento) || other.segmento == segmento)&&(identical(other.nacionalidade, nacionalidade) || other.nacionalidade == nacionalidade)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.consultadoEm, consultadoEm) || other.consultadoEm == consultadoEm)&&(identical(other.fipe, fipe) || other.fipe == fipe)&&const DeepCollectionEquality().equals(other.fipeTodos, fipeTodos)&&(identical(other.fipeMatch, fipeMatch) || other.fipeMatch == fipeMatch)&&const DeepCollectionEquality().equals(other.extra, extra)&&(identical(other.cached, cached) || other.cached == cached)&&(identical(other.usage, usage) || other.usage == usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,placa,placaAlternativa,marca,modelo,marcaModelo,versao,ano,anoModelo,cor,chassi,municipio,uf,situacao,origem,combustivel,cilindradas,especie,tipoVeiculo,passageiros,segmento,nacionalidade,logoUrl,consultadoEm,fipe,const DeepCollectionEquality().hash(fipeTodos),fipeMatch,const DeepCollectionEquality().hash(extra),cached,usage]);

@override
String toString() {
  return 'PlateInfo(placa: $placa, placaAlternativa: $placaAlternativa, marca: $marca, modelo: $modelo, marcaModelo: $marcaModelo, versao: $versao, ano: $ano, anoModelo: $anoModelo, cor: $cor, chassi: $chassi, municipio: $municipio, uf: $uf, situacao: $situacao, origem: $origem, combustivel: $combustivel, cilindradas: $cilindradas, especie: $especie, tipoVeiculo: $tipoVeiculo, passageiros: $passageiros, segmento: $segmento, nacionalidade: $nacionalidade, logoUrl: $logoUrl, consultadoEm: $consultadoEm, fipe: $fipe, fipeTodos: $fipeTodos, fipeMatch: $fipeMatch, extra: $extra, cached: $cached, usage: $usage)';
}


}

/// @nodoc
abstract mixin class $PlateInfoCopyWith<$Res>  {
  factory $PlateInfoCopyWith(PlateInfo value, $Res Function(PlateInfo) _then) = _$PlateInfoCopyWithImpl;
@useResult
$Res call({
 String placa, String? placaAlternativa, String? marca, String? modelo, String? marcaModelo, String? versao, String? ano, String? anoModelo, String? cor, String? chassi, String? municipio, String? uf, String? situacao, String? origem, String? combustivel, String? cilindradas, String? especie, String? tipoVeiculo, String? passageiros, String? segmento, String? nacionalidade, String? logoUrl, String? consultadoEm, PlateFipe? fipe, List<PlateFipe> fipeTodos, PlateFipeMatch? fipeMatch, Map<String, String> extra, bool cached, PlateQuota? usage
});


$PlateFipeCopyWith<$Res>? get fipe;$PlateFipeMatchCopyWith<$Res>? get fipeMatch;$PlateQuotaCopyWith<$Res>? get usage;

}
/// @nodoc
class _$PlateInfoCopyWithImpl<$Res>
    implements $PlateInfoCopyWith<$Res> {
  _$PlateInfoCopyWithImpl(this._self, this._then);

  final PlateInfo _self;
  final $Res Function(PlateInfo) _then;

/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? placa = null,Object? placaAlternativa = freezed,Object? marca = freezed,Object? modelo = freezed,Object? marcaModelo = freezed,Object? versao = freezed,Object? ano = freezed,Object? anoModelo = freezed,Object? cor = freezed,Object? chassi = freezed,Object? municipio = freezed,Object? uf = freezed,Object? situacao = freezed,Object? origem = freezed,Object? combustivel = freezed,Object? cilindradas = freezed,Object? especie = freezed,Object? tipoVeiculo = freezed,Object? passageiros = freezed,Object? segmento = freezed,Object? nacionalidade = freezed,Object? logoUrl = freezed,Object? consultadoEm = freezed,Object? fipe = freezed,Object? fipeTodos = null,Object? fipeMatch = freezed,Object? extra = null,Object? cached = null,Object? usage = freezed,}) {
  return _then(_self.copyWith(
placa: null == placa ? _self.placa : placa // ignore: cast_nullable_to_non_nullable
as String,placaAlternativa: freezed == placaAlternativa ? _self.placaAlternativa : placaAlternativa // ignore: cast_nullable_to_non_nullable
as String?,marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as String?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as String?,marcaModelo: freezed == marcaModelo ? _self.marcaModelo : marcaModelo // ignore: cast_nullable_to_non_nullable
as String?,versao: freezed == versao ? _self.versao : versao // ignore: cast_nullable_to_non_nullable
as String?,ano: freezed == ano ? _self.ano : ano // ignore: cast_nullable_to_non_nullable
as String?,anoModelo: freezed == anoModelo ? _self.anoModelo : anoModelo // ignore: cast_nullable_to_non_nullable
as String?,cor: freezed == cor ? _self.cor : cor // ignore: cast_nullable_to_non_nullable
as String?,chassi: freezed == chassi ? _self.chassi : chassi // ignore: cast_nullable_to_non_nullable
as String?,municipio: freezed == municipio ? _self.municipio : municipio // ignore: cast_nullable_to_non_nullable
as String?,uf: freezed == uf ? _self.uf : uf // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,origem: freezed == origem ? _self.origem : origem // ignore: cast_nullable_to_non_nullable
as String?,combustivel: freezed == combustivel ? _self.combustivel : combustivel // ignore: cast_nullable_to_non_nullable
as String?,cilindradas: freezed == cilindradas ? _self.cilindradas : cilindradas // ignore: cast_nullable_to_non_nullable
as String?,especie: freezed == especie ? _self.especie : especie // ignore: cast_nullable_to_non_nullable
as String?,tipoVeiculo: freezed == tipoVeiculo ? _self.tipoVeiculo : tipoVeiculo // ignore: cast_nullable_to_non_nullable
as String?,passageiros: freezed == passageiros ? _self.passageiros : passageiros // ignore: cast_nullable_to_non_nullable
as String?,segmento: freezed == segmento ? _self.segmento : segmento // ignore: cast_nullable_to_non_nullable
as String?,nacionalidade: freezed == nacionalidade ? _self.nacionalidade : nacionalidade // ignore: cast_nullable_to_non_nullable
as String?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,consultadoEm: freezed == consultadoEm ? _self.consultadoEm : consultadoEm // ignore: cast_nullable_to_non_nullable
as String?,fipe: freezed == fipe ? _self.fipe : fipe // ignore: cast_nullable_to_non_nullable
as PlateFipe?,fipeTodos: null == fipeTodos ? _self.fipeTodos : fipeTodos // ignore: cast_nullable_to_non_nullable
as List<PlateFipe>,fipeMatch: freezed == fipeMatch ? _self.fipeMatch : fipeMatch // ignore: cast_nullable_to_non_nullable
as PlateFipeMatch?,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, String>,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as PlateQuota?,
  ));
}
/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeCopyWith<$Res>? get fipe {
    if (_self.fipe == null) {
    return null;
  }

  return $PlateFipeCopyWith<$Res>(_self.fipe!, (value) {
    return _then(_self.copyWith(fipe: value));
  });
}/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeMatchCopyWith<$Res>? get fipeMatch {
    if (_self.fipeMatch == null) {
    return null;
  }

  return $PlateFipeMatchCopyWith<$Res>(_self.fipeMatch!, (value) {
    return _then(_self.copyWith(fipeMatch: value));
  });
}/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateQuotaCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $PlateQuotaCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlateInfo].
extension PlateInfoPatterns on PlateInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlateInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlateInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlateInfo value)  $default,){
final _that = this;
switch (_that) {
case _PlateInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlateInfo value)?  $default,){
final _that = this;
switch (_that) {
case _PlateInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String placa,  String? placaAlternativa,  String? marca,  String? modelo,  String? marcaModelo,  String? versao,  String? ano,  String? anoModelo,  String? cor,  String? chassi,  String? municipio,  String? uf,  String? situacao,  String? origem,  String? combustivel,  String? cilindradas,  String? especie,  String? tipoVeiculo,  String? passageiros,  String? segmento,  String? nacionalidade,  String? logoUrl,  String? consultadoEm,  PlateFipe? fipe,  List<PlateFipe> fipeTodos,  PlateFipeMatch? fipeMatch,  Map<String, String> extra,  bool cached,  PlateQuota? usage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlateInfo() when $default != null:
return $default(_that.placa,_that.placaAlternativa,_that.marca,_that.modelo,_that.marcaModelo,_that.versao,_that.ano,_that.anoModelo,_that.cor,_that.chassi,_that.municipio,_that.uf,_that.situacao,_that.origem,_that.combustivel,_that.cilindradas,_that.especie,_that.tipoVeiculo,_that.passageiros,_that.segmento,_that.nacionalidade,_that.logoUrl,_that.consultadoEm,_that.fipe,_that.fipeTodos,_that.fipeMatch,_that.extra,_that.cached,_that.usage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String placa,  String? placaAlternativa,  String? marca,  String? modelo,  String? marcaModelo,  String? versao,  String? ano,  String? anoModelo,  String? cor,  String? chassi,  String? municipio,  String? uf,  String? situacao,  String? origem,  String? combustivel,  String? cilindradas,  String? especie,  String? tipoVeiculo,  String? passageiros,  String? segmento,  String? nacionalidade,  String? logoUrl,  String? consultadoEm,  PlateFipe? fipe,  List<PlateFipe> fipeTodos,  PlateFipeMatch? fipeMatch,  Map<String, String> extra,  bool cached,  PlateQuota? usage)  $default,) {final _that = this;
switch (_that) {
case _PlateInfo():
return $default(_that.placa,_that.placaAlternativa,_that.marca,_that.modelo,_that.marcaModelo,_that.versao,_that.ano,_that.anoModelo,_that.cor,_that.chassi,_that.municipio,_that.uf,_that.situacao,_that.origem,_that.combustivel,_that.cilindradas,_that.especie,_that.tipoVeiculo,_that.passageiros,_that.segmento,_that.nacionalidade,_that.logoUrl,_that.consultadoEm,_that.fipe,_that.fipeTodos,_that.fipeMatch,_that.extra,_that.cached,_that.usage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String placa,  String? placaAlternativa,  String? marca,  String? modelo,  String? marcaModelo,  String? versao,  String? ano,  String? anoModelo,  String? cor,  String? chassi,  String? municipio,  String? uf,  String? situacao,  String? origem,  String? combustivel,  String? cilindradas,  String? especie,  String? tipoVeiculo,  String? passageiros,  String? segmento,  String? nacionalidade,  String? logoUrl,  String? consultadoEm,  PlateFipe? fipe,  List<PlateFipe> fipeTodos,  PlateFipeMatch? fipeMatch,  Map<String, String> extra,  bool cached,  PlateQuota? usage)?  $default,) {final _that = this;
switch (_that) {
case _PlateInfo() when $default != null:
return $default(_that.placa,_that.placaAlternativa,_that.marca,_that.modelo,_that.marcaModelo,_that.versao,_that.ano,_that.anoModelo,_that.cor,_that.chassi,_that.municipio,_that.uf,_that.situacao,_that.origem,_that.combustivel,_that.cilindradas,_that.especie,_that.tipoVeiculo,_that.passageiros,_that.segmento,_that.nacionalidade,_that.logoUrl,_that.consultadoEm,_that.fipe,_that.fipeTodos,_that.fipeMatch,_that.extra,_that.cached,_that.usage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlateInfo implements PlateInfo {
  const _PlateInfo({required this.placa, this.placaAlternativa, this.marca, this.modelo, this.marcaModelo, this.versao, this.ano, this.anoModelo, this.cor, this.chassi, this.municipio, this.uf, this.situacao, this.origem, this.combustivel, this.cilindradas, this.especie, this.tipoVeiculo, this.passageiros, this.segmento, this.nacionalidade, this.logoUrl, this.consultadoEm, this.fipe, final  List<PlateFipe> fipeTodos = const <PlateFipe>[], this.fipeMatch, final  Map<String, String> extra = const <String, String>{}, this.cached = false, this.usage}): _fipeTodos = fipeTodos,_extra = extra;
  factory _PlateInfo.fromJson(Map<String, dynamic> json) => _$PlateInfoFromJson(json);

@override final  String placa;
@override final  String? placaAlternativa;
@override final  String? marca;
@override final  String? modelo;
@override final  String? marcaModelo;
@override final  String? versao;
@override final  String? ano;
@override final  String? anoModelo;
@override final  String? cor;
@override final  String? chassi;
@override final  String? municipio;
@override final  String? uf;
@override final  String? situacao;
@override final  String? origem;
@override final  String? combustivel;
@override final  String? cilindradas;
@override final  String? especie;
@override final  String? tipoVeiculo;
@override final  String? passageiros;
@override final  String? segmento;
@override final  String? nacionalidade;
@override final  String? logoUrl;
@override final  String? consultadoEm;
@override final  PlateFipe? fipe;
/// Todas as correspondências FIPE (ficha detalhada), maior score primeiro.
 final  List<PlateFipe> _fipeTodos;
/// Todas as correspondências FIPE (ficha detalhada), maior score primeiro.
@override@JsonKey() List<PlateFipe> get fipeTodos {
  if (_fipeTodos is EqualUnmodifiableListView) return _fipeTodos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fipeTodos);
}

/// Equivalente no catálogo do cadastro (autofill + cascata).
@override final  PlateFipeMatch? fipeMatch;
/// Bloco técnico completo da consulta (chave crua → valor). Rótulos em
/// `plate_labels.dart`; pode vir vazio (a API não garante este bloco).
 final  Map<String, String> _extra;
/// Bloco técnico completo da consulta (chave crua → valor). Rótulos em
/// `plate_labels.dart`; pode vir vazio (a API não garante este bloco).
@override@JsonKey() Map<String, String> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}

@override@JsonKey() final  bool cached;
@override final  PlateQuota? usage;

/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlateInfoCopyWith<_PlateInfo> get copyWith => __$PlateInfoCopyWithImpl<_PlateInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlateInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlateInfo&&(identical(other.placa, placa) || other.placa == placa)&&(identical(other.placaAlternativa, placaAlternativa) || other.placaAlternativa == placaAlternativa)&&(identical(other.marca, marca) || other.marca == marca)&&(identical(other.modelo, modelo) || other.modelo == modelo)&&(identical(other.marcaModelo, marcaModelo) || other.marcaModelo == marcaModelo)&&(identical(other.versao, versao) || other.versao == versao)&&(identical(other.ano, ano) || other.ano == ano)&&(identical(other.anoModelo, anoModelo) || other.anoModelo == anoModelo)&&(identical(other.cor, cor) || other.cor == cor)&&(identical(other.chassi, chassi) || other.chassi == chassi)&&(identical(other.municipio, municipio) || other.municipio == municipio)&&(identical(other.uf, uf) || other.uf == uf)&&(identical(other.situacao, situacao) || other.situacao == situacao)&&(identical(other.origem, origem) || other.origem == origem)&&(identical(other.combustivel, combustivel) || other.combustivel == combustivel)&&(identical(other.cilindradas, cilindradas) || other.cilindradas == cilindradas)&&(identical(other.especie, especie) || other.especie == especie)&&(identical(other.tipoVeiculo, tipoVeiculo) || other.tipoVeiculo == tipoVeiculo)&&(identical(other.passageiros, passageiros) || other.passageiros == passageiros)&&(identical(other.segmento, segmento) || other.segmento == segmento)&&(identical(other.nacionalidade, nacionalidade) || other.nacionalidade == nacionalidade)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.consultadoEm, consultadoEm) || other.consultadoEm == consultadoEm)&&(identical(other.fipe, fipe) || other.fipe == fipe)&&const DeepCollectionEquality().equals(other._fipeTodos, _fipeTodos)&&(identical(other.fipeMatch, fipeMatch) || other.fipeMatch == fipeMatch)&&const DeepCollectionEquality().equals(other._extra, _extra)&&(identical(other.cached, cached) || other.cached == cached)&&(identical(other.usage, usage) || other.usage == usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,placa,placaAlternativa,marca,modelo,marcaModelo,versao,ano,anoModelo,cor,chassi,municipio,uf,situacao,origem,combustivel,cilindradas,especie,tipoVeiculo,passageiros,segmento,nacionalidade,logoUrl,consultadoEm,fipe,const DeepCollectionEquality().hash(_fipeTodos),fipeMatch,const DeepCollectionEquality().hash(_extra),cached,usage]);

@override
String toString() {
  return 'PlateInfo(placa: $placa, placaAlternativa: $placaAlternativa, marca: $marca, modelo: $modelo, marcaModelo: $marcaModelo, versao: $versao, ano: $ano, anoModelo: $anoModelo, cor: $cor, chassi: $chassi, municipio: $municipio, uf: $uf, situacao: $situacao, origem: $origem, combustivel: $combustivel, cilindradas: $cilindradas, especie: $especie, tipoVeiculo: $tipoVeiculo, passageiros: $passageiros, segmento: $segmento, nacionalidade: $nacionalidade, logoUrl: $logoUrl, consultadoEm: $consultadoEm, fipe: $fipe, fipeTodos: $fipeTodos, fipeMatch: $fipeMatch, extra: $extra, cached: $cached, usage: $usage)';
}


}

/// @nodoc
abstract mixin class _$PlateInfoCopyWith<$Res> implements $PlateInfoCopyWith<$Res> {
  factory _$PlateInfoCopyWith(_PlateInfo value, $Res Function(_PlateInfo) _then) = __$PlateInfoCopyWithImpl;
@override @useResult
$Res call({
 String placa, String? placaAlternativa, String? marca, String? modelo, String? marcaModelo, String? versao, String? ano, String? anoModelo, String? cor, String? chassi, String? municipio, String? uf, String? situacao, String? origem, String? combustivel, String? cilindradas, String? especie, String? tipoVeiculo, String? passageiros, String? segmento, String? nacionalidade, String? logoUrl, String? consultadoEm, PlateFipe? fipe, List<PlateFipe> fipeTodos, PlateFipeMatch? fipeMatch, Map<String, String> extra, bool cached, PlateQuota? usage
});


@override $PlateFipeCopyWith<$Res>? get fipe;@override $PlateFipeMatchCopyWith<$Res>? get fipeMatch;@override $PlateQuotaCopyWith<$Res>? get usage;

}
/// @nodoc
class __$PlateInfoCopyWithImpl<$Res>
    implements _$PlateInfoCopyWith<$Res> {
  __$PlateInfoCopyWithImpl(this._self, this._then);

  final _PlateInfo _self;
  final $Res Function(_PlateInfo) _then;

/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? placa = null,Object? placaAlternativa = freezed,Object? marca = freezed,Object? modelo = freezed,Object? marcaModelo = freezed,Object? versao = freezed,Object? ano = freezed,Object? anoModelo = freezed,Object? cor = freezed,Object? chassi = freezed,Object? municipio = freezed,Object? uf = freezed,Object? situacao = freezed,Object? origem = freezed,Object? combustivel = freezed,Object? cilindradas = freezed,Object? especie = freezed,Object? tipoVeiculo = freezed,Object? passageiros = freezed,Object? segmento = freezed,Object? nacionalidade = freezed,Object? logoUrl = freezed,Object? consultadoEm = freezed,Object? fipe = freezed,Object? fipeTodos = null,Object? fipeMatch = freezed,Object? extra = null,Object? cached = null,Object? usage = freezed,}) {
  return _then(_PlateInfo(
placa: null == placa ? _self.placa : placa // ignore: cast_nullable_to_non_nullable
as String,placaAlternativa: freezed == placaAlternativa ? _self.placaAlternativa : placaAlternativa // ignore: cast_nullable_to_non_nullable
as String?,marca: freezed == marca ? _self.marca : marca // ignore: cast_nullable_to_non_nullable
as String?,modelo: freezed == modelo ? _self.modelo : modelo // ignore: cast_nullable_to_non_nullable
as String?,marcaModelo: freezed == marcaModelo ? _self.marcaModelo : marcaModelo // ignore: cast_nullable_to_non_nullable
as String?,versao: freezed == versao ? _self.versao : versao // ignore: cast_nullable_to_non_nullable
as String?,ano: freezed == ano ? _self.ano : ano // ignore: cast_nullable_to_non_nullable
as String?,anoModelo: freezed == anoModelo ? _self.anoModelo : anoModelo // ignore: cast_nullable_to_non_nullable
as String?,cor: freezed == cor ? _self.cor : cor // ignore: cast_nullable_to_non_nullable
as String?,chassi: freezed == chassi ? _self.chassi : chassi // ignore: cast_nullable_to_non_nullable
as String?,municipio: freezed == municipio ? _self.municipio : municipio // ignore: cast_nullable_to_non_nullable
as String?,uf: freezed == uf ? _self.uf : uf // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,origem: freezed == origem ? _self.origem : origem // ignore: cast_nullable_to_non_nullable
as String?,combustivel: freezed == combustivel ? _self.combustivel : combustivel // ignore: cast_nullable_to_non_nullable
as String?,cilindradas: freezed == cilindradas ? _self.cilindradas : cilindradas // ignore: cast_nullable_to_non_nullable
as String?,especie: freezed == especie ? _self.especie : especie // ignore: cast_nullable_to_non_nullable
as String?,tipoVeiculo: freezed == tipoVeiculo ? _self.tipoVeiculo : tipoVeiculo // ignore: cast_nullable_to_non_nullable
as String?,passageiros: freezed == passageiros ? _self.passageiros : passageiros // ignore: cast_nullable_to_non_nullable
as String?,segmento: freezed == segmento ? _self.segmento : segmento // ignore: cast_nullable_to_non_nullable
as String?,nacionalidade: freezed == nacionalidade ? _self.nacionalidade : nacionalidade // ignore: cast_nullable_to_non_nullable
as String?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,consultadoEm: freezed == consultadoEm ? _self.consultadoEm : consultadoEm // ignore: cast_nullable_to_non_nullable
as String?,fipe: freezed == fipe ? _self.fipe : fipe // ignore: cast_nullable_to_non_nullable
as PlateFipe?,fipeTodos: null == fipeTodos ? _self._fipeTodos : fipeTodos // ignore: cast_nullable_to_non_nullable
as List<PlateFipe>,fipeMatch: freezed == fipeMatch ? _self.fipeMatch : fipeMatch // ignore: cast_nullable_to_non_nullable
as PlateFipeMatch?,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, String>,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as PlateQuota?,
  ));
}

/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeCopyWith<$Res>? get fipe {
    if (_self.fipe == null) {
    return null;
  }

  return $PlateFipeCopyWith<$Res>(_self.fipe!, (value) {
    return _then(_self.copyWith(fipe: value));
  });
}/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateFipeMatchCopyWith<$Res>? get fipeMatch {
    if (_self.fipeMatch == null) {
    return null;
  }

  return $PlateFipeMatchCopyWith<$Res>(_self.fipeMatch!, (value) {
    return _then(_self.copyWith(fipeMatch: value));
  });
}/// Create a copy of PlateInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlateQuotaCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $PlateQuotaCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}
}


/// @nodoc
mixin _$CnpjEmpresa {

 String get cnpj; String get razaoSocial; String? get nomeFantasia; String? get situacao; String? get telefone; String? get email; String? get logradouro; String? get numero; String? get bairro; String? get municipio; String? get uf; String? get cep;
/// Create a copy of CnpjEmpresa
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CnpjEmpresaCopyWith<CnpjEmpresa> get copyWith => _$CnpjEmpresaCopyWithImpl<CnpjEmpresa>(this as CnpjEmpresa, _$identity);

  /// Serializes this CnpjEmpresa to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CnpjEmpresa&&(identical(other.cnpj, cnpj) || other.cnpj == cnpj)&&(identical(other.razaoSocial, razaoSocial) || other.razaoSocial == razaoSocial)&&(identical(other.nomeFantasia, nomeFantasia) || other.nomeFantasia == nomeFantasia)&&(identical(other.situacao, situacao) || other.situacao == situacao)&&(identical(other.telefone, telefone) || other.telefone == telefone)&&(identical(other.email, email) || other.email == email)&&(identical(other.logradouro, logradouro) || other.logradouro == logradouro)&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.bairro, bairro) || other.bairro == bairro)&&(identical(other.municipio, municipio) || other.municipio == municipio)&&(identical(other.uf, uf) || other.uf == uf)&&(identical(other.cep, cep) || other.cep == cep));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cnpj,razaoSocial,nomeFantasia,situacao,telefone,email,logradouro,numero,bairro,municipio,uf,cep);

@override
String toString() {
  return 'CnpjEmpresa(cnpj: $cnpj, razaoSocial: $razaoSocial, nomeFantasia: $nomeFantasia, situacao: $situacao, telefone: $telefone, email: $email, logradouro: $logradouro, numero: $numero, bairro: $bairro, municipio: $municipio, uf: $uf, cep: $cep)';
}


}

/// @nodoc
abstract mixin class $CnpjEmpresaCopyWith<$Res>  {
  factory $CnpjEmpresaCopyWith(CnpjEmpresa value, $Res Function(CnpjEmpresa) _then) = _$CnpjEmpresaCopyWithImpl;
@useResult
$Res call({
 String cnpj, String razaoSocial, String? nomeFantasia, String? situacao, String? telefone, String? email, String? logradouro, String? numero, String? bairro, String? municipio, String? uf, String? cep
});




}
/// @nodoc
class _$CnpjEmpresaCopyWithImpl<$Res>
    implements $CnpjEmpresaCopyWith<$Res> {
  _$CnpjEmpresaCopyWithImpl(this._self, this._then);

  final CnpjEmpresa _self;
  final $Res Function(CnpjEmpresa) _then;

/// Create a copy of CnpjEmpresa
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cnpj = null,Object? razaoSocial = null,Object? nomeFantasia = freezed,Object? situacao = freezed,Object? telefone = freezed,Object? email = freezed,Object? logradouro = freezed,Object? numero = freezed,Object? bairro = freezed,Object? municipio = freezed,Object? uf = freezed,Object? cep = freezed,}) {
  return _then(_self.copyWith(
cnpj: null == cnpj ? _self.cnpj : cnpj // ignore: cast_nullable_to_non_nullable
as String,razaoSocial: null == razaoSocial ? _self.razaoSocial : razaoSocial // ignore: cast_nullable_to_non_nullable
as String,nomeFantasia: freezed == nomeFantasia ? _self.nomeFantasia : nomeFantasia // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,telefone: freezed == telefone ? _self.telefone : telefone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,logradouro: freezed == logradouro ? _self.logradouro : logradouro // ignore: cast_nullable_to_non_nullable
as String?,numero: freezed == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as String?,bairro: freezed == bairro ? _self.bairro : bairro // ignore: cast_nullable_to_non_nullable
as String?,municipio: freezed == municipio ? _self.municipio : municipio // ignore: cast_nullable_to_non_nullable
as String?,uf: freezed == uf ? _self.uf : uf // ignore: cast_nullable_to_non_nullable
as String?,cep: freezed == cep ? _self.cep : cep // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CnpjEmpresa].
extension CnpjEmpresaPatterns on CnpjEmpresa {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CnpjEmpresa value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CnpjEmpresa() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CnpjEmpresa value)  $default,){
final _that = this;
switch (_that) {
case _CnpjEmpresa():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CnpjEmpresa value)?  $default,){
final _that = this;
switch (_that) {
case _CnpjEmpresa() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String cnpj,  String razaoSocial,  String? nomeFantasia,  String? situacao,  String? telefone,  String? email,  String? logradouro,  String? numero,  String? bairro,  String? municipio,  String? uf,  String? cep)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CnpjEmpresa() when $default != null:
return $default(_that.cnpj,_that.razaoSocial,_that.nomeFantasia,_that.situacao,_that.telefone,_that.email,_that.logradouro,_that.numero,_that.bairro,_that.municipio,_that.uf,_that.cep);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String cnpj,  String razaoSocial,  String? nomeFantasia,  String? situacao,  String? telefone,  String? email,  String? logradouro,  String? numero,  String? bairro,  String? municipio,  String? uf,  String? cep)  $default,) {final _that = this;
switch (_that) {
case _CnpjEmpresa():
return $default(_that.cnpj,_that.razaoSocial,_that.nomeFantasia,_that.situacao,_that.telefone,_that.email,_that.logradouro,_that.numero,_that.bairro,_that.municipio,_that.uf,_that.cep);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String cnpj,  String razaoSocial,  String? nomeFantasia,  String? situacao,  String? telefone,  String? email,  String? logradouro,  String? numero,  String? bairro,  String? municipio,  String? uf,  String? cep)?  $default,) {final _that = this;
switch (_that) {
case _CnpjEmpresa() when $default != null:
return $default(_that.cnpj,_that.razaoSocial,_that.nomeFantasia,_that.situacao,_that.telefone,_that.email,_that.logradouro,_that.numero,_that.bairro,_that.municipio,_that.uf,_that.cep);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CnpjEmpresa implements CnpjEmpresa {
  const _CnpjEmpresa({this.cnpj = '', this.razaoSocial = '', this.nomeFantasia, this.situacao, this.telefone, this.email, this.logradouro, this.numero, this.bairro, this.municipio, this.uf, this.cep});
  factory _CnpjEmpresa.fromJson(Map<String, dynamic> json) => _$CnpjEmpresaFromJson(json);

@override@JsonKey() final  String cnpj;
@override@JsonKey() final  String razaoSocial;
@override final  String? nomeFantasia;
@override final  String? situacao;
@override final  String? telefone;
@override final  String? email;
@override final  String? logradouro;
@override final  String? numero;
@override final  String? bairro;
@override final  String? municipio;
@override final  String? uf;
@override final  String? cep;

/// Create a copy of CnpjEmpresa
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CnpjEmpresaCopyWith<_CnpjEmpresa> get copyWith => __$CnpjEmpresaCopyWithImpl<_CnpjEmpresa>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CnpjEmpresaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CnpjEmpresa&&(identical(other.cnpj, cnpj) || other.cnpj == cnpj)&&(identical(other.razaoSocial, razaoSocial) || other.razaoSocial == razaoSocial)&&(identical(other.nomeFantasia, nomeFantasia) || other.nomeFantasia == nomeFantasia)&&(identical(other.situacao, situacao) || other.situacao == situacao)&&(identical(other.telefone, telefone) || other.telefone == telefone)&&(identical(other.email, email) || other.email == email)&&(identical(other.logradouro, logradouro) || other.logradouro == logradouro)&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.bairro, bairro) || other.bairro == bairro)&&(identical(other.municipio, municipio) || other.municipio == municipio)&&(identical(other.uf, uf) || other.uf == uf)&&(identical(other.cep, cep) || other.cep == cep));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cnpj,razaoSocial,nomeFantasia,situacao,telefone,email,logradouro,numero,bairro,municipio,uf,cep);

@override
String toString() {
  return 'CnpjEmpresa(cnpj: $cnpj, razaoSocial: $razaoSocial, nomeFantasia: $nomeFantasia, situacao: $situacao, telefone: $telefone, email: $email, logradouro: $logradouro, numero: $numero, bairro: $bairro, municipio: $municipio, uf: $uf, cep: $cep)';
}


}

/// @nodoc
abstract mixin class _$CnpjEmpresaCopyWith<$Res> implements $CnpjEmpresaCopyWith<$Res> {
  factory _$CnpjEmpresaCopyWith(_CnpjEmpresa value, $Res Function(_CnpjEmpresa) _then) = __$CnpjEmpresaCopyWithImpl;
@override @useResult
$Res call({
 String cnpj, String razaoSocial, String? nomeFantasia, String? situacao, String? telefone, String? email, String? logradouro, String? numero, String? bairro, String? municipio, String? uf, String? cep
});




}
/// @nodoc
class __$CnpjEmpresaCopyWithImpl<$Res>
    implements _$CnpjEmpresaCopyWith<$Res> {
  __$CnpjEmpresaCopyWithImpl(this._self, this._then);

  final _CnpjEmpresa _self;
  final $Res Function(_CnpjEmpresa) _then;

/// Create a copy of CnpjEmpresa
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cnpj = null,Object? razaoSocial = null,Object? nomeFantasia = freezed,Object? situacao = freezed,Object? telefone = freezed,Object? email = freezed,Object? logradouro = freezed,Object? numero = freezed,Object? bairro = freezed,Object? municipio = freezed,Object? uf = freezed,Object? cep = freezed,}) {
  return _then(_CnpjEmpresa(
cnpj: null == cnpj ? _self.cnpj : cnpj // ignore: cast_nullable_to_non_nullable
as String,razaoSocial: null == razaoSocial ? _self.razaoSocial : razaoSocial // ignore: cast_nullable_to_non_nullable
as String,nomeFantasia: freezed == nomeFantasia ? _self.nomeFantasia : nomeFantasia // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,telefone: freezed == telefone ? _self.telefone : telefone // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,logradouro: freezed == logradouro ? _self.logradouro : logradouro // ignore: cast_nullable_to_non_nullable
as String?,numero: freezed == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as String?,bairro: freezed == bairro ? _self.bairro : bairro // ignore: cast_nullable_to_non_nullable
as String?,municipio: freezed == municipio ? _self.municipio : municipio // ignore: cast_nullable_to_non_nullable
as String?,uf: freezed == uf ? _self.uf : uf // ignore: cast_nullable_to_non_nullable
as String?,cep: freezed == cep ? _self.cep : cep // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
