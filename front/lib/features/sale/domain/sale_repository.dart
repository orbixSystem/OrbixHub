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

  /// Edita uma venda registrada: cliente, itens e desconto.
  ///
  /// `items` SUBSTITUI as linhas (manda a lista inteira, como na criação); o
  /// total é recalculado no servidor e o estoque reconciliado. O backend recusa
  /// quando a edição quebraria algo já emitido: nota fiscal existente ou total
  /// abaixo do que o cliente já pagou.
  Future<Sale> updateSale(
    String id, {
    String? customerId,
    List<SaleItemDraft>? items,
    double? discount,
  });

  /// Cancelamento lógico (estorna estoque no backend). Nunca apaga.
  Future<Sale> cancelSale(String id, {String? reason});

  /// Dispara a emissão da nota via o Fiscal; devolve o resultado (snapshot).
  Future<SaleFiscalResult> emitInvoice(String id);
}
