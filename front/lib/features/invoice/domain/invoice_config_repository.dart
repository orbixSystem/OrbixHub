import 'dart:typed_data';

import 'invoice_config_models.dart';

/// Configuração fiscal do tenant (`/invoices/config`) — permissão
/// `invoice.config`, gated pelo módulo `invoice`. O certificado A1 (.pfx) e o
/// CSC em si nunca residem no front: o upload é passthrough para o provedor
/// fiscal; aqui só lemos/gravamos metadados e preferências.
abstract class InvoiceConfigRepository {
  /// Busca a configuração fiscal atual do tenant.
  Future<InvoiceFiscalConfig> fetch();

  /// Aplica [patch] (apenas os campos alterados) e retorna a config atualizada.
  Future<InvoiceFiscalConfig> update(Map<String, dynamic> patch);

  /// Cadastra a empresa no provedor fiscal usando a identidade fiscal já
  /// cadastrada no núcleo (dados da empresa em Configurações).
  Future<InvoiceFiscalConfig> registerEmpresa();

  /// Envia o certificado A1 (.pfx/.p12) + senha ao provedor (passthrough —
  /// nunca persistido aqui). Retorna a config atualizada (com a validade).
  Future<InvoiceFiscalConfig> uploadCertificate(
    Uint8List bytes,
    String filename,
    String password,
  );
}
