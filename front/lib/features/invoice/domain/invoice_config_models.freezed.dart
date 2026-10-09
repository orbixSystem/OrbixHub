// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invoice_config_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CertificateInfo {

@JsonKey(name: 'validoAte') String? get validoAte;
/// Create a copy of CertificateInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CertificateInfoCopyWith<CertificateInfo> get copyWith => _$CertificateInfoCopyWithImpl<CertificateInfo>(this as CertificateInfo, _$identity);

  /// Serializes this CertificateInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CertificateInfo&&(identical(other.validoAte, validoAte) || other.validoAte == validoAte));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,validoAte);

@override
String toString() {
  return 'CertificateInfo(validoAte: $validoAte)';
}


}

/// @nodoc
abstract mixin class $CertificateInfoCopyWith<$Res>  {
  factory $CertificateInfoCopyWith(CertificateInfo value, $Res Function(CertificateInfo) _then) = _$CertificateInfoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'validoAte') String? validoAte
});




}
/// @nodoc
class _$CertificateInfoCopyWithImpl<$Res>
    implements $CertificateInfoCopyWith<$Res> {
  _$CertificateInfoCopyWithImpl(this._self, this._then);

  final CertificateInfo _self;
  final $Res Function(CertificateInfo) _then;

/// Create a copy of CertificateInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? validoAte = freezed,}) {
  return _then(_self.copyWith(
validoAte: freezed == validoAte ? _self.validoAte : validoAte // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CertificateInfo].
extension CertificateInfoPatterns on CertificateInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CertificateInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CertificateInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CertificateInfo value)  $default,){
final _that = this;
switch (_that) {
case _CertificateInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CertificateInfo value)?  $default,){
final _that = this;
switch (_that) {
case _CertificateInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'validoAte')  String? validoAte)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CertificateInfo() when $default != null:
return $default(_that.validoAte);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'validoAte')  String? validoAte)  $default,) {final _that = this;
switch (_that) {
case _CertificateInfo():
return $default(_that.validoAte);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'validoAte')  String? validoAte)?  $default,) {final _that = this;
switch (_that) {
case _CertificateInfo() when $default != null:
return $default(_that.validoAte);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CertificateInfo implements CertificateInfo {
  const _CertificateInfo({@JsonKey(name: 'validoAte') this.validoAte});
  factory _CertificateInfo.fromJson(Map<String, dynamic> json) => _$CertificateInfoFromJson(json);

@override@JsonKey(name: 'validoAte') final  String? validoAte;

/// Create a copy of CertificateInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CertificateInfoCopyWith<_CertificateInfo> get copyWith => __$CertificateInfoCopyWithImpl<_CertificateInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CertificateInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CertificateInfo&&(identical(other.validoAte, validoAte) || other.validoAte == validoAte));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,validoAte);

@override
String toString() {
  return 'CertificateInfo(validoAte: $validoAte)';
}


}

/// @nodoc
abstract mixin class _$CertificateInfoCopyWith<$Res> implements $CertificateInfoCopyWith<$Res> {
  factory _$CertificateInfoCopyWith(_CertificateInfo value, $Res Function(_CertificateInfo) _then) = __$CertificateInfoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'validoAte') String? validoAte
});




}
/// @nodoc
class __$CertificateInfoCopyWithImpl<$Res>
    implements _$CertificateInfoCopyWith<$Res> {
  __$CertificateInfoCopyWithImpl(this._self, this._then);

  final _CertificateInfo _self;
  final $Res Function(_CertificateInfo) _then;

/// Create a copy of CertificateInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? validoAte = freezed,}) {
  return _then(_CertificateInfo(
validoAte: freezed == validoAte ? _self.validoAte : validoAte // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$InvoiceFiscalConfig {

 String get ambiente; String get serieNfse; String get serieNfce; String get serieNfe; String get idCsc; bool get empresaRegistrada; CertificateInfo get certificado; String get provider; List<String> get pendencias; String get codigoServicoNacional; String get codigoNbs; double? get aliquotaIss; double? get percentualTributosSimples;
/// Create a copy of InvoiceFiscalConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceFiscalConfigCopyWith<InvoiceFiscalConfig> get copyWith => _$InvoiceFiscalConfigCopyWithImpl<InvoiceFiscalConfig>(this as InvoiceFiscalConfig, _$identity);

  /// Serializes this InvoiceFiscalConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceFiscalConfig&&(identical(other.ambiente, ambiente) || other.ambiente == ambiente)&&(identical(other.serieNfse, serieNfse) || other.serieNfse == serieNfse)&&(identical(other.serieNfce, serieNfce) || other.serieNfce == serieNfce)&&(identical(other.serieNfe, serieNfe) || other.serieNfe == serieNfe)&&(identical(other.idCsc, idCsc) || other.idCsc == idCsc)&&(identical(other.empresaRegistrada, empresaRegistrada) || other.empresaRegistrada == empresaRegistrada)&&(identical(other.certificado, certificado) || other.certificado == certificado)&&(identical(other.provider, provider) || other.provider == provider)&&const DeepCollectionEquality().equals(other.pendencias, pendencias)&&(identical(other.codigoServicoNacional, codigoServicoNacional) || other.codigoServicoNacional == codigoServicoNacional)&&(identical(other.codigoNbs, codigoNbs) || other.codigoNbs == codigoNbs)&&(identical(other.aliquotaIss, aliquotaIss) || other.aliquotaIss == aliquotaIss)&&(identical(other.percentualTributosSimples, percentualTributosSimples) || other.percentualTributosSimples == percentualTributosSimples));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ambiente,serieNfse,serieNfce,serieNfe,idCsc,empresaRegistrada,certificado,provider,const DeepCollectionEquality().hash(pendencias),codigoServicoNacional,codigoNbs,aliquotaIss,percentualTributosSimples);

@override
String toString() {
  return 'InvoiceFiscalConfig(ambiente: $ambiente, serieNfse: $serieNfse, serieNfce: $serieNfce, serieNfe: $serieNfe, idCsc: $idCsc, empresaRegistrada: $empresaRegistrada, certificado: $certificado, provider: $provider, pendencias: $pendencias, codigoServicoNacional: $codigoServicoNacional, codigoNbs: $codigoNbs, aliquotaIss: $aliquotaIss, percentualTributosSimples: $percentualTributosSimples)';
}


}

/// @nodoc
abstract mixin class $InvoiceFiscalConfigCopyWith<$Res>  {
  factory $InvoiceFiscalConfigCopyWith(InvoiceFiscalConfig value, $Res Function(InvoiceFiscalConfig) _then) = _$InvoiceFiscalConfigCopyWithImpl;
@useResult
$Res call({
 String ambiente, String serieNfse, String serieNfce, String serieNfe, String idCsc, bool empresaRegistrada, CertificateInfo certificado, String provider, List<String> pendencias, String codigoServicoNacional, String codigoNbs, double? aliquotaIss, double? percentualTributosSimples
});


$CertificateInfoCopyWith<$Res> get certificado;

}
/// @nodoc
class _$InvoiceFiscalConfigCopyWithImpl<$Res>
    implements $InvoiceFiscalConfigCopyWith<$Res> {
  _$InvoiceFiscalConfigCopyWithImpl(this._self, this._then);

  final InvoiceFiscalConfig _self;
  final $Res Function(InvoiceFiscalConfig) _then;

/// Create a copy of InvoiceFiscalConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ambiente = null,Object? serieNfse = null,Object? serieNfce = null,Object? serieNfe = null,Object? idCsc = null,Object? empresaRegistrada = null,Object? certificado = null,Object? provider = null,Object? pendencias = null,Object? codigoServicoNacional = null,Object? codigoNbs = null,Object? aliquotaIss = freezed,Object? percentualTributosSimples = freezed,}) {
  return _then(_self.copyWith(
ambiente: null == ambiente ? _self.ambiente : ambiente // ignore: cast_nullable_to_non_nullable
as String,serieNfse: null == serieNfse ? _self.serieNfse : serieNfse // ignore: cast_nullable_to_non_nullable
as String,serieNfce: null == serieNfce ? _self.serieNfce : serieNfce // ignore: cast_nullable_to_non_nullable
as String,serieNfe: null == serieNfe ? _self.serieNfe : serieNfe // ignore: cast_nullable_to_non_nullable
as String,idCsc: null == idCsc ? _self.idCsc : idCsc // ignore: cast_nullable_to_non_nullable
as String,empresaRegistrada: null == empresaRegistrada ? _self.empresaRegistrada : empresaRegistrada // ignore: cast_nullable_to_non_nullable
as bool,certificado: null == certificado ? _self.certificado : certificado // ignore: cast_nullable_to_non_nullable
as CertificateInfo,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,pendencias: null == pendencias ? _self.pendencias : pendencias // ignore: cast_nullable_to_non_nullable
as List<String>,codigoServicoNacional: null == codigoServicoNacional ? _self.codigoServicoNacional : codigoServicoNacional // ignore: cast_nullable_to_non_nullable
as String,codigoNbs: null == codigoNbs ? _self.codigoNbs : codigoNbs // ignore: cast_nullable_to_non_nullable
as String,aliquotaIss: freezed == aliquotaIss ? _self.aliquotaIss : aliquotaIss // ignore: cast_nullable_to_non_nullable
as double?,percentualTributosSimples: freezed == percentualTributosSimples ? _self.percentualTributosSimples : percentualTributosSimples // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of InvoiceFiscalConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CertificateInfoCopyWith<$Res> get certificado {
  
  return $CertificateInfoCopyWith<$Res>(_self.certificado, (value) {
    return _then(_self.copyWith(certificado: value));
  });
}
}


/// Adds pattern-matching-related methods to [InvoiceFiscalConfig].
extension InvoiceFiscalConfigPatterns on InvoiceFiscalConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceFiscalConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceFiscalConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceFiscalConfig value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceFiscalConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceFiscalConfig value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceFiscalConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ambiente,  String serieNfse,  String serieNfce,  String serieNfe,  String idCsc,  bool empresaRegistrada,  CertificateInfo certificado,  String provider,  List<String> pendencias,  String codigoServicoNacional,  String codigoNbs,  double? aliquotaIss,  double? percentualTributosSimples)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceFiscalConfig() when $default != null:
return $default(_that.ambiente,_that.serieNfse,_that.serieNfce,_that.serieNfe,_that.idCsc,_that.empresaRegistrada,_that.certificado,_that.provider,_that.pendencias,_that.codigoServicoNacional,_that.codigoNbs,_that.aliquotaIss,_that.percentualTributosSimples);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ambiente,  String serieNfse,  String serieNfce,  String serieNfe,  String idCsc,  bool empresaRegistrada,  CertificateInfo certificado,  String provider,  List<String> pendencias,  String codigoServicoNacional,  String codigoNbs,  double? aliquotaIss,  double? percentualTributosSimples)  $default,) {final _that = this;
switch (_that) {
case _InvoiceFiscalConfig():
return $default(_that.ambiente,_that.serieNfse,_that.serieNfce,_that.serieNfe,_that.idCsc,_that.empresaRegistrada,_that.certificado,_that.provider,_that.pendencias,_that.codigoServicoNacional,_that.codigoNbs,_that.aliquotaIss,_that.percentualTributosSimples);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ambiente,  String serieNfse,  String serieNfce,  String serieNfe,  String idCsc,  bool empresaRegistrada,  CertificateInfo certificado,  String provider,  List<String> pendencias,  String codigoServicoNacional,  String codigoNbs,  double? aliquotaIss,  double? percentualTributosSimples)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceFiscalConfig() when $default != null:
return $default(_that.ambiente,_that.serieNfse,_that.serieNfce,_that.serieNfe,_that.idCsc,_that.empresaRegistrada,_that.certificado,_that.provider,_that.pendencias,_that.codigoServicoNacional,_that.codigoNbs,_that.aliquotaIss,_that.percentualTributosSimples);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceFiscalConfig extends InvoiceFiscalConfig {
  const _InvoiceFiscalConfig({this.ambiente = 'homologacao', this.serieNfse = '1', this.serieNfce = '1', this.serieNfe = '1', this.idCsc = '', this.empresaRegistrada = false, this.certificado = const CertificateInfo(), this.provider = 'noop', final  List<String> pendencias = const <String>[], this.codigoServicoNacional = '', this.codigoNbs = '', this.aliquotaIss, this.percentualTributosSimples}): _pendencias = pendencias,super._();
  factory _InvoiceFiscalConfig.fromJson(Map<String, dynamic> json) => _$InvoiceFiscalConfigFromJson(json);

@override@JsonKey() final  String ambiente;
@override@JsonKey() final  String serieNfse;
@override@JsonKey() final  String serieNfce;
@override@JsonKey() final  String serieNfe;
@override@JsonKey() final  String idCsc;
@override@JsonKey() final  bool empresaRegistrada;
@override@JsonKey() final  CertificateInfo certificado;
@override@JsonKey() final  String provider;
 final  List<String> _pendencias;
@override@JsonKey() List<String> get pendencias {
  if (_pendencias is EqualUnmodifiableListView) return _pendencias;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendencias);
}

@override@JsonKey() final  String codigoServicoNacional;
@override@JsonKey() final  String codigoNbs;
@override final  double? aliquotaIss;
@override final  double? percentualTributosSimples;

/// Create a copy of InvoiceFiscalConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceFiscalConfigCopyWith<_InvoiceFiscalConfig> get copyWith => __$InvoiceFiscalConfigCopyWithImpl<_InvoiceFiscalConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceFiscalConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceFiscalConfig&&(identical(other.ambiente, ambiente) || other.ambiente == ambiente)&&(identical(other.serieNfse, serieNfse) || other.serieNfse == serieNfse)&&(identical(other.serieNfce, serieNfce) || other.serieNfce == serieNfce)&&(identical(other.serieNfe, serieNfe) || other.serieNfe == serieNfe)&&(identical(other.idCsc, idCsc) || other.idCsc == idCsc)&&(identical(other.empresaRegistrada, empresaRegistrada) || other.empresaRegistrada == empresaRegistrada)&&(identical(other.certificado, certificado) || other.certificado == certificado)&&(identical(other.provider, provider) || other.provider == provider)&&const DeepCollectionEquality().equals(other._pendencias, _pendencias)&&(identical(other.codigoServicoNacional, codigoServicoNacional) || other.codigoServicoNacional == codigoServicoNacional)&&(identical(other.codigoNbs, codigoNbs) || other.codigoNbs == codigoNbs)&&(identical(other.aliquotaIss, aliquotaIss) || other.aliquotaIss == aliquotaIss)&&(identical(other.percentualTributosSimples, percentualTributosSimples) || other.percentualTributosSimples == percentualTributosSimples));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ambiente,serieNfse,serieNfce,serieNfe,idCsc,empresaRegistrada,certificado,provider,const DeepCollectionEquality().hash(_pendencias),codigoServicoNacional,codigoNbs,aliquotaIss,percentualTributosSimples);

@override
String toString() {
  return 'InvoiceFiscalConfig(ambiente: $ambiente, serieNfse: $serieNfse, serieNfce: $serieNfce, serieNfe: $serieNfe, idCsc: $idCsc, empresaRegistrada: $empresaRegistrada, certificado: $certificado, provider: $provider, pendencias: $pendencias, codigoServicoNacional: $codigoServicoNacional, codigoNbs: $codigoNbs, aliquotaIss: $aliquotaIss, percentualTributosSimples: $percentualTributosSimples)';
}


}

/// @nodoc
abstract mixin class _$InvoiceFiscalConfigCopyWith<$Res> implements $InvoiceFiscalConfigCopyWith<$Res> {
  factory _$InvoiceFiscalConfigCopyWith(_InvoiceFiscalConfig value, $Res Function(_InvoiceFiscalConfig) _then) = __$InvoiceFiscalConfigCopyWithImpl;
@override @useResult
$Res call({
 String ambiente, String serieNfse, String serieNfce, String serieNfe, String idCsc, bool empresaRegistrada, CertificateInfo certificado, String provider, List<String> pendencias, String codigoServicoNacional, String codigoNbs, double? aliquotaIss, double? percentualTributosSimples
});


@override $CertificateInfoCopyWith<$Res> get certificado;

}
/// @nodoc
class __$InvoiceFiscalConfigCopyWithImpl<$Res>
    implements _$InvoiceFiscalConfigCopyWith<$Res> {
  __$InvoiceFiscalConfigCopyWithImpl(this._self, this._then);

  final _InvoiceFiscalConfig _self;
  final $Res Function(_InvoiceFiscalConfig) _then;

/// Create a copy of InvoiceFiscalConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ambiente = null,Object? serieNfse = null,Object? serieNfce = null,Object? serieNfe = null,Object? idCsc = null,Object? empresaRegistrada = null,Object? certificado = null,Object? provider = null,Object? pendencias = null,Object? codigoServicoNacional = null,Object? codigoNbs = null,Object? aliquotaIss = freezed,Object? percentualTributosSimples = freezed,}) {
  return _then(_InvoiceFiscalConfig(
ambiente: null == ambiente ? _self.ambiente : ambiente // ignore: cast_nullable_to_non_nullable
as String,serieNfse: null == serieNfse ? _self.serieNfse : serieNfse // ignore: cast_nullable_to_non_nullable
as String,serieNfce: null == serieNfce ? _self.serieNfce : serieNfce // ignore: cast_nullable_to_non_nullable
as String,serieNfe: null == serieNfe ? _self.serieNfe : serieNfe // ignore: cast_nullable_to_non_nullable
as String,idCsc: null == idCsc ? _self.idCsc : idCsc // ignore: cast_nullable_to_non_nullable
as String,empresaRegistrada: null == empresaRegistrada ? _self.empresaRegistrada : empresaRegistrada // ignore: cast_nullable_to_non_nullable
as bool,certificado: null == certificado ? _self.certificado : certificado // ignore: cast_nullable_to_non_nullable
as CertificateInfo,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,pendencias: null == pendencias ? _self._pendencias : pendencias // ignore: cast_nullable_to_non_nullable
as List<String>,codigoServicoNacional: null == codigoServicoNacional ? _self.codigoServicoNacional : codigoServicoNacional // ignore: cast_nullable_to_non_nullable
as String,codigoNbs: null == codigoNbs ? _self.codigoNbs : codigoNbs // ignore: cast_nullable_to_non_nullable
as String,aliquotaIss: freezed == aliquotaIss ? _self.aliquotaIss : aliquotaIss // ignore: cast_nullable_to_non_nullable
as double?,percentualTributosSimples: freezed == percentualTributosSimples ? _self.percentualTributosSimples : percentualTributosSimples // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of InvoiceFiscalConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CertificateInfoCopyWith<$Res> get certificado {
  
  return $CertificateInfoCopyWith<$Res>(_self.certificado, (value) {
    return _then(_self.copyWith(certificado: value));
  });
}
}

// dart format on
