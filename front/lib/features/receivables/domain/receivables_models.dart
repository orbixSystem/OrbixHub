import 'package:freezed_annotation/freezed_annotation.dart';

part 'receivables_models.freezed.dart';
part 'receivables_models.g.dart';

/// Modelos do controle de FIADO (contas a receber).
///
/// "Fiado" não é um estado próprio no banco: é toda venda/OS com saldo em
/// aberto. O backend (`receivables`) compõe OS + Vendas — que já derivam o
/// pagamento do caixa — e agrupa a dívida por cliente. Valores chegam como
/// número (são computados, não colunas).

/// Um cliente devedor e o que ele deve.
@freezed
abstract class Debtor with _$Debtor {
  const factory Debtor({
    /// `null` = venda de balcão sem cliente identificado.
    @JsonKey(name: 'customerId') String? customerId,
    @JsonKey(name: 'customerName') @Default('Sem cliente') String customerName,
    @JsonKey(name: 'totalDue') @Default(0) num totalDue,
    @JsonKey(name: 'titleCount') @Default(0) int titleCount,

    /// Título mais antigo em aberto — "deve desde quando".
    @JsonKey(name: 'oldestAt') String? oldestAt,
  }) = _Debtor;

  factory Debtor.fromJson(Map<String, dynamic> json) => _$DebtorFromJson(json);
}

/// Página de devedores + o total a receber da carteira.
@freezed
abstract class DebtorsPage with _$DebtorsPage {
  const factory DebtorsPage({
    @Default(<Debtor>[]) List<Debtor> items,
    @JsonKey(name: 'totalDue') @Default(0) num totalDue,

    /// A varredura bateu no teto do servidor: há dívida não listada. A tela avisa
    /// em vez de deixar o usuário achar que viu tudo.
    @Default(false) bool truncated,
  }) = _DebtorsPage;

  factory DebtorsPage.fromJson(Map<String, dynamic> json) =>
      _$DebtorsPageFromJson(json);
}

/// Um item do que foi vendido — o "quais serviços e quanto de cada".
@freezed
abstract class ReceivableItem with _$ReceivableItem {
  const factory ReceivableItem({
    @Default('') String name,
    String? kind, // 'product' | 'service'
    @Default(0) num quantity,
    @JsonKey(name: 'unitPrice') @Default(0) num unitPrice,
    @Default(0) num total,
  }) = _ReceivableItem;

  factory ReceivableItem.fromJson(Map<String, dynamic> json) =>
      _$ReceivableItemFromJson(json);
}

/// Um título em aberto: a venda ou OS que gerou a dívida.
@freezed
abstract class ReceivableTitle with _$ReceivableTitle {
  const factory ReceivableTitle({
    required String id,

    /// 'os' | 'sale' — decide qual tela abrir no drill-down.
    @Default('sale') String origin,
    @Default('') String number,
    @JsonKey(name: 'createdAt') String? createdAt,
    @Default(0) num total,
    @Default(0) num paid,
    @Default(0) num balance,

    /// 'a_receber' | 'parcial'
    @Default('a_receber') String status,
    @Default(<ReceivableItem>[]) List<ReceivableItem> items,
  }) = _ReceivableTitle;

  factory ReceivableTitle.fromJson(Map<String, dynamic> json) =>
      _$ReceivableTitleFromJson(json);
}

/// Os títulos em aberto de UM cliente.
@freezed
abstract class DebtorDetail with _$DebtorDetail {
  const factory DebtorDetail({
    @JsonKey(name: 'customerName') @Default('Sem cliente') String customerName,
    @JsonKey(name: 'totalDue') @Default(0) num totalDue,
    @Default(<ReceivableTitle>[]) List<ReceivableTitle> items,
  }) = _DebtorDetail;

  factory DebtorDetail.fromJson(Map<String, dynamic> json) =>
      _$DebtorDetailFromJson(json);
}
