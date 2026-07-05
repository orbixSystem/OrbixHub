// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invoice_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Invoice {

 String get id;@JsonKey(name: 'document_type') String get documentType; String get status; String? get environment;@JsonKey(name: 'order_id') String? get orderId;@JsonKey(name: 'sale_id') String? get saleId;@JsonKey(name: 'order_number') String? get orderNumber;@JsonKey(name: 'customer_id') String? get customerId;@JsonKey(name: 'customer_name') String? get customerName;@JsonKey(name: 'customer_document') String? get customerDocument; String? get series; String? get number;@JsonKey(name: 'access_key') String? get accessKey;@JsonKey(name: 'service_amount') String? get serviceAmount;@JsonKey(name: 'product_amount') String? get productAmount;@JsonKey(name: 'total_amount') String? get totalAmount;@JsonKey(name: 'pdf_url') String? get pdfUrl;@JsonKey(name: 'xml_url') String? get xmlUrl;@JsonKey(name: 'rejection_reason') String? get rejectionReason;@JsonKey(name: 'authorized_at') String? get authorizedAt;@JsonKey(name: 'canceled_at') String? get canceledAt;@JsonKey(name: 'created_at') String? get createdAt;@JsonKey(name: 'updated_at') String? get updatedAt;// Preenchidos só em GET /invoices/:id (detalhe).
 List<InvoiceLine> get lines; List<InvoiceEvent> get events;
/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceCopyWith<Invoice> get copyWith => _$InvoiceCopyWithImpl<Invoice>(this as Invoice, _$identity);

  /// Serializes this Invoice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.documentType, documentType) || other.documentType == documentType)&&(identical(other.status, status) || other.status == status)&&(identical(other.environment, environment) || other.environment == environment)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerDocument, customerDocument) || other.customerDocument == customerDocument)&&(identical(other.series, series) || other.series == series)&&(identical(other.number, number) || other.number == number)&&(identical(other.accessKey, accessKey) || other.accessKey == accessKey)&&(identical(other.serviceAmount, serviceAmount) || other.serviceAmount == serviceAmount)&&(identical(other.productAmount, productAmount) || other.productAmount == productAmount)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.pdfUrl, pdfUrl) || other.pdfUrl == pdfUrl)&&(identical(other.xmlUrl, xmlUrl) || other.xmlUrl == xmlUrl)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason)&&(identical(other.authorizedAt, authorizedAt) || other.authorizedAt == authorizedAt)&&(identical(other.canceledAt, canceledAt) || other.canceledAt == canceledAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.lines, lines)&&const DeepCollectionEquality().equals(other.events, events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,documentType,status,environment,orderId,saleId,orderNumber,customerId,customerName,customerDocument,series,number,accessKey,serviceAmount,productAmount,totalAmount,pdfUrl,xmlUrl,rejectionReason,authorizedAt,canceledAt,createdAt,updatedAt,const DeepCollectionEquality().hash(lines),const DeepCollectionEquality().hash(events)]);

@override
String toString() {
  return 'Invoice(id: $id, documentType: $documentType, status: $status, environment: $environment, orderId: $orderId, saleId: $saleId, orderNumber: $orderNumber, customerId: $customerId, customerName: $customerName, customerDocument: $customerDocument, series: $series, number: $number, accessKey: $accessKey, serviceAmount: $serviceAmount, productAmount: $productAmount, totalAmount: $totalAmount, pdfUrl: $pdfUrl, xmlUrl: $xmlUrl, rejectionReason: $rejectionReason, authorizedAt: $authorizedAt, canceledAt: $canceledAt, createdAt: $createdAt, updatedAt: $updatedAt, lines: $lines, events: $events)';
}


}

/// @nodoc
abstract mixin class $InvoiceCopyWith<$Res>  {
  factory $InvoiceCopyWith(Invoice value, $Res Function(Invoice) _then) = _$InvoiceCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'document_type') String documentType, String status, String? environment,@JsonKey(name: 'order_id') String? orderId,@JsonKey(name: 'sale_id') String? saleId,@JsonKey(name: 'order_number') String? orderNumber,@JsonKey(name: 'customer_id') String? customerId,@JsonKey(name: 'customer_name') String? customerName,@JsonKey(name: 'customer_document') String? customerDocument, String? series, String? number,@JsonKey(name: 'access_key') String? accessKey,@JsonKey(name: 'service_amount') String? serviceAmount,@JsonKey(name: 'product_amount') String? productAmount,@JsonKey(name: 'total_amount') String? totalAmount,@JsonKey(name: 'pdf_url') String? pdfUrl,@JsonKey(name: 'xml_url') String? xmlUrl,@JsonKey(name: 'rejection_reason') String? rejectionReason,@JsonKey(name: 'authorized_at') String? authorizedAt,@JsonKey(name: 'canceled_at') String? canceledAt,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt, List<InvoiceLine> lines, List<InvoiceEvent> events
});




}
/// @nodoc
class _$InvoiceCopyWithImpl<$Res>
    implements $InvoiceCopyWith<$Res> {
  _$InvoiceCopyWithImpl(this._self, this._then);

  final Invoice _self;
  final $Res Function(Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? documentType = null,Object? status = null,Object? environment = freezed,Object? orderId = freezed,Object? saleId = freezed,Object? orderNumber = freezed,Object? customerId = freezed,Object? customerName = freezed,Object? customerDocument = freezed,Object? series = freezed,Object? number = freezed,Object? accessKey = freezed,Object? serviceAmount = freezed,Object? productAmount = freezed,Object? totalAmount = freezed,Object? pdfUrl = freezed,Object? xmlUrl = freezed,Object? rejectionReason = freezed,Object? authorizedAt = freezed,Object? canceledAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lines = null,Object? events = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,documentType: null == documentType ? _self.documentType : documentType // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,environment: freezed == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as String?,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String?,saleId: freezed == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as String?,orderNumber: freezed == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String?,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerDocument: freezed == customerDocument ? _self.customerDocument : customerDocument // ignore: cast_nullable_to_non_nullable
as String?,series: freezed == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as String?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String?,accessKey: freezed == accessKey ? _self.accessKey : accessKey // ignore: cast_nullable_to_non_nullable
as String?,serviceAmount: freezed == serviceAmount ? _self.serviceAmount : serviceAmount // ignore: cast_nullable_to_non_nullable
as String?,productAmount: freezed == productAmount ? _self.productAmount : productAmount // ignore: cast_nullable_to_non_nullable
as String?,totalAmount: freezed == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as String?,pdfUrl: freezed == pdfUrl ? _self.pdfUrl : pdfUrl // ignore: cast_nullable_to_non_nullable
as String?,xmlUrl: freezed == xmlUrl ? _self.xmlUrl : xmlUrl // ignore: cast_nullable_to_non_nullable
as String?,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,authorizedAt: freezed == authorizedAt ? _self.authorizedAt : authorizedAt // ignore: cast_nullable_to_non_nullable
as String?,canceledAt: freezed == canceledAt ? _self.canceledAt : canceledAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<InvoiceEvent>,
  ));
}

}


/// Adds pattern-matching-related methods to [Invoice].
extension InvoicePatterns on Invoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Invoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Invoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Invoice value)  $default,){
final _that = this;
switch (_that) {
case _Invoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Invoice value)?  $default,){
final _that = this;
switch (_that) {
case _Invoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'document_type')  String documentType,  String status,  String? environment, @JsonKey(name: 'order_id')  String? orderId, @JsonKey(name: 'sale_id')  String? saleId, @JsonKey(name: 'order_number')  String? orderNumber, @JsonKey(name: 'customer_id')  String? customerId, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'customer_document')  String? customerDocument,  String? series,  String? number, @JsonKey(name: 'access_key')  String? accessKey, @JsonKey(name: 'service_amount')  String? serviceAmount, @JsonKey(name: 'product_amount')  String? productAmount, @JsonKey(name: 'total_amount')  String? totalAmount, @JsonKey(name: 'pdf_url')  String? pdfUrl, @JsonKey(name: 'xml_url')  String? xmlUrl, @JsonKey(name: 'rejection_reason')  String? rejectionReason, @JsonKey(name: 'authorized_at')  String? authorizedAt, @JsonKey(name: 'canceled_at')  String? canceledAt, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt,  List<InvoiceLine> lines,  List<InvoiceEvent> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.documentType,_that.status,_that.environment,_that.orderId,_that.saleId,_that.orderNumber,_that.customerId,_that.customerName,_that.customerDocument,_that.series,_that.number,_that.accessKey,_that.serviceAmount,_that.productAmount,_that.totalAmount,_that.pdfUrl,_that.xmlUrl,_that.rejectionReason,_that.authorizedAt,_that.canceledAt,_that.createdAt,_that.updatedAt,_that.lines,_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'document_type')  String documentType,  String status,  String? environment, @JsonKey(name: 'order_id')  String? orderId, @JsonKey(name: 'sale_id')  String? saleId, @JsonKey(name: 'order_number')  String? orderNumber, @JsonKey(name: 'customer_id')  String? customerId, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'customer_document')  String? customerDocument,  String? series,  String? number, @JsonKey(name: 'access_key')  String? accessKey, @JsonKey(name: 'service_amount')  String? serviceAmount, @JsonKey(name: 'product_amount')  String? productAmount, @JsonKey(name: 'total_amount')  String? totalAmount, @JsonKey(name: 'pdf_url')  String? pdfUrl, @JsonKey(name: 'xml_url')  String? xmlUrl, @JsonKey(name: 'rejection_reason')  String? rejectionReason, @JsonKey(name: 'authorized_at')  String? authorizedAt, @JsonKey(name: 'canceled_at')  String? canceledAt, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt,  List<InvoiceLine> lines,  List<InvoiceEvent> events)  $default,) {final _that = this;
switch (_that) {
case _Invoice():
return $default(_that.id,_that.documentType,_that.status,_that.environment,_that.orderId,_that.saleId,_that.orderNumber,_that.customerId,_that.customerName,_that.customerDocument,_that.series,_that.number,_that.accessKey,_that.serviceAmount,_that.productAmount,_that.totalAmount,_that.pdfUrl,_that.xmlUrl,_that.rejectionReason,_that.authorizedAt,_that.canceledAt,_that.createdAt,_that.updatedAt,_that.lines,_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'document_type')  String documentType,  String status,  String? environment, @JsonKey(name: 'order_id')  String? orderId, @JsonKey(name: 'sale_id')  String? saleId, @JsonKey(name: 'order_number')  String? orderNumber, @JsonKey(name: 'customer_id')  String? customerId, @JsonKey(name: 'customer_name')  String? customerName, @JsonKey(name: 'customer_document')  String? customerDocument,  String? series,  String? number, @JsonKey(name: 'access_key')  String? accessKey, @JsonKey(name: 'service_amount')  String? serviceAmount, @JsonKey(name: 'product_amount')  String? productAmount, @JsonKey(name: 'total_amount')  String? totalAmount, @JsonKey(name: 'pdf_url')  String? pdfUrl, @JsonKey(name: 'xml_url')  String? xmlUrl, @JsonKey(name: 'rejection_reason')  String? rejectionReason, @JsonKey(name: 'authorized_at')  String? authorizedAt, @JsonKey(name: 'canceled_at')  String? canceledAt, @JsonKey(name: 'created_at')  String? createdAt, @JsonKey(name: 'updated_at')  String? updatedAt,  List<InvoiceLine> lines,  List<InvoiceEvent> events)?  $default,) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.documentType,_that.status,_that.environment,_that.orderId,_that.saleId,_that.orderNumber,_that.customerId,_that.customerName,_that.customerDocument,_that.series,_that.number,_that.accessKey,_that.serviceAmount,_that.productAmount,_that.totalAmount,_that.pdfUrl,_that.xmlUrl,_that.rejectionReason,_that.authorizedAt,_that.canceledAt,_that.createdAt,_that.updatedAt,_that.lines,_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Invoice implements Invoice {
  const _Invoice({required this.id, @JsonKey(name: 'document_type') this.documentType = 'nfse', this.status = 'draft', this.environment, @JsonKey(name: 'order_id') this.orderId, @JsonKey(name: 'sale_id') this.saleId, @JsonKey(name: 'order_number') this.orderNumber, @JsonKey(name: 'customer_id') this.customerId, @JsonKey(name: 'customer_name') this.customerName, @JsonKey(name: 'customer_document') this.customerDocument, this.series, this.number, @JsonKey(name: 'access_key') this.accessKey, @JsonKey(name: 'service_amount') this.serviceAmount, @JsonKey(name: 'product_amount') this.productAmount, @JsonKey(name: 'total_amount') this.totalAmount, @JsonKey(name: 'pdf_url') this.pdfUrl, @JsonKey(name: 'xml_url') this.xmlUrl, @JsonKey(name: 'rejection_reason') this.rejectionReason, @JsonKey(name: 'authorized_at') this.authorizedAt, @JsonKey(name: 'canceled_at') this.canceledAt, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, final  List<InvoiceLine> lines = const <InvoiceLine>[], final  List<InvoiceEvent> events = const <InvoiceEvent>[]}): _lines = lines,_events = events;
  factory _Invoice.fromJson(Map<String, dynamic> json) => _$InvoiceFromJson(json);

@override final  String id;
@override@JsonKey(name: 'document_type') final  String documentType;
@override@JsonKey() final  String status;
@override final  String? environment;
@override@JsonKey(name: 'order_id') final  String? orderId;
@override@JsonKey(name: 'sale_id') final  String? saleId;
@override@JsonKey(name: 'order_number') final  String? orderNumber;
@override@JsonKey(name: 'customer_id') final  String? customerId;
@override@JsonKey(name: 'customer_name') final  String? customerName;
@override@JsonKey(name: 'customer_document') final  String? customerDocument;
@override final  String? series;
@override final  String? number;
@override@JsonKey(name: 'access_key') final  String? accessKey;
@override@JsonKey(name: 'service_amount') final  String? serviceAmount;
@override@JsonKey(name: 'product_amount') final  String? productAmount;
@override@JsonKey(name: 'total_amount') final  String? totalAmount;
@override@JsonKey(name: 'pdf_url') final  String? pdfUrl;
@override@JsonKey(name: 'xml_url') final  String? xmlUrl;
@override@JsonKey(name: 'rejection_reason') final  String? rejectionReason;
@override@JsonKey(name: 'authorized_at') final  String? authorizedAt;
@override@JsonKey(name: 'canceled_at') final  String? canceledAt;
@override@JsonKey(name: 'created_at') final  String? createdAt;
@override@JsonKey(name: 'updated_at') final  String? updatedAt;
// Preenchidos só em GET /invoices/:id (detalhe).
 final  List<InvoiceLine> _lines;
// Preenchidos só em GET /invoices/:id (detalhe).
@override@JsonKey() List<InvoiceLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

 final  List<InvoiceEvent> _events;
@override@JsonKey() List<InvoiceEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceCopyWith<_Invoice> get copyWith => __$InvoiceCopyWithImpl<_Invoice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.documentType, documentType) || other.documentType == documentType)&&(identical(other.status, status) || other.status == status)&&(identical(other.environment, environment) || other.environment == environment)&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.saleId, saleId) || other.saleId == saleId)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerDocument, customerDocument) || other.customerDocument == customerDocument)&&(identical(other.series, series) || other.series == series)&&(identical(other.number, number) || other.number == number)&&(identical(other.accessKey, accessKey) || other.accessKey == accessKey)&&(identical(other.serviceAmount, serviceAmount) || other.serviceAmount == serviceAmount)&&(identical(other.productAmount, productAmount) || other.productAmount == productAmount)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.pdfUrl, pdfUrl) || other.pdfUrl == pdfUrl)&&(identical(other.xmlUrl, xmlUrl) || other.xmlUrl == xmlUrl)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason)&&(identical(other.authorizedAt, authorizedAt) || other.authorizedAt == authorizedAt)&&(identical(other.canceledAt, canceledAt) || other.canceledAt == canceledAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._lines, _lines)&&const DeepCollectionEquality().equals(other._events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,documentType,status,environment,orderId,saleId,orderNumber,customerId,customerName,customerDocument,series,number,accessKey,serviceAmount,productAmount,totalAmount,pdfUrl,xmlUrl,rejectionReason,authorizedAt,canceledAt,createdAt,updatedAt,const DeepCollectionEquality().hash(_lines),const DeepCollectionEquality().hash(_events)]);

@override
String toString() {
  return 'Invoice(id: $id, documentType: $documentType, status: $status, environment: $environment, orderId: $orderId, saleId: $saleId, orderNumber: $orderNumber, customerId: $customerId, customerName: $customerName, customerDocument: $customerDocument, series: $series, number: $number, accessKey: $accessKey, serviceAmount: $serviceAmount, productAmount: $productAmount, totalAmount: $totalAmount, pdfUrl: $pdfUrl, xmlUrl: $xmlUrl, rejectionReason: $rejectionReason, authorizedAt: $authorizedAt, canceledAt: $canceledAt, createdAt: $createdAt, updatedAt: $updatedAt, lines: $lines, events: $events)';
}


}

/// @nodoc
abstract mixin class _$InvoiceCopyWith<$Res> implements $InvoiceCopyWith<$Res> {
  factory _$InvoiceCopyWith(_Invoice value, $Res Function(_Invoice) _then) = __$InvoiceCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'document_type') String documentType, String status, String? environment,@JsonKey(name: 'order_id') String? orderId,@JsonKey(name: 'sale_id') String? saleId,@JsonKey(name: 'order_number') String? orderNumber,@JsonKey(name: 'customer_id') String? customerId,@JsonKey(name: 'customer_name') String? customerName,@JsonKey(name: 'customer_document') String? customerDocument, String? series, String? number,@JsonKey(name: 'access_key') String? accessKey,@JsonKey(name: 'service_amount') String? serviceAmount,@JsonKey(name: 'product_amount') String? productAmount,@JsonKey(name: 'total_amount') String? totalAmount,@JsonKey(name: 'pdf_url') String? pdfUrl,@JsonKey(name: 'xml_url') String? xmlUrl,@JsonKey(name: 'rejection_reason') String? rejectionReason,@JsonKey(name: 'authorized_at') String? authorizedAt,@JsonKey(name: 'canceled_at') String? canceledAt,@JsonKey(name: 'created_at') String? createdAt,@JsonKey(name: 'updated_at') String? updatedAt, List<InvoiceLine> lines, List<InvoiceEvent> events
});




}
/// @nodoc
class __$InvoiceCopyWithImpl<$Res>
    implements _$InvoiceCopyWith<$Res> {
  __$InvoiceCopyWithImpl(this._self, this._then);

  final _Invoice _self;
  final $Res Function(_Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? documentType = null,Object? status = null,Object? environment = freezed,Object? orderId = freezed,Object? saleId = freezed,Object? orderNumber = freezed,Object? customerId = freezed,Object? customerName = freezed,Object? customerDocument = freezed,Object? series = freezed,Object? number = freezed,Object? accessKey = freezed,Object? serviceAmount = freezed,Object? productAmount = freezed,Object? totalAmount = freezed,Object? pdfUrl = freezed,Object? xmlUrl = freezed,Object? rejectionReason = freezed,Object? authorizedAt = freezed,Object? canceledAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lines = null,Object? events = null,}) {
  return _then(_Invoice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,documentType: null == documentType ? _self.documentType : documentType // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,environment: freezed == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as String?,orderId: freezed == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String?,saleId: freezed == saleId ? _self.saleId : saleId // ignore: cast_nullable_to_non_nullable
as String?,orderNumber: freezed == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String?,customerId: freezed == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerDocument: freezed == customerDocument ? _self.customerDocument : customerDocument // ignore: cast_nullable_to_non_nullable
as String?,series: freezed == series ? _self.series : series // ignore: cast_nullable_to_non_nullable
as String?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String?,accessKey: freezed == accessKey ? _self.accessKey : accessKey // ignore: cast_nullable_to_non_nullable
as String?,serviceAmount: freezed == serviceAmount ? _self.serviceAmount : serviceAmount // ignore: cast_nullable_to_non_nullable
as String?,productAmount: freezed == productAmount ? _self.productAmount : productAmount // ignore: cast_nullable_to_non_nullable
as String?,totalAmount: freezed == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as String?,pdfUrl: freezed == pdfUrl ? _self.pdfUrl : pdfUrl // ignore: cast_nullable_to_non_nullable
as String?,xmlUrl: freezed == xmlUrl ? _self.xmlUrl : xmlUrl // ignore: cast_nullable_to_non_nullable
as String?,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,authorizedAt: freezed == authorizedAt ? _self.authorizedAt : authorizedAt // ignore: cast_nullable_to_non_nullable
as String?,canceledAt: freezed == canceledAt ? _self.canceledAt : canceledAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<InvoiceEvent>,
  ));
}


}


/// @nodoc
mixin _$InvoiceLine {

 String get kind;// 'product' | 'service'
 String get name; String get quantity;@JsonKey(name: 'unit_price') String get unitPrice; String get total;
/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceLineCopyWith<InvoiceLine> get copyWith => _$InvoiceLineCopyWithImpl<InvoiceLine>(this as InvoiceLine, _$identity);

  /// Serializes this InvoiceLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceLine&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,name,quantity,unitPrice,total);

@override
String toString() {
  return 'InvoiceLine(kind: $kind, name: $name, quantity: $quantity, unitPrice: $unitPrice, total: $total)';
}


}

/// @nodoc
abstract mixin class $InvoiceLineCopyWith<$Res>  {
  factory $InvoiceLineCopyWith(InvoiceLine value, $Res Function(InvoiceLine) _then) = _$InvoiceLineCopyWithImpl;
@useResult
$Res call({
 String kind, String name, String quantity,@JsonKey(name: 'unit_price') String unitPrice, String total
});




}
/// @nodoc
class _$InvoiceLineCopyWithImpl<$Res>
    implements $InvoiceLineCopyWith<$Res> {
  _$InvoiceLineCopyWithImpl(this._self, this._then);

  final InvoiceLine _self;
  final $Res Function(InvoiceLine) _then;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? total = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceLine].
extension InvoiceLinePatterns on InvoiceLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceLine value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceLine value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.kind,_that.name,_that.quantity,_that.unitPrice,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String total)  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine():
return $default(_that.kind,_that.name,_that.quantity,_that.unitPrice,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String name,  String quantity, @JsonKey(name: 'unit_price')  String unitPrice,  String total)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.kind,_that.name,_that.quantity,_that.unitPrice,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceLine implements InvoiceLine {
  const _InvoiceLine({this.kind = 'product', required this.name, this.quantity = '0', @JsonKey(name: 'unit_price') this.unitPrice = '0', this.total = '0'});
  factory _InvoiceLine.fromJson(Map<String, dynamic> json) => _$InvoiceLineFromJson(json);

@override@JsonKey() final  String kind;
// 'product' | 'service'
@override final  String name;
@override@JsonKey() final  String quantity;
@override@JsonKey(name: 'unit_price') final  String unitPrice;
@override@JsonKey() final  String total;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceLineCopyWith<_InvoiceLine> get copyWith => __$InvoiceLineCopyWithImpl<_InvoiceLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceLine&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,name,quantity,unitPrice,total);

@override
String toString() {
  return 'InvoiceLine(kind: $kind, name: $name, quantity: $quantity, unitPrice: $unitPrice, total: $total)';
}


}

/// @nodoc
abstract mixin class _$InvoiceLineCopyWith<$Res> implements $InvoiceLineCopyWith<$Res> {
  factory _$InvoiceLineCopyWith(_InvoiceLine value, $Res Function(_InvoiceLine) _then) = __$InvoiceLineCopyWithImpl;
@override @useResult
$Res call({
 String kind, String name, String quantity,@JsonKey(name: 'unit_price') String unitPrice, String total
});




}
/// @nodoc
class __$InvoiceLineCopyWithImpl<$Res>
    implements _$InvoiceLineCopyWith<$Res> {
  __$InvoiceLineCopyWithImpl(this._self, this._then);

  final _InvoiceLine _self;
  final $Res Function(_InvoiceLine) _then;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? total = null,}) {
  return _then(_InvoiceLine(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$InvoiceEvent {

 String get kind; String? get message;@JsonKey(name: 'status_snapshot') String? get statusSnapshot;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of InvoiceEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceEventCopyWith<InvoiceEvent> get copyWith => _$InvoiceEventCopyWithImpl<InvoiceEvent>(this as InvoiceEvent, _$identity);

  /// Serializes this InvoiceEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceEvent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message)&&(identical(other.statusSnapshot, statusSnapshot) || other.statusSnapshot == statusSnapshot)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,message,statusSnapshot,createdAt);

@override
String toString() {
  return 'InvoiceEvent(kind: $kind, message: $message, statusSnapshot: $statusSnapshot, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $InvoiceEventCopyWith<$Res>  {
  factory $InvoiceEventCopyWith(InvoiceEvent value, $Res Function(InvoiceEvent) _then) = _$InvoiceEventCopyWithImpl;
@useResult
$Res call({
 String kind, String? message,@JsonKey(name: 'status_snapshot') String? statusSnapshot,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$InvoiceEventCopyWithImpl<$Res>
    implements $InvoiceEventCopyWith<$Res> {
  _$InvoiceEventCopyWithImpl(this._self, this._then);

  final InvoiceEvent _self;
  final $Res Function(InvoiceEvent) _then;

/// Create a copy of InvoiceEvent
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


/// Adds pattern-matching-related methods to [InvoiceEvent].
extension InvoiceEventPatterns on InvoiceEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceEvent value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceEvent value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String? message, @JsonKey(name: 'status_snapshot')  String? statusSnapshot, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceEvent() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String? message, @JsonKey(name: 'status_snapshot')  String? statusSnapshot, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _InvoiceEvent():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String? message, @JsonKey(name: 'status_snapshot')  String? statusSnapshot, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceEvent() when $default != null:
return $default(_that.kind,_that.message,_that.statusSnapshot,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceEvent implements InvoiceEvent {
  const _InvoiceEvent({required this.kind, this.message, @JsonKey(name: 'status_snapshot') this.statusSnapshot, @JsonKey(name: 'created_at') this.createdAt});
  factory _InvoiceEvent.fromJson(Map<String, dynamic> json) => _$InvoiceEventFromJson(json);

@override final  String kind;
@override final  String? message;
@override@JsonKey(name: 'status_snapshot') final  String? statusSnapshot;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of InvoiceEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceEventCopyWith<_InvoiceEvent> get copyWith => __$InvoiceEventCopyWithImpl<_InvoiceEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceEvent&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message)&&(identical(other.statusSnapshot, statusSnapshot) || other.statusSnapshot == statusSnapshot)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,message,statusSnapshot,createdAt);

@override
String toString() {
  return 'InvoiceEvent(kind: $kind, message: $message, statusSnapshot: $statusSnapshot, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$InvoiceEventCopyWith<$Res> implements $InvoiceEventCopyWith<$Res> {
  factory _$InvoiceEventCopyWith(_InvoiceEvent value, $Res Function(_InvoiceEvent) _then) = __$InvoiceEventCopyWithImpl;
@override @useResult
$Res call({
 String kind, String? message,@JsonKey(name: 'status_snapshot') String? statusSnapshot,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$InvoiceEventCopyWithImpl<$Res>
    implements _$InvoiceEventCopyWith<$Res> {
  __$InvoiceEventCopyWithImpl(this._self, this._then);

  final _InvoiceEvent _self;
  final $Res Function(_InvoiceEvent) _then;

/// Create a copy of InvoiceEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? message = freezed,Object? statusSnapshot = freezed,Object? createdAt = freezed,}) {
  return _then(_InvoiceEvent(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,statusSnapshot: freezed == statusSnapshot ? _self.statusSnapshot : statusSnapshot // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$InvoicePage {

 List<Invoice> get items; int get total; int get page; int get pageSize;
/// Create a copy of InvoicePage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoicePageCopyWith<InvoicePage> get copyWith => _$InvoicePageCopyWithImpl<InvoicePage>(this as InvoicePage, _$identity);

  /// Serializes this InvoicePage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoicePage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,page,pageSize);

@override
String toString() {
  return 'InvoicePage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class $InvoicePageCopyWith<$Res>  {
  factory $InvoicePageCopyWith(InvoicePage value, $Res Function(InvoicePage) _then) = _$InvoicePageCopyWithImpl;
@useResult
$Res call({
 List<Invoice> items, int total, int page, int pageSize
});




}
/// @nodoc
class _$InvoicePageCopyWithImpl<$Res>
    implements $InvoicePageCopyWith<$Res> {
  _$InvoicePageCopyWithImpl(this._self, this._then);

  final InvoicePage _self;
  final $Res Function(InvoicePage) _then;

/// Create a copy of InvoicePage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Invoice>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoicePage].
extension InvoicePagePatterns on InvoicePage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoicePage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoicePage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoicePage value)  $default,){
final _that = this;
switch (_that) {
case _InvoicePage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoicePage value)?  $default,){
final _that = this;
switch (_that) {
case _InvoicePage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Invoice> items,  int total,  int page,  int pageSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoicePage() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Invoice> items,  int total,  int page,  int pageSize)  $default,) {final _that = this;
switch (_that) {
case _InvoicePage():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Invoice> items,  int total,  int page,  int pageSize)?  $default,) {final _that = this;
switch (_that) {
case _InvoicePage() when $default != null:
return $default(_that.items,_that.total,_that.page,_that.pageSize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoicePage implements InvoicePage {
  const _InvoicePage({final  List<Invoice> items = const <Invoice>[], this.total = 0, this.page = 1, this.pageSize = 20}): _items = items;
  factory _InvoicePage.fromJson(Map<String, dynamic> json) => _$InvoicePageFromJson(json);

 final  List<Invoice> _items;
@override@JsonKey() List<Invoice> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  int total;
@override@JsonKey() final  int page;
@override@JsonKey() final  int pageSize;

/// Create a copy of InvoicePage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoicePageCopyWith<_InvoicePage> get copyWith => __$InvoicePageCopyWithImpl<_InvoicePage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoicePageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoicePage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,page,pageSize);

@override
String toString() {
  return 'InvoicePage(items: $items, total: $total, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$InvoicePageCopyWith<$Res> implements $InvoicePageCopyWith<$Res> {
  factory _$InvoicePageCopyWith(_InvoicePage value, $Res Function(_InvoicePage) _then) = __$InvoicePageCopyWithImpl;
@override @useResult
$Res call({
 List<Invoice> items, int total, int page, int pageSize
});




}
/// @nodoc
class __$InvoicePageCopyWithImpl<$Res>
    implements _$InvoicePageCopyWith<$Res> {
  __$InvoicePageCopyWithImpl(this._self, this._then);

  final _InvoicePage _self;
  final $Res Function(_InvoicePage) _then;

/// Create a copy of InvoicePage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_InvoicePage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Invoice>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
