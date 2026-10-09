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
/// segredos — o .pfx nunca volta do servidor; aqui só metadados/preferências.
/// Contrato real do backend: camelCase.
///
/// `provider` diz QUEM emite: `govbr` = direto na NFS-e Nacional (o certificado
/// fica cifrado no servidor e não há cadastro em provedor); outros valores =
/// provedor/simulação. `pendencias` é a lista (do backend) do que ainda falta
/// para emitir — vazia = pronto.
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
    @Default('noop') String provider,
    @Default(<String>[]) List<String> pendencias,
    @Default('') String codigoServicoNacional,
    @Default('') String codigoNbs,
    double? aliquotaIss,
    double? percentualTributosSimples,
  }) = _InvoiceFiscalConfig;

  const InvoiceFiscalConfig._();

  /// Emissão direta pelo governo (NFS-e Nacional).
  bool get isGovBr => provider == 'govbr';

  factory InvoiceFiscalConfig.fromJson(Map<String, dynamic> json) =>
      _$InvoiceFiscalConfigFromJson(json);
}
