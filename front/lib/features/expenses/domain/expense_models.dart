import 'package:freezed_annotation/freezed_annotation.dart';

import 'expense_status.dart';

part 'expense_models.freezed.dart';
part 'expense_models.g.dart';

/// Converte o `Decimal` do Postgres, que o Prisma serializa como **String**
/// (`"2500"`, `"2612.5"`), no `num` que a tela usa.
///
/// Aceita `num` também: o repositório fake monta os objetos com número direto, e
/// exigir string ali só para agradar o serializador seria deixar o teste refém
/// do formato do banco.
class _Decimal implements JsonConverter<num, Object?> {
  const _Decimal();

  @override
  num fromJson(Object? json) => switch (json) {
        num n => n,
        String s => num.tryParse(s) ?? 0,
        _ => 0,
      };

  @override
  Object? toJson(num value) => value;
}

/// Idem, para os campos que podem vir nulos (`paid_amount`).
class _DecimalOrNull implements JsonConverter<num?, Object?> {
  const _DecimalOrNull();

  @override
  num? fromJson(Object? json) => switch (json) {
        null => null,
        num n => n,
        String s => num.tryParse(s),
        _ => null,
      };

  @override
  Object? toJson(num? value) => value;
}

/// Modelos do módulo Despesas (lembrete de pagamento).
///
/// Três conceitos, deliberadamente separados:
///   [ExpenseCategory]   — o rótulo (nome + ícone + cor).
///   [ExpenseRecurrence] — a REGRA ("todo dia 10, Aluguel, R$ 2.500").
///   [Expense]           — a CONTA de um vencimento específico.
///
/// A regra não é a conta: separadas, dá para corrigir o valor de UM mês (a luz
/// veio cara) sem reescrever o histórico nem a regra.

/// Categoria de despesa. `icon` é uma CHAVE simbólica ('energia'), nunca um
/// codepoint — ver [iconeDaCategoria].
@freezed
abstract class ExpenseCategory with _$ExpenseCategory {
  const factory ExpenseCategory({
    required String id,
    @Default('') String name,
    @Default('outros') String icon,

    /// Hex `#RRGGBB` vindo do servidor.
    @Default('#6B7280') String color,

    /// Esta categoria tem FORNECEDOR do outro lado?
    ///
    /// Peças e manutenção têm; aluguel, energia e salário não. É o que decide se
    /// o cadastro de despesa oferece o campo — mostrá-lo em toda conta era ruído
    /// em quase todas. Vem do banco e não de uma lista fixa aqui porque a cliente
    /// cria as próprias categorias, e uma whitelist no app erraria todas elas.
    @JsonKey(name: 'tracks_supplier') @Default(false) bool tracksSupplier,
    @Default('active') String status,
  }) = _ExpenseCategory;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) =>
      _$ExpenseCategoryFromJson(json);
}

/// Uma conta a pagar.
@freezed
abstract class Expense with _$Expense {
  const factory Expense({
    required String id,
    @Default('') String description,

    /// 0 = "valor a confirmar" (a conta existe antes de o boleto chegar).
    @_Decimal() @Default(0) num amount,

    /// Vencimento. O servidor devolve a linha crua do Prisma, então chega em ISO
    /// completo (`2026-08-10T00:00:00.000Z`) mesmo sendo `date` no banco.
    @JsonKey(name: 'due_date') required String dueDate,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'recurrence_id') String? recurrenceId,

    /// Instante do pagamento. `null` = não paga — é o ÚNICO fato gravado sobre
    /// pagamento; a situação sai daqui (ver [ExpenseStatus]).
    @JsonKey(name: 'paid_at') String? paidAt,

    /// Pode divergir de [amount] (juros, desconto): o que saiu é o que saiu.
    @_DecimalOrNull() @JsonKey(name: 'paid_amount') num? paidAmount,
    @JsonKey(name: 'paid_method') String? paidMethod,

    /// Id do lançamento no Caixa gerado pela baixa. Só o ID (regra 1): este
    /// módulo nunca lê a tabela do caixa.
    @JsonKey(name: 'cash_entry_id') String? cashEntryId,
    String? notes,

    /// Parcelamento: qual parcela esta conta é, de quantas, e o grupo que junta
    /// as irmãs. As três andam juntas (CHECK no banco) ou são todas nulas.
    @JsonKey(name: 'installment_no') int? installmentNo,
    @JsonKey(name: 'installment_total') int? installmentTotal,
    @JsonKey(name: 'installment_group_id') String? installmentGroupId,

    /// Fornecedor — retrato de quem cobrou, não FK para cadastro.
    @JsonKey(name: 'supplier_name') String? supplierName,

    /// Só dígitos (14 = CNPJ, 11 = CPF). Quem formata é a tela.
    @JsonKey(name: 'supplier_doc') String? supplierDoc,
    @Default('active') String status,
  }) = _Expense;

  const Expense._();

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);

  DateTime get vencimento => DateTime.parse(dueDate);
  DateTime? get pagoEm => paidAt == null ? null : DateTime.parse(paidAt!);
  bool get pago => paidAt != null;

  /// `true` quando é uma parcela de compra parcelada.
  bool get parcelada => installmentNo != null && installmentTotal != null;

  /// "2/6" para o card. Vazio quando não é parcelada.
  String get rotuloParcela =>
      parcelada ? '$installmentNo/$installmentTotal' : '';

  /// `true` quando nasceu de uma regra ("todo mês").
  bool get fixa => recurrenceId != null;

  /// Vazio = "valor a confirmar"; a tela mostra isso em vez de "R$ 0,00", que
  /// leria como "não devo nada".
  bool get temValor => amount > 0;

  /// Quanto efetivamente saiu (cai no previsto quando não houve divergência).
  num get valorEfetivo => paidAmount ?? amount;

  ExpenseStatus situacao(DateTime hoje) => statusDaDespesa(
        dueDate: vencimento,
        paidAt: pagoEm,
        hoje: hoje,
      );
}

/// A regra que gera contas mês a mês.
@freezed
abstract class ExpenseRecurrence with _$ExpenseRecurrence {
  const factory ExpenseRecurrence({
    required String id,
    @Default('') String description,
    @_Decimal() @Default(0) num amount,
    @JsonKey(name: 'category_id') String? categoryId,

    /// 'monthly' | 'yearly'
    @Default('monthly') String frequency,
    @JsonKey(name: 'day_of_month') @Default(1) int dayOfMonth,
    @JsonKey(name: 'month_of_year') int? monthOfYear,
    String? method,
    String? notes,
    @JsonKey(name: 'ends_on') String? endsOn,
    @Default('active') String status,
  }) = _ExpenseRecurrence;

  const ExpenseRecurrence._();

  factory ExpenseRecurrence.fromJson(Map<String, dynamic> json) =>
      _$ExpenseRecurrenceFromJson(json);

  bool get ativa => status == 'active';
}

/// Dados para criar/editar uma conta. Campos nulos = "não mexe" na edição.
///
/// Só [description] e [dueDate] são obrigatórios na criação — o resto a cliente
/// preenche se quiser (valor pode não ter chegado, categoria cai em "Outros").
@freezed
abstract class ExpenseDraft with _$ExpenseDraft {
  const factory ExpenseDraft({
    String? description,
    num? amount,
    String? dueDate,
    String? categoryId,
    String? notes,

    /// Recorrência pedida na criação; `null` = conta avulsa (uma vez só).
    ExpenseRecurrenceDraft? recorrencia,

    /// Parcelamento pedido na criação. `amount` é o **TOTAL** — quem rateia é o
    /// servidor. Excludente com [recorrencia].
    int? parcelas,

    /// Uuids das parcelas, na ordem — só no caminho OFFLINE, para o replay não
    /// criar um segundo conjunto de linhas. Ver [ExpensesRepository.criar].
    List<String>? installmentIds,
    String? installmentGroupId,
    String? supplierName,

    /// Só dígitos; o servidor recusa tamanho diferente de 11 ou 14.
    String? supplierDoc,

    /// Edição: limpar a categoria exige dizer explicitamente (ausência = "não
    /// mexe", senão nunca daria para tirar uma categoria já gravada).
    @Default(false) bool limparCategoria,

    /// Idem para o fornecedor.
    @Default(false) bool limparFornecedor,
  }) = _ExpenseDraft;

  factory ExpenseDraft.fromJson(Map<String, dynamic> json) =>
      _$ExpenseDraftFromJson(json);
}

/// A parte de recorrência de um rascunho.
@freezed
abstract class ExpenseRecurrenceDraft with _$ExpenseRecurrenceDraft {
  const factory ExpenseRecurrenceDraft({
    @Default('monthly') String frequency,
    @JsonKey(name: 'dayOfMonth') @Default(1) int dayOfMonth,
    @JsonKey(name: 'monthOfYear') int? monthOfYear,
    @JsonKey(name: 'endsOn') String? endsOn,
  }) = _ExpenseRecurrenceDraft;

  factory ExpenseRecurrenceDraft.fromJson(Map<String, dynamic> json) =>
      _$ExpenseRecurrenceDraftFromJson(json);
}

/// Um mês de contas + os totais que a tela mostra no topo.
@freezed
abstract class ExpensesMonth with _$ExpensesMonth {
  const factory ExpensesMonth({
    @Default(<Expense>[]) List<Expense> items,
    @Default(<ExpenseCategory>[]) List<ExpenseCategory> categories,

    /// As REGRAS citadas pelas contas do mês. Sem elas a tela não teria como
    /// dizer "próxima em 10/09" ao dar baixa numa conta fixa: a próxima
    /// ocorrência é uma linha de OUTRO mês, ausente desta listagem.
    @Default(<ExpenseRecurrence>[]) List<ExpenseRecurrence> recurrences,

    /// Somas vêm do servidor: ele enxerga o mês inteiro mesmo se a lista for
    /// paginada, e a conta de "quanto ainda devo" não pode depender do que
    /// coube na tela.
    @JsonKey(name: 'totalPrevisto') @Default(0) num totalPrevisto,
    @JsonKey(name: 'totalPago') @Default(0) num totalPago,
    @JsonKey(name: 'totalEmAberto') @Default(0) num totalEmAberto,
    @JsonKey(name: 'totalVencido') @Default(0) num totalVencido,
  }) = _ExpensesMonth;

  factory ExpensesMonth.fromJson(Map<String, dynamic> json) =>
      _$ExpensesMonthFromJson(json);
}

/// Retorno da consulta de CNPJ, para preencher o fornecedor da conta.
///
/// Só o que o formulário usa. A fonte pública devolve muito mais (endereço,
/// telefone), mas guardar tudo na despesa seria inventar cadastro de fornecedor —
/// e esse é outro módulo.
@freezed
abstract class ExpenseSupplierLookup with _$ExpenseSupplierLookup {
  const factory ExpenseSupplierLookup({
    /// Documento só com dígitos, como vai para o banco.
    @Default('') String doc,
    @JsonKey(name: 'razaoSocial') @Default('') String razaoSocial,
    @JsonKey(name: 'nomeFantasia') String? nomeFantasia,

    /// "ATIVA", "BAIXADA"… A tela avisa quando não está ativa: pagar boleto de
    /// empresa baixada é sinal de golpe.
    String? situacao,
  }) = _ExpenseSupplierLookup;

  const ExpenseSupplierLookup._();

  factory ExpenseSupplierLookup.fromJson(Map<String, dynamic> json) =>
      _$ExpenseSupplierLookupFromJson(json);

  /// Nome que o campo recebe: o fantasia é como a oficina chama o fornecedor no
  /// dia a dia; a razão social é a reserva.
  String get nomeUsual =>
      (nomeFantasia?.trim().isNotEmpty ?? false) ? nomeFantasia!.trim() : razaoSocial;
}

/// Uma conta com o contexto que o DETALHE mostra.
///
/// Separado de [Expense] de propósito: a lista do mês carrega dezenas de contas e
/// não deve arrastar regra e irmãs de cada uma. Quem abre uma conta paga o custo
/// só daquela.
@freezed
abstract class ExpenseDetail with _$ExpenseDetail {
  const factory ExpenseDetail({
    required Expense expense,

    /// A regra que gerou a conta (`null` quando avulsa ou parcelada).
    ExpenseRecurrence? recurrence,

    /// As irmãs do parcelamento, em ordem. Vazio quando não é parcelada.
    @Default(<Expense>[]) List<Expense> parcelas,
  }) = _ExpenseDetail;

  const ExpenseDetail._();

  factory ExpenseDetail.fromJson(Map<String, dynamic> json) =>
      _$ExpenseDetailFromJson(json);

  /// Total da dívida parcelada = SOMA das irmãs. Não há coluna de total, de
  /// propósito: uma parcela corrigida (juros num mês) mudaria o total, e um campo
  /// gravado ficaria mentindo.
  num get totalParcelado =>
      parcelas.fold<num>(0, (soma, p) => soma + p.amount);

  /// Quantas parcelas do grupo já foram pagas — "3 de 6 pagas" no detalhe.
  int get parcelasPagas => parcelas.where((p) => p.pago).length;
}
