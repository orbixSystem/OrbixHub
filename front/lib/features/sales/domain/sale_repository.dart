import 'sale_models.dart';

/// Contrato do módulo Vendas/Caixa. O backend é a verdade (RLS + permissões
/// `cashier.read`/`cashier.write` + gating de módulo); o cliente só reflete para
/// UX. Impl real (dio) + fake, trocadas por injeção Riverpod. A UI nunca fala
/// com o dio direto.
abstract interface class SaleRepository {
  /// Lista paginada (`GET /sales`). `status` filtra por situação
  /// ('concluida'|'cancelada'); `customerId` filtra as vendas de um cliente.
  /// `page` é 1-based. Exige `cashier.read`.
  Future<SalePage> list({int page, String? status, String? customerId});

  /// Uma venda por id, com `items` (`GET /sales/:id`). Exige `cashier.read`.
  Future<Sale> getOne(String id);

  /// Finaliza uma venda de balcão (`POST /sales`). Exige `cashier.write`.
  Future<Sale> checkout(SaleDraft draft);

  /// Cancela uma venda concluída (`POST /sales/:id/cancel`). `reason` de 3 a 255
  /// chars; estorna o estoque no backend. Exige `cashier.write`. Sem hard delete
  /// — só muda o status.
  Future<Sale> cancel(String id, String reason);
}
