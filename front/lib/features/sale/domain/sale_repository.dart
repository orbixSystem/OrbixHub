import 'sale_models.dart';

/// Contrato do módulo Venda de balcão. O backend é a verdade (RLS + permissões +
/// gating de módulo); o cliente só reflete para UX. Impl real (dio) + fake,
/// trocadas por injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class SaleRepository {
  /// Histórico de vendas. `from`/`to` recortam por data de criação (ISO) e `q`
  /// busca por número da venda ou nome do cliente — é o que responde "o que
  /// vendi, para quem e quando".
  Future<SalePage> listSales({
    String? status,
    String? customerId,
    String? q,
    String? from,
    String? to,
    int page,
  });
  Future<Sale> getSale(String id);
  Future<Sale> createSale(SaleDraft draft);

  /// Cancelamento lógico (estorna estoque no backend). Nunca apaga.
  Future<Sale> cancelSale(String id, {String? reason});

  /// Dispara a emissão da nota via o Fiscal; devolve o resultado (snapshot).
  Future<SaleFiscalResult> emitInvoice(String id);
}
