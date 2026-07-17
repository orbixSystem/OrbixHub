import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice_config_models.freezed.dart';
part 'invoice_config_models.g.dart';

/// Metadado de validade do certificado A1 (o .pfx em si nunca chega ao front —
/// fica só o metadado de validade). Contrato real do backend: camelCase.
@freezed
abstract class CertificateInfo with _$CertificateInfo {
  const factory CertificateInfo({
    @JsonKey(name: 'validoAte') String? validoAte,
  }) = _CertificateInfo;

  factory CertificateInfo.fromJson(Map<String, dynamic> json) =>
      _$CertificateInfoFromJson(json);
}

/// Configuração fiscal do tenant (`GET/PATCH /invoices/config`). Não guarda
/// segredos — o .pfx e o CSC em si vivem no provedor; aqui só metadados/
/// preferências ("aponta, não invade"). Contrato real do backend: camelCase.
@freezed
abstract class InvoiceFiscalConfig with _$InvoiceFiscalConfig {
  const factory InvoiceFiscalConfig({
    @Default('homologacao') String ambiente,
    @Default('1') String serieNfse,
    @Default('1') String serieNfce,
    @Default('1') String serieNfe,
    @Default('') String idCsc,
    @Default(false) bool empresaRegistrada,
    @Default(CertificateInfo()) CertificateInfo certificado,
  }) = _InvoiceFiscalConfig;

  factory InvoiceFiscalConfig.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFiscalConfigFromJson(json);
}
