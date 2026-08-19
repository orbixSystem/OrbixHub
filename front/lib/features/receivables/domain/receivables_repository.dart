import 'receivables_models.dart';

/// Contrato do controle de FIADO (contas a receber). Leitura apenas: RECEBER um
/// fiado é um lançamento no Caixa (`CashierRepository.createEntry` com
/// `saleKind`+`saleId`), que já aceita parcial e é a única porta por onde
/// dinheiro entra — não há um "quitar" próprio aqui.
///
/// Backend é a verdade (RLS + permissões + gating do módulo `cashier`); o
/// cliente reflete para UX. Impl real (dio) + fake, trocadas por injeção
/// Riverpod. A UI nunca fala com o dio direto.
abstract interface class ReceivablesRepository {
  /// Devedores, do maior saldo para o menor.
  Future<DebtorsPage> listDebtors();

  /// TODOS os títulos em aberto, achatados (com o dono em cada um) e do mais
  /// recente para o mais antigo. É o que o histórico do caixa consome para
  /// mostrar a OS fiada junto da venda fiada.
  Future<OpenTitlesPage> listOpenTitles();

  /// Títulos em aberto de um cliente, com os itens de cada.
  /// `customerId: null` = vendas de balcão sem cliente identificado.
  Future<DebtorDetail> titlesOf(String? customerId);
}
