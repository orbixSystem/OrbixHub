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
