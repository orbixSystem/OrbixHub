import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice_models.freezed.dart';
part 'invoice_models.g.dart';

/// Nota fiscal (header). O módulo `invoice` é dono do próprio registro e
/// **aponta** para a OS e o cliente por id + snapshot ("aponta, não invade").
/// Valores monetários chegam do backend como STRING (decimal serializado) —
/// formatados na UI via `money(...)`. Campos em snake_case (contrato real).
@freezed
abstract class Invoice with _$Invoice {
  const factory Invoice({
    required String id,
    @JsonKey(name: 'document_type') @Default('nfse') String documentType,
    @Default('draft') String status,
    String? environment,
    @JsonKey(name: 'order_id') String? orderId,
    @JsonKey(name: 'sale_id') String? saleId,
    @JsonKey(name: 'order_number') String? orderNumber,
    @JsonKey(name: 'customer_id') String? customerId,
    @JsonKey(name: 'customer_name') String? customerName,
    @JsonKey(name: 'customer_document') String? customerDocument,
    String? series,
    String? number,
    @JsonKey(name: 'access_key') String? accessKey,
    @JsonKey(name: 'service_amount') String? serviceAmount,
    @JsonKey(name: 'product_amount') String? productAmount,
    @JsonKey(name: 'total_amount') String? totalAmount,
    @JsonKey(name: 'pdf_url') String? pdfUrl,
    @JsonKey(name: 'xml_url') String? xmlUrl,
    @JsonKey(name: 'rejection_reason') String? rejectionReason,
    @JsonKey(name: 'authorized_at') String? authorizedAt,
    @JsonKey(name: 'canceled_at') String? canceledAt,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
    // Preenchidos só em GET /invoices/:id (detalhe).
    @Default(<InvoiceLine>[]) List<InvoiceLine> lines,
    @Default(<InvoiceEvent>[]) List<InvoiceEvent> events,
  }) = _Invoice;

  factory Invoice.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFromJson(json);
}

/// Linha (item) da nota — snapshot da OS. `kind ∈ product|service`. Decimais
/// como String.
@freezed
abstract class InvoiceLine with _$InvoiceLine {
  const factory InvoiceLine({
    @Default('product') String kind, // 'product' | 'service'
    required String name,
    @Default('0') String quantity,
    @JsonKey(name: 'unit_price') @Default('0') String unitPrice,
    @Default('0') String total,
  }) = _InvoiceLine;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) =>
      _$InvoiceLineFromJson(json);
}

/// Evento da linha do tempo da nota (created/sent/authorized/rejected/error/
/// canceled/webhook…). `statusSnapshot` registra o status no momento.
@freezed
abstract class InvoiceEvent with _$InvoiceEvent {
  const factory InvoiceEvent({
    required String kind,
    String? message,
    @JsonKey(name: 'status_snapshot') String? statusSnapshot,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _InvoiceEvent;

  factory InvoiceEvent.fromJson(Map<String, dynamic> json) =>
      _$InvoiceEventFromJson(json);
}

/// Página de notas fiscais (`GET /invoices`). `page` é 1-based.
@freezed
abstract class InvoicePage with _$InvoicePage {
  const factory InvoicePage({
    @Default(<Invoice>[]) List<Invoice> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _InvoicePage;

  factory InvoicePage.fromJson(Map<String, dynamic> json) =>
      _$InvoicePageFromJson(json);
}
