import 'dart:typed_data';

import '../domain/invoice_config_models.dart';
import '../domain/invoice_config_repository.dart';

/// Fake [InvoiceConfigRepository] em memória — usado em testes e como
/// referência de comportamento (patch parcial + flags derivadas).
class FakeInvoiceConfigRepository implements InvoiceConfigRepository {
  InvoiceFiscalConfig _cfg = const InvoiceFiscalConfig();

  @override
  Future<InvoiceFiscalConfig> fetch() async => _cfg;

  @override
  Future<InvoiceFiscalConfig> update(Map<String, dynamic> patch) async {
    _cfg = _cfg.copyWith(
      ambiente: patch['ambiente'] as String? ?? _cfg.ambiente,
      serieNfse: patch['serieNfse'] as String? ?? _cfg.serieNfse,
      serieNfce: patch['serieNfce'] as String? ?? _cfg.serieNfce,
      serieNfe: patch['serieNfe'] as String? ?? _cfg.serieNfe,
      idCsc: patch['idCsc'] as String? ?? _cfg.idCsc,
    );
    return _cfg;
  }

  @override
  Future<InvoiceFiscalConfig> registerEmpresa() async {
    _cfg = _cfg.copyWith(empresaRegistrada: true);
    return _cfg;
  }

  @override
  Future<InvoiceFiscalConfig> uploadCertificate(
    Uint8List bytes,
    String filename,
    String password,
  ) async {
    _cfg = _cfg.copyWith(
      certificado: const CertificateInfo(validoAte: '2027-01-01T00:00:00Z'),
    );
    return _cfg;
  }
}
