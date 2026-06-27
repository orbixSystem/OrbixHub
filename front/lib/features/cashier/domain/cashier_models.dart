import 'package:freezed_annotation/freezed_annotation.dart';

part 'cashier_models.freezed.dart';
part 'cashier_models.g.dart';

/// Sessão de caixa (caixa do dia). Valores monetários de coluna (Decimal) chegam
/// como String serializada; os totais COMPUTADOS (`totals`, `byMethod`) chegam
/// como número. O backend é a verdade — o cliente só reflete para UX.
@freezed
abstract class CashSession with _$CashSession {
  const factory CashSession({
    required String id,
    @Default('open') String status, // 'open' | 'closed'
    @JsonKey(name: 'opening_amount') @Default('0') String openingAmount,
    @JsonKey(name: 'opened_at') String? openedAt,
    @JsonKey(name: 'closed_at') String? closedAt,
    @JsonKey(name: 'closing_amount_counted') String? closingAmountCounted,
    @JsonKey(name: 'closing_amount_expected') String? closingAmountExpected,
    String? difference,
    String? notes,
    @Default(<MethodTotal>[]) List<MethodTotal> byMethod,
    SessionTotals? totals,
  }) = _CashSession;

  factory CashSession.fromJson(Map<String, dynamic> json) =>
      _$CashSessionFromJson(json);
}

/// Totais correntes da sessão (entrada/saída e esperado calculado).
@freezed
abstract class SessionTotals with _$SessionTotals {
  const factory SessionTotals({
    @JsonKey(name: 'in') @Default(0) num inTotal,
    @JsonKey(name: 'out') @Default(0) num outTotal,
    @Default(0) num expected,
  }) = _SessionTotals;

  factory SessionTotals.fromJson(Map<String, dynamic> json) =>
      _$SessionTotalsFromJson(json);
}

/// Total por método (informativo) — entrada e saída.
@freezed
abstract class MethodTotal with _$MethodTotal {
  const factory MethodTotal({
    required String method,
    @JsonKey(name: 'in') @Default(0) num inAmount,
    @JsonKey(name: 'out') @Default(0) num outAmount,
  }) = _MethodTotal;

  factory MethodTotal.fromJson(Map<String, dynamic> json) =>
      _$MethodTotalFromJson(json);
}

/// Total por chave genérica (categoria/origem) — entrada e saída.
@freezed
abstract class KeyedTotal with _$KeyedTotal {
  const factory KeyedTotal({
    required String key,
    @JsonKey(name: 'in') @Default(0) num inAmount,
    @JsonKey(name: 'out') @Default(0) num outAmount,
  }) = _KeyedTotal;

  factory KeyedTotal.fromJson(Map<String, dynamic> json) =>
      _$KeyedTotalFromJson(json);
}

/// Um lançamento do livro caixa. `amount` é Decimal serializado (String).
@freezed
abstract class CashEntry with _$CashEntry {
  const factory CashEntry({
    required String id,
    required String direction, // 'in' | 'out'
    @Default('0') String amount,
    required String method,
    required String category,
    @JsonKey(name: 'sale_kind') String? saleKind,
    @JsonKey(name: 'sale_id') String? saleId,
    String? description,
    @JsonKey(name: 'reversed_at') String? reversedAt,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _CashEntry;

  factory CashEntry.fromJson(Map<String, dynamic> json) =>
      _$CashEntryFromJson(json);
}

/// Página de lançamentos (extrato).
@freezed
abstract class EntryPage with _$EntryPage {
  const factory EntryPage({
    @Default(<CashEntry>[]) List<CashEntry> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _EntryPage;

  factory EntryPage.fromJson(Map<String, dynamic> json) =>
      _$EntryPageFromJson(json);
}

/// Página de sessões (histórico).
@freezed
abstract class SessionPage with _$SessionPage {
  const factory SessionPage({
    @Default(<CashSession>[]) List<CashSession> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _SessionPage;

  factory SessionPage.fromJson(Map<String, dynamic> json) =>
      _$SessionPageFromJson(json);
}

/// Resumo por período (base dos relatórios de recebido).
@freezed
abstract class CashSummary with _$CashSummary {
  const factory CashSummary({
    @Default(<MethodTotal>[]) List<MethodTotal> byMethod,
    @Default(<KeyedTotal>[]) List<KeyedTotal> byCategory,
    @Default(<KeyedTotal>[]) List<KeyedTotal> byOrigin,
    @Default(0) num totalIn,
    @Default(0) num totalOut,
    @Default(0) num net,
  }) = _CashSummary;

  factory CashSummary.fromJson(Map<String, dynamic> json) =>
      _$CashSummaryFromJson(json);
}

/// Resumo de pagamento de uma venda (total/pago/saldo/status + lançamentos).
@freezed
abstract class PaymentDetail with _$PaymentDetail {
  const factory PaymentDetail({
    @Default(0) num total,
    @Default(0) num paid,
    @Default(0) num balance,
    @Default('a_receber') String status,
    @Default(<CashEntry>[]) List<CashEntry> entries,
  }) = _PaymentDetail;

  factory PaymentDetail.fromJson(Map<String, dynamic> json) =>
      _$PaymentDetailFromJson(json);
}

/// Config do módulo (vinda de `GET /cashier/config`).
@freezed
abstract class CashierConfig with _$CashierConfig {
  const factory CashierConfig({
    @Default(<String>['pix', 'dinheiro', 'cartao_credito', 'cartao_debito', 'outro'])
    List<String> paymentMethods,
    @Default(true) bool requireOpenSession,
    @Default(true) bool countCashOnly,
  }) = _CashierConfig;

  factory CashierConfig.fromJson(Map<String, dynamic> json) =>
      _$CashierConfigFromJson(json);
}

/// Rascunho de um lançamento (a direção é derivada da categoria no backend).
class EntryDraft {
  const EntryDraft({
    required this.amount,
    required this.method,
    required this.category,
    this.saleKind,
    this.saleId,
    this.description,
  });

  final double amount;
  final String method;
  final String category;
  final String? saleKind;
  final String? saleId;
  final String? description;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'method': method,
        'category': category,
        if (saleKind != null) 'saleKind': saleKind,
        if (saleId != null) 'saleId': saleId,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}
