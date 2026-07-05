import 'package:freezed_annotation/freezed_annotation.dart';

part 'customers_models.freezed.dart';
part 'customers_models.g.dart';

/// Cliente (contato/pagador). Entidade genérica — sem termo de vertical.
@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    required String id,
    required String name,
    @Default('PF') String type,
    String? document,
    String? phone,
    String? email,
    String? address,
    String? notes,
    @Default('active') String status,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
}

/// Subject = o que recebe o serviço (genérico). O rótulo ("Veículo"/"Pet") e os
/// campos vêm da config, nunca hardcoded. `identifier` é a placa na oficina.
@freezed
abstract class Subject with _$Subject {
  const factory Subject({
    required String id,
    @JsonKey(name: 'customer_id') required String customerId,
    String? label,
    String? identifier,
    @Default(<String, dynamic>{}) Map<String, dynamic> attributes,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @Default('active') String status,
  }) = _Subject;

  factory Subject.fromJson(Map<String, dynamic> json) =>
      _$SubjectFromJson(json);
}

/// Rótulo dinâmico do subject (singular/plural).
@freezed
abstract class SubjectLabel with _$SubjectLabel {
  const factory SubjectLabel({
    @Default('Veículo') String singular,
    @Default('Veículos') String plural,
  }) = _SubjectLabel;

  factory SubjectLabel.fromJson(Map<String, dynamic> json) =>
      _$SubjectLabelFromJson(json);
}

/// Definição de um campo do formulário de subject (vem da config).
@freezed
abstract class SubjectFieldConfig with _$SubjectFieldConfig {
  const factory SubjectFieldConfig({
    required String chave,
    required String rotulo,
    @Default('text') String tipo, // 'text' | 'number'
    @Default(false) bool obrigatorio,
    String? fonte, // ex.: 'fipe.marcas' — null = campo manual
    String? dependeDe, // chave do campo do qual depende (cascata)
  }) = _SubjectFieldConfig;

  factory SubjectFieldConfig.fromJson(Map<String, dynamic> json) =>
      _$SubjectFieldConfigFromJson(json);
}

/// Config do módulo (rótulo/campos dinâmicos + flags), de `GET /customers/config`.
@freezed
abstract class CustomersConfig with _$CustomersConfig {
  const factory CustomersConfig({
    @Default(true) bool usaSubjects,
    @Default(SubjectLabel()) SubjectLabel subjectLabel,
    @Default(<SubjectFieldConfig>[]) List<SubjectFieldConfig> subjectFields,
    @Default(false) bool documentRequired,
  }) = _CustomersConfig;

  factory CustomersConfig.fromJson(Map<String, dynamic> json) =>
      _$CustomersConfigFromJson(json);
}

/// Uma entrada do histórico (ex.: uma OS). Vazio até a OS existir. `subjectId`/
/// `subjectLabel` indicam a qual veículo o evento pertence (timeline do cliente).
@freezed
abstract class SubjectHistoryEntry with _$SubjectHistoryEntry {
  const factory SubjectHistoryEntry({
    required String id,
    required String kind,
    required String title,
    required String status,
    required String occurredAt,
    String? subjectId,
    String? subjectLabel,
  }) = _SubjectHistoryEntry;

  factory SubjectHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$SubjectHistoryEntryFromJson(json);
}

/// Página de clientes (`GET /customers`).
@freezed
abstract class CustomerPage with _$CustomerPage {
  const factory CustomerPage({
    @Default(<Customer>[]) List<Customer> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _CustomerPage;

  factory CustomerPage.fromJson(Map<String, dynamic> json) =>
      _$CustomerPageFromJson(json);
}

/// Página de subjects (`GET /subjects`).
@freezed
abstract class SubjectPage with _$SubjectPage {
  const factory SubjectPage({
    @Default(<Subject>[]) List<Subject> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _SubjectPage;

  factory SubjectPage.fromJson(Map<String, dynamic> json) =>
      _$SubjectPageFromJson(json);
}

/// Draft de escrita de cliente (create/update). Só envia campos não-nulos.
class CustomerDraft {
  const CustomerDraft({
    this.name,
    this.type,
    this.document,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String? name;
  final String? type;
  final String? document;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (type != null) 'type': type,
        if (document != null) 'document': document,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (notes != null) 'notes': notes,
      };
}

/// Draft de escrita de subject (create/update).
class SubjectDraft {
  const SubjectDraft({this.label, this.identifier, this.attributes});

  final String? label;
  final String? identifier;
  final Map<String, dynamic>? attributes;

  Map<String, dynamic> toJson() => {
        if (label != null) 'label': label,
        if (identifier != null) 'identifier': identifier,
        if (attributes != null) 'attributes': attributes,
      };
}

/// Opção de autocomplete vinda de `GET /customers/lookups/:fonte`.
/// `value` é o texto salvo; `meta['codigo']` (quando houver) alimenta a cascata.
@freezed
abstract class LookupOption with _$LookupOption {
  const factory LookupOption({
    required String value,
    required String label,
    @Default(<String, dynamic>{}) Map<String, dynamic> meta,
  }) = _LookupOption;

  factory LookupOption.fromJson(Map<String, dynamic> json) =>
      _$LookupOptionFromJson(json);
}
