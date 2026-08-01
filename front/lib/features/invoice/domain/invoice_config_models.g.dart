// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_config_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CertificateInfo _$CertificateInfoFromJson(Map<String, dynamic> json) =>
    _CertificateInfo(validoAte: json['validoAte'] as String?);

Map<String, dynamic> _$CertificateInfoToJson(_CertificateInfo instance) =>
    <String, dynamic>{'validoAte': instance.validoAte};

_InvoiceFiscalConfig _$InvoiceFiscalConfigFromJson(Map<String, dynamic> json) =>
    _InvoiceFiscalConfig(
      ambiente: json['ambiente'] as String? ?? 'homologacao',
      serieNfse: json['serieNfse'] as String? ?? '1',
      serieNfce: json['serieNfce'] as String? ?? '1',
      serieNfe: json['serieNfe'] as String? ?? '1',
      idCsc: json['idCsc'] as String? ?? '',
      empresaRegistrada: json['empresaRegistrada'] as bool? ?? false,
      certificado: json['certificado'] == null
          ? const CertificateInfo()
          : CertificateInfo.fromJson(
              json['certificado'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$InvoiceFiscalConfigToJson(
  _InvoiceFiscalConfig instance,
) => <String, dynamic>{
  'ambiente': instance.ambiente,
  'serieNfse': instance.serieNfse,
  'serieNfce': instance.serieNfce,
  'serieNfe': instance.serieNfe,
  'idCsc': instance.idCsc,
  'empresaRegistrada': instance.empresaRegistrada,
  'certificado': instance.certificado.toJson(),
};
