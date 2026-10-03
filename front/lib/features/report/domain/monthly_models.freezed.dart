// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monthly_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VisaoMensal {

 PeriodoMensal get periodo; List<KpiMensal> get kpis; List<SinalMensal> get sinais; GraficosDoMes get graficos;
/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VisaoMensalCopyWith<VisaoMensal> get copyWith => _$VisaoMensalCopyWithImpl<VisaoMensal>(this as VisaoMensal, _$identity);

  /// Serializes this VisaoMensal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VisaoMensal&&(identical(other.periodo, periodo) || other.periodo == periodo)&&const DeepCollectionEquality().equals(other.kpis, kpis)&&const DeepCollectionEquality().equals(other.sinais, sinais)&&(identical(other.graficos, graficos) || other.graficos == graficos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,periodo,const DeepCollectionEquality().hash(kpis),const DeepCollectionEquality().hash(sinais),graficos);

@override
String toString() {
  return 'VisaoMensal(periodo: $periodo, kpis: $kpis, sinais: $sinais, graficos: $graficos)';
}


}

/// @nodoc
abstract mixin class $VisaoMensalCopyWith<$Res>  {
  factory $VisaoMensalCopyWith(VisaoMensal value, $Res Function(VisaoMensal) _then) = _$VisaoMensalCopyWithImpl;
@useResult
$Res call({
 PeriodoMensal periodo, List<KpiMensal> kpis, List<SinalMensal> sinais, GraficosDoMes graficos
});


$PeriodoMensalCopyWith<$Res> get periodo;$GraficosDoMesCopyWith<$Res> get graficos;

}
/// @nodoc
class _$VisaoMensalCopyWithImpl<$Res>
    implements $VisaoMensalCopyWith<$Res> {
  _$VisaoMensalCopyWithImpl(this._self, this._then);

  final VisaoMensal _self;
  final $Res Function(VisaoMensal) _then;

/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? periodo = null,Object? kpis = null,Object? sinais = null,Object? graficos = null,}) {
  return _then(_self.copyWith(
periodo: null == periodo ? _self.periodo : periodo // ignore: cast_nullable_to_non_nullable
as PeriodoMensal,kpis: null == kpis ? _self.kpis : kpis // ignore: cast_nullable_to_non_nullable
as List<KpiMensal>,sinais: null == sinais ? _self.sinais : sinais // ignore: cast_nullable_to_non_nullable
as List<SinalMensal>,graficos: null == graficos ? _self.graficos : graficos // ignore: cast_nullable_to_non_nullable
as GraficosDoMes,
  ));
}
/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PeriodoMensalCopyWith<$Res> get periodo {
  
  return $PeriodoMensalCopyWith<$Res>(_self.periodo, (value) {
    return _then(_self.copyWith(periodo: value));
  });
}/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraficosDoMesCopyWith<$Res> get graficos {
  
  return $GraficosDoMesCopyWith<$Res>(_self.graficos, (value) {
    return _then(_self.copyWith(graficos: value));
  });
}
}


/// Adds pattern-matching-related methods to [VisaoMensal].
extension VisaoMensalPatterns on VisaoMensal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VisaoMensal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VisaoMensal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VisaoMensal value)  $default,){
final _that = this;
switch (_that) {
case _VisaoMensal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VisaoMensal value)?  $default,){
final _that = this;
switch (_that) {
case _VisaoMensal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PeriodoMensal periodo,  List<KpiMensal> kpis,  List<SinalMensal> sinais,  GraficosDoMes graficos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VisaoMensal() when $default != null:
return $default(_that.periodo,_that.kpis,_that.sinais,_that.graficos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PeriodoMensal periodo,  List<KpiMensal> kpis,  List<SinalMensal> sinais,  GraficosDoMes graficos)  $default,) {final _that = this;
switch (_that) {
case _VisaoMensal():
return $default(_that.periodo,_that.kpis,_that.sinais,_that.graficos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PeriodoMensal periodo,  List<KpiMensal> kpis,  List<SinalMensal> sinais,  GraficosDoMes graficos)?  $default,) {final _that = this;
switch (_that) {
case _VisaoMensal() when $default != null:
return $default(_that.periodo,_that.kpis,_that.sinais,_that.graficos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VisaoMensal implements VisaoMensal {
  const _VisaoMensal({this.periodo = const PeriodoMensal(), final  List<KpiMensal> kpis = const <KpiMensal>[], final  List<SinalMensal> sinais = const <SinalMensal>[], this.graficos = const GraficosDoMes()}): _kpis = kpis,_sinais = sinais;
  factory _VisaoMensal.fromJson(Map<String, dynamic> json) => _$VisaoMensalFromJson(json);

@override@JsonKey() final  PeriodoMensal periodo;
 final  List<KpiMensal> _kpis;
@override@JsonKey() List<KpiMensal> get kpis {
  if (_kpis is EqualUnmodifiableListView) return _kpis;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_kpis);
}

 final  List<SinalMensal> _sinais;
@override@JsonKey() List<SinalMensal> get sinais {
  if (_sinais is EqualUnmodifiableListView) return _sinais;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sinais);
}

@override@JsonKey() final  GraficosDoMes graficos;

/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VisaoMensalCopyWith<_VisaoMensal> get copyWith => __$VisaoMensalCopyWithImpl<_VisaoMensal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VisaoMensalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VisaoMensal&&(identical(other.periodo, periodo) || other.periodo == periodo)&&const DeepCollectionEquality().equals(other._kpis, _kpis)&&const DeepCollectionEquality().equals(other._sinais, _sinais)&&(identical(other.graficos, graficos) || other.graficos == graficos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,periodo,const DeepCollectionEquality().hash(_kpis),const DeepCollectionEquality().hash(_sinais),graficos);

@override
String toString() {
  return 'VisaoMensal(periodo: $periodo, kpis: $kpis, sinais: $sinais, graficos: $graficos)';
}


}

/// @nodoc
abstract mixin class _$VisaoMensalCopyWith<$Res> implements $VisaoMensalCopyWith<$Res> {
  factory _$VisaoMensalCopyWith(_VisaoMensal value, $Res Function(_VisaoMensal) _then) = __$VisaoMensalCopyWithImpl;
@override @useResult
$Res call({
 PeriodoMensal periodo, List<KpiMensal> kpis, List<SinalMensal> sinais, GraficosDoMes graficos
});


@override $PeriodoMensalCopyWith<$Res> get periodo;@override $GraficosDoMesCopyWith<$Res> get graficos;

}
/// @nodoc
class __$VisaoMensalCopyWithImpl<$Res>
    implements _$VisaoMensalCopyWith<$Res> {
  __$VisaoMensalCopyWithImpl(this._self, this._then);

  final _VisaoMensal _self;
  final $Res Function(_VisaoMensal) _then;

/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? periodo = null,Object? kpis = null,Object? sinais = null,Object? graficos = null,}) {
  return _then(_VisaoMensal(
periodo: null == periodo ? _self.periodo : periodo // ignore: cast_nullable_to_non_nullable
as PeriodoMensal,kpis: null == kpis ? _self._kpis : kpis // ignore: cast_nullable_to_non_nullable
as List<KpiMensal>,sinais: null == sinais ? _self._sinais : sinais // ignore: cast_nullable_to_non_nullable
as List<SinalMensal>,graficos: null == graficos ? _self.graficos : graficos // ignore: cast_nullable_to_non_nullable
as GraficosDoMes,
  ));
}

/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PeriodoMensalCopyWith<$Res> get periodo {
  
  return $PeriodoMensalCopyWith<$Res>(_self.periodo, (value) {
    return _then(_self.copyWith(periodo: value));
  });
}/// Create a copy of VisaoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraficosDoMesCopyWith<$Res> get graficos {
  
  return $GraficosDoMesCopyWith<$Res>(_self.graficos, (value) {
    return _then(_self.copyWith(graficos: value));
  });
}
}


/// @nodoc
mixin _$GraficosDoMes {

 List<PontoDiario> get serieDiaria; List<FatiaCategoria> get despesasPorCategoria;
/// Create a copy of GraficosDoMes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GraficosDoMesCopyWith<GraficosDoMes> get copyWith => _$GraficosDoMesCopyWithImpl<GraficosDoMes>(this as GraficosDoMes, _$identity);

  /// Serializes this GraficosDoMes to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GraficosDoMes&&const DeepCollectionEquality().equals(other.serieDiaria, serieDiaria)&&const DeepCollectionEquality().equals(other.despesasPorCategoria, despesasPorCategoria));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(serieDiaria),const DeepCollectionEquality().hash(despesasPorCategoria));

@override
String toString() {
  return 'GraficosDoMes(serieDiaria: $serieDiaria, despesasPorCategoria: $despesasPorCategoria)';
}


}

/// @nodoc
abstract mixin class $GraficosDoMesCopyWith<$Res>  {
  factory $GraficosDoMesCopyWith(GraficosDoMes value, $Res Function(GraficosDoMes) _then) = _$GraficosDoMesCopyWithImpl;
@useResult
$Res call({
 List<PontoDiario> serieDiaria, List<FatiaCategoria> despesasPorCategoria
});




}
/// @nodoc
class _$GraficosDoMesCopyWithImpl<$Res>
    implements $GraficosDoMesCopyWith<$Res> {
  _$GraficosDoMesCopyWithImpl(this._self, this._then);

  final GraficosDoMes _self;
  final $Res Function(GraficosDoMes) _then;

/// Create a copy of GraficosDoMes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serieDiaria = null,Object? despesasPorCategoria = null,}) {
  return _then(_self.copyWith(
serieDiaria: null == serieDiaria ? _self.serieDiaria : serieDiaria // ignore: cast_nullable_to_non_nullable
as List<PontoDiario>,despesasPorCategoria: null == despesasPorCategoria ? _self.despesasPorCategoria : despesasPorCategoria // ignore: cast_nullable_to_non_nullable
as List<FatiaCategoria>,
  ));
}

}


/// Adds pattern-matching-related methods to [GraficosDoMes].
extension GraficosDoMesPatterns on GraficosDoMes {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GraficosDoMes value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GraficosDoMes() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GraficosDoMes value)  $default,){
final _that = this;
switch (_that) {
case _GraficosDoMes():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GraficosDoMes value)?  $default,){
final _that = this;
switch (_that) {
case _GraficosDoMes() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PontoDiario> serieDiaria,  List<FatiaCategoria> despesasPorCategoria)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GraficosDoMes() when $default != null:
return $default(_that.serieDiaria,_that.despesasPorCategoria);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PontoDiario> serieDiaria,  List<FatiaCategoria> despesasPorCategoria)  $default,) {final _that = this;
switch (_that) {
case _GraficosDoMes():
return $default(_that.serieDiaria,_that.despesasPorCategoria);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PontoDiario> serieDiaria,  List<FatiaCategoria> despesasPorCategoria)?  $default,) {final _that = this;
switch (_that) {
case _GraficosDoMes() when $default != null:
return $default(_that.serieDiaria,_that.despesasPorCategoria);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GraficosDoMes implements GraficosDoMes {
  const _GraficosDoMes({final  List<PontoDiario> serieDiaria = const <PontoDiario>[], final  List<FatiaCategoria> despesasPorCategoria = const <FatiaCategoria>[]}): _serieDiaria = serieDiaria,_despesasPorCategoria = despesasPorCategoria;
  factory _GraficosDoMes.fromJson(Map<String, dynamic> json) => _$GraficosDoMesFromJson(json);

 final  List<PontoDiario> _serieDiaria;
@override@JsonKey() List<PontoDiario> get serieDiaria {
  if (_serieDiaria is EqualUnmodifiableListView) return _serieDiaria;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_serieDiaria);
}

 final  List<FatiaCategoria> _despesasPorCategoria;
@override@JsonKey() List<FatiaCategoria> get despesasPorCategoria {
  if (_despesasPorCategoria is EqualUnmodifiableListView) return _despesasPorCategoria;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_despesasPorCategoria);
}


/// Create a copy of GraficosDoMes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GraficosDoMesCopyWith<_GraficosDoMes> get copyWith => __$GraficosDoMesCopyWithImpl<_GraficosDoMes>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GraficosDoMesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GraficosDoMes&&const DeepCollectionEquality().equals(other._serieDiaria, _serieDiaria)&&const DeepCollectionEquality().equals(other._despesasPorCategoria, _despesasPorCategoria));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_serieDiaria),const DeepCollectionEquality().hash(_despesasPorCategoria));

@override
String toString() {
  return 'GraficosDoMes(serieDiaria: $serieDiaria, despesasPorCategoria: $despesasPorCategoria)';
}


}

/// @nodoc
abstract mixin class _$GraficosDoMesCopyWith<$Res> implements $GraficosDoMesCopyWith<$Res> {
  factory _$GraficosDoMesCopyWith(_GraficosDoMes value, $Res Function(_GraficosDoMes) _then) = __$GraficosDoMesCopyWithImpl;
@override @useResult
$Res call({
 List<PontoDiario> serieDiaria, List<FatiaCategoria> despesasPorCategoria
});




}
/// @nodoc
class __$GraficosDoMesCopyWithImpl<$Res>
    implements _$GraficosDoMesCopyWith<$Res> {
  __$GraficosDoMesCopyWithImpl(this._self, this._then);

  final _GraficosDoMes _self;
  final $Res Function(_GraficosDoMes) _then;

/// Create a copy of GraficosDoMes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serieDiaria = null,Object? despesasPorCategoria = null,}) {
  return _then(_GraficosDoMes(
serieDiaria: null == serieDiaria ? _self._serieDiaria : serieDiaria // ignore: cast_nullable_to_non_nullable
as List<PontoDiario>,despesasPorCategoria: null == despesasPorCategoria ? _self._despesasPorCategoria : despesasPorCategoria // ignore: cast_nullable_to_non_nullable
as List<FatiaCategoria>,
  ));
}


}


/// @nodoc
mixin _$PontoDiario {

/// "2026-09-17".
 String get dia; num get valor;
/// Create a copy of PontoDiario
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PontoDiarioCopyWith<PontoDiario> get copyWith => _$PontoDiarioCopyWithImpl<PontoDiario>(this as PontoDiario, _$identity);

  /// Serializes this PontoDiario to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PontoDiario&&(identical(other.dia, dia) || other.dia == dia)&&(identical(other.valor, valor) || other.valor == valor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dia,valor);

@override
String toString() {
  return 'PontoDiario(dia: $dia, valor: $valor)';
}


}

/// @nodoc
abstract mixin class $PontoDiarioCopyWith<$Res>  {
  factory $PontoDiarioCopyWith(PontoDiario value, $Res Function(PontoDiario) _then) = _$PontoDiarioCopyWithImpl;
@useResult
$Res call({
 String dia, num valor
});




}
/// @nodoc
class _$PontoDiarioCopyWithImpl<$Res>
    implements $PontoDiarioCopyWith<$Res> {
  _$PontoDiarioCopyWithImpl(this._self, this._then);

  final PontoDiario _self;
  final $Res Function(PontoDiario) _then;

/// Create a copy of PontoDiario
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dia = null,Object? valor = null,}) {
  return _then(_self.copyWith(
dia: null == dia ? _self.dia : dia // ignore: cast_nullable_to_non_nullable
as String,valor: null == valor ? _self.valor : valor // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [PontoDiario].
extension PontoDiarioPatterns on PontoDiario {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PontoDiario value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PontoDiario() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PontoDiario value)  $default,){
final _that = this;
switch (_that) {
case _PontoDiario():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PontoDiario value)?  $default,){
final _that = this;
switch (_that) {
case _PontoDiario() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String dia,  num valor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PontoDiario() when $default != null:
return $default(_that.dia,_that.valor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String dia,  num valor)  $default,) {final _that = this;
switch (_that) {
case _PontoDiario():
return $default(_that.dia,_that.valor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String dia,  num valor)?  $default,) {final _that = this;
switch (_that) {
case _PontoDiario() when $default != null:
return $default(_that.dia,_that.valor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PontoDiario implements PontoDiario {
  const _PontoDiario({this.dia = '', this.valor = 0});
  factory _PontoDiario.fromJson(Map<String, dynamic> json) => _$PontoDiarioFromJson(json);

/// "2026-09-17".
@override@JsonKey() final  String dia;
@override@JsonKey() final  num valor;

/// Create a copy of PontoDiario
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PontoDiarioCopyWith<_PontoDiario> get copyWith => __$PontoDiarioCopyWithImpl<_PontoDiario>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PontoDiarioToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PontoDiario&&(identical(other.dia, dia) || other.dia == dia)&&(identical(other.valor, valor) || other.valor == valor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dia,valor);

@override
String toString() {
  return 'PontoDiario(dia: $dia, valor: $valor)';
}


}

/// @nodoc
abstract mixin class _$PontoDiarioCopyWith<$Res> implements $PontoDiarioCopyWith<$Res> {
  factory _$PontoDiarioCopyWith(_PontoDiario value, $Res Function(_PontoDiario) _then) = __$PontoDiarioCopyWithImpl;
@override @useResult
$Res call({
 String dia, num valor
});




}
/// @nodoc
class __$PontoDiarioCopyWithImpl<$Res>
    implements _$PontoDiarioCopyWith<$Res> {
  __$PontoDiarioCopyWithImpl(this._self, this._then);

  final _PontoDiario _self;
  final $Res Function(_PontoDiario) _then;

/// Create a copy of PontoDiario
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dia = null,Object? valor = null,}) {
  return _then(_PontoDiario(
dia: null == dia ? _self.dia : dia // ignore: cast_nullable_to_non_nullable
as String,valor: null == valor ? _self.valor : valor // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$FatiaCategoria {

 String get categoria; num get total;
/// Create a copy of FatiaCategoria
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FatiaCategoriaCopyWith<FatiaCategoria> get copyWith => _$FatiaCategoriaCopyWithImpl<FatiaCategoria>(this as FatiaCategoria, _$identity);

  /// Serializes this FatiaCategoria to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FatiaCategoria&&(identical(other.categoria, categoria) || other.categoria == categoria)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,categoria,total);

@override
String toString() {
  return 'FatiaCategoria(categoria: $categoria, total: $total)';
}


}

/// @nodoc
abstract mixin class $FatiaCategoriaCopyWith<$Res>  {
  factory $FatiaCategoriaCopyWith(FatiaCategoria value, $Res Function(FatiaCategoria) _then) = _$FatiaCategoriaCopyWithImpl;
@useResult
$Res call({
 String categoria, num total
});




}
/// @nodoc
class _$FatiaCategoriaCopyWithImpl<$Res>
    implements $FatiaCategoriaCopyWith<$Res> {
  _$FatiaCategoriaCopyWithImpl(this._self, this._then);

  final FatiaCategoria _self;
  final $Res Function(FatiaCategoria) _then;

/// Create a copy of FatiaCategoria
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? categoria = null,Object? total = null,}) {
  return _then(_self.copyWith(
categoria: null == categoria ? _self.categoria : categoria // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [FatiaCategoria].
extension FatiaCategoriaPatterns on FatiaCategoria {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FatiaCategoria value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FatiaCategoria() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FatiaCategoria value)  $default,){
final _that = this;
switch (_that) {
case _FatiaCategoria():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FatiaCategoria value)?  $default,){
final _that = this;
switch (_that) {
case _FatiaCategoria() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String categoria,  num total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FatiaCategoria() when $default != null:
return $default(_that.categoria,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String categoria,  num total)  $default,) {final _that = this;
switch (_that) {
case _FatiaCategoria():
return $default(_that.categoria,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String categoria,  num total)?  $default,) {final _that = this;
switch (_that) {
case _FatiaCategoria() when $default != null:
return $default(_that.categoria,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FatiaCategoria implements FatiaCategoria {
  const _FatiaCategoria({this.categoria = '', this.total = 0});
  factory _FatiaCategoria.fromJson(Map<String, dynamic> json) => _$FatiaCategoriaFromJson(json);

@override@JsonKey() final  String categoria;
@override@JsonKey() final  num total;

/// Create a copy of FatiaCategoria
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FatiaCategoriaCopyWith<_FatiaCategoria> get copyWith => __$FatiaCategoriaCopyWithImpl<_FatiaCategoria>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FatiaCategoriaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FatiaCategoria&&(identical(other.categoria, categoria) || other.categoria == categoria)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,categoria,total);

@override
String toString() {
  return 'FatiaCategoria(categoria: $categoria, total: $total)';
}


}

/// @nodoc
abstract mixin class _$FatiaCategoriaCopyWith<$Res> implements $FatiaCategoriaCopyWith<$Res> {
  factory _$FatiaCategoriaCopyWith(_FatiaCategoria value, $Res Function(_FatiaCategoria) _then) = __$FatiaCategoriaCopyWithImpl;
@override @useResult
$Res call({
 String categoria, num total
});




}
/// @nodoc
class __$FatiaCategoriaCopyWithImpl<$Res>
    implements _$FatiaCategoriaCopyWith<$Res> {
  __$FatiaCategoriaCopyWithImpl(this._self, this._then);

  final _FatiaCategoria _self;
  final $Res Function(_FatiaCategoria) _then;

/// Create a copy of FatiaCategoria
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? categoria = null,Object? total = null,}) {
  return _then(_FatiaCategoria(
categoria: null == categoria ? _self.categoria : categoria // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$PeriodoMensal {

 String get de; String get ate;/// "Setembro/2026".
 String get rotulo;
/// Create a copy of PeriodoMensal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PeriodoMensalCopyWith<PeriodoMensal> get copyWith => _$PeriodoMensalCopyWithImpl<PeriodoMensal>(this as PeriodoMensal, _$identity);

  /// Serializes this PeriodoMensal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PeriodoMensal&&(identical(other.de, de) || other.de == de)&&(identical(other.ate, ate) || other.ate == ate)&&(identical(other.rotulo, rotulo) || other.rotulo == rotulo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,de,ate,rotulo);

@override
String toString() {
  return 'PeriodoMensal(de: $de, ate: $ate, rotulo: $rotulo)';
}


}

/// @nodoc
abstract mixin class $PeriodoMensalCopyWith<$Res>  {
  factory $PeriodoMensalCopyWith(PeriodoMensal value, $Res Function(PeriodoMensal) _then) = _$PeriodoMensalCopyWithImpl;
@useResult
$Res call({
 String de, String ate, String rotulo
});




}
/// @nodoc
class _$PeriodoMensalCopyWithImpl<$Res>
    implements $PeriodoMensalCopyWith<$Res> {
  _$PeriodoMensalCopyWithImpl(this._self, this._then);

  final PeriodoMensal _self;
  final $Res Function(PeriodoMensal) _then;

/// Create a copy of PeriodoMensal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? de = null,Object? ate = null,Object? rotulo = null,}) {
  return _then(_self.copyWith(
de: null == de ? _self.de : de // ignore: cast_nullable_to_non_nullable
as String,ate: null == ate ? _self.ate : ate // ignore: cast_nullable_to_non_nullable
as String,rotulo: null == rotulo ? _self.rotulo : rotulo // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PeriodoMensal].
extension PeriodoMensalPatterns on PeriodoMensal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PeriodoMensal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PeriodoMensal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PeriodoMensal value)  $default,){
final _that = this;
switch (_that) {
case _PeriodoMensal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PeriodoMensal value)?  $default,){
final _that = this;
switch (_that) {
case _PeriodoMensal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String de,  String ate,  String rotulo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PeriodoMensal() when $default != null:
return $default(_that.de,_that.ate,_that.rotulo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String de,  String ate,  String rotulo)  $default,) {final _that = this;
switch (_that) {
case _PeriodoMensal():
return $default(_that.de,_that.ate,_that.rotulo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String de,  String ate,  String rotulo)?  $default,) {final _that = this;
switch (_that) {
case _PeriodoMensal() when $default != null:
return $default(_that.de,_that.ate,_that.rotulo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PeriodoMensal implements PeriodoMensal {
  const _PeriodoMensal({this.de = '', this.ate = '', this.rotulo = ''});
  factory _PeriodoMensal.fromJson(Map<String, dynamic> json) => _$PeriodoMensalFromJson(json);

@override@JsonKey() final  String de;
@override@JsonKey() final  String ate;
/// "Setembro/2026".
@override@JsonKey() final  String rotulo;

/// Create a copy of PeriodoMensal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PeriodoMensalCopyWith<_PeriodoMensal> get copyWith => __$PeriodoMensalCopyWithImpl<_PeriodoMensal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PeriodoMensalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PeriodoMensal&&(identical(other.de, de) || other.de == de)&&(identical(other.ate, ate) || other.ate == ate)&&(identical(other.rotulo, rotulo) || other.rotulo == rotulo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,de,ate,rotulo);

@override
String toString() {
  return 'PeriodoMensal(de: $de, ate: $ate, rotulo: $rotulo)';
}


}

/// @nodoc
abstract mixin class _$PeriodoMensalCopyWith<$Res> implements $PeriodoMensalCopyWith<$Res> {
  factory _$PeriodoMensalCopyWith(_PeriodoMensal value, $Res Function(_PeriodoMensal) _then) = __$PeriodoMensalCopyWithImpl;
@override @useResult
$Res call({
 String de, String ate, String rotulo
});




}
/// @nodoc
class __$PeriodoMensalCopyWithImpl<$Res>
    implements _$PeriodoMensalCopyWith<$Res> {
  __$PeriodoMensalCopyWithImpl(this._self, this._then);

  final _PeriodoMensal _self;
  final $Res Function(_PeriodoMensal) _then;

/// Create a copy of PeriodoMensal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? de = null,Object? ate = null,Object? rotulo = null,}) {
  return _then(_PeriodoMensal(
de: null == de ? _self.de : de // ignore: cast_nullable_to_non_nullable
as String,ate: null == ate ? _self.ate : ate // ignore: cast_nullable_to_non_nullable
as String,rotulo: null == rotulo ? _self.rotulo : rotulo // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VariacaoMensal {

 num get anterior; num get pct;
/// Create a copy of VariacaoMensal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VariacaoMensalCopyWith<VariacaoMensal> get copyWith => _$VariacaoMensalCopyWithImpl<VariacaoMensal>(this as VariacaoMensal, _$identity);

  /// Serializes this VariacaoMensal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VariacaoMensal&&(identical(other.anterior, anterior) || other.anterior == anterior)&&(identical(other.pct, pct) || other.pct == pct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,anterior,pct);

@override
String toString() {
  return 'VariacaoMensal(anterior: $anterior, pct: $pct)';
}


}

/// @nodoc
abstract mixin class $VariacaoMensalCopyWith<$Res>  {
  factory $VariacaoMensalCopyWith(VariacaoMensal value, $Res Function(VariacaoMensal) _then) = _$VariacaoMensalCopyWithImpl;
@useResult
$Res call({
 num anterior, num pct
});




}
/// @nodoc
class _$VariacaoMensalCopyWithImpl<$Res>
    implements $VariacaoMensalCopyWith<$Res> {
  _$VariacaoMensalCopyWithImpl(this._self, this._then);

  final VariacaoMensal _self;
  final $Res Function(VariacaoMensal) _then;

/// Create a copy of VariacaoMensal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? anterior = null,Object? pct = null,}) {
  return _then(_self.copyWith(
anterior: null == anterior ? _self.anterior : anterior // ignore: cast_nullable_to_non_nullable
as num,pct: null == pct ? _self.pct : pct // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [VariacaoMensal].
extension VariacaoMensalPatterns on VariacaoMensal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VariacaoMensal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VariacaoMensal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VariacaoMensal value)  $default,){
final _that = this;
switch (_that) {
case _VariacaoMensal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VariacaoMensal value)?  $default,){
final _that = this;
switch (_that) {
case _VariacaoMensal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( num anterior,  num pct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VariacaoMensal() when $default != null:
return $default(_that.anterior,_that.pct);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( num anterior,  num pct)  $default,) {final _that = this;
switch (_that) {
case _VariacaoMensal():
return $default(_that.anterior,_that.pct);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( num anterior,  num pct)?  $default,) {final _that = this;
switch (_that) {
case _VariacaoMensal() when $default != null:
return $default(_that.anterior,_that.pct);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VariacaoMensal implements VariacaoMensal {
  const _VariacaoMensal({this.anterior = 0, this.pct = 0});
  factory _VariacaoMensal.fromJson(Map<String, dynamic> json) => _$VariacaoMensalFromJson(json);

@override@JsonKey() final  num anterior;
@override@JsonKey() final  num pct;

/// Create a copy of VariacaoMensal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VariacaoMensalCopyWith<_VariacaoMensal> get copyWith => __$VariacaoMensalCopyWithImpl<_VariacaoMensal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VariacaoMensalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VariacaoMensal&&(identical(other.anterior, anterior) || other.anterior == anterior)&&(identical(other.pct, pct) || other.pct == pct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,anterior,pct);

@override
String toString() {
  return 'VariacaoMensal(anterior: $anterior, pct: $pct)';
}


}

/// @nodoc
abstract mixin class _$VariacaoMensalCopyWith<$Res> implements $VariacaoMensalCopyWith<$Res> {
  factory _$VariacaoMensalCopyWith(_VariacaoMensal value, $Res Function(_VariacaoMensal) _then) = __$VariacaoMensalCopyWithImpl;
@override @useResult
$Res call({
 num anterior, num pct
});




}
/// @nodoc
class __$VariacaoMensalCopyWithImpl<$Res>
    implements _$VariacaoMensalCopyWith<$Res> {
  __$VariacaoMensalCopyWithImpl(this._self, this._then);

  final _VariacaoMensal _self;
  final $Res Function(_VariacaoMensal) _then;

/// Create a copy of VariacaoMensal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? anterior = null,Object? pct = null,}) {
  return _then(_VariacaoMensal(
anterior: null == anterior ? _self.anterior : anterior // ignore: cast_nullable_to_non_nullable
as num,pct: null == pct ? _self.pct : pct // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$KpiMensal {

 String get chave; String get rotulo; num get valor;/// 'dinheiro' | 'numero'.
 String get formato;/// `null` quando não há com o que comparar — o servidor nunca manda um
/// percentual inventado, e a tela não deve desenhar seta nesse caso.
 VariacaoMensal? get variacao;@JsonKey(name: 'maiorEhMelhor') bool get maiorEhMelhor;
/// Create a copy of KpiMensal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KpiMensalCopyWith<KpiMensal> get copyWith => _$KpiMensalCopyWithImpl<KpiMensal>(this as KpiMensal, _$identity);

  /// Serializes this KpiMensal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KpiMensal&&(identical(other.chave, chave) || other.chave == chave)&&(identical(other.rotulo, rotulo) || other.rotulo == rotulo)&&(identical(other.valor, valor) || other.valor == valor)&&(identical(other.formato, formato) || other.formato == formato)&&(identical(other.variacao, variacao) || other.variacao == variacao)&&(identical(other.maiorEhMelhor, maiorEhMelhor) || other.maiorEhMelhor == maiorEhMelhor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chave,rotulo,valor,formato,variacao,maiorEhMelhor);

@override
String toString() {
  return 'KpiMensal(chave: $chave, rotulo: $rotulo, valor: $valor, formato: $formato, variacao: $variacao, maiorEhMelhor: $maiorEhMelhor)';
}


}

/// @nodoc
abstract mixin class $KpiMensalCopyWith<$Res>  {
  factory $KpiMensalCopyWith(KpiMensal value, $Res Function(KpiMensal) _then) = _$KpiMensalCopyWithImpl;
@useResult
$Res call({
 String chave, String rotulo, num valor, String formato, VariacaoMensal? variacao,@JsonKey(name: 'maiorEhMelhor') bool maiorEhMelhor
});


$VariacaoMensalCopyWith<$Res>? get variacao;

}
/// @nodoc
class _$KpiMensalCopyWithImpl<$Res>
    implements $KpiMensalCopyWith<$Res> {
  _$KpiMensalCopyWithImpl(this._self, this._then);

  final KpiMensal _self;
  final $Res Function(KpiMensal) _then;

/// Create a copy of KpiMensal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chave = null,Object? rotulo = null,Object? valor = null,Object? formato = null,Object? variacao = freezed,Object? maiorEhMelhor = null,}) {
  return _then(_self.copyWith(
chave: null == chave ? _self.chave : chave // ignore: cast_nullable_to_non_nullable
as String,rotulo: null == rotulo ? _self.rotulo : rotulo // ignore: cast_nullable_to_non_nullable
as String,valor: null == valor ? _self.valor : valor // ignore: cast_nullable_to_non_nullable
as num,formato: null == formato ? _self.formato : formato // ignore: cast_nullable_to_non_nullable
as String,variacao: freezed == variacao ? _self.variacao : variacao // ignore: cast_nullable_to_non_nullable
as VariacaoMensal?,maiorEhMelhor: null == maiorEhMelhor ? _self.maiorEhMelhor : maiorEhMelhor // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of KpiMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VariacaoMensalCopyWith<$Res>? get variacao {
    if (_self.variacao == null) {
    return null;
  }

  return $VariacaoMensalCopyWith<$Res>(_self.variacao!, (value) {
    return _then(_self.copyWith(variacao: value));
  });
}
}


/// Adds pattern-matching-related methods to [KpiMensal].
extension KpiMensalPatterns on KpiMensal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KpiMensal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KpiMensal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KpiMensal value)  $default,){
final _that = this;
switch (_that) {
case _KpiMensal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KpiMensal value)?  $default,){
final _that = this;
switch (_that) {
case _KpiMensal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chave,  String rotulo,  num valor,  String formato,  VariacaoMensal? variacao, @JsonKey(name: 'maiorEhMelhor')  bool maiorEhMelhor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KpiMensal() when $default != null:
return $default(_that.chave,_that.rotulo,_that.valor,_that.formato,_that.variacao,_that.maiorEhMelhor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chave,  String rotulo,  num valor,  String formato,  VariacaoMensal? variacao, @JsonKey(name: 'maiorEhMelhor')  bool maiorEhMelhor)  $default,) {final _that = this;
switch (_that) {
case _KpiMensal():
return $default(_that.chave,_that.rotulo,_that.valor,_that.formato,_that.variacao,_that.maiorEhMelhor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chave,  String rotulo,  num valor,  String formato,  VariacaoMensal? variacao, @JsonKey(name: 'maiorEhMelhor')  bool maiorEhMelhor)?  $default,) {final _that = this;
switch (_that) {
case _KpiMensal() when $default != null:
return $default(_that.chave,_that.rotulo,_that.valor,_that.formato,_that.variacao,_that.maiorEhMelhor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KpiMensal extends KpiMensal {
  const _KpiMensal({this.chave = '', this.rotulo = '', this.valor = 0, this.formato = 'numero', this.variacao, @JsonKey(name: 'maiorEhMelhor') this.maiorEhMelhor = true}): super._();
  factory _KpiMensal.fromJson(Map<String, dynamic> json) => _$KpiMensalFromJson(json);

@override@JsonKey() final  String chave;
@override@JsonKey() final  String rotulo;
@override@JsonKey() final  num valor;
/// 'dinheiro' | 'numero'.
@override@JsonKey() final  String formato;
/// `null` quando não há com o que comparar — o servidor nunca manda um
/// percentual inventado, e a tela não deve desenhar seta nesse caso.
@override final  VariacaoMensal? variacao;
@override@JsonKey(name: 'maiorEhMelhor') final  bool maiorEhMelhor;

/// Create a copy of KpiMensal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KpiMensalCopyWith<_KpiMensal> get copyWith => __$KpiMensalCopyWithImpl<_KpiMensal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KpiMensalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KpiMensal&&(identical(other.chave, chave) || other.chave == chave)&&(identical(other.rotulo, rotulo) || other.rotulo == rotulo)&&(identical(other.valor, valor) || other.valor == valor)&&(identical(other.formato, formato) || other.formato == formato)&&(identical(other.variacao, variacao) || other.variacao == variacao)&&(identical(other.maiorEhMelhor, maiorEhMelhor) || other.maiorEhMelhor == maiorEhMelhor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chave,rotulo,valor,formato,variacao,maiorEhMelhor);

@override
String toString() {
  return 'KpiMensal(chave: $chave, rotulo: $rotulo, valor: $valor, formato: $formato, variacao: $variacao, maiorEhMelhor: $maiorEhMelhor)';
}


}

/// @nodoc
abstract mixin class _$KpiMensalCopyWith<$Res> implements $KpiMensalCopyWith<$Res> {
  factory _$KpiMensalCopyWith(_KpiMensal value, $Res Function(_KpiMensal) _then) = __$KpiMensalCopyWithImpl;
@override @useResult
$Res call({
 String chave, String rotulo, num valor, String formato, VariacaoMensal? variacao,@JsonKey(name: 'maiorEhMelhor') bool maiorEhMelhor
});


@override $VariacaoMensalCopyWith<$Res>? get variacao;

}
/// @nodoc
class __$KpiMensalCopyWithImpl<$Res>
    implements _$KpiMensalCopyWith<$Res> {
  __$KpiMensalCopyWithImpl(this._self, this._then);

  final _KpiMensal _self;
  final $Res Function(_KpiMensal) _then;

/// Create a copy of KpiMensal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chave = null,Object? rotulo = null,Object? valor = null,Object? formato = null,Object? variacao = freezed,Object? maiorEhMelhor = null,}) {
  return _then(_KpiMensal(
chave: null == chave ? _self.chave : chave // ignore: cast_nullable_to_non_nullable
as String,rotulo: null == rotulo ? _self.rotulo : rotulo // ignore: cast_nullable_to_non_nullable
as String,valor: null == valor ? _self.valor : valor // ignore: cast_nullable_to_non_nullable
as num,formato: null == formato ? _self.formato : formato // ignore: cast_nullable_to_non_nullable
as String,variacao: freezed == variacao ? _self.variacao : variacao // ignore: cast_nullable_to_non_nullable
as VariacaoMensal?,maiorEhMelhor: null == maiorEhMelhor ? _self.maiorEhMelhor : maiorEhMelhor // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of KpiMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VariacaoMensalCopyWith<$Res>? get variacao {
    if (_self.variacao == null) {
    return null;
  }

  return $VariacaoMensalCopyWith<$Res>(_self.variacao!, (value) {
    return _then(_self.copyWith(variacao: value));
  });
}
}


/// @nodoc
mixin _$SinalMensal {

 String get chave;/// 'critico' | 'alerta' | 'info'.
 String get severidade; String get titulo; String get detalhe; Map<String, num> get numeros;
/// Create a copy of SinalMensal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SinalMensalCopyWith<SinalMensal> get copyWith => _$SinalMensalCopyWithImpl<SinalMensal>(this as SinalMensal, _$identity);

  /// Serializes this SinalMensal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SinalMensal&&(identical(other.chave, chave) || other.chave == chave)&&(identical(other.severidade, severidade) || other.severidade == severidade)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.detalhe, detalhe) || other.detalhe == detalhe)&&const DeepCollectionEquality().equals(other.numeros, numeros));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chave,severidade,titulo,detalhe,const DeepCollectionEquality().hash(numeros));

@override
String toString() {
  return 'SinalMensal(chave: $chave, severidade: $severidade, titulo: $titulo, detalhe: $detalhe, numeros: $numeros)';
}


}

/// @nodoc
abstract mixin class $SinalMensalCopyWith<$Res>  {
  factory $SinalMensalCopyWith(SinalMensal value, $Res Function(SinalMensal) _then) = _$SinalMensalCopyWithImpl;
@useResult
$Res call({
 String chave, String severidade, String titulo, String detalhe, Map<String, num> numeros
});




}
/// @nodoc
class _$SinalMensalCopyWithImpl<$Res>
    implements $SinalMensalCopyWith<$Res> {
  _$SinalMensalCopyWithImpl(this._self, this._then);

  final SinalMensal _self;
  final $Res Function(SinalMensal) _then;

/// Create a copy of SinalMensal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chave = null,Object? severidade = null,Object? titulo = null,Object? detalhe = null,Object? numeros = null,}) {
  return _then(_self.copyWith(
chave: null == chave ? _self.chave : chave // ignore: cast_nullable_to_non_nullable
as String,severidade: null == severidade ? _self.severidade : severidade // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,detalhe: null == detalhe ? _self.detalhe : detalhe // ignore: cast_nullable_to_non_nullable
as String,numeros: null == numeros ? _self.numeros : numeros // ignore: cast_nullable_to_non_nullable
as Map<String, num>,
  ));
}

}


/// Adds pattern-matching-related methods to [SinalMensal].
extension SinalMensalPatterns on SinalMensal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SinalMensal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SinalMensal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SinalMensal value)  $default,){
final _that = this;
switch (_that) {
case _SinalMensal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SinalMensal value)?  $default,){
final _that = this;
switch (_that) {
case _SinalMensal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chave,  String severidade,  String titulo,  String detalhe,  Map<String, num> numeros)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SinalMensal() when $default != null:
return $default(_that.chave,_that.severidade,_that.titulo,_that.detalhe,_that.numeros);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chave,  String severidade,  String titulo,  String detalhe,  Map<String, num> numeros)  $default,) {final _that = this;
switch (_that) {
case _SinalMensal():
return $default(_that.chave,_that.severidade,_that.titulo,_that.detalhe,_that.numeros);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chave,  String severidade,  String titulo,  String detalhe,  Map<String, num> numeros)?  $default,) {final _that = this;
switch (_that) {
case _SinalMensal() when $default != null:
return $default(_that.chave,_that.severidade,_that.titulo,_that.detalhe,_that.numeros);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SinalMensal extends SinalMensal {
  const _SinalMensal({this.chave = '', this.severidade = 'info', this.titulo = '', this.detalhe = '', final  Map<String, num> numeros = const <String, num>{}}): _numeros = numeros,super._();
  factory _SinalMensal.fromJson(Map<String, dynamic> json) => _$SinalMensalFromJson(json);

@override@JsonKey() final  String chave;
/// 'critico' | 'alerta' | 'info'.
@override@JsonKey() final  String severidade;
@override@JsonKey() final  String titulo;
@override@JsonKey() final  String detalhe;
 final  Map<String, num> _numeros;
@override@JsonKey() Map<String, num> get numeros {
  if (_numeros is EqualUnmodifiableMapView) return _numeros;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_numeros);
}


/// Create a copy of SinalMensal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SinalMensalCopyWith<_SinalMensal> get copyWith => __$SinalMensalCopyWithImpl<_SinalMensal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SinalMensalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SinalMensal&&(identical(other.chave, chave) || other.chave == chave)&&(identical(other.severidade, severidade) || other.severidade == severidade)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.detalhe, detalhe) || other.detalhe == detalhe)&&const DeepCollectionEquality().equals(other._numeros, _numeros));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,chave,severidade,titulo,detalhe,const DeepCollectionEquality().hash(_numeros));

@override
String toString() {
  return 'SinalMensal(chave: $chave, severidade: $severidade, titulo: $titulo, detalhe: $detalhe, numeros: $numeros)';
}


}

/// @nodoc
abstract mixin class _$SinalMensalCopyWith<$Res> implements $SinalMensalCopyWith<$Res> {
  factory _$SinalMensalCopyWith(_SinalMensal value, $Res Function(_SinalMensal) _then) = __$SinalMensalCopyWithImpl;
@override @useResult
$Res call({
 String chave, String severidade, String titulo, String detalhe, Map<String, num> numeros
});




}
/// @nodoc
class __$SinalMensalCopyWithImpl<$Res>
    implements _$SinalMensalCopyWith<$Res> {
  __$SinalMensalCopyWithImpl(this._self, this._then);

  final _SinalMensal _self;
  final $Res Function(_SinalMensal) _then;

/// Create a copy of SinalMensal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chave = null,Object? severidade = null,Object? titulo = null,Object? detalhe = null,Object? numeros = null,}) {
  return _then(_SinalMensal(
chave: null == chave ? _self.chave : chave // ignore: cast_nullable_to_non_nullable
as String,severidade: null == severidade ? _self.severidade : severidade // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,detalhe: null == detalhe ? _self.detalhe : detalhe // ignore: cast_nullable_to_non_nullable
as String,numeros: null == numeros ? _self._numeros : numeros // ignore: cast_nullable_to_non_nullable
as Map<String, num>,
  ));
}


}


/// @nodoc
mixin _$NarrativaMensal {

 String get titulo; String get leitura; List<String> get alertas; List<String> get recomendacoes;
/// Create a copy of NarrativaMensal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NarrativaMensalCopyWith<NarrativaMensal> get copyWith => _$NarrativaMensalCopyWithImpl<NarrativaMensal>(this as NarrativaMensal, _$identity);

  /// Serializes this NarrativaMensal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NarrativaMensal&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.leitura, leitura) || other.leitura == leitura)&&const DeepCollectionEquality().equals(other.alertas, alertas)&&const DeepCollectionEquality().equals(other.recomendacoes, recomendacoes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,titulo,leitura,const DeepCollectionEquality().hash(alertas),const DeepCollectionEquality().hash(recomendacoes));

@override
String toString() {
  return 'NarrativaMensal(titulo: $titulo, leitura: $leitura, alertas: $alertas, recomendacoes: $recomendacoes)';
}


}

/// @nodoc
abstract mixin class $NarrativaMensalCopyWith<$Res>  {
  factory $NarrativaMensalCopyWith(NarrativaMensal value, $Res Function(NarrativaMensal) _then) = _$NarrativaMensalCopyWithImpl;
@useResult
$Res call({
 String titulo, String leitura, List<String> alertas, List<String> recomendacoes
});




}
/// @nodoc
class _$NarrativaMensalCopyWithImpl<$Res>
    implements $NarrativaMensalCopyWith<$Res> {
  _$NarrativaMensalCopyWithImpl(this._self, this._then);

  final NarrativaMensal _self;
  final $Res Function(NarrativaMensal) _then;

/// Create a copy of NarrativaMensal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? titulo = null,Object? leitura = null,Object? alertas = null,Object? recomendacoes = null,}) {
  return _then(_self.copyWith(
titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,leitura: null == leitura ? _self.leitura : leitura // ignore: cast_nullable_to_non_nullable
as String,alertas: null == alertas ? _self.alertas : alertas // ignore: cast_nullable_to_non_nullable
as List<String>,recomendacoes: null == recomendacoes ? _self.recomendacoes : recomendacoes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [NarrativaMensal].
extension NarrativaMensalPatterns on NarrativaMensal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NarrativaMensal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NarrativaMensal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NarrativaMensal value)  $default,){
final _that = this;
switch (_that) {
case _NarrativaMensal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NarrativaMensal value)?  $default,){
final _that = this;
switch (_that) {
case _NarrativaMensal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String titulo,  String leitura,  List<String> alertas,  List<String> recomendacoes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NarrativaMensal() when $default != null:
return $default(_that.titulo,_that.leitura,_that.alertas,_that.recomendacoes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String titulo,  String leitura,  List<String> alertas,  List<String> recomendacoes)  $default,) {final _that = this;
switch (_that) {
case _NarrativaMensal():
return $default(_that.titulo,_that.leitura,_that.alertas,_that.recomendacoes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String titulo,  String leitura,  List<String> alertas,  List<String> recomendacoes)?  $default,) {final _that = this;
switch (_that) {
case _NarrativaMensal() when $default != null:
return $default(_that.titulo,_that.leitura,_that.alertas,_that.recomendacoes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NarrativaMensal implements NarrativaMensal {
  const _NarrativaMensal({this.titulo = '', this.leitura = '', final  List<String> alertas = const <String>[], final  List<String> recomendacoes = const <String>[]}): _alertas = alertas,_recomendacoes = recomendacoes;
  factory _NarrativaMensal.fromJson(Map<String, dynamic> json) => _$NarrativaMensalFromJson(json);

@override@JsonKey() final  String titulo;
@override@JsonKey() final  String leitura;
 final  List<String> _alertas;
@override@JsonKey() List<String> get alertas {
  if (_alertas is EqualUnmodifiableListView) return _alertas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_alertas);
}

 final  List<String> _recomendacoes;
@override@JsonKey() List<String> get recomendacoes {
  if (_recomendacoes is EqualUnmodifiableListView) return _recomendacoes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recomendacoes);
}


/// Create a copy of NarrativaMensal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NarrativaMensalCopyWith<_NarrativaMensal> get copyWith => __$NarrativaMensalCopyWithImpl<_NarrativaMensal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NarrativaMensalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NarrativaMensal&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.leitura, leitura) || other.leitura == leitura)&&const DeepCollectionEquality().equals(other._alertas, _alertas)&&const DeepCollectionEquality().equals(other._recomendacoes, _recomendacoes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,titulo,leitura,const DeepCollectionEquality().hash(_alertas),const DeepCollectionEquality().hash(_recomendacoes));

@override
String toString() {
  return 'NarrativaMensal(titulo: $titulo, leitura: $leitura, alertas: $alertas, recomendacoes: $recomendacoes)';
}


}

/// @nodoc
abstract mixin class _$NarrativaMensalCopyWith<$Res> implements $NarrativaMensalCopyWith<$Res> {
  factory _$NarrativaMensalCopyWith(_NarrativaMensal value, $Res Function(_NarrativaMensal) _then) = __$NarrativaMensalCopyWithImpl;
@override @useResult
$Res call({
 String titulo, String leitura, List<String> alertas, List<String> recomendacoes
});




}
/// @nodoc
class __$NarrativaMensalCopyWithImpl<$Res>
    implements _$NarrativaMensalCopyWith<$Res> {
  __$NarrativaMensalCopyWithImpl(this._self, this._then);

  final _NarrativaMensal _self;
  final $Res Function(_NarrativaMensal) _then;

/// Create a copy of NarrativaMensal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? titulo = null,Object? leitura = null,Object? alertas = null,Object? recomendacoes = null,}) {
  return _then(_NarrativaMensal(
titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,leitura: null == leitura ? _self.leitura : leitura // ignore: cast_nullable_to_non_nullable
as String,alertas: null == alertas ? _self._alertas : alertas // ignore: cast_nullable_to_non_nullable
as List<String>,recomendacoes: null == recomendacoes ? _self._recomendacoes : recomendacoes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$ResumoMensal {

/// Primeiro dia do mês analisado, "2026-09-01".
 String get period; PeriodoMensal get periodo; List<KpiMensal> get kpis; List<SinalMensal> get sinais; NarrativaMensal get narrativa;@JsonKey(name: 'aiModel') String get aiModel;/// 'ok' = escrito pelo modelo; 'fallback' = montado pelo sistema.
@JsonKey(name: 'aiStatus') String get aiStatus;@JsonKey(name: 'generatedAt') String get generatedAt;
/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResumoMensalCopyWith<ResumoMensal> get copyWith => _$ResumoMensalCopyWithImpl<ResumoMensal>(this as ResumoMensal, _$identity);

  /// Serializes this ResumoMensal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResumoMensal&&(identical(other.period, period) || other.period == period)&&(identical(other.periodo, periodo) || other.periodo == periodo)&&const DeepCollectionEquality().equals(other.kpis, kpis)&&const DeepCollectionEquality().equals(other.sinais, sinais)&&(identical(other.narrativa, narrativa) || other.narrativa == narrativa)&&(identical(other.aiModel, aiModel) || other.aiModel == aiModel)&&(identical(other.aiStatus, aiStatus) || other.aiStatus == aiStatus)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,period,periodo,const DeepCollectionEquality().hash(kpis),const DeepCollectionEquality().hash(sinais),narrativa,aiModel,aiStatus,generatedAt);

@override
String toString() {
  return 'ResumoMensal(period: $period, periodo: $periodo, kpis: $kpis, sinais: $sinais, narrativa: $narrativa, aiModel: $aiModel, aiStatus: $aiStatus, generatedAt: $generatedAt)';
}


}

/// @nodoc
abstract mixin class $ResumoMensalCopyWith<$Res>  {
  factory $ResumoMensalCopyWith(ResumoMensal value, $Res Function(ResumoMensal) _then) = _$ResumoMensalCopyWithImpl;
@useResult
$Res call({
 String period, PeriodoMensal periodo, List<KpiMensal> kpis, List<SinalMensal> sinais, NarrativaMensal narrativa,@JsonKey(name: 'aiModel') String aiModel,@JsonKey(name: 'aiStatus') String aiStatus,@JsonKey(name: 'generatedAt') String generatedAt
});


$PeriodoMensalCopyWith<$Res> get periodo;$NarrativaMensalCopyWith<$Res> get narrativa;

}
/// @nodoc
class _$ResumoMensalCopyWithImpl<$Res>
    implements $ResumoMensalCopyWith<$Res> {
  _$ResumoMensalCopyWithImpl(this._self, this._then);

  final ResumoMensal _self;
  final $Res Function(ResumoMensal) _then;

/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? periodo = null,Object? kpis = null,Object? sinais = null,Object? narrativa = null,Object? aiModel = null,Object? aiStatus = null,Object? generatedAt = null,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,periodo: null == periodo ? _self.periodo : periodo // ignore: cast_nullable_to_non_nullable
as PeriodoMensal,kpis: null == kpis ? _self.kpis : kpis // ignore: cast_nullable_to_non_nullable
as List<KpiMensal>,sinais: null == sinais ? _self.sinais : sinais // ignore: cast_nullable_to_non_nullable
as List<SinalMensal>,narrativa: null == narrativa ? _self.narrativa : narrativa // ignore: cast_nullable_to_non_nullable
as NarrativaMensal,aiModel: null == aiModel ? _self.aiModel : aiModel // ignore: cast_nullable_to_non_nullable
as String,aiStatus: null == aiStatus ? _self.aiStatus : aiStatus // ignore: cast_nullable_to_non_nullable
as String,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PeriodoMensalCopyWith<$Res> get periodo {
  
  return $PeriodoMensalCopyWith<$Res>(_self.periodo, (value) {
    return _then(_self.copyWith(periodo: value));
  });
}/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NarrativaMensalCopyWith<$Res> get narrativa {
  
  return $NarrativaMensalCopyWith<$Res>(_self.narrativa, (value) {
    return _then(_self.copyWith(narrativa: value));
  });
}
}


/// Adds pattern-matching-related methods to [ResumoMensal].
extension ResumoMensalPatterns on ResumoMensal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResumoMensal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResumoMensal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResumoMensal value)  $default,){
final _that = this;
switch (_that) {
case _ResumoMensal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResumoMensal value)?  $default,){
final _that = this;
switch (_that) {
case _ResumoMensal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String period,  PeriodoMensal periodo,  List<KpiMensal> kpis,  List<SinalMensal> sinais,  NarrativaMensal narrativa, @JsonKey(name: 'aiModel')  String aiModel, @JsonKey(name: 'aiStatus')  String aiStatus, @JsonKey(name: 'generatedAt')  String generatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResumoMensal() when $default != null:
return $default(_that.period,_that.periodo,_that.kpis,_that.sinais,_that.narrativa,_that.aiModel,_that.aiStatus,_that.generatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String period,  PeriodoMensal periodo,  List<KpiMensal> kpis,  List<SinalMensal> sinais,  NarrativaMensal narrativa, @JsonKey(name: 'aiModel')  String aiModel, @JsonKey(name: 'aiStatus')  String aiStatus, @JsonKey(name: 'generatedAt')  String generatedAt)  $default,) {final _that = this;
switch (_that) {
case _ResumoMensal():
return $default(_that.period,_that.periodo,_that.kpis,_that.sinais,_that.narrativa,_that.aiModel,_that.aiStatus,_that.generatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String period,  PeriodoMensal periodo,  List<KpiMensal> kpis,  List<SinalMensal> sinais,  NarrativaMensal narrativa, @JsonKey(name: 'aiModel')  String aiModel, @JsonKey(name: 'aiStatus')  String aiStatus, @JsonKey(name: 'generatedAt')  String generatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ResumoMensal() when $default != null:
return $default(_that.period,_that.periodo,_that.kpis,_that.sinais,_that.narrativa,_that.aiModel,_that.aiStatus,_that.generatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResumoMensal extends ResumoMensal {
  const _ResumoMensal({this.period = '', this.periodo = const PeriodoMensal(), final  List<KpiMensal> kpis = const <KpiMensal>[], final  List<SinalMensal> sinais = const <SinalMensal>[], this.narrativa = const NarrativaMensal(), @JsonKey(name: 'aiModel') this.aiModel = '', @JsonKey(name: 'aiStatus') this.aiStatus = 'ok', @JsonKey(name: 'generatedAt') this.generatedAt = ''}): _kpis = kpis,_sinais = sinais,super._();
  factory _ResumoMensal.fromJson(Map<String, dynamic> json) => _$ResumoMensalFromJson(json);

/// Primeiro dia do mês analisado, "2026-09-01".
@override@JsonKey() final  String period;
@override@JsonKey() final  PeriodoMensal periodo;
 final  List<KpiMensal> _kpis;
@override@JsonKey() List<KpiMensal> get kpis {
  if (_kpis is EqualUnmodifiableListView) return _kpis;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_kpis);
}

 final  List<SinalMensal> _sinais;
@override@JsonKey() List<SinalMensal> get sinais {
  if (_sinais is EqualUnmodifiableListView) return _sinais;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sinais);
}

@override@JsonKey() final  NarrativaMensal narrativa;
@override@JsonKey(name: 'aiModel') final  String aiModel;
/// 'ok' = escrito pelo modelo; 'fallback' = montado pelo sistema.
@override@JsonKey(name: 'aiStatus') final  String aiStatus;
@override@JsonKey(name: 'generatedAt') final  String generatedAt;

/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResumoMensalCopyWith<_ResumoMensal> get copyWith => __$ResumoMensalCopyWithImpl<_ResumoMensal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResumoMensalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResumoMensal&&(identical(other.period, period) || other.period == period)&&(identical(other.periodo, periodo) || other.periodo == periodo)&&const DeepCollectionEquality().equals(other._kpis, _kpis)&&const DeepCollectionEquality().equals(other._sinais, _sinais)&&(identical(other.narrativa, narrativa) || other.narrativa == narrativa)&&(identical(other.aiModel, aiModel) || other.aiModel == aiModel)&&(identical(other.aiStatus, aiStatus) || other.aiStatus == aiStatus)&&(identical(other.generatedAt, generatedAt) || other.generatedAt == generatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,period,periodo,const DeepCollectionEquality().hash(_kpis),const DeepCollectionEquality().hash(_sinais),narrativa,aiModel,aiStatus,generatedAt);

@override
String toString() {
  return 'ResumoMensal(period: $period, periodo: $periodo, kpis: $kpis, sinais: $sinais, narrativa: $narrativa, aiModel: $aiModel, aiStatus: $aiStatus, generatedAt: $generatedAt)';
}


}

/// @nodoc
abstract mixin class _$ResumoMensalCopyWith<$Res> implements $ResumoMensalCopyWith<$Res> {
  factory _$ResumoMensalCopyWith(_ResumoMensal value, $Res Function(_ResumoMensal) _then) = __$ResumoMensalCopyWithImpl;
@override @useResult
$Res call({
 String period, PeriodoMensal periodo, List<KpiMensal> kpis, List<SinalMensal> sinais, NarrativaMensal narrativa,@JsonKey(name: 'aiModel') String aiModel,@JsonKey(name: 'aiStatus') String aiStatus,@JsonKey(name: 'generatedAt') String generatedAt
});


@override $PeriodoMensalCopyWith<$Res> get periodo;@override $NarrativaMensalCopyWith<$Res> get narrativa;

}
/// @nodoc
class __$ResumoMensalCopyWithImpl<$Res>
    implements _$ResumoMensalCopyWith<$Res> {
  __$ResumoMensalCopyWithImpl(this._self, this._then);

  final _ResumoMensal _self;
  final $Res Function(_ResumoMensal) _then;

/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? period = null,Object? periodo = null,Object? kpis = null,Object? sinais = null,Object? narrativa = null,Object? aiModel = null,Object? aiStatus = null,Object? generatedAt = null,}) {
  return _then(_ResumoMensal(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,periodo: null == periodo ? _self.periodo : periodo // ignore: cast_nullable_to_non_nullable
as PeriodoMensal,kpis: null == kpis ? _self._kpis : kpis // ignore: cast_nullable_to_non_nullable
as List<KpiMensal>,sinais: null == sinais ? _self._sinais : sinais // ignore: cast_nullable_to_non_nullable
as List<SinalMensal>,narrativa: null == narrativa ? _self.narrativa : narrativa // ignore: cast_nullable_to_non_nullable
as NarrativaMensal,aiModel: null == aiModel ? _self.aiModel : aiModel // ignore: cast_nullable_to_non_nullable
as String,aiStatus: null == aiStatus ? _self.aiStatus : aiStatus // ignore: cast_nullable_to_non_nullable
as String,generatedAt: null == generatedAt ? _self.generatedAt : generatedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PeriodoMensalCopyWith<$Res> get periodo {
  
  return $PeriodoMensalCopyWith<$Res>(_self.periodo, (value) {
    return _then(_self.copyWith(periodo: value));
  });
}/// Create a copy of ResumoMensal
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NarrativaMensalCopyWith<$Res> get narrativa {
  
  return $NarrativaMensalCopyWith<$Res>(_self.narrativa, (value) {
    return _then(_self.copyWith(narrativa: value));
  });
}
}


/// @nodoc
mixin _$ResumoMensalPagina {

 ResumoMensal? get resumo; List<String> get periodos;
/// Create a copy of ResumoMensalPagina
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResumoMensalPaginaCopyWith<ResumoMensalPagina> get copyWith => _$ResumoMensalPaginaCopyWithImpl<ResumoMensalPagina>(this as ResumoMensalPagina, _$identity);

  /// Serializes this ResumoMensalPagina to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResumoMensalPagina&&(identical(other.resumo, resumo) || other.resumo == resumo)&&const DeepCollectionEquality().equals(other.periodos, periodos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,resumo,const DeepCollectionEquality().hash(periodos));

@override
String toString() {
  return 'ResumoMensalPagina(resumo: $resumo, periodos: $periodos)';
}


}

/// @nodoc
abstract mixin class $ResumoMensalPaginaCopyWith<$Res>  {
  factory $ResumoMensalPaginaCopyWith(ResumoMensalPagina value, $Res Function(ResumoMensalPagina) _then) = _$ResumoMensalPaginaCopyWithImpl;
@useResult
$Res call({
 ResumoMensal? resumo, List<String> periodos
});


$ResumoMensalCopyWith<$Res>? get resumo;

}
/// @nodoc
class _$ResumoMensalPaginaCopyWithImpl<$Res>
    implements $ResumoMensalPaginaCopyWith<$Res> {
  _$ResumoMensalPaginaCopyWithImpl(this._self, this._then);

  final ResumoMensalPagina _self;
  final $Res Function(ResumoMensalPagina) _then;

/// Create a copy of ResumoMensalPagina
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? resumo = freezed,Object? periodos = null,}) {
  return _then(_self.copyWith(
resumo: freezed == resumo ? _self.resumo : resumo // ignore: cast_nullable_to_non_nullable
as ResumoMensal?,periodos: null == periodos ? _self.periodos : periodos // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of ResumoMensalPagina
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResumoMensalCopyWith<$Res>? get resumo {
    if (_self.resumo == null) {
    return null;
  }

  return $ResumoMensalCopyWith<$Res>(_self.resumo!, (value) {
    return _then(_self.copyWith(resumo: value));
  });
}
}


/// Adds pattern-matching-related methods to [ResumoMensalPagina].
extension ResumoMensalPaginaPatterns on ResumoMensalPagina {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResumoMensalPagina value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResumoMensalPagina() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResumoMensalPagina value)  $default,){
final _that = this;
switch (_that) {
case _ResumoMensalPagina():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResumoMensalPagina value)?  $default,){
final _that = this;
switch (_that) {
case _ResumoMensalPagina() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ResumoMensal? resumo,  List<String> periodos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResumoMensalPagina() when $default != null:
return $default(_that.resumo,_that.periodos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ResumoMensal? resumo,  List<String> periodos)  $default,) {final _that = this;
switch (_that) {
case _ResumoMensalPagina():
return $default(_that.resumo,_that.periodos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ResumoMensal? resumo,  List<String> periodos)?  $default,) {final _that = this;
switch (_that) {
case _ResumoMensalPagina() when $default != null:
return $default(_that.resumo,_that.periodos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResumoMensalPagina implements ResumoMensalPagina {
  const _ResumoMensalPagina({this.resumo, final  List<String> periodos = const <String>[]}): _periodos = periodos;
  factory _ResumoMensalPagina.fromJson(Map<String, dynamic> json) => _$ResumoMensalPaginaFromJson(json);

@override final  ResumoMensal? resumo;
 final  List<String> _periodos;
@override@JsonKey() List<String> get periodos {
  if (_periodos is EqualUnmodifiableListView) return _periodos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_periodos);
}


/// Create a copy of ResumoMensalPagina
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResumoMensalPaginaCopyWith<_ResumoMensalPagina> get copyWith => __$ResumoMensalPaginaCopyWithImpl<_ResumoMensalPagina>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResumoMensalPaginaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResumoMensalPagina&&(identical(other.resumo, resumo) || other.resumo == resumo)&&const DeepCollectionEquality().equals(other._periodos, _periodos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,resumo,const DeepCollectionEquality().hash(_periodos));

@override
String toString() {
  return 'ResumoMensalPagina(resumo: $resumo, periodos: $periodos)';
}


}

/// @nodoc
abstract mixin class _$ResumoMensalPaginaCopyWith<$Res> implements $ResumoMensalPaginaCopyWith<$Res> {
  factory _$ResumoMensalPaginaCopyWith(_ResumoMensalPagina value, $Res Function(_ResumoMensalPagina) _then) = __$ResumoMensalPaginaCopyWithImpl;
@override @useResult
$Res call({
 ResumoMensal? resumo, List<String> periodos
});


@override $ResumoMensalCopyWith<$Res>? get resumo;

}
/// @nodoc
class __$ResumoMensalPaginaCopyWithImpl<$Res>
    implements _$ResumoMensalPaginaCopyWith<$Res> {
  __$ResumoMensalPaginaCopyWithImpl(this._self, this._then);

  final _ResumoMensalPagina _self;
  final $Res Function(_ResumoMensalPagina) _then;

/// Create a copy of ResumoMensalPagina
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? resumo = freezed,Object? periodos = null,}) {
  return _then(_ResumoMensalPagina(
resumo: freezed == resumo ? _self.resumo : resumo // ignore: cast_nullable_to_non_nullable
as ResumoMensal?,periodos: null == periodos ? _self._periodos : periodos // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of ResumoMensalPagina
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResumoMensalCopyWith<$Res>? get resumo {
    if (_self.resumo == null) {
    return null;
  }

  return $ResumoMensalCopyWith<$Res>(_self.resumo!, (value) {
    return _then(_self.copyWith(resumo: value));
  });
}
}

// dart format on
