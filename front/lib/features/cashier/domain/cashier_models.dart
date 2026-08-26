import 'package:freezed_annotation/freezed_annotation.dart';

import 'cashier_format.dart';

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
    /// Desconto concedido na quitação. Vem como String (Decimal do Postgres,
    /// como `amount`). A dívida fechou por `amount + discount` — mostrar só o
    /// `amount` faria a conta não bater aos olhos de quem confere.
    @Default('0') String discount,
    @JsonKey(name: 'discount_reason') String? discountReason,
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
    /// Desconto concedido no período. NÃO faz parte de [totalIn] nem de [net]:
    /// fecha dívida sem entrar dinheiro. É número irmão, não parcela.
    @JsonKey(name: 'totalDiscount') @Default(0) num totalDiscount,
  }) = _CashSummary;

  factory CashSummary.fromJson(Map<String, dynamic> json) =>
      _$CashSummaryFromJson(json);
}

/// Resumo de pagamento de uma venda (total/pago/saldo/status + lançamentos).
@freezed
abstract class PaymentDetail with _$PaymentDetail {
  const factory PaymentDetail({
    @Default(0) num total,
    /// Quanto da DÍVIDA foi quitado: dinheiro recebido + desconto concedido.
    @Default(0) num paid,
    /// Dinheiro que de fato entrou (subconjunto de [paid]).
    @Default(0) num received,
    /// Desconto concedido na quitação (o resto de [paid]).
    @Default(0) num discount,
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
    /// **Sempre `false`.** A cerimônia de abrir/fechar caixa saiu do produto e o
    /// servidor normaliza este campo. O default aqui era `true`, e essa
    /// divergência era um bug de verdade: quando a config não carregava, o app
    /// achava que precisava de caixa aberto, exigia abertura e a venda criava
    /// mas o recebimento falhava com "Abra o caixa antes de lançar".
    @Default(false) bool requireOpenSession,
    @Default(true) bool countCashOnly,
  }) = _CashierConfig;

  factory CashierConfig.fromJson(Map<String, dynamic> json) =>
      _$CashierConfigFromJson(json);
}

/// Despesa fixa: modelo (nome + valor) para lançar em um toque.
///
/// `amount` vem como String (Decimal do Postgres, como no resto do módulo).
/// **`'0'` significa "o valor varia"** — o atalho preenche só o nome e deixa o
/// valor para digitar; é o caso da conta de luz.
@freezed
abstract class ExpenseTemplate with _$ExpenseTemplate {
  const factory ExpenseTemplate({
    required String id,
    required String name,
    @Default('0') String amount,
    @Default('despesa') String category, // 'despesa' | 'sangria'
    /// Forma sugerida; null = usar o default do caixa (não chutar).
    String? method,
    @Default('active') String status, // 'active' | 'disabled'
  }) = _ExpenseTemplate;

  factory ExpenseTemplate.fromJson(Map<String, dynamic> json) =>
      _$ExpenseTemplateFromJson(json);
}

/// Helpers de leitura (freezed 3 exige construtor privado p/ getters de instância).
extension ExpenseTemplateX on ExpenseTemplate {
  /// Valor sugerido; 0 = "varia".
  double get valor => moneyToDouble(amount);

  /// Se o modelo já traz o valor pronto (o atalho fica de um toque só).
  bool get temValor => valor > 0;

  bool get ativo => status == 'active';
}

/// Draft de escrita de uma despesa fixa (create/update). Só envia o que mudou —
/// `method: null` no update é ambíguo por natureza, então quem quer LIMPAR a
/// forma passa `limparMethod: true`; ausência significa "não mexe".
class ExpenseTemplateDraft {
  const ExpenseTemplateDraft({
    this.id,
    this.name,
    this.amount,
    this.category,
    this.method,
    this.limparMethod = false,
    this.status,
  });

  /// Uuid gerado no cliente (create offline preserva o id no replay).
  final String? id;
  final String? name;
  final double? amount;
  final String? category;
  final String? method;
  final bool limparMethod;
  final String? status;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (amount != null) 'amount': amount,
        if (category != null) 'category': category,
        if (limparMethod) 'method': null else if (method != null) 'method': method,
        if (status != null) 'status': status,
      };
}

// ===================== Parcelamento de fiado =====================

/// Uma parcela de fiado (provisionada ou quitada).
class Installment {
  const Installment({
    required this.id,
    required this.saleKind,
    required this.saleId,
    required this.amount,
    required this.dueDate,
    this.paidAt,
    this.entryId,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String saleKind;
  final String saleId;
  final String amount;
  final String dueDate;
  final String? paidAt;
  final String? entryId;
  final String? notes;
  final String? createdAt;

  factory Installment.fromJson(Map<String, dynamic> json) => Installment(
        id: json['id'] as String,
        saleKind: json['sale_kind'] as String,
        saleId: json['sale_id'] as String,
        amount: (json['amount'] ?? '0').toString(),
        dueDate: json['due_date'] as String,
        paidAt: json['paid_at'] as String?,
        entryId: json['entry_id'] as String?,
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String?,
      );

  /// Espelho local (row-store) — mesma shape do `fromJson`, pra o offline
  /// conseguir guardar/reler a mesma linha.
  Map<String, dynamic> toJson() => {
        'id': id,
        'sale_kind': saleKind,
        'sale_id': saleId,
        'amount': amount,
        'due_date': dueDate,
        'paid_at': paidAt,
        'entry_id': entryId,
        'notes': notes,
        'created_at': createdAt,
      };

  double get valor => moneyToDouble(amount);

  InstallmentStatus get status {
    if (paidAt != null) return InstallmentStatus.paga;
    final due = DateTime.tryParse(dueDate);
    if (due != null && due.isBefore(DateTime.now())) {
      return InstallmentStatus.vencida;
    }
    return InstallmentStatus.pendente;
  }

  bool get venceHoje {
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }
}

/// Status derivado de uma parcela.
enum InstallmentStatus { pendente, vencida, paga }

/// Plano de parcelamento a criar.
class InstallmentPlanDraft {
  const InstallmentPlanDraft({
    required this.saleKind,
    required this.saleId,
    required this.installmentCount,
    required this.dueDayOfMonth,
    required this.totalAmount,
    this.firstDueDate,
    this.notes,
  });

  final String saleKind;
  final String saleId;
  final int installmentCount;
  final int dueDayOfMonth;
  /// Valor total a parcelar (será dividido igualmente entre as parcelas).
  final double totalAmount;
  final String? firstDueDate;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'saleKind': saleKind,
        'saleId': saleId,
        'installmentCount': installmentCount,
        'dueDayOfMonth': dueDayOfMonth,
        'totalAmount': totalAmount,
        if (firstDueDate != null) 'firstDueDate': firstDueDate,
        if (notes != null) 'notes': notes,
      };
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
    this.discount = 0,
    this.discountReason,
    this.saleTotal,
  });

  final double amount;
  final String method;
  final String category;
  final String? saleKind;
  final String? saleId;
  final String? description;

  /// Desconto concedido na quitação. NÃO altera o total do documento — a dívida
  /// fecha quando `amount + discount` cobre o saldo. O backend valida permissão
  /// e teto; o front só oferece o campo a quem tem `cashier.discount`.
  final double discount;
  final String? discountReason;

  /// Total do documento, informado por quem o conhece. O caixa não lê a tabela
  /// da OS/venda, então sem isto o backend não aplica o teto percentual.
  final double? saleTotal;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'method': method,
        'category': category,
        if (saleKind != null) 'saleKind': saleKind,
        if (saleId != null) 'saleId': saleId,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (discount > 0) 'discount': discount,
        if (discount > 0 &&
            discountReason != null &&
            discountReason!.isNotEmpty)
          'discountReason': discountReason,
        if (saleTotal != null) 'saleTotal': saleTotal,
      };
}
