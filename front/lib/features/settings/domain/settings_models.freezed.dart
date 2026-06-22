// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SettingsFieldOption {

 String get value; String get label;
/// Create a copy of SettingsFieldOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsFieldOptionCopyWith<SettingsFieldOption> get copyWith => _$SettingsFieldOptionCopyWithImpl<SettingsFieldOption>(this as SettingsFieldOption, _$identity);

  /// Serializes this SettingsFieldOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsFieldOption&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,label);

@override
String toString() {
  return 'SettingsFieldOption(value: $value, label: $label)';
}


}

/// @nodoc
abstract mixin class $SettingsFieldOptionCopyWith<$Res>  {
  factory $SettingsFieldOptionCopyWith(SettingsFieldOption value, $Res Function(SettingsFieldOption) _then) = _$SettingsFieldOptionCopyWithImpl;
@useResult
$Res call({
 String value, String label
});




}
/// @nodoc
class _$SettingsFieldOptionCopyWithImpl<$Res>
    implements $SettingsFieldOptionCopyWith<$Res> {
  _$SettingsFieldOptionCopyWithImpl(this._self, this._then);

  final SettingsFieldOption _self;
  final $Res Function(SettingsFieldOption) _then;

/// Create a copy of SettingsFieldOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? label = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingsFieldOption].
extension SettingsFieldOptionPatterns on SettingsFieldOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsFieldOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsFieldOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsFieldOption value)  $default,){
final _that = this;
switch (_that) {
case _SettingsFieldOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsFieldOption value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsFieldOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value,  String label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsFieldOption() when $default != null:
return $default(_that.value,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value,  String label)  $default,) {final _that = this;
switch (_that) {
case _SettingsFieldOption():
return $default(_that.value,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value,  String label)?  $default,) {final _that = this;
switch (_that) {
case _SettingsFieldOption() when $default != null:
return $default(_that.value,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SettingsFieldOption implements SettingsFieldOption {
  const _SettingsFieldOption({required this.value, required this.label});
  factory _SettingsFieldOption.fromJson(Map<String, dynamic> json) => _$SettingsFieldOptionFromJson(json);

@override final  String value;
@override final  String label;

/// Create a copy of SettingsFieldOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsFieldOptionCopyWith<_SettingsFieldOption> get copyWith => __$SettingsFieldOptionCopyWithImpl<_SettingsFieldOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SettingsFieldOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsFieldOption&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value,label);

@override
String toString() {
  return 'SettingsFieldOption(value: $value, label: $label)';
}


}

/// @nodoc
abstract mixin class _$SettingsFieldOptionCopyWith<$Res> implements $SettingsFieldOptionCopyWith<$Res> {
  factory _$SettingsFieldOptionCopyWith(_SettingsFieldOption value, $Res Function(_SettingsFieldOption) _then) = __$SettingsFieldOptionCopyWithImpl;
@override @useResult
$Res call({
 String value, String label
});




}
/// @nodoc
class __$SettingsFieldOptionCopyWithImpl<$Res>
    implements _$SettingsFieldOptionCopyWith<$Res> {
  __$SettingsFieldOptionCopyWithImpl(this._self, this._then);

  final _SettingsFieldOption _self;
  final $Res Function(_SettingsFieldOption) _then;

/// Create a copy of SettingsFieldOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? label = null,}) {
  return _then(_SettingsFieldOption(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SettingsField {

 String get key; String get label; String get type; List<SettingsFieldOption> get options; String? get group;
/// Create a copy of SettingsField
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsFieldCopyWith<SettingsField> get copyWith => _$SettingsFieldCopyWithImpl<SettingsField>(this as SettingsField, _$identity);

  /// Serializes this SettingsField to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsField&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.group, group) || other.group == group));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,type,const DeepCollectionEquality().hash(options),group);

@override
String toString() {
  return 'SettingsField(key: $key, label: $label, type: $type, options: $options, group: $group)';
}


}

/// @nodoc
abstract mixin class $SettingsFieldCopyWith<$Res>  {
  factory $SettingsFieldCopyWith(SettingsField value, $Res Function(SettingsField) _then) = _$SettingsFieldCopyWithImpl;
@useResult
$Res call({
 String key, String label, String type, List<SettingsFieldOption> options, String? group
});




}
/// @nodoc
class _$SettingsFieldCopyWithImpl<$Res>
    implements $SettingsFieldCopyWith<$Res> {
  _$SettingsFieldCopyWithImpl(this._self, this._then);

  final SettingsField _self;
  final $Res Function(SettingsField) _then;

/// Create a copy of SettingsField
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? label = null,Object? type = null,Object? options = null,Object? group = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<SettingsFieldOption>,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingsField].
extension SettingsFieldPatterns on SettingsField {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsField value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsField() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsField value)  $default,){
final _that = this;
switch (_that) {
case _SettingsField():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsField value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsField() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String label,  String type,  List<SettingsFieldOption> options,  String? group)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsField() when $default != null:
return $default(_that.key,_that.label,_that.type,_that.options,_that.group);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String label,  String type,  List<SettingsFieldOption> options,  String? group)  $default,) {final _that = this;
switch (_that) {
case _SettingsField():
return $default(_that.key,_that.label,_that.type,_that.options,_that.group);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String label,  String type,  List<SettingsFieldOption> options,  String? group)?  $default,) {final _that = this;
switch (_that) {
case _SettingsField() when $default != null:
return $default(_that.key,_that.label,_that.type,_that.options,_that.group);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SettingsField implements SettingsField {
  const _SettingsField({required this.key, required this.label, required this.type, final  List<SettingsFieldOption> options = const <SettingsFieldOption>[], this.group}): _options = options;
  factory _SettingsField.fromJson(Map<String, dynamic> json) => _$SettingsFieldFromJson(json);

@override final  String key;
@override final  String label;
@override final  String type;
 final  List<SettingsFieldOption> _options;
@override@JsonKey() List<SettingsFieldOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  String? group;

/// Create a copy of SettingsField
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsFieldCopyWith<_SettingsField> get copyWith => __$SettingsFieldCopyWithImpl<_SettingsField>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SettingsFieldToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsField&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.group, group) || other.group == group));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,type,const DeepCollectionEquality().hash(_options),group);

@override
String toString() {
  return 'SettingsField(key: $key, label: $label, type: $type, options: $options, group: $group)';
}


}

/// @nodoc
abstract mixin class _$SettingsFieldCopyWith<$Res> implements $SettingsFieldCopyWith<$Res> {
  factory _$SettingsFieldCopyWith(_SettingsField value, $Res Function(_SettingsField) _then) = __$SettingsFieldCopyWithImpl;
@override @useResult
$Res call({
 String key, String label, String type, List<SettingsFieldOption> options, String? group
});




}
/// @nodoc
class __$SettingsFieldCopyWithImpl<$Res>
    implements _$SettingsFieldCopyWith<$Res> {
  __$SettingsFieldCopyWithImpl(this._self, this._then);

  final _SettingsField _self;
  final $Res Function(_SettingsField) _then;

/// Create a copy of SettingsField
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? label = null,Object? type = null,Object? options = null,Object? group = freezed,}) {
  return _then(_SettingsField(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<SettingsFieldOption>,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SettingsSection {

 String get key; String get title; String? get moduleKey; List<SettingsField> get fields;
/// Create a copy of SettingsSection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsSectionCopyWith<SettingsSection> get copyWith => _$SettingsSectionCopyWithImpl<SettingsSection>(this as SettingsSection, _$identity);

  /// Serializes this SettingsSection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsSection&&(identical(other.key, key) || other.key == key)&&(identical(other.title, title) || other.title == title)&&(identical(other.moduleKey, moduleKey) || other.moduleKey == moduleKey)&&const DeepCollectionEquality().equals(other.fields, fields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,title,moduleKey,const DeepCollectionEquality().hash(fields));

@override
String toString() {
  return 'SettingsSection(key: $key, title: $title, moduleKey: $moduleKey, fields: $fields)';
}


}

/// @nodoc
abstract mixin class $SettingsSectionCopyWith<$Res>  {
  factory $SettingsSectionCopyWith(SettingsSection value, $Res Function(SettingsSection) _then) = _$SettingsSectionCopyWithImpl;
@useResult
$Res call({
 String key, String title, String? moduleKey, List<SettingsField> fields
});




}
/// @nodoc
class _$SettingsSectionCopyWithImpl<$Res>
    implements $SettingsSectionCopyWith<$Res> {
  _$SettingsSectionCopyWithImpl(this._self, this._then);

  final SettingsSection _self;
  final $Res Function(SettingsSection) _then;

/// Create a copy of SettingsSection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? title = null,Object? moduleKey = freezed,Object? fields = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,moduleKey: freezed == moduleKey ? _self.moduleKey : moduleKey // ignore: cast_nullable_to_non_nullable
as String?,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as List<SettingsField>,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingsSection].
extension SettingsSectionPatterns on SettingsSection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsSection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsSection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsSection value)  $default,){
final _that = this;
switch (_that) {
case _SettingsSection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsSection value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsSection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String title,  String? moduleKey,  List<SettingsField> fields)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsSection() when $default != null:
return $default(_that.key,_that.title,_that.moduleKey,_that.fields);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String title,  String? moduleKey,  List<SettingsField> fields)  $default,) {final _that = this;
switch (_that) {
case _SettingsSection():
return $default(_that.key,_that.title,_that.moduleKey,_that.fields);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String title,  String? moduleKey,  List<SettingsField> fields)?  $default,) {final _that = this;
switch (_that) {
case _SettingsSection() when $default != null:
return $default(_that.key,_that.title,_that.moduleKey,_that.fields);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SettingsSection implements SettingsSection {
  const _SettingsSection({required this.key, required this.title, this.moduleKey, final  List<SettingsField> fields = const <SettingsField>[]}): _fields = fields;
  factory _SettingsSection.fromJson(Map<String, dynamic> json) => _$SettingsSectionFromJson(json);

@override final  String key;
@override final  String title;
@override final  String? moduleKey;
 final  List<SettingsField> _fields;
@override@JsonKey() List<SettingsField> get fields {
  if (_fields is EqualUnmodifiableListView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fields);
}


/// Create a copy of SettingsSection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsSectionCopyWith<_SettingsSection> get copyWith => __$SettingsSectionCopyWithImpl<_SettingsSection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SettingsSectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsSection&&(identical(other.key, key) || other.key == key)&&(identical(other.title, title) || other.title == title)&&(identical(other.moduleKey, moduleKey) || other.moduleKey == moduleKey)&&const DeepCollectionEquality().equals(other._fields, _fields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,title,moduleKey,const DeepCollectionEquality().hash(_fields));

@override
String toString() {
  return 'SettingsSection(key: $key, title: $title, moduleKey: $moduleKey, fields: $fields)';
}


}

/// @nodoc
abstract mixin class _$SettingsSectionCopyWith<$Res> implements $SettingsSectionCopyWith<$Res> {
  factory _$SettingsSectionCopyWith(_SettingsSection value, $Res Function(_SettingsSection) _then) = __$SettingsSectionCopyWithImpl;
@override @useResult
$Res call({
 String key, String title, String? moduleKey, List<SettingsField> fields
});




}
/// @nodoc
class __$SettingsSectionCopyWithImpl<$Res>
    implements _$SettingsSectionCopyWith<$Res> {
  __$SettingsSectionCopyWithImpl(this._self, this._then);

  final _SettingsSection _self;
  final $Res Function(_SettingsSection) _then;

/// Create a copy of SettingsSection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? title = null,Object? moduleKey = freezed,Object? fields = null,}) {
  return _then(_SettingsSection(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,moduleKey: freezed == moduleKey ? _self.moduleKey : moduleKey // ignore: cast_nullable_to_non_nullable
as String?,fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as List<SettingsField>,
  ));
}


}


/// @nodoc
mixin _$SettingsBundle {

 Map<String, dynamic> get company; List<SettingsSection> get sections;
/// Create a copy of SettingsBundle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsBundleCopyWith<SettingsBundle> get copyWith => _$SettingsBundleCopyWithImpl<SettingsBundle>(this as SettingsBundle, _$identity);

  /// Serializes this SettingsBundle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsBundle&&const DeepCollectionEquality().equals(other.company, company)&&const DeepCollectionEquality().equals(other.sections, sections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(company),const DeepCollectionEquality().hash(sections));

@override
String toString() {
  return 'SettingsBundle(company: $company, sections: $sections)';
}


}

/// @nodoc
abstract mixin class $SettingsBundleCopyWith<$Res>  {
  factory $SettingsBundleCopyWith(SettingsBundle value, $Res Function(SettingsBundle) _then) = _$SettingsBundleCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> company, List<SettingsSection> sections
});




}
/// @nodoc
class _$SettingsBundleCopyWithImpl<$Res>
    implements $SettingsBundleCopyWith<$Res> {
  _$SettingsBundleCopyWithImpl(this._self, this._then);

  final SettingsBundle _self;
  final $Res Function(SettingsBundle) _then;

/// Create a copy of SettingsBundle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? company = null,Object? sections = null,}) {
  return _then(_self.copyWith(
company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,sections: null == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as List<SettingsSection>,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingsBundle].
extension SettingsBundlePatterns on SettingsBundle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsBundle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsBundle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsBundle value)  $default,){
final _that = this;
switch (_that) {
case _SettingsBundle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsBundle value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsBundle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, dynamic> company,  List<SettingsSection> sections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsBundle() when $default != null:
return $default(_that.company,_that.sections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, dynamic> company,  List<SettingsSection> sections)  $default,) {final _that = this;
switch (_that) {
case _SettingsBundle():
return $default(_that.company,_that.sections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, dynamic> company,  List<SettingsSection> sections)?  $default,) {final _that = this;
switch (_that) {
case _SettingsBundle() when $default != null:
return $default(_that.company,_that.sections);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SettingsBundle implements SettingsBundle {
  const _SettingsBundle({final  Map<String, dynamic> company = const <String, dynamic>{}, final  List<SettingsSection> sections = const <SettingsSection>[]}): _company = company,_sections = sections;
  factory _SettingsBundle.fromJson(Map<String, dynamic> json) => _$SettingsBundleFromJson(json);

 final  Map<String, dynamic> _company;
@override@JsonKey() Map<String, dynamic> get company {
  if (_company is EqualUnmodifiableMapView) return _company;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_company);
}

 final  List<SettingsSection> _sections;
@override@JsonKey() List<SettingsSection> get sections {
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sections);
}


/// Create a copy of SettingsBundle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsBundleCopyWith<_SettingsBundle> get copyWith => __$SettingsBundleCopyWithImpl<_SettingsBundle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SettingsBundleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsBundle&&const DeepCollectionEquality().equals(other._company, _company)&&const DeepCollectionEquality().equals(other._sections, _sections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_company),const DeepCollectionEquality().hash(_sections));

@override
String toString() {
  return 'SettingsBundle(company: $company, sections: $sections)';
}


}

/// @nodoc
abstract mixin class _$SettingsBundleCopyWith<$Res> implements $SettingsBundleCopyWith<$Res> {
  factory _$SettingsBundleCopyWith(_SettingsBundle value, $Res Function(_SettingsBundle) _then) = __$SettingsBundleCopyWithImpl;
@override @useResult
$Res call({
 Map<String, dynamic> company, List<SettingsSection> sections
});




}
/// @nodoc
class __$SettingsBundleCopyWithImpl<$Res>
    implements _$SettingsBundleCopyWith<$Res> {
  __$SettingsBundleCopyWithImpl(this._self, this._then);

  final _SettingsBundle _self;
  final $Res Function(_SettingsBundle) _then;

/// Create a copy of SettingsBundle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? company = null,Object? sections = null,}) {
  return _then(_SettingsBundle(
company: null == company ? _self._company : company // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,sections: null == sections ? _self._sections : sections // ignore: cast_nullable_to_non_nullable
as List<SettingsSection>,
  ));
}


}

// dart format on
