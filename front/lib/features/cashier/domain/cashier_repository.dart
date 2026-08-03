import 'cashier_models.dart';

/// Contrato do módulo Caixa. Backend é a verdade (RLS + permissões + gating de
/// módulo); o cliente reflete para UX. Impl real (dio) + fake, trocadas por
/// injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class CashierRepository {
  Future<CashierConfig> fetchConfig();
  Future<CashierConfig> updateConfig({
    List<String>? paymentMethods,
    bool? requireOpenSession,
    bool? countCashOnly,
  });

  /// Sessão aberta atual (ou null se o caixa está fechado).
  Future<CashSession?> currentSession();
  Future<CashSession> openSession({double? openingAmount, String? notes});
  Future<CashSession> closeSession({required double countedAmount, String? notes});
  Future<SessionPage> listSessions({int page});

  /// Valor contado no ÚLTIMO fechamento deste ponto de caixa — o troco que ficou
  /// na gaveta, usado para sugerir a abertura. `null` quando não há fechamento
  /// anterior (primeiro uso do terminal).
  Future<double?> lastClosingAmount();

  Future<CashEntry> createEntry(EntryDraft draft);

  /// Estorno lógico (auditado) — não apaga, marca `reversedAt`.
  Future<CashEntry> reverseEntry(String id, String reason);

  /// Edita o que o lançamento **diz** — descrição e categoria de mesma direção.
  /// Nunca o quanto vale: para valor/forma existe [correctEntry].
  Future<CashEntry> updateEntry(
    String id, {
    String? description,
    String? category,
  });

  /// **Corrige** um lançamento errado: estorna o original (com motivo) e relança
  /// com os valores certos, numa operação. É o "editar" do dinheiro — o livro
  /// caixa não sobrescreve movimento, registra a correção. Devolve o NOVO
  /// lançamento. Campos ausentes herdam do original.
  Future<CashEntry> correctEntry(
    String id, {
    required String reason,
    double? amount,
    String? method,
    String? category,
    String? description,
  });

  Future<EntryPage> listEntries({
    String? sessionId,
    /// Busca textual na descrição (número da OS/venda, cliente). Aplicada no
    /// SERVIDOR e, offline, no espelho local — nunca só na página carregada.
    String? q,
    String? direction,
    String? method,
    String? category,
    String? saleKind,
    String? saleId,
    String? from,
    String? to,
    int page,
  });

  Future<CashSummary> summary({String? from, String? to});

  Future<PaymentDetail> paymentSummary({
    required String saleKind,
    required String saleId,
    double? total,
  });
}
