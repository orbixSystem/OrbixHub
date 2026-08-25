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
    String? tipo,
    String? marca,
    String? modelo,
    @JsonKey(name: 'numero_serie') String? numeroSerie,
    @Default(<String, dynamic>{}) Map<String, dynamic> attributes,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @Default('active') String status,

    /// Retorno da consulta por placa (colunas exclusivas dela no banco).
    /// Mapa cru — o contrato é jsonb livre; use `plateInfo` para tipar com
    /// segurança. Null = veículo cadastrado à mão, sem consulta.
    @JsonKey(name: 'plate_data') Map<String, dynamic>? plateData,
    @JsonKey(name: 'plate_data_at') String? plateDataAt,
  }) = _Subject;

  factory Subject.fromJson(Map<String, dynamic> json) =>
      _$SubjectFromJson(json);
}

extension SubjectPlateData on Subject {
  /// Consulta por placa já tipada. Devolve null quando não há dados ou quando
  /// o payload salvo não bate com o formato atual — um registro antigo nunca
  /// derruba a tela de detalhes.
  PlateInfo? get plateInfo {
    final raw = plateData;
    if (raw == null || raw.isEmpty) return null;
    try {
      return PlateInfo.fromJson(raw);
    } on Object {
      return null;
    }
  }
}

/// Rótulo dinâmico do subject (singular/plural).
@freezed
abstract class SubjectLabel with _$SubjectLabel {
  const factory SubjectLabel({
    @Default('Objeto') String singular,
    @Default('Objetos') String plural,
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
  const SubjectDraft({
    this.label,
    this.identifier,
    this.tipo,
    this.marca,
    this.modelo,
    this.numeroSerie,
    this.attributes,
    this.plateData,
  });

  final String? label;
  final String? identifier;
  final String? tipo;
  final String? marca;
  final String? modelo;
  final String? numeroSerie;
  final Map<String, dynamic>? attributes;

  /// Retorno da consulta por placa a persistir (só quando houve consulta —
  /// omitir mantém o que já estava salvo).
  final Map<String, dynamic>? plateData;

  Map<String, dynamic> toJson() => {
        if (label != null) 'label': label,
        if (identifier != null) 'identifier': identifier,
        if (tipo != null) 'tipo': tipo,
        if (marca != null) 'marca': marca,
        if (modelo != null) 'modelo': modelo,
        if (numeroSerie != null) 'numeroSerie': numeroSerie,
        if (attributes != null) 'attributes': attributes,
        if (plateData != null) 'plateData': plateData,
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

/// Opção casada no catálogo FIPE do cadastro; `codigo` alimenta a cascata
/// marca → modelo → ano.
@freezed
abstract class PlateFipeRef with _$PlateFipeRef {
  const factory PlateFipeRef({required String value, String? codigo}) =
      _PlateFipeRef;

  factory PlateFipeRef.fromJson(Map<String, dynamic> json) =>
      _$PlateFipeRefFromJson(json);
}

/// "Equivalente" do veículo no catálogo FIPE que o cadastro já usa — resolvido
/// no backend. É o que permite o autofill escrever o valor CANÔNICO nos campos
/// e manter a cascata funcionando.
@freezed
abstract class PlateFipeMatch with _$PlateFipeMatch {
  const factory PlateFipeMatch({
    PlateFipeRef? marca,
    PlateFipeRef? modelo,
    PlateFipeRef? ano,
  }) = _PlateFipeMatch;

  factory PlateFipeMatch.fromJson(Map<String, dynamic> json) =>
      _$PlateFipeMatchFromJson(json);
}

/// Uma correspondência FIPE da consulta de placa (a consulta pode trazer mais
/// de uma; a de maior `score` é a melhor, recomendação da própria API).
@freezed
abstract class PlateFipe with _$PlateFipe {
  const factory PlateFipe({
    String? codigoFipe,
    String? marca,
    String? modelo,
    String? valor,
    String? combustivel,
    String? anoModelo,
    String? mesReferencia,
    int? score,
  }) = _PlateFipe;

  factory PlateFipe.fromJson(Map<String, dynamic> json) =>
      _$PlateFipeFromJson(json);
}

/// Contador da cota mensal de consultas de placa — vem do backend junto de
/// cada consulta e em `GET /customers/plates/usage`. NUNCA calculado no front.
@freezed
abstract class PlateQuota with _$PlateQuota {
  const factory PlateQuota({
    required String period,
    required int used,
    required int limit,
    required int remaining,
    @Default(false) bool enabled,
  }) = _PlateQuota;

  factory PlateQuota.fromJson(Map<String, dynamic> json) =>
      _$PlateQuotaFromJson(json);
}

/// Resultado normalizado de `GET /customers/plates/:placa` (API Placas via
/// backend — o token e a cota vivem lá). `cached=true` = servido do cache do
/// servidor, sem consumir a cota do mês. Alimenta o autofill do cadastro de
/// veículo e a ficha em PDF.
@freezed
abstract class PlateInfo with _$PlateInfo {
  const factory PlateInfo({
    required String placa,
    String? placaAlternativa,
    String? marca,
    String? modelo,
    String? marcaModelo,
    String? versao,
    String? ano,
    String? anoModelo,
    String? cor,
    String? chassi,
    String? municipio,
    String? uf,
    String? situacao,
    String? origem,
    String? combustivel,
    String? cilindradas,
    String? especie,
    String? tipoVeiculo,
    String? passageiros,
    String? segmento,
    String? nacionalidade,
    String? logoUrl,
    String? consultadoEm,
    PlateFipe? fipe,

    /// Todas as correspondências FIPE (ficha detalhada), maior score primeiro.
    @Default(<PlateFipe>[]) List<PlateFipe> fipeTodos,

    /// Equivalente no catálogo do cadastro (autofill + cascata).
    PlateFipeMatch? fipeMatch,

    /// Bloco técnico completo da consulta (chave crua → valor). Rótulos em
    /// `plate_labels.dart`; pode vir vazio (a API não garante este bloco).
    @Default(<String, String>{}) Map<String, String> extra,
    @Default(false) bool cached,
    PlateQuota? usage,
  }) = _PlateInfo;

  factory PlateInfo.fromJson(Map<String, dynamic> json) =>
      _$PlateInfoFromJson(json);
}

/// Dados públicos de uma empresa (consulta por CNPJ na Receita, via backend).
///
/// `email` costuma vir vazio — a base pública raramente o traz. Isso é normal:
/// o formulário só deixa o campo em branco, sem tratar como erro.
@freezed
abstract class CnpjEmpresa with _$CnpjEmpresa {
  const factory CnpjEmpresa({
    @Default('') String cnpj,
    @Default('') String razaoSocial,
    String? nomeFantasia,
    String? situacao,
    String? telefone,
    String? email,
    String? logradouro,
    String? numero,
    String? bairro,
    String? municipio,
    String? uf,
    String? cep,
  }) = _CnpjEmpresa;

  factory CnpjEmpresa.fromJson(Map<String, dynamic> json) =>
      _$CnpjEmpresaFromJson(json);
}

/// Helpers de leitura. Em extension (não na classe) porque freezed 3 exige
/// construtor privado para membros de instância — e não vale adicionar cerimônia
/// à classe por causa de um getter.
extension CnpjEmpresaX on CnpjEmpresa {
  /// Endereço numa linha, no formato que o formulário de cliente guarda.
  String get enderecoLinha => [
        if (logradouro != null && logradouro!.isNotEmpty) logradouro!,
        if (bairro != null && bairro!.isNotEmpty) bairro!,
        if (municipio != null && municipio!.isNotEmpty)
          [municipio!, if (uf != null && uf!.isNotEmpty) uf!].join('/'),
      ].join(', ');
}
