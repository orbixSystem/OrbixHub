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
  tipo: json['tipo'] as String?,
  marca: json['marca'] as String?,
  modelo: json['modelo'] as String?,
  numeroSerie: json['numero_serie'] as String?,
  attributes:
      json['attributes'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  photoUrl: json['photo_url'] as String?,
  status: json['status'] as String? ?? 'active',
  plateData: json['plate_data'] as Map<String, dynamic>?,
  plateDataAt: json['plate_data_at'] as String?,
);

Map<String, dynamic> _$SubjectToJson(_Subject instance) => <String, dynamic>{
  'id': instance.id,
  'customer_id': instance.customerId,
  'label': instance.label,
  'identifier': instance.identifier,
  'tipo': instance.tipo,
  'marca': instance.marca,
  'modelo': instance.modelo,
  'numero_serie': instance.numeroSerie,
  'attributes': instance.attributes,
  'photo_url': instance.photoUrl,
  'status': instance.status,
  'plate_data': instance.plateData,
  'plate_data_at': instance.plateDataAt,
};

_SubjectLabel _$SubjectLabelFromJson(Map<String, dynamic> json) =>
    _SubjectLabel(
      singular: json['singular'] as String? ?? 'Objeto',
      plural: json['plural'] as String? ?? 'Objetos',
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
      formato: json['formato'] as String?,
    );

Map<String, dynamic> _$SubjectFieldConfigToJson(_SubjectFieldConfig instance) =>
    <String, dynamic>{
      'chave': instance.chave,
      'rotulo': instance.rotulo,
      'tipo': instance.tipo,
      'obrigatorio': instance.obrigatorio,
      'fonte': instance.fonte,
      'dependeDe': instance.dependeDe,
      'formato': instance.formato,
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
      'subjectLabel': instance.subjectLabel.toJson(),
      'subjectFields': instance.subjectFields.map((e) => e.toJson()).toList(),
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
      'items': instance.items.map((e) => e.toJson()).toList(),
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
      'items': instance.items.map((e) => e.toJson()).toList(),
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

_PlateFipeRef _$PlateFipeRefFromJson(Map<String, dynamic> json) =>
    _PlateFipeRef(
      value: json['value'] as String,
      codigo: json['codigo'] as String?,
    );

Map<String, dynamic> _$PlateFipeRefToJson(_PlateFipeRef instance) =>
    <String, dynamic>{'value': instance.value, 'codigo': instance.codigo};

_PlateFipeMatch _$PlateFipeMatchFromJson(Map<String, dynamic> json) =>
    _PlateFipeMatch(
      marca: json['marca'] == null
          ? null
          : PlateFipeRef.fromJson(json['marca'] as Map<String, dynamic>),
      modelo: json['modelo'] == null
          ? null
          : PlateFipeRef.fromJson(json['modelo'] as Map<String, dynamic>),
      ano: json['ano'] == null
          ? null
          : PlateFipeRef.fromJson(json['ano'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PlateFipeMatchToJson(_PlateFipeMatch instance) =>
    <String, dynamic>{
      'marca': instance.marca?.toJson(),
      'modelo': instance.modelo?.toJson(),
      'ano': instance.ano?.toJson(),
    };

_PlateFipe _$PlateFipeFromJson(Map<String, dynamic> json) => _PlateFipe(
  codigoFipe: json['codigoFipe'] as String?,
  marca: json['marca'] as String?,
  modelo: json['modelo'] as String?,
  valor: json['valor'] as String?,
  combustivel: json['combustivel'] as String?,
  anoModelo: json['anoModelo'] as String?,
  mesReferencia: json['mesReferencia'] as String?,
  score: (json['score'] as num?)?.toInt(),
);

Map<String, dynamic> _$PlateFipeToJson(_PlateFipe instance) =>
    <String, dynamic>{
      'codigoFipe': instance.codigoFipe,
      'marca': instance.marca,
      'modelo': instance.modelo,
      'valor': instance.valor,
      'combustivel': instance.combustivel,
      'anoModelo': instance.anoModelo,
      'mesReferencia': instance.mesReferencia,
      'score': instance.score,
    };

_PlateQuota _$PlateQuotaFromJson(Map<String, dynamic> json) => _PlateQuota(
  period: json['period'] as String,
  used: (json['used'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  remaining: (json['remaining'] as num).toInt(),
  enabled: json['enabled'] as bool? ?? false,
);

Map<String, dynamic> _$PlateQuotaToJson(_PlateQuota instance) =>
    <String, dynamic>{
      'period': instance.period,
      'used': instance.used,
      'limit': instance.limit,
      'remaining': instance.remaining,
      'enabled': instance.enabled,
    };

_PlateInfo _$PlateInfoFromJson(Map<String, dynamic> json) => _PlateInfo(
  placa: json['placa'] as String,
  placaAlternativa: json['placaAlternativa'] as String?,
  marca: json['marca'] as String?,
  modelo: json['modelo'] as String?,
  marcaModelo: json['marcaModelo'] as String?,
  versao: json['versao'] as String?,
  ano: json['ano'] as String?,
  anoModelo: json['anoModelo'] as String?,
  cor: json['cor'] as String?,
  chassi: json['chassi'] as String?,
  municipio: json['municipio'] as String?,
  uf: json['uf'] as String?,
  situacao: json['situacao'] as String?,
  origem: json['origem'] as String?,
  combustivel: json['combustivel'] as String?,
  cilindradas: json['cilindradas'] as String?,
  especie: json['especie'] as String?,
  tipoVeiculo: json['tipoVeiculo'] as String?,
  passageiros: json['passageiros'] as String?,
  segmento: json['segmento'] as String?,
  nacionalidade: json['nacionalidade'] as String?,
  logoUrl: json['logoUrl'] as String?,
  consultadoEm: json['consultadoEm'] as String?,
  fipe: json['fipe'] == null
      ? null
      : PlateFipe.fromJson(json['fipe'] as Map<String, dynamic>),
  fipeTodos:
      (json['fipeTodos'] as List<dynamic>?)
          ?.map((e) => PlateFipe.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PlateFipe>[],
  fipeMatch: json['fipeMatch'] == null
      ? null
      : PlateFipeMatch.fromJson(json['fipeMatch'] as Map<String, dynamic>),
  extra:
      (json['extra'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  cached: json['cached'] as bool? ?? false,
  usage: json['usage'] == null
      ? null
      : PlateQuota.fromJson(json['usage'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PlateInfoToJson(_PlateInfo instance) =>
    <String, dynamic>{
      'placa': instance.placa,
      'placaAlternativa': instance.placaAlternativa,
      'marca': instance.marca,
      'modelo': instance.modelo,
      'marcaModelo': instance.marcaModelo,
      'versao': instance.versao,
      'ano': instance.ano,
      'anoModelo': instance.anoModelo,
      'cor': instance.cor,
      'chassi': instance.chassi,
      'municipio': instance.municipio,
      'uf': instance.uf,
      'situacao': instance.situacao,
      'origem': instance.origem,
      'combustivel': instance.combustivel,
      'cilindradas': instance.cilindradas,
      'especie': instance.especie,
      'tipoVeiculo': instance.tipoVeiculo,
      'passageiros': instance.passageiros,
      'segmento': instance.segmento,
      'nacionalidade': instance.nacionalidade,
      'logoUrl': instance.logoUrl,
      'consultadoEm': instance.consultadoEm,
      'fipe': instance.fipe?.toJson(),
      'fipeTodos': instance.fipeTodos.map((e) => e.toJson()).toList(),
      'fipeMatch': instance.fipeMatch?.toJson(),
      'extra': instance.extra,
      'cached': instance.cached,
      'usage': instance.usage?.toJson(),
    };

_CnpjEmpresa _$CnpjEmpresaFromJson(Map<String, dynamic> json) => _CnpjEmpresa(
  cnpj: json['cnpj'] as String? ?? '',
  razaoSocial: json['razaoSocial'] as String? ?? '',
  nomeFantasia: json['nomeFantasia'] as String?,
  situacao: json['situacao'] as String?,
  telefone: json['telefone'] as String?,
  email: json['email'] as String?,
  logradouro: json['logradouro'] as String?,
  numero: json['numero'] as String?,
  bairro: json['bairro'] as String?,
  municipio: json['municipio'] as String?,
  uf: json['uf'] as String?,
  cep: json['cep'] as String?,
);

Map<String, dynamic> _$CnpjEmpresaToJson(_CnpjEmpresa instance) =>
    <String, dynamic>{
      'cnpj': instance.cnpj,
      'razaoSocial': instance.razaoSocial,
      'nomeFantasia': instance.nomeFantasia,
      'situacao': instance.situacao,
      'telefone': instance.telefone,
      'email': instance.email,
      'logradouro': instance.logradouro,
      'numero': instance.numero,
      'bairro': instance.bairro,
      'municipio': instance.municipio,
      'uf': instance.uf,
      'cep': instance.cep,
    };
