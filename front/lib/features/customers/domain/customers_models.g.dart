// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customers_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Customer _$CustomerFromJson(Map<String, dynamic> json) => _Customer(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String? ?? 'PF',
  document: json['document'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  address: json['address'] as String?,
  notes: json['notes'] as String?,
  status: json['status'] as String? ?? 'active',
);

Map<String, dynamic> _$CustomerToJson(_Customer instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': instance.type,
  'document': instance.document,
  'phone': instance.phone,
  'email': instance.email,
  'address': instance.address,
  'notes': instance.notes,
  'status': instance.status,
};

_Subject _$SubjectFromJson(Map<String, dynamic> json) => _Subject(
  id: json['id'] as String,
  customerId: json['customer_id'] as String,
  label: json['label'] as String?,
  identifier: json['identifier'] as String?,
  attributes:
      json['attributes'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  status: json['status'] as String? ?? 'active',
);

Map<String, dynamic> _$SubjectToJson(_Subject instance) => <String, dynamic>{
  'id': instance.id,
  'customer_id': instance.customerId,
  'label': instance.label,
  'identifier': instance.identifier,
  'attributes': instance.attributes,
  'status': instance.status,
};

_SubjectLabel _$SubjectLabelFromJson(Map<String, dynamic> json) =>
    _SubjectLabel(
      singular: json['singular'] as String? ?? 'Veículo',
      plural: json['plural'] as String? ?? 'Veículos',
    );

Map<String, dynamic> _$SubjectLabelToJson(_SubjectLabel instance) =>
    <String, dynamic>{'singular': instance.singular, 'plural': instance.plural};

_SubjectFieldConfig _$SubjectFieldConfigFromJson(Map<String, dynamic> json) =>
    _SubjectFieldConfig(
      chave: json['chave'] as String,
      rotulo: json['rotulo'] as String,
      tipo: json['tipo'] as String? ?? 'text',
      obrigatorio: json['obrigatorio'] as bool? ?? false,
      fonte: json['fonte'] as String?,
      dependeDe: json['dependeDe'] as String?,
    );

Map<String, dynamic> _$SubjectFieldConfigToJson(_SubjectFieldConfig instance) =>
    <String, dynamic>{
      'chave': instance.chave,
      'rotulo': instance.rotulo,
      'tipo': instance.tipo,
      'obrigatorio': instance.obrigatorio,
      'fonte': instance.fonte,
      'dependeDe': instance.dependeDe,
    };

_CustomersConfig _$CustomersConfigFromJson(Map<String, dynamic> json) =>
    _CustomersConfig(
      usaSubjects: json['usaSubjects'] as bool? ?? true,
      subjectLabel: json['subjectLabel'] == null
          ? const SubjectLabel()
          : SubjectLabel.fromJson(json['subjectLabel'] as Map<String, dynamic>),
      subjectFields:
          (json['subjectFields'] as List<dynamic>?)
              ?.map(
                (e) => SubjectFieldConfig.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <SubjectFieldConfig>[],
      documentRequired: json['documentRequired'] as bool? ?? false,
    );

Map<String, dynamic> _$CustomersConfigToJson(_CustomersConfig instance) =>
    <String, dynamic>{
      'usaSubjects': instance.usaSubjects,
      'subjectLabel': instance.subjectLabel,
      'subjectFields': instance.subjectFields,
      'documentRequired': instance.documentRequired,
    };

_SubjectHistoryEntry _$SubjectHistoryEntryFromJson(Map<String, dynamic> json) =>
    _SubjectHistoryEntry(
      id: json['id'] as String,
      kind: json['kind'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      occurredAt: json['occurredAt'] as String,
      subjectId: json['subjectId'] as String?,
      subjectLabel: json['subjectLabel'] as String?,
    );

Map<String, dynamic> _$SubjectHistoryEntryToJson(
  _SubjectHistoryEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'title': instance.title,
  'status': instance.status,
  'occurredAt': instance.occurredAt,
  'subjectId': instance.subjectId,
  'subjectLabel': instance.subjectLabel,
};

_CustomerPage _$CustomerPageFromJson(Map<String, dynamic> json) =>
    _CustomerPage(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => Customer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Customer>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
    );

Map<String, dynamic> _$CustomerPageToJson(_CustomerPage instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };

_SubjectPage _$SubjectPageFromJson(Map<String, dynamic> json) => _SubjectPage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => Subject.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Subject>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$SubjectPageToJson(_SubjectPage instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };

_LookupOption _$LookupOptionFromJson(Map<String, dynamic> json) =>
    _LookupOption(
      value: json['value'] as String,
      label: json['label'] as String,
      meta: json['meta'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$LookupOptionToJson(_LookupOption instance) =>
    <String, dynamic>{
      'value': instance.value,
      'label': instance.label,
      'meta': instance.meta,
    };
