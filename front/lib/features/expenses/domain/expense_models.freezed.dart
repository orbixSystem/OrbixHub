// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExpenseCategory {

 String get id; String get name; String get icon;/// Hex `#RRGGBB` vindo do servidor.
 String get color; String get status;
/// Create a copy of ExpenseCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseCategoryCopyWith<ExpenseCategory> get copyWith => _$ExpenseCategoryCopyWithImpl<ExpenseCategory>(this as ExpenseCategory, _$identity);

  /// Serializes this ExpenseCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.color, color) || other.color == color)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,icon,color,status);

@override
String toString() {
  return 'ExpenseCategory(id: $id, name: $name, icon: $icon, color: $color, status: $status)';
}


}

/// @nodoc
abstract mixin class $ExpenseCategoryCopyWith<$Res>  {
  factory $ExpenseCategoryCopyWith(ExpenseCategory value, $Res Function(ExpenseCategory) _then) = _$ExpenseCategoryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String icon, String color, String status
});




}
/// @nodoc
class _$ExpenseCategoryCopyWithImpl<$Res>
    implements $ExpenseCategoryCopyWith<$Res> {
  _$ExpenseCategoryCopyWithImpl(this._self, this._then);

  final ExpenseCategory _self;
  final $Res Function(ExpenseCategory) _then;

/// Create a copy of ExpenseCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? icon = null,Object? color = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseCategory].
extension ExpenseCategoryPatterns on ExpenseCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseCategory value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseCategory value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String icon,  String color,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseCategory() when $default != null:
return $default(_that.id,_that.name,_that.icon,_that.color,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String icon,  String color,  String status)  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategory():
return $default(_that.id,_that.name,_that.icon,_that.color,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String icon,  String color,  String status)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategory() when $default != null:
return $default(_that.id,_that.name,_that.icon,_that.color,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseCategory implements ExpenseCategory {
  const _ExpenseCategory({required this.id, this.name = '', this.icon = 'outros', this.color = '#6B7280', this.status = 'active'});
  factory _ExpenseCategory.fromJson(Map<String, dynamic> json) => _$ExpenseCategoryFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String icon;
/// Hex `#RRGGBB` vindo do servidor.
@override@JsonKey() final  String color;
@override@JsonKey() final  String status;

/// Create a copy of ExpenseCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseCategoryCopyWith<_ExpenseCategory> get copyWith => __$ExpenseCategoryCopyWithImpl<_ExpenseCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.color, color) || other.color == color)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,icon,color,status);

@override
String toString() {
  return 'ExpenseCategory(id: $id, name: $name, icon: $icon, color: $color, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ExpenseCategoryCopyWith<$Res> implements $ExpenseCategoryCopyWith<$Res> {
  factory _$ExpenseCategoryCopyWith(_ExpenseCategory value, $Res Function(_ExpenseCategory) _then) = __$ExpenseCategoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String icon, String color, String status
});




}
/// @nodoc
class __$ExpenseCategoryCopyWithImpl<$Res>
    implements _$ExpenseCategoryCopyWith<$Res> {
  __$ExpenseCategoryCopyWithImpl(this._self, this._then);

  final _ExpenseCategory _self;
  final $Res Function(_ExpenseCategory) _then;

/// Create a copy of ExpenseCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? icon = null,Object? color = null,Object? status = null,}) {
  return _then(_ExpenseCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Expense {

 String get id; String get description;/// 0 = "valor a confirmar" (a conta existe antes de o boleto chegar).
@_Decimal() num get amount;/// Vencimento. O servidor devolve a linha crua do Prisma, então chega em ISO
/// completo (`2026-08-10T00:00:00.000Z`) mesmo sendo `date` no banco.
@JsonKey(name: 'due_date') String get dueDate;@JsonKey(name: 'category_id') String? get categoryId;@JsonKey(name: 'recurrence_id') String? get recurrenceId;/// Instante do pagamento. `null` = não paga — é o ÚNICO fato gravado sobre
/// pagamento; a situação sai daqui (ver [ExpenseStatus]).
@JsonKey(name: 'paid_at') String? get paidAt;/// Pode divergir de [amount] (juros, desconto): o que saiu é o que saiu.
@_DecimalOrNull()@JsonKey(name: 'paid_amount') num? get paidAmount;@JsonKey(name: 'paid_method') String? get paidMethod;/// Id do lançamento no Caixa gerado pela baixa. Só o ID (regra 1): este
/// módulo nunca lê a tabela do caixa.
@JsonKey(name: 'cash_entry_id') String? get cashEntryId; String? get notes;/// Parcelamento: qual parcela esta conta é, de quantas, e o grupo que junta
/// as irmãs. As três andam juntas (CHECK no banco) ou são todas nulas.
@JsonKey(name: 'installment_no') int? get installmentNo;@JsonKey(name: 'installment_total') int? get installmentTotal;@JsonKey(name: 'installment_group_id') String? get installmentGroupId;/// Fornecedor — retrato de quem cobrou, não FK para cadastro.
@JsonKey(name: 'supplier_name') String? get supplierName;/// Só dígitos (14 = CNPJ, 11 = CPF). Quem formata é a tela.
@JsonKey(name: 'supplier_doc') String? get supplierDoc; String get status;
/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseCopyWith<Expense> get copyWith => _$ExpenseCopyWithImpl<Expense>(this as Expense, _$identity);

  /// Serializes this Expense to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Expense&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.recurrenceId, recurrenceId) || other.recurrenceId == recurrenceId)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt)&&(identical(other.paidAmount, paidAmount) || other.paidAmount == paidAmount)&&(identical(other.paidMethod, paidMethod) || other.paidMethod == paidMethod)&&(identical(other.cashEntryId, cashEntryId) || other.cashEntryId == cashEntryId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.installmentNo, installmentNo) || other.installmentNo == installmentNo)&&(identical(other.installmentTotal, installmentTotal) || other.installmentTotal == installmentTotal)&&(identical(other.installmentGroupId, installmentGroupId) || other.installmentGroupId == installmentGroupId)&&(identical(other.supplierName, supplierName) || other.supplierName == supplierName)&&(identical(other.supplierDoc, supplierDoc) || other.supplierDoc == supplierDoc)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description,amount,dueDate,categoryId,recurrenceId,paidAt,paidAmount,paidMethod,cashEntryId,notes,installmentNo,installmentTotal,installmentGroupId,supplierName,supplierDoc,status);

@override
String toString() {
  return 'Expense(id: $id, description: $description, amount: $amount, dueDate: $dueDate, categoryId: $categoryId, recurrenceId: $recurrenceId, paidAt: $paidAt, paidAmount: $paidAmount, paidMethod: $paidMethod, cashEntryId: $cashEntryId, notes: $notes, installmentNo: $installmentNo, installmentTotal: $installmentTotal, installmentGroupId: $installmentGroupId, supplierName: $supplierName, supplierDoc: $supplierDoc, status: $status)';
}


}

/// @nodoc
abstract mixin class $ExpenseCopyWith<$Res>  {
  factory $ExpenseCopyWith(Expense value, $Res Function(Expense) _then) = _$ExpenseCopyWithImpl;
@useResult
$Res call({
 String id, String description,@_Decimal() num amount,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'category_id') String? categoryId,@JsonKey(name: 'recurrence_id') String? recurrenceId,@JsonKey(name: 'paid_at') String? paidAt,@_DecimalOrNull()@JsonKey(name: 'paid_amount') num? paidAmount,@JsonKey(name: 'paid_method') String? paidMethod,@JsonKey(name: 'cash_entry_id') String? cashEntryId, String? notes,@JsonKey(name: 'installment_no') int? installmentNo,@JsonKey(name: 'installment_total') int? installmentTotal,@JsonKey(name: 'installment_group_id') String? installmentGroupId,@JsonKey(name: 'supplier_name') String? supplierName,@JsonKey(name: 'supplier_doc') String? supplierDoc, String status
});




}
/// @nodoc
class _$ExpenseCopyWithImpl<$Res>
    implements $ExpenseCopyWith<$Res> {
  _$ExpenseCopyWithImpl(this._self, this._then);

  final Expense _self;
  final $Res Function(Expense) _then;

/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? description = null,Object? amount = null,Object? dueDate = null,Object? categoryId = freezed,Object? recurrenceId = freezed,Object? paidAt = freezed,Object? paidAmount = freezed,Object? paidMethod = freezed,Object? cashEntryId = freezed,Object? notes = freezed,Object? installmentNo = freezed,Object? installmentTotal = freezed,Object? installmentGroupId = freezed,Object? supplierName = freezed,Object? supplierDoc = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,recurrenceId: freezed == recurrenceId ? _self.recurrenceId : recurrenceId // ignore: cast_nullable_to_non_nullable
as String?,paidAt: freezed == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as String?,paidAmount: freezed == paidAmount ? _self.paidAmount : paidAmount // ignore: cast_nullable_to_non_nullable
as num?,paidMethod: freezed == paidMethod ? _self.paidMethod : paidMethod // ignore: cast_nullable_to_non_nullable
as String?,cashEntryId: freezed == cashEntryId ? _self.cashEntryId : cashEntryId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,installmentNo: freezed == installmentNo ? _self.installmentNo : installmentNo // ignore: cast_nullable_to_non_nullable
as int?,installmentTotal: freezed == installmentTotal ? _self.installmentTotal : installmentTotal // ignore: cast_nullable_to_non_nullable
as int?,installmentGroupId: freezed == installmentGroupId ? _self.installmentGroupId : installmentGroupId // ignore: cast_nullable_to_non_nullable
as String?,supplierName: freezed == supplierName ? _self.supplierName : supplierName // ignore: cast_nullable_to_non_nullable
as String?,supplierDoc: freezed == supplierDoc ? _self.supplierDoc : supplierDoc // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Expense].
extension ExpensePatterns on Expense {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Expense value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Expense() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Expense value)  $default,){
final _that = this;
switch (_that) {
case _Expense():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Expense value)?  $default,){
final _that = this;
switch (_that) {
case _Expense() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String description, @_Decimal()  num amount, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'recurrence_id')  String? recurrenceId, @JsonKey(name: 'paid_at')  String? paidAt, @_DecimalOrNull()@JsonKey(name: 'paid_amount')  num? paidAmount, @JsonKey(name: 'paid_method')  String? paidMethod, @JsonKey(name: 'cash_entry_id')  String? cashEntryId,  String? notes, @JsonKey(name: 'installment_no')  int? installmentNo, @JsonKey(name: 'installment_total')  int? installmentTotal, @JsonKey(name: 'installment_group_id')  String? installmentGroupId, @JsonKey(name: 'supplier_name')  String? supplierName, @JsonKey(name: 'supplier_doc')  String? supplierDoc,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Expense() when $default != null:
return $default(_that.id,_that.description,_that.amount,_that.dueDate,_that.categoryId,_that.recurrenceId,_that.paidAt,_that.paidAmount,_that.paidMethod,_that.cashEntryId,_that.notes,_that.installmentNo,_that.installmentTotal,_that.installmentGroupId,_that.supplierName,_that.supplierDoc,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String description, @_Decimal()  num amount, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'recurrence_id')  String? recurrenceId, @JsonKey(name: 'paid_at')  String? paidAt, @_DecimalOrNull()@JsonKey(name: 'paid_amount')  num? paidAmount, @JsonKey(name: 'paid_method')  String? paidMethod, @JsonKey(name: 'cash_entry_id')  String? cashEntryId,  String? notes, @JsonKey(name: 'installment_no')  int? installmentNo, @JsonKey(name: 'installment_total')  int? installmentTotal, @JsonKey(name: 'installment_group_id')  String? installmentGroupId, @JsonKey(name: 'supplier_name')  String? supplierName, @JsonKey(name: 'supplier_doc')  String? supplierDoc,  String status)  $default,) {final _that = this;
switch (_that) {
case _Expense():
return $default(_that.id,_that.description,_that.amount,_that.dueDate,_that.categoryId,_that.recurrenceId,_that.paidAt,_that.paidAmount,_that.paidMethod,_that.cashEntryId,_that.notes,_that.installmentNo,_that.installmentTotal,_that.installmentGroupId,_that.supplierName,_that.supplierDoc,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String description, @_Decimal()  num amount, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'recurrence_id')  String? recurrenceId, @JsonKey(name: 'paid_at')  String? paidAt, @_DecimalOrNull()@JsonKey(name: 'paid_amount')  num? paidAmount, @JsonKey(name: 'paid_method')  String? paidMethod, @JsonKey(name: 'cash_entry_id')  String? cashEntryId,  String? notes, @JsonKey(name: 'installment_no')  int? installmentNo, @JsonKey(name: 'installment_total')  int? installmentTotal, @JsonKey(name: 'installment_group_id')  String? installmentGroupId, @JsonKey(name: 'supplier_name')  String? supplierName, @JsonKey(name: 'supplier_doc')  String? supplierDoc,  String status)?  $default,) {final _that = this;
switch (_that) {
case _Expense() when $default != null:
return $default(_that.id,_that.description,_that.amount,_that.dueDate,_that.categoryId,_that.recurrenceId,_that.paidAt,_that.paidAmount,_that.paidMethod,_that.cashEntryId,_that.notes,_that.installmentNo,_that.installmentTotal,_that.installmentGroupId,_that.supplierName,_that.supplierDoc,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Expense extends Expense {
  const _Expense({required this.id, this.description = '', @_Decimal() this.amount = 0, @JsonKey(name: 'due_date') required this.dueDate, @JsonKey(name: 'category_id') this.categoryId, @JsonKey(name: 'recurrence_id') this.recurrenceId, @JsonKey(name: 'paid_at') this.paidAt, @_DecimalOrNull()@JsonKey(name: 'paid_amount') this.paidAmount, @JsonKey(name: 'paid_method') this.paidMethod, @JsonKey(name: 'cash_entry_id') this.cashEntryId, this.notes, @JsonKey(name: 'installment_no') this.installmentNo, @JsonKey(name: 'installment_total') this.installmentTotal, @JsonKey(name: 'installment_group_id') this.installmentGroupId, @JsonKey(name: 'supplier_name') this.supplierName, @JsonKey(name: 'supplier_doc') this.supplierDoc, this.status = 'active'}): super._();
  factory _Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);

@override final  String id;
@override@JsonKey() final  String description;
/// 0 = "valor a confirmar" (a conta existe antes de o boleto chegar).
@override@JsonKey()@_Decimal() final  num amount;
/// Vencimento. O servidor devolve a linha crua do Prisma, então chega em ISO
/// completo (`2026-08-10T00:00:00.000Z`) mesmo sendo `date` no banco.
@override@JsonKey(name: 'due_date') final  String dueDate;
@override@JsonKey(name: 'category_id') final  String? categoryId;
@override@JsonKey(name: 'recurrence_id') final  String? recurrenceId;
/// Instante do pagamento. `null` = não paga — é o ÚNICO fato gravado sobre
/// pagamento; a situação sai daqui (ver [ExpenseStatus]).
@override@JsonKey(name: 'paid_at') final  String? paidAt;
/// Pode divergir de [amount] (juros, desconto): o que saiu é o que saiu.
@override@_DecimalOrNull()@JsonKey(name: 'paid_amount') final  num? paidAmount;
@override@JsonKey(name: 'paid_method') final  String? paidMethod;
/// Id do lançamento no Caixa gerado pela baixa. Só o ID (regra 1): este
/// módulo nunca lê a tabela do caixa.
@override@JsonKey(name: 'cash_entry_id') final  String? cashEntryId;
@override final  String? notes;
/// Parcelamento: qual parcela esta conta é, de quantas, e o grupo que junta
/// as irmãs. As três andam juntas (CHECK no banco) ou são todas nulas.
@override@JsonKey(name: 'installment_no') final  int? installmentNo;
@override@JsonKey(name: 'installment_total') final  int? installmentTotal;
@override@JsonKey(name: 'installment_group_id') final  String? installmentGroupId;
/// Fornecedor — retrato de quem cobrou, não FK para cadastro.
@override@JsonKey(name: 'supplier_name') final  String? supplierName;
/// Só dígitos (14 = CNPJ, 11 = CPF). Quem formata é a tela.
@override@JsonKey(name: 'supplier_doc') final  String? supplierDoc;
@override@JsonKey() final  String status;

/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseCopyWith<_Expense> get copyWith => __$ExpenseCopyWithImpl<_Expense>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Expense&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.recurrenceId, recurrenceId) || other.recurrenceId == recurrenceId)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt)&&(identical(other.paidAmount, paidAmount) || other.paidAmount == paidAmount)&&(identical(other.paidMethod, paidMethod) || other.paidMethod == paidMethod)&&(identical(other.cashEntryId, cashEntryId) || other.cashEntryId == cashEntryId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.installmentNo, installmentNo) || other.installmentNo == installmentNo)&&(identical(other.installmentTotal, installmentTotal) || other.installmentTotal == installmentTotal)&&(identical(other.installmentGroupId, installmentGroupId) || other.installmentGroupId == installmentGroupId)&&(identical(other.supplierName, supplierName) || other.supplierName == supplierName)&&(identical(other.supplierDoc, supplierDoc) || other.supplierDoc == supplierDoc)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description,amount,dueDate,categoryId,recurrenceId,paidAt,paidAmount,paidMethod,cashEntryId,notes,installmentNo,installmentTotal,installmentGroupId,supplierName,supplierDoc,status);

@override
String toString() {
  return 'Expense(id: $id, description: $description, amount: $amount, dueDate: $dueDate, categoryId: $categoryId, recurrenceId: $recurrenceId, paidAt: $paidAt, paidAmount: $paidAmount, paidMethod: $paidMethod, cashEntryId: $cashEntryId, notes: $notes, installmentNo: $installmentNo, installmentTotal: $installmentTotal, installmentGroupId: $installmentGroupId, supplierName: $supplierName, supplierDoc: $supplierDoc, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ExpenseCopyWith<$Res> implements $ExpenseCopyWith<$Res> {
  factory _$ExpenseCopyWith(_Expense value, $Res Function(_Expense) _then) = __$ExpenseCopyWithImpl;
@override @useResult
$Res call({
 String id, String description,@_Decimal() num amount,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'category_id') String? categoryId,@JsonKey(name: 'recurrence_id') String? recurrenceId,@JsonKey(name: 'paid_at') String? paidAt,@_DecimalOrNull()@JsonKey(name: 'paid_amount') num? paidAmount,@JsonKey(name: 'paid_method') String? paidMethod,@JsonKey(name: 'cash_entry_id') String? cashEntryId, String? notes,@JsonKey(name: 'installment_no') int? installmentNo,@JsonKey(name: 'installment_total') int? installmentTotal,@JsonKey(name: 'installment_group_id') String? installmentGroupId,@JsonKey(name: 'supplier_name') String? supplierName,@JsonKey(name: 'supplier_doc') String? supplierDoc, String status
});




}
/// @nodoc
class __$ExpenseCopyWithImpl<$Res>
    implements _$ExpenseCopyWith<$Res> {
  __$ExpenseCopyWithImpl(this._self, this._then);

  final _Expense _self;
  final $Res Function(_Expense) _then;

/// Create a copy of Expense
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? description = null,Object? amount = null,Object? dueDate = null,Object? categoryId = freezed,Object? recurrenceId = freezed,Object? paidAt = freezed,Object? paidAmount = freezed,Object? paidMethod = freezed,Object? cashEntryId = freezed,Object? notes = freezed,Object? installmentNo = freezed,Object? installmentTotal = freezed,Object? installmentGroupId = freezed,Object? supplierName = freezed,Object? supplierDoc = freezed,Object? status = null,}) {
  return _then(_Expense(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,recurrenceId: freezed == recurrenceId ? _self.recurrenceId : recurrenceId // ignore: cast_nullable_to_non_nullable
as String?,paidAt: freezed == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as String?,paidAmount: freezed == paidAmount ? _self.paidAmount : paidAmount // ignore: cast_nullable_to_non_nullable
as num?,paidMethod: freezed == paidMethod ? _self.paidMethod : paidMethod // ignore: cast_nullable_to_non_nullable
as String?,cashEntryId: freezed == cashEntryId ? _self.cashEntryId : cashEntryId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,installmentNo: freezed == installmentNo ? _self.installmentNo : installmentNo // ignore: cast_nullable_to_non_nullable
as int?,installmentTotal: freezed == installmentTotal ? _self.installmentTotal : installmentTotal // ignore: cast_nullable_to_non_nullable
as int?,installmentGroupId: freezed == installmentGroupId ? _self.installmentGroupId : installmentGroupId // ignore: cast_nullable_to_non_nullable
as String?,supplierName: freezed == supplierName ? _self.supplierName : supplierName // ignore: cast_nullable_to_non_nullable
as String?,supplierDoc: freezed == supplierDoc ? _self.supplierDoc : supplierDoc // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ExpenseRecurrence {

 String get id; String get description;@_Decimal() num get amount;@JsonKey(name: 'category_id') String? get categoryId;/// 'monthly' | 'yearly'
 String get frequency;@JsonKey(name: 'day_of_month') int get dayOfMonth;@JsonKey(name: 'month_of_year') int? get monthOfYear; String? get method; String? get notes;@JsonKey(name: 'ends_on') String? get endsOn; String get status;
/// Create a copy of ExpenseRecurrence
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseRecurrenceCopyWith<ExpenseRecurrence> get copyWith => _$ExpenseRecurrenceCopyWithImpl<ExpenseRecurrence>(this as ExpenseRecurrence, _$identity);

  /// Serializes this ExpenseRecurrence to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseRecurrence&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.dayOfMonth, dayOfMonth) || other.dayOfMonth == dayOfMonth)&&(identical(other.monthOfYear, monthOfYear) || other.monthOfYear == monthOfYear)&&(identical(other.method, method) || other.method == method)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.endsOn, endsOn) || other.endsOn == endsOn)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description,amount,categoryId,frequency,dayOfMonth,monthOfYear,method,notes,endsOn,status);

@override
String toString() {
  return 'ExpenseRecurrence(id: $id, description: $description, amount: $amount, categoryId: $categoryId, frequency: $frequency, dayOfMonth: $dayOfMonth, monthOfYear: $monthOfYear, method: $method, notes: $notes, endsOn: $endsOn, status: $status)';
}


}

/// @nodoc
abstract mixin class $ExpenseRecurrenceCopyWith<$Res>  {
  factory $ExpenseRecurrenceCopyWith(ExpenseRecurrence value, $Res Function(ExpenseRecurrence) _then) = _$ExpenseRecurrenceCopyWithImpl;
@useResult
$Res call({
 String id, String description,@_Decimal() num amount,@JsonKey(name: 'category_id') String? categoryId, String frequency,@JsonKey(name: 'day_of_month') int dayOfMonth,@JsonKey(name: 'month_of_year') int? monthOfYear, String? method, String? notes,@JsonKey(name: 'ends_on') String? endsOn, String status
});




}
/// @nodoc
class _$ExpenseRecurrenceCopyWithImpl<$Res>
    implements $ExpenseRecurrenceCopyWith<$Res> {
  _$ExpenseRecurrenceCopyWithImpl(this._self, this._then);

  final ExpenseRecurrence _self;
  final $Res Function(ExpenseRecurrence) _then;

/// Create a copy of ExpenseRecurrence
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? description = null,Object? amount = null,Object? categoryId = freezed,Object? frequency = null,Object? dayOfMonth = null,Object? monthOfYear = freezed,Object? method = freezed,Object? notes = freezed,Object? endsOn = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as String,dayOfMonth: null == dayOfMonth ? _self.dayOfMonth : dayOfMonth // ignore: cast_nullable_to_non_nullable
as int,monthOfYear: freezed == monthOfYear ? _self.monthOfYear : monthOfYear // ignore: cast_nullable_to_non_nullable
as int?,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,endsOn: freezed == endsOn ? _self.endsOn : endsOn // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseRecurrence].
extension ExpenseRecurrencePatterns on ExpenseRecurrence {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseRecurrence value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseRecurrence() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseRecurrence value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseRecurrence():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseRecurrence value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseRecurrence() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String description, @_Decimal()  num amount, @JsonKey(name: 'category_id')  String? categoryId,  String frequency, @JsonKey(name: 'day_of_month')  int dayOfMonth, @JsonKey(name: 'month_of_year')  int? monthOfYear,  String? method,  String? notes, @JsonKey(name: 'ends_on')  String? endsOn,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseRecurrence() when $default != null:
return $default(_that.id,_that.description,_that.amount,_that.categoryId,_that.frequency,_that.dayOfMonth,_that.monthOfYear,_that.method,_that.notes,_that.endsOn,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String description, @_Decimal()  num amount, @JsonKey(name: 'category_id')  String? categoryId,  String frequency, @JsonKey(name: 'day_of_month')  int dayOfMonth, @JsonKey(name: 'month_of_year')  int? monthOfYear,  String? method,  String? notes, @JsonKey(name: 'ends_on')  String? endsOn,  String status)  $default,) {final _that = this;
switch (_that) {
case _ExpenseRecurrence():
return $default(_that.id,_that.description,_that.amount,_that.categoryId,_that.frequency,_that.dayOfMonth,_that.monthOfYear,_that.method,_that.notes,_that.endsOn,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String description, @_Decimal()  num amount, @JsonKey(name: 'category_id')  String? categoryId,  String frequency, @JsonKey(name: 'day_of_month')  int dayOfMonth, @JsonKey(name: 'month_of_year')  int? monthOfYear,  String? method,  String? notes, @JsonKey(name: 'ends_on')  String? endsOn,  String status)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseRecurrence() when $default != null:
return $default(_that.id,_that.description,_that.amount,_that.categoryId,_that.frequency,_that.dayOfMonth,_that.monthOfYear,_that.method,_that.notes,_that.endsOn,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseRecurrence extends ExpenseRecurrence {
  const _ExpenseRecurrence({required this.id, this.description = '', @_Decimal() this.amount = 0, @JsonKey(name: 'category_id') this.categoryId, this.frequency = 'monthly', @JsonKey(name: 'day_of_month') this.dayOfMonth = 1, @JsonKey(name: 'month_of_year') this.monthOfYear, this.method, this.notes, @JsonKey(name: 'ends_on') this.endsOn, this.status = 'active'}): super._();
  factory _ExpenseRecurrence.fromJson(Map<String, dynamic> json) => _$ExpenseRecurrenceFromJson(json);

@override final  String id;
@override@JsonKey() final  String description;
@override@JsonKey()@_Decimal() final  num amount;
@override@JsonKey(name: 'category_id') final  String? categoryId;
/// 'monthly' | 'yearly'
@override@JsonKey() final  String frequency;
@override@JsonKey(name: 'day_of_month') final  int dayOfMonth;
@override@JsonKey(name: 'month_of_year') final  int? monthOfYear;
@override final  String? method;
@override final  String? notes;
@override@JsonKey(name: 'ends_on') final  String? endsOn;
@override@JsonKey() final  String status;

/// Create a copy of ExpenseRecurrence
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseRecurrenceCopyWith<_ExpenseRecurrence> get copyWith => __$ExpenseRecurrenceCopyWithImpl<_ExpenseRecurrence>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseRecurrenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseRecurrence&&(identical(other.id, id) || other.id == id)&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.dayOfMonth, dayOfMonth) || other.dayOfMonth == dayOfMonth)&&(identical(other.monthOfYear, monthOfYear) || other.monthOfYear == monthOfYear)&&(identical(other.method, method) || other.method == method)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.endsOn, endsOn) || other.endsOn == endsOn)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,description,amount,categoryId,frequency,dayOfMonth,monthOfYear,method,notes,endsOn,status);

@override
String toString() {
  return 'ExpenseRecurrence(id: $id, description: $description, amount: $amount, categoryId: $categoryId, frequency: $frequency, dayOfMonth: $dayOfMonth, monthOfYear: $monthOfYear, method: $method, notes: $notes, endsOn: $endsOn, status: $status)';
}


}

/// @nodoc
abstract mixin class _$ExpenseRecurrenceCopyWith<$Res> implements $ExpenseRecurrenceCopyWith<$Res> {
  factory _$ExpenseRecurrenceCopyWith(_ExpenseRecurrence value, $Res Function(_ExpenseRecurrence) _then) = __$ExpenseRecurrenceCopyWithImpl;
@override @useResult
$Res call({
 String id, String description,@_Decimal() num amount,@JsonKey(name: 'category_id') String? categoryId, String frequency,@JsonKey(name: 'day_of_month') int dayOfMonth,@JsonKey(name: 'month_of_year') int? monthOfYear, String? method, String? notes,@JsonKey(name: 'ends_on') String? endsOn, String status
});




}
/// @nodoc
class __$ExpenseRecurrenceCopyWithImpl<$Res>
    implements _$ExpenseRecurrenceCopyWith<$Res> {
  __$ExpenseRecurrenceCopyWithImpl(this._self, this._then);

  final _ExpenseRecurrence _self;
  final $Res Function(_ExpenseRecurrence) _then;

/// Create a copy of ExpenseRecurrence
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? description = null,Object? amount = null,Object? categoryId = freezed,Object? frequency = null,Object? dayOfMonth = null,Object? monthOfYear = freezed,Object? method = freezed,Object? notes = freezed,Object? endsOn = freezed,Object? status = null,}) {
  return _then(_ExpenseRecurrence(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as String,dayOfMonth: null == dayOfMonth ? _self.dayOfMonth : dayOfMonth // ignore: cast_nullable_to_non_nullable
as int,monthOfYear: freezed == monthOfYear ? _self.monthOfYear : monthOfYear // ignore: cast_nullable_to_non_nullable
as int?,method: freezed == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,endsOn: freezed == endsOn ? _self.endsOn : endsOn // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ExpenseDraft {

 String? get description; num? get amount; String? get dueDate; String? get categoryId; String? get notes;/// Recorrência pedida na criação; `null` = conta avulsa (uma vez só).
 ExpenseRecurrenceDraft? get recorrencia;/// Parcelamento pedido na criação. `amount` é o **TOTAL** — quem rateia é o
/// servidor. Excludente com [recorrencia].
 int? get parcelas;/// Uuids das parcelas, na ordem — só no caminho OFFLINE, para o replay não
/// criar um segundo conjunto de linhas. Ver [ExpensesRepository.criar].
 List<String>? get installmentIds; String? get installmentGroupId; String? get supplierName;/// Só dígitos; o servidor recusa tamanho diferente de 11 ou 14.
 String? get supplierDoc;/// Edição: limpar a categoria exige dizer explicitamente (ausência = "não
/// mexe", senão nunca daria para tirar uma categoria já gravada).
 bool get limparCategoria;/// Idem para o fornecedor.
 bool get limparFornecedor;
/// Create a copy of ExpenseDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseDraftCopyWith<ExpenseDraft> get copyWith => _$ExpenseDraftCopyWithImpl<ExpenseDraft>(this as ExpenseDraft, _$identity);

  /// Serializes this ExpenseDraft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseDraft&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.recorrencia, recorrencia) || other.recorrencia == recorrencia)&&(identical(other.parcelas, parcelas) || other.parcelas == parcelas)&&const DeepCollectionEquality().equals(other.installmentIds, installmentIds)&&(identical(other.installmentGroupId, installmentGroupId) || other.installmentGroupId == installmentGroupId)&&(identical(other.supplierName, supplierName) || other.supplierName == supplierName)&&(identical(other.supplierDoc, supplierDoc) || other.supplierDoc == supplierDoc)&&(identical(other.limparCategoria, limparCategoria) || other.limparCategoria == limparCategoria)&&(identical(other.limparFornecedor, limparFornecedor) || other.limparFornecedor == limparFornecedor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,description,amount,dueDate,categoryId,notes,recorrencia,parcelas,const DeepCollectionEquality().hash(installmentIds),installmentGroupId,supplierName,supplierDoc,limparCategoria,limparFornecedor);

@override
String toString() {
  return 'ExpenseDraft(description: $description, amount: $amount, dueDate: $dueDate, categoryId: $categoryId, notes: $notes, recorrencia: $recorrencia, parcelas: $parcelas, installmentIds: $installmentIds, installmentGroupId: $installmentGroupId, supplierName: $supplierName, supplierDoc: $supplierDoc, limparCategoria: $limparCategoria, limparFornecedor: $limparFornecedor)';
}


}

/// @nodoc
abstract mixin class $ExpenseDraftCopyWith<$Res>  {
  factory $ExpenseDraftCopyWith(ExpenseDraft value, $Res Function(ExpenseDraft) _then) = _$ExpenseDraftCopyWithImpl;
@useResult
$Res call({
 String? description, num? amount, String? dueDate, String? categoryId, String? notes, ExpenseRecurrenceDraft? recorrencia, int? parcelas, List<String>? installmentIds, String? installmentGroupId, String? supplierName, String? supplierDoc, bool limparCategoria, bool limparFornecedor
});


$ExpenseRecurrenceDraftCopyWith<$Res>? get recorrencia;

}
/// @nodoc
class _$ExpenseDraftCopyWithImpl<$Res>
    implements $ExpenseDraftCopyWith<$Res> {
  _$ExpenseDraftCopyWithImpl(this._self, this._then);

  final ExpenseDraft _self;
  final $Res Function(ExpenseDraft) _then;

/// Create a copy of ExpenseDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? description = freezed,Object? amount = freezed,Object? dueDate = freezed,Object? categoryId = freezed,Object? notes = freezed,Object? recorrencia = freezed,Object? parcelas = freezed,Object? installmentIds = freezed,Object? installmentGroupId = freezed,Object? supplierName = freezed,Object? supplierDoc = freezed,Object? limparCategoria = null,Object? limparFornecedor = null,}) {
  return _then(_self.copyWith(
description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,recorrencia: freezed == recorrencia ? _self.recorrencia : recorrencia // ignore: cast_nullable_to_non_nullable
as ExpenseRecurrenceDraft?,parcelas: freezed == parcelas ? _self.parcelas : parcelas // ignore: cast_nullable_to_non_nullable
as int?,installmentIds: freezed == installmentIds ? _self.installmentIds : installmentIds // ignore: cast_nullable_to_non_nullable
as List<String>?,installmentGroupId: freezed == installmentGroupId ? _self.installmentGroupId : installmentGroupId // ignore: cast_nullable_to_non_nullable
as String?,supplierName: freezed == supplierName ? _self.supplierName : supplierName // ignore: cast_nullable_to_non_nullable
as String?,supplierDoc: freezed == supplierDoc ? _self.supplierDoc : supplierDoc // ignore: cast_nullable_to_non_nullable
as String?,limparCategoria: null == limparCategoria ? _self.limparCategoria : limparCategoria // ignore: cast_nullable_to_non_nullable
as bool,limparFornecedor: null == limparFornecedor ? _self.limparFornecedor : limparFornecedor // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ExpenseDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseRecurrenceDraftCopyWith<$Res>? get recorrencia {
    if (_self.recorrencia == null) {
    return null;
  }

  return $ExpenseRecurrenceDraftCopyWith<$Res>(_self.recorrencia!, (value) {
    return _then(_self.copyWith(recorrencia: value));
  });
}
}


/// Adds pattern-matching-related methods to [ExpenseDraft].
extension ExpenseDraftPatterns on ExpenseDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseDraft value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseDraft value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? description,  num? amount,  String? dueDate,  String? categoryId,  String? notes,  ExpenseRecurrenceDraft? recorrencia,  int? parcelas,  List<String>? installmentIds,  String? installmentGroupId,  String? supplierName,  String? supplierDoc,  bool limparCategoria,  bool limparFornecedor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseDraft() when $default != null:
return $default(_that.description,_that.amount,_that.dueDate,_that.categoryId,_that.notes,_that.recorrencia,_that.parcelas,_that.installmentIds,_that.installmentGroupId,_that.supplierName,_that.supplierDoc,_that.limparCategoria,_that.limparFornecedor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? description,  num? amount,  String? dueDate,  String? categoryId,  String? notes,  ExpenseRecurrenceDraft? recorrencia,  int? parcelas,  List<String>? installmentIds,  String? installmentGroupId,  String? supplierName,  String? supplierDoc,  bool limparCategoria,  bool limparFornecedor)  $default,) {final _that = this;
switch (_that) {
case _ExpenseDraft():
return $default(_that.description,_that.amount,_that.dueDate,_that.categoryId,_that.notes,_that.recorrencia,_that.parcelas,_that.installmentIds,_that.installmentGroupId,_that.supplierName,_that.supplierDoc,_that.limparCategoria,_that.limparFornecedor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? description,  num? amount,  String? dueDate,  String? categoryId,  String? notes,  ExpenseRecurrenceDraft? recorrencia,  int? parcelas,  List<String>? installmentIds,  String? installmentGroupId,  String? supplierName,  String? supplierDoc,  bool limparCategoria,  bool limparFornecedor)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseDraft() when $default != null:
return $default(_that.description,_that.amount,_that.dueDate,_that.categoryId,_that.notes,_that.recorrencia,_that.parcelas,_that.installmentIds,_that.installmentGroupId,_that.supplierName,_that.supplierDoc,_that.limparCategoria,_that.limparFornecedor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseDraft implements ExpenseDraft {
  const _ExpenseDraft({this.description, this.amount, this.dueDate, this.categoryId, this.notes, this.recorrencia, this.parcelas, final  List<String>? installmentIds, this.installmentGroupId, this.supplierName, this.supplierDoc, this.limparCategoria = false, this.limparFornecedor = false}): _installmentIds = installmentIds;
  factory _ExpenseDraft.fromJson(Map<String, dynamic> json) => _$ExpenseDraftFromJson(json);

@override final  String? description;
@override final  num? amount;
@override final  String? dueDate;
@override final  String? categoryId;
@override final  String? notes;
/// Recorrência pedida na criação; `null` = conta avulsa (uma vez só).
@override final  ExpenseRecurrenceDraft? recorrencia;
/// Parcelamento pedido na criação. `amount` é o **TOTAL** — quem rateia é o
/// servidor. Excludente com [recorrencia].
@override final  int? parcelas;
/// Uuids das parcelas, na ordem — só no caminho OFFLINE, para o replay não
/// criar um segundo conjunto de linhas. Ver [ExpensesRepository.criar].
 final  List<String>? _installmentIds;
/// Uuids das parcelas, na ordem — só no caminho OFFLINE, para o replay não
/// criar um segundo conjunto de linhas. Ver [ExpensesRepository.criar].
@override List<String>? get installmentIds {
  final value = _installmentIds;
  if (value == null) return null;
  if (_installmentIds is EqualUnmodifiableListView) return _installmentIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? installmentGroupId;
@override final  String? supplierName;
/// Só dígitos; o servidor recusa tamanho diferente de 11 ou 14.
@override final  String? supplierDoc;
/// Edição: limpar a categoria exige dizer explicitamente (ausência = "não
/// mexe", senão nunca daria para tirar uma categoria já gravada).
@override@JsonKey() final  bool limparCategoria;
/// Idem para o fornecedor.
@override@JsonKey() final  bool limparFornecedor;

/// Create a copy of ExpenseDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseDraftCopyWith<_ExpenseDraft> get copyWith => __$ExpenseDraftCopyWithImpl<_ExpenseDraft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseDraftToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseDraft&&(identical(other.description, description) || other.description == description)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.recorrencia, recorrencia) || other.recorrencia == recorrencia)&&(identical(other.parcelas, parcelas) || other.parcelas == parcelas)&&const DeepCollectionEquality().equals(other._installmentIds, _installmentIds)&&(identical(other.installmentGroupId, installmentGroupId) || other.installmentGroupId == installmentGroupId)&&(identical(other.supplierName, supplierName) || other.supplierName == supplierName)&&(identical(other.supplierDoc, supplierDoc) || other.supplierDoc == supplierDoc)&&(identical(other.limparCategoria, limparCategoria) || other.limparCategoria == limparCategoria)&&(identical(other.limparFornecedor, limparFornecedor) || other.limparFornecedor == limparFornecedor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,description,amount,dueDate,categoryId,notes,recorrencia,parcelas,const DeepCollectionEquality().hash(_installmentIds),installmentGroupId,supplierName,supplierDoc,limparCategoria,limparFornecedor);

@override
String toString() {
  return 'ExpenseDraft(description: $description, amount: $amount, dueDate: $dueDate, categoryId: $categoryId, notes: $notes, recorrencia: $recorrencia, parcelas: $parcelas, installmentIds: $installmentIds, installmentGroupId: $installmentGroupId, supplierName: $supplierName, supplierDoc: $supplierDoc, limparCategoria: $limparCategoria, limparFornecedor: $limparFornecedor)';
}


}

/// @nodoc
abstract mixin class _$ExpenseDraftCopyWith<$Res> implements $ExpenseDraftCopyWith<$Res> {
  factory _$ExpenseDraftCopyWith(_ExpenseDraft value, $Res Function(_ExpenseDraft) _then) = __$ExpenseDraftCopyWithImpl;
@override @useResult
$Res call({
 String? description, num? amount, String? dueDate, String? categoryId, String? notes, ExpenseRecurrenceDraft? recorrencia, int? parcelas, List<String>? installmentIds, String? installmentGroupId, String? supplierName, String? supplierDoc, bool limparCategoria, bool limparFornecedor
});


@override $ExpenseRecurrenceDraftCopyWith<$Res>? get recorrencia;

}
/// @nodoc
class __$ExpenseDraftCopyWithImpl<$Res>
    implements _$ExpenseDraftCopyWith<$Res> {
  __$ExpenseDraftCopyWithImpl(this._self, this._then);

  final _ExpenseDraft _self;
  final $Res Function(_ExpenseDraft) _then;

/// Create a copy of ExpenseDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? description = freezed,Object? amount = freezed,Object? dueDate = freezed,Object? categoryId = freezed,Object? notes = freezed,Object? recorrencia = freezed,Object? parcelas = freezed,Object? installmentIds = freezed,Object? installmentGroupId = freezed,Object? supplierName = freezed,Object? supplierDoc = freezed,Object? limparCategoria = null,Object? limparFornecedor = null,}) {
  return _then(_ExpenseDraft(
description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,amount: freezed == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as num?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,recorrencia: freezed == recorrencia ? _self.recorrencia : recorrencia // ignore: cast_nullable_to_non_nullable
as ExpenseRecurrenceDraft?,parcelas: freezed == parcelas ? _self.parcelas : parcelas // ignore: cast_nullable_to_non_nullable
as int?,installmentIds: freezed == installmentIds ? _self._installmentIds : installmentIds // ignore: cast_nullable_to_non_nullable
as List<String>?,installmentGroupId: freezed == installmentGroupId ? _self.installmentGroupId : installmentGroupId // ignore: cast_nullable_to_non_nullable
as String?,supplierName: freezed == supplierName ? _self.supplierName : supplierName // ignore: cast_nullable_to_non_nullable
as String?,supplierDoc: freezed == supplierDoc ? _self.supplierDoc : supplierDoc // ignore: cast_nullable_to_non_nullable
as String?,limparCategoria: null == limparCategoria ? _self.limparCategoria : limparCategoria // ignore: cast_nullable_to_non_nullable
as bool,limparFornecedor: null == limparFornecedor ? _self.limparFornecedor : limparFornecedor // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ExpenseDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseRecurrenceDraftCopyWith<$Res>? get recorrencia {
    if (_self.recorrencia == null) {
    return null;
  }

  return $ExpenseRecurrenceDraftCopyWith<$Res>(_self.recorrencia!, (value) {
    return _then(_self.copyWith(recorrencia: value));
  });
}
}


/// @nodoc
mixin _$ExpenseRecurrenceDraft {

 String get frequency;@JsonKey(name: 'dayOfMonth') int get dayOfMonth;@JsonKey(name: 'monthOfYear') int? get monthOfYear;@JsonKey(name: 'endsOn') String? get endsOn;
/// Create a copy of ExpenseRecurrenceDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseRecurrenceDraftCopyWith<ExpenseRecurrenceDraft> get copyWith => _$ExpenseRecurrenceDraftCopyWithImpl<ExpenseRecurrenceDraft>(this as ExpenseRecurrenceDraft, _$identity);

  /// Serializes this ExpenseRecurrenceDraft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseRecurrenceDraft&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.dayOfMonth, dayOfMonth) || other.dayOfMonth == dayOfMonth)&&(identical(other.monthOfYear, monthOfYear) || other.monthOfYear == monthOfYear)&&(identical(other.endsOn, endsOn) || other.endsOn == endsOn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,frequency,dayOfMonth,monthOfYear,endsOn);

@override
String toString() {
  return 'ExpenseRecurrenceDraft(frequency: $frequency, dayOfMonth: $dayOfMonth, monthOfYear: $monthOfYear, endsOn: $endsOn)';
}


}

/// @nodoc
abstract mixin class $ExpenseRecurrenceDraftCopyWith<$Res>  {
  factory $ExpenseRecurrenceDraftCopyWith(ExpenseRecurrenceDraft value, $Res Function(ExpenseRecurrenceDraft) _then) = _$ExpenseRecurrenceDraftCopyWithImpl;
@useResult
$Res call({
 String frequency,@JsonKey(name: 'dayOfMonth') int dayOfMonth,@JsonKey(name: 'monthOfYear') int? monthOfYear,@JsonKey(name: 'endsOn') String? endsOn
});




}
/// @nodoc
class _$ExpenseRecurrenceDraftCopyWithImpl<$Res>
    implements $ExpenseRecurrenceDraftCopyWith<$Res> {
  _$ExpenseRecurrenceDraftCopyWithImpl(this._self, this._then);

  final ExpenseRecurrenceDraft _self;
  final $Res Function(ExpenseRecurrenceDraft) _then;

/// Create a copy of ExpenseRecurrenceDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? frequency = null,Object? dayOfMonth = null,Object? monthOfYear = freezed,Object? endsOn = freezed,}) {
  return _then(_self.copyWith(
frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as String,dayOfMonth: null == dayOfMonth ? _self.dayOfMonth : dayOfMonth // ignore: cast_nullable_to_non_nullable
as int,monthOfYear: freezed == monthOfYear ? _self.monthOfYear : monthOfYear // ignore: cast_nullable_to_non_nullable
as int?,endsOn: freezed == endsOn ? _self.endsOn : endsOn // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseRecurrenceDraft].
extension ExpenseRecurrenceDraftPatterns on ExpenseRecurrenceDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseRecurrenceDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseRecurrenceDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseRecurrenceDraft value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseRecurrenceDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseRecurrenceDraft value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseRecurrenceDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String frequency, @JsonKey(name: 'dayOfMonth')  int dayOfMonth, @JsonKey(name: 'monthOfYear')  int? monthOfYear, @JsonKey(name: 'endsOn')  String? endsOn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseRecurrenceDraft() when $default != null:
return $default(_that.frequency,_that.dayOfMonth,_that.monthOfYear,_that.endsOn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String frequency, @JsonKey(name: 'dayOfMonth')  int dayOfMonth, @JsonKey(name: 'monthOfYear')  int? monthOfYear, @JsonKey(name: 'endsOn')  String? endsOn)  $default,) {final _that = this;
switch (_that) {
case _ExpenseRecurrenceDraft():
return $default(_that.frequency,_that.dayOfMonth,_that.monthOfYear,_that.endsOn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String frequency, @JsonKey(name: 'dayOfMonth')  int dayOfMonth, @JsonKey(name: 'monthOfYear')  int? monthOfYear, @JsonKey(name: 'endsOn')  String? endsOn)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseRecurrenceDraft() when $default != null:
return $default(_that.frequency,_that.dayOfMonth,_that.monthOfYear,_that.endsOn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseRecurrenceDraft implements ExpenseRecurrenceDraft {
  const _ExpenseRecurrenceDraft({this.frequency = 'monthly', @JsonKey(name: 'dayOfMonth') this.dayOfMonth = 1, @JsonKey(name: 'monthOfYear') this.monthOfYear, @JsonKey(name: 'endsOn') this.endsOn});
  factory _ExpenseRecurrenceDraft.fromJson(Map<String, dynamic> json) => _$ExpenseRecurrenceDraftFromJson(json);

@override@JsonKey() final  String frequency;
@override@JsonKey(name: 'dayOfMonth') final  int dayOfMonth;
@override@JsonKey(name: 'monthOfYear') final  int? monthOfYear;
@override@JsonKey(name: 'endsOn') final  String? endsOn;

/// Create a copy of ExpenseRecurrenceDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseRecurrenceDraftCopyWith<_ExpenseRecurrenceDraft> get copyWith => __$ExpenseRecurrenceDraftCopyWithImpl<_ExpenseRecurrenceDraft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseRecurrenceDraftToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseRecurrenceDraft&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.dayOfMonth, dayOfMonth) || other.dayOfMonth == dayOfMonth)&&(identical(other.monthOfYear, monthOfYear) || other.monthOfYear == monthOfYear)&&(identical(other.endsOn, endsOn) || other.endsOn == endsOn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,frequency,dayOfMonth,monthOfYear,endsOn);

@override
String toString() {
  return 'ExpenseRecurrenceDraft(frequency: $frequency, dayOfMonth: $dayOfMonth, monthOfYear: $monthOfYear, endsOn: $endsOn)';
}


}

/// @nodoc
abstract mixin class _$ExpenseRecurrenceDraftCopyWith<$Res> implements $ExpenseRecurrenceDraftCopyWith<$Res> {
  factory _$ExpenseRecurrenceDraftCopyWith(_ExpenseRecurrenceDraft value, $Res Function(_ExpenseRecurrenceDraft) _then) = __$ExpenseRecurrenceDraftCopyWithImpl;
@override @useResult
$Res call({
 String frequency,@JsonKey(name: 'dayOfMonth') int dayOfMonth,@JsonKey(name: 'monthOfYear') int? monthOfYear,@JsonKey(name: 'endsOn') String? endsOn
});




}
/// @nodoc
class __$ExpenseRecurrenceDraftCopyWithImpl<$Res>
    implements _$ExpenseRecurrenceDraftCopyWith<$Res> {
  __$ExpenseRecurrenceDraftCopyWithImpl(this._self, this._then);

  final _ExpenseRecurrenceDraft _self;
  final $Res Function(_ExpenseRecurrenceDraft) _then;

/// Create a copy of ExpenseRecurrenceDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? frequency = null,Object? dayOfMonth = null,Object? monthOfYear = freezed,Object? endsOn = freezed,}) {
  return _then(_ExpenseRecurrenceDraft(
frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as String,dayOfMonth: null == dayOfMonth ? _self.dayOfMonth : dayOfMonth // ignore: cast_nullable_to_non_nullable
as int,monthOfYear: freezed == monthOfYear ? _self.monthOfYear : monthOfYear // ignore: cast_nullable_to_non_nullable
as int?,endsOn: freezed == endsOn ? _self.endsOn : endsOn // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ExpensesMonth {

 List<Expense> get items; List<ExpenseCategory> get categories;/// As REGRAS citadas pelas contas do mês. Sem elas a tela não teria como
/// dizer "próxima em 10/09" ao dar baixa numa conta fixa: a próxima
/// ocorrência é uma linha de OUTRO mês, ausente desta listagem.
 List<ExpenseRecurrence> get recurrences;/// Somas vêm do servidor: ele enxerga o mês inteiro mesmo se a lista for
/// paginada, e a conta de "quanto ainda devo" não pode depender do que
/// coube na tela.
@JsonKey(name: 'totalPrevisto') num get totalPrevisto;@JsonKey(name: 'totalPago') num get totalPago;@JsonKey(name: 'totalEmAberto') num get totalEmAberto;@JsonKey(name: 'totalVencido') num get totalVencido;
/// Create a copy of ExpensesMonth
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpensesMonthCopyWith<ExpensesMonth> get copyWith => _$ExpensesMonthCopyWithImpl<ExpensesMonth>(this as ExpensesMonth, _$identity);

  /// Serializes this ExpensesMonth to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpensesMonth&&const DeepCollectionEquality().equals(other.items, items)&&const DeepCollectionEquality().equals(other.categories, categories)&&const DeepCollectionEquality().equals(other.recurrences, recurrences)&&(identical(other.totalPrevisto, totalPrevisto) || other.totalPrevisto == totalPrevisto)&&(identical(other.totalPago, totalPago) || other.totalPago == totalPago)&&(identical(other.totalEmAberto, totalEmAberto) || other.totalEmAberto == totalEmAberto)&&(identical(other.totalVencido, totalVencido) || other.totalVencido == totalVencido));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),const DeepCollectionEquality().hash(categories),const DeepCollectionEquality().hash(recurrences),totalPrevisto,totalPago,totalEmAberto,totalVencido);

@override
String toString() {
  return 'ExpensesMonth(items: $items, categories: $categories, recurrences: $recurrences, totalPrevisto: $totalPrevisto, totalPago: $totalPago, totalEmAberto: $totalEmAberto, totalVencido: $totalVencido)';
}


}

/// @nodoc
abstract mixin class $ExpensesMonthCopyWith<$Res>  {
  factory $ExpensesMonthCopyWith(ExpensesMonth value, $Res Function(ExpensesMonth) _then) = _$ExpensesMonthCopyWithImpl;
@useResult
$Res call({
 List<Expense> items, List<ExpenseCategory> categories, List<ExpenseRecurrence> recurrences,@JsonKey(name: 'totalPrevisto') num totalPrevisto,@JsonKey(name: 'totalPago') num totalPago,@JsonKey(name: 'totalEmAberto') num totalEmAberto,@JsonKey(name: 'totalVencido') num totalVencido
});




}
/// @nodoc
class _$ExpensesMonthCopyWithImpl<$Res>
    implements $ExpensesMonthCopyWith<$Res> {
  _$ExpensesMonthCopyWithImpl(this._self, this._then);

  final ExpensesMonth _self;
  final $Res Function(ExpensesMonth) _then;

/// Create a copy of ExpensesMonth
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? categories = null,Object? recurrences = null,Object? totalPrevisto = null,Object? totalPago = null,Object? totalEmAberto = null,Object? totalVencido = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Expense>,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<ExpenseCategory>,recurrences: null == recurrences ? _self.recurrences : recurrences // ignore: cast_nullable_to_non_nullable
as List<ExpenseRecurrence>,totalPrevisto: null == totalPrevisto ? _self.totalPrevisto : totalPrevisto // ignore: cast_nullable_to_non_nullable
as num,totalPago: null == totalPago ? _self.totalPago : totalPago // ignore: cast_nullable_to_non_nullable
as num,totalEmAberto: null == totalEmAberto ? _self.totalEmAberto : totalEmAberto // ignore: cast_nullable_to_non_nullable
as num,totalVencido: null == totalVencido ? _self.totalVencido : totalVencido // ignore: cast_nullable_to_non_nullable
as num,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpensesMonth].
extension ExpensesMonthPatterns on ExpensesMonth {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpensesMonth value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpensesMonth() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpensesMonth value)  $default,){
final _that = this;
switch (_that) {
case _ExpensesMonth():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpensesMonth value)?  $default,){
final _that = this;
switch (_that) {
case _ExpensesMonth() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Expense> items,  List<ExpenseCategory> categories,  List<ExpenseRecurrence> recurrences, @JsonKey(name: 'totalPrevisto')  num totalPrevisto, @JsonKey(name: 'totalPago')  num totalPago, @JsonKey(name: 'totalEmAberto')  num totalEmAberto, @JsonKey(name: 'totalVencido')  num totalVencido)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpensesMonth() when $default != null:
return $default(_that.items,_that.categories,_that.recurrences,_that.totalPrevisto,_that.totalPago,_that.totalEmAberto,_that.totalVencido);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Expense> items,  List<ExpenseCategory> categories,  List<ExpenseRecurrence> recurrences, @JsonKey(name: 'totalPrevisto')  num totalPrevisto, @JsonKey(name: 'totalPago')  num totalPago, @JsonKey(name: 'totalEmAberto')  num totalEmAberto, @JsonKey(name: 'totalVencido')  num totalVencido)  $default,) {final _that = this;
switch (_that) {
case _ExpensesMonth():
return $default(_that.items,_that.categories,_that.recurrences,_that.totalPrevisto,_that.totalPago,_that.totalEmAberto,_that.totalVencido);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Expense> items,  List<ExpenseCategory> categories,  List<ExpenseRecurrence> recurrences, @JsonKey(name: 'totalPrevisto')  num totalPrevisto, @JsonKey(name: 'totalPago')  num totalPago, @JsonKey(name: 'totalEmAberto')  num totalEmAberto, @JsonKey(name: 'totalVencido')  num totalVencido)?  $default,) {final _that = this;
switch (_that) {
case _ExpensesMonth() when $default != null:
return $default(_that.items,_that.categories,_that.recurrences,_that.totalPrevisto,_that.totalPago,_that.totalEmAberto,_that.totalVencido);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpensesMonth implements ExpensesMonth {
  const _ExpensesMonth({final  List<Expense> items = const <Expense>[], final  List<ExpenseCategory> categories = const <ExpenseCategory>[], final  List<ExpenseRecurrence> recurrences = const <ExpenseRecurrence>[], @JsonKey(name: 'totalPrevisto') this.totalPrevisto = 0, @JsonKey(name: 'totalPago') this.totalPago = 0, @JsonKey(name: 'totalEmAberto') this.totalEmAberto = 0, @JsonKey(name: 'totalVencido') this.totalVencido = 0}): _items = items,_categories = categories,_recurrences = recurrences;
  factory _ExpensesMonth.fromJson(Map<String, dynamic> json) => _$ExpensesMonthFromJson(json);

 final  List<Expense> _items;
@override@JsonKey() List<Expense> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

 final  List<ExpenseCategory> _categories;
@override@JsonKey() List<ExpenseCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

/// As REGRAS citadas pelas contas do mês. Sem elas a tela não teria como
/// dizer "próxima em 10/09" ao dar baixa numa conta fixa: a próxima
/// ocorrência é uma linha de OUTRO mês, ausente desta listagem.
 final  List<ExpenseRecurrence> _recurrences;
/// As REGRAS citadas pelas contas do mês. Sem elas a tela não teria como
/// dizer "próxima em 10/09" ao dar baixa numa conta fixa: a próxima
/// ocorrência é uma linha de OUTRO mês, ausente desta listagem.
@override@JsonKey() List<ExpenseRecurrence> get recurrences {
  if (_recurrences is EqualUnmodifiableListView) return _recurrences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recurrences);
}

/// Somas vêm do servidor: ele enxerga o mês inteiro mesmo se a lista for
/// paginada, e a conta de "quanto ainda devo" não pode depender do que
/// coube na tela.
@override@JsonKey(name: 'totalPrevisto') final  num totalPrevisto;
@override@JsonKey(name: 'totalPago') final  num totalPago;
@override@JsonKey(name: 'totalEmAberto') final  num totalEmAberto;
@override@JsonKey(name: 'totalVencido') final  num totalVencido;

/// Create a copy of ExpensesMonth
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpensesMonthCopyWith<_ExpensesMonth> get copyWith => __$ExpensesMonthCopyWithImpl<_ExpensesMonth>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpensesMonthToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpensesMonth&&const DeepCollectionEquality().equals(other._items, _items)&&const DeepCollectionEquality().equals(other._categories, _categories)&&const DeepCollectionEquality().equals(other._recurrences, _recurrences)&&(identical(other.totalPrevisto, totalPrevisto) || other.totalPrevisto == totalPrevisto)&&(identical(other.totalPago, totalPago) || other.totalPago == totalPago)&&(identical(other.totalEmAberto, totalEmAberto) || other.totalEmAberto == totalEmAberto)&&(identical(other.totalVencido, totalVencido) || other.totalVencido == totalVencido));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),const DeepCollectionEquality().hash(_categories),const DeepCollectionEquality().hash(_recurrences),totalPrevisto,totalPago,totalEmAberto,totalVencido);

@override
String toString() {
  return 'ExpensesMonth(items: $items, categories: $categories, recurrences: $recurrences, totalPrevisto: $totalPrevisto, totalPago: $totalPago, totalEmAberto: $totalEmAberto, totalVencido: $totalVencido)';
}


}

/// @nodoc
abstract mixin class _$ExpensesMonthCopyWith<$Res> implements $ExpensesMonthCopyWith<$Res> {
  factory _$ExpensesMonthCopyWith(_ExpensesMonth value, $Res Function(_ExpensesMonth) _then) = __$ExpensesMonthCopyWithImpl;
@override @useResult
$Res call({
 List<Expense> items, List<ExpenseCategory> categories, List<ExpenseRecurrence> recurrences,@JsonKey(name: 'totalPrevisto') num totalPrevisto,@JsonKey(name: 'totalPago') num totalPago,@JsonKey(name: 'totalEmAberto') num totalEmAberto,@JsonKey(name: 'totalVencido') num totalVencido
});




}
/// @nodoc
class __$ExpensesMonthCopyWithImpl<$Res>
    implements _$ExpensesMonthCopyWith<$Res> {
  __$ExpensesMonthCopyWithImpl(this._self, this._then);

  final _ExpensesMonth _self;
  final $Res Function(_ExpensesMonth) _then;

/// Create a copy of ExpensesMonth
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? categories = null,Object? recurrences = null,Object? totalPrevisto = null,Object? totalPago = null,Object? totalEmAberto = null,Object? totalVencido = null,}) {
  return _then(_ExpensesMonth(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Expense>,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<ExpenseCategory>,recurrences: null == recurrences ? _self._recurrences : recurrences // ignore: cast_nullable_to_non_nullable
as List<ExpenseRecurrence>,totalPrevisto: null == totalPrevisto ? _self.totalPrevisto : totalPrevisto // ignore: cast_nullable_to_non_nullable
as num,totalPago: null == totalPago ? _self.totalPago : totalPago // ignore: cast_nullable_to_non_nullable
as num,totalEmAberto: null == totalEmAberto ? _self.totalEmAberto : totalEmAberto // ignore: cast_nullable_to_non_nullable
as num,totalVencido: null == totalVencido ? _self.totalVencido : totalVencido // ignore: cast_nullable_to_non_nullable
as num,
  ));
}


}


/// @nodoc
mixin _$ExpenseSupplierLookup {

/// Documento só com dígitos, como vai para o banco.
 String get doc;@JsonKey(name: 'razaoSocial') String get razaoSocial;@JsonKey(name: 'nomeFantasia') String? get nomeFantasia;/// "ATIVA", "BAIXADA"… A tela avisa quando não está ativa: pagar boleto de
/// empresa baixada é sinal de golpe.
 String? get situacao;
/// Create a copy of ExpenseSupplierLookup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseSupplierLookupCopyWith<ExpenseSupplierLookup> get copyWith => _$ExpenseSupplierLookupCopyWithImpl<ExpenseSupplierLookup>(this as ExpenseSupplierLookup, _$identity);

  /// Serializes this ExpenseSupplierLookup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseSupplierLookup&&(identical(other.doc, doc) || other.doc == doc)&&(identical(other.razaoSocial, razaoSocial) || other.razaoSocial == razaoSocial)&&(identical(other.nomeFantasia, nomeFantasia) || other.nomeFantasia == nomeFantasia)&&(identical(other.situacao, situacao) || other.situacao == situacao));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,doc,razaoSocial,nomeFantasia,situacao);

@override
String toString() {
  return 'ExpenseSupplierLookup(doc: $doc, razaoSocial: $razaoSocial, nomeFantasia: $nomeFantasia, situacao: $situacao)';
}


}

/// @nodoc
abstract mixin class $ExpenseSupplierLookupCopyWith<$Res>  {
  factory $ExpenseSupplierLookupCopyWith(ExpenseSupplierLookup value, $Res Function(ExpenseSupplierLookup) _then) = _$ExpenseSupplierLookupCopyWithImpl;
@useResult
$Res call({
 String doc,@JsonKey(name: 'razaoSocial') String razaoSocial,@JsonKey(name: 'nomeFantasia') String? nomeFantasia, String? situacao
});




}
/// @nodoc
class _$ExpenseSupplierLookupCopyWithImpl<$Res>
    implements $ExpenseSupplierLookupCopyWith<$Res> {
  _$ExpenseSupplierLookupCopyWithImpl(this._self, this._then);

  final ExpenseSupplierLookup _self;
  final $Res Function(ExpenseSupplierLookup) _then;

/// Create a copy of ExpenseSupplierLookup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? doc = null,Object? razaoSocial = null,Object? nomeFantasia = freezed,Object? situacao = freezed,}) {
  return _then(_self.copyWith(
doc: null == doc ? _self.doc : doc // ignore: cast_nullable_to_non_nullable
as String,razaoSocial: null == razaoSocial ? _self.razaoSocial : razaoSocial // ignore: cast_nullable_to_non_nullable
as String,nomeFantasia: freezed == nomeFantasia ? _self.nomeFantasia : nomeFantasia // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseSupplierLookup].
extension ExpenseSupplierLookupPatterns on ExpenseSupplierLookup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseSupplierLookup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseSupplierLookup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseSupplierLookup value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseSupplierLookup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseSupplierLookup value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseSupplierLookup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String doc, @JsonKey(name: 'razaoSocial')  String razaoSocial, @JsonKey(name: 'nomeFantasia')  String? nomeFantasia,  String? situacao)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseSupplierLookup() when $default != null:
return $default(_that.doc,_that.razaoSocial,_that.nomeFantasia,_that.situacao);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String doc, @JsonKey(name: 'razaoSocial')  String razaoSocial, @JsonKey(name: 'nomeFantasia')  String? nomeFantasia,  String? situacao)  $default,) {final _that = this;
switch (_that) {
case _ExpenseSupplierLookup():
return $default(_that.doc,_that.razaoSocial,_that.nomeFantasia,_that.situacao);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String doc, @JsonKey(name: 'razaoSocial')  String razaoSocial, @JsonKey(name: 'nomeFantasia')  String? nomeFantasia,  String? situacao)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseSupplierLookup() when $default != null:
return $default(_that.doc,_that.razaoSocial,_that.nomeFantasia,_that.situacao);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseSupplierLookup extends ExpenseSupplierLookup {
  const _ExpenseSupplierLookup({this.doc = '', @JsonKey(name: 'razaoSocial') this.razaoSocial = '', @JsonKey(name: 'nomeFantasia') this.nomeFantasia, this.situacao}): super._();
  factory _ExpenseSupplierLookup.fromJson(Map<String, dynamic> json) => _$ExpenseSupplierLookupFromJson(json);

/// Documento só com dígitos, como vai para o banco.
@override@JsonKey() final  String doc;
@override@JsonKey(name: 'razaoSocial') final  String razaoSocial;
@override@JsonKey(name: 'nomeFantasia') final  String? nomeFantasia;
/// "ATIVA", "BAIXADA"… A tela avisa quando não está ativa: pagar boleto de
/// empresa baixada é sinal de golpe.
@override final  String? situacao;

/// Create a copy of ExpenseSupplierLookup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseSupplierLookupCopyWith<_ExpenseSupplierLookup> get copyWith => __$ExpenseSupplierLookupCopyWithImpl<_ExpenseSupplierLookup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseSupplierLookupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseSupplierLookup&&(identical(other.doc, doc) || other.doc == doc)&&(identical(other.razaoSocial, razaoSocial) || other.razaoSocial == razaoSocial)&&(identical(other.nomeFantasia, nomeFantasia) || other.nomeFantasia == nomeFantasia)&&(identical(other.situacao, situacao) || other.situacao == situacao));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,doc,razaoSocial,nomeFantasia,situacao);

@override
String toString() {
  return 'ExpenseSupplierLookup(doc: $doc, razaoSocial: $razaoSocial, nomeFantasia: $nomeFantasia, situacao: $situacao)';
}


}

/// @nodoc
abstract mixin class _$ExpenseSupplierLookupCopyWith<$Res> implements $ExpenseSupplierLookupCopyWith<$Res> {
  factory _$ExpenseSupplierLookupCopyWith(_ExpenseSupplierLookup value, $Res Function(_ExpenseSupplierLookup) _then) = __$ExpenseSupplierLookupCopyWithImpl;
@override @useResult
$Res call({
 String doc,@JsonKey(name: 'razaoSocial') String razaoSocial,@JsonKey(name: 'nomeFantasia') String? nomeFantasia, String? situacao
});




}
/// @nodoc
class __$ExpenseSupplierLookupCopyWithImpl<$Res>
    implements _$ExpenseSupplierLookupCopyWith<$Res> {
  __$ExpenseSupplierLookupCopyWithImpl(this._self, this._then);

  final _ExpenseSupplierLookup _self;
  final $Res Function(_ExpenseSupplierLookup) _then;

/// Create a copy of ExpenseSupplierLookup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? doc = null,Object? razaoSocial = null,Object? nomeFantasia = freezed,Object? situacao = freezed,}) {
  return _then(_ExpenseSupplierLookup(
doc: null == doc ? _self.doc : doc // ignore: cast_nullable_to_non_nullable
as String,razaoSocial: null == razaoSocial ? _self.razaoSocial : razaoSocial // ignore: cast_nullable_to_non_nullable
as String,nomeFantasia: freezed == nomeFantasia ? _self.nomeFantasia : nomeFantasia // ignore: cast_nullable_to_non_nullable
as String?,situacao: freezed == situacao ? _self.situacao : situacao // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ExpenseDetail {

 Expense get expense;/// A regra que gerou a conta (`null` quando avulsa ou parcelada).
 ExpenseRecurrence? get recurrence;/// As irmãs do parcelamento, em ordem. Vazio quando não é parcelada.
 List<Expense> get parcelas;
/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseDetailCopyWith<ExpenseDetail> get copyWith => _$ExpenseDetailCopyWithImpl<ExpenseDetail>(this as ExpenseDetail, _$identity);

  /// Serializes this ExpenseDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseDetail&&(identical(other.expense, expense) || other.expense == expense)&&(identical(other.recurrence, recurrence) || other.recurrence == recurrence)&&const DeepCollectionEquality().equals(other.parcelas, parcelas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,expense,recurrence,const DeepCollectionEquality().hash(parcelas));

@override
String toString() {
  return 'ExpenseDetail(expense: $expense, recurrence: $recurrence, parcelas: $parcelas)';
}


}

/// @nodoc
abstract mixin class $ExpenseDetailCopyWith<$Res>  {
  factory $ExpenseDetailCopyWith(ExpenseDetail value, $Res Function(ExpenseDetail) _then) = _$ExpenseDetailCopyWithImpl;
@useResult
$Res call({
 Expense expense, ExpenseRecurrence? recurrence, List<Expense> parcelas
});


$ExpenseCopyWith<$Res> get expense;$ExpenseRecurrenceCopyWith<$Res>? get recurrence;

}
/// @nodoc
class _$ExpenseDetailCopyWithImpl<$Res>
    implements $ExpenseDetailCopyWith<$Res> {
  _$ExpenseDetailCopyWithImpl(this._self, this._then);

  final ExpenseDetail _self;
  final $Res Function(ExpenseDetail) _then;

/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? expense = null,Object? recurrence = freezed,Object? parcelas = null,}) {
  return _then(_self.copyWith(
expense: null == expense ? _self.expense : expense // ignore: cast_nullable_to_non_nullable
as Expense,recurrence: freezed == recurrence ? _self.recurrence : recurrence // ignore: cast_nullable_to_non_nullable
as ExpenseRecurrence?,parcelas: null == parcelas ? _self.parcelas : parcelas // ignore: cast_nullable_to_non_nullable
as List<Expense>,
  ));
}
/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseCopyWith<$Res> get expense {
  
  return $ExpenseCopyWith<$Res>(_self.expense, (value) {
    return _then(_self.copyWith(expense: value));
  });
}/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseRecurrenceCopyWith<$Res>? get recurrence {
    if (_self.recurrence == null) {
    return null;
  }

  return $ExpenseRecurrenceCopyWith<$Res>(_self.recurrence!, (value) {
    return _then(_self.copyWith(recurrence: value));
  });
}
}


/// Adds pattern-matching-related methods to [ExpenseDetail].
extension ExpenseDetailPatterns on ExpenseDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseDetail value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseDetail value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Expense expense,  ExpenseRecurrence? recurrence,  List<Expense> parcelas)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseDetail() when $default != null:
return $default(_that.expense,_that.recurrence,_that.parcelas);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Expense expense,  ExpenseRecurrence? recurrence,  List<Expense> parcelas)  $default,) {final _that = this;
switch (_that) {
case _ExpenseDetail():
return $default(_that.expense,_that.recurrence,_that.parcelas);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Expense expense,  ExpenseRecurrence? recurrence,  List<Expense> parcelas)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseDetail() when $default != null:
return $default(_that.expense,_that.recurrence,_that.parcelas);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseDetail extends ExpenseDetail {
  const _ExpenseDetail({required this.expense, this.recurrence, final  List<Expense> parcelas = const <Expense>[]}): _parcelas = parcelas,super._();
  factory _ExpenseDetail.fromJson(Map<String, dynamic> json) => _$ExpenseDetailFromJson(json);

@override final  Expense expense;
/// A regra que gerou a conta (`null` quando avulsa ou parcelada).
@override final  ExpenseRecurrence? recurrence;
/// As irmãs do parcelamento, em ordem. Vazio quando não é parcelada.
 final  List<Expense> _parcelas;
/// As irmãs do parcelamento, em ordem. Vazio quando não é parcelada.
@override@JsonKey() List<Expense> get parcelas {
  if (_parcelas is EqualUnmodifiableListView) return _parcelas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parcelas);
}


/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseDetailCopyWith<_ExpenseDetail> get copyWith => __$ExpenseDetailCopyWithImpl<_ExpenseDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseDetail&&(identical(other.expense, expense) || other.expense == expense)&&(identical(other.recurrence, recurrence) || other.recurrence == recurrence)&&const DeepCollectionEquality().equals(other._parcelas, _parcelas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,expense,recurrence,const DeepCollectionEquality().hash(_parcelas));

@override
String toString() {
  return 'ExpenseDetail(expense: $expense, recurrence: $recurrence, parcelas: $parcelas)';
}


}

/// @nodoc
abstract mixin class _$ExpenseDetailCopyWith<$Res> implements $ExpenseDetailCopyWith<$Res> {
  factory _$ExpenseDetailCopyWith(_ExpenseDetail value, $Res Function(_ExpenseDetail) _then) = __$ExpenseDetailCopyWithImpl;
@override @useResult
$Res call({
 Expense expense, ExpenseRecurrence? recurrence, List<Expense> parcelas
});


@override $ExpenseCopyWith<$Res> get expense;@override $ExpenseRecurrenceCopyWith<$Res>? get recurrence;

}
/// @nodoc
class __$ExpenseDetailCopyWithImpl<$Res>
    implements _$ExpenseDetailCopyWith<$Res> {
  __$ExpenseDetailCopyWithImpl(this._self, this._then);

  final _ExpenseDetail _self;
  final $Res Function(_ExpenseDetail) _then;

/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? expense = null,Object? recurrence = freezed,Object? parcelas = null,}) {
  return _then(_ExpenseDetail(
expense: null == expense ? _self.expense : expense // ignore: cast_nullable_to_non_nullable
as Expense,recurrence: freezed == recurrence ? _self.recurrence : recurrence // ignore: cast_nullable_to_non_nullable
as ExpenseRecurrence?,parcelas: null == parcelas ? _self._parcelas : parcelas // ignore: cast_nullable_to_non_nullable
as List<Expense>,
  ));
}

/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseCopyWith<$Res> get expense {
  
  return $ExpenseCopyWith<$Res>(_self.expense, (value) {
    return _then(_self.copyWith(expense: value));
  });
}/// Create a copy of ExpenseDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseRecurrenceCopyWith<$Res>? get recurrence {
    if (_self.recurrence == null) {
    return null;
  }

  return $ExpenseRecurrenceCopyWith<$Res>(_self.recurrence!, (value) {
    return _then(_self.copyWith(recurrence: value));
  });
}
}

// dart format on
