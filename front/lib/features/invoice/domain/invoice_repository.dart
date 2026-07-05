import 'invoice_models.dart';

/// Contrato do módulo Notas Fiscais. O backend é a verdade (RLS + permissões
/// `invoice.read`/`invoice.issue` + gating de módulo); o cliente só reflete para
/// UX. Impl real (dio) + fake, trocadas por injeção Riverpod. A UI nunca fala
/// com o dio direto.
abstract interface class InvoiceRepository {
  /// Lista paginada (`GET /invoices`). `status` filtra por situação; `orderId`
  /// filtra as notas de uma OS. `page` é 1-based.
  Future<InvoicePage> list({int page, String? status, String? orderId});

  /// Uma nota por id, com `lines` e `events` (`GET /invoices/:id`).
  Future<Invoice> getOne(String id);

  /// Emite uma nota a partir de uma OS OU de uma venda (`POST /invoices`) —
  /// exatamente um dos dois. `documentType` cai no default do backend ('nfse')
  /// quando nulo. Exige `invoice.issue`.
  Future<Invoice> issue({String? orderId, String? saleId, String? documentType});

  /// Cancela uma nota autorizada (`POST /invoices/:id/cancel`). `reason` de 3 a
  /// 255 chars. Exige `invoice.issue`. Sem hard delete — só muda o status.
  Future<Invoice> cancel(String id, String reason);
}
