// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cashier_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CashSession _$CashSessionFromJson(Map<String, dynamic> json) => _CashSession(
  id: json['id'] as String,
  status: json['status'] as String? ?? 'open',
  openingAmount: json['opening_amount'] as String? ?? '0',
  openedAt: json['opened_at'] as String?,
  closedAt: json['closed_at'] as String?,
  closingAmountCounted: json['closing_amount_counted'] as String?,
  closingAmountExpected: json['closing_amount_expected'] as String?,
  difference: json['difference'] as String?,
  notes: json['notes'] as String?,
  byMethod:
      (json['byMethod'] as List<dynamic>?)
          ?.map((e) => MethodTotal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MethodTotal>[],
  totals: json['totals'] == null
      ? null
      : SessionTotals.fromJson(json['totals'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CashSessionToJson(_CashSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'opening_amount': instance.openingAmount,
      'opened_at': instance.openedAt,
      'closed_at': instance.closedAt,
      'closing_amount_counted': instance.closingAmountCounted,
      'closing_amount_expected': instance.closingAmountExpected,
      'difference': instance.difference,
      'notes': instance.notes,
      'byMethod': instance.byMethod.map((e) => e.toJson()).toList(),
      'totals': instance.totals?.toJson(),
    };

_SessionTotals _$SessionTotalsFromJson(Map<String, dynamic> json) =>
    _SessionTotals(
      inTotal: json['in'] as num? ?? 0,
      outTotal: json['out'] as num? ?? 0,
      expected: json['expected'] as num? ?? 0,
    );

Map<String, dynamic> _$SessionTotalsToJson(_SessionTotals instance) =>
    <String, dynamic>{
      'in': instance.inTotal,
      'out': instance.outTotal,
      'expected': instance.expected,
    };

_MethodTotal _$MethodTotalFromJson(Map<String, dynamic> json) => _MethodTotal(
  method: json['method'] as String,
  inAmount: json['in'] as num? ?? 0,
  outAmount: json['out'] as num? ?? 0,
);

Map<String, dynamic> _$MethodTotalToJson(_MethodTotal instance) =>
    <String, dynamic>{
      'method': instance.method,
      'in': instance.inAmount,
      'out': instance.outAmount,
    };

_KeyedTotal _$KeyedTotalFromJson(Map<String, dynamic> json) => _KeyedTotal(
  key: json['key'] as String,
  inAmount: json['in'] as num? ?? 0,
  outAmount: json['out'] as num? ?? 0,
);

Map<String, dynamic> _$KeyedTotalToJson(_KeyedTotal instance) =>
    <String, dynamic>{
      'key': instance.key,
      'in': instance.inAmount,
      'out': instance.outAmount,
    };

_CashEntry _$CashEntryFromJson(Map<String, dynamic> json) => _CashEntry(
  id: json['id'] as String,
  direction: json['direction'] as String,
  amount: json['amount'] as String? ?? '0',
  method: json['method'] as String,
  category: json['category'] as String,
  saleKind: json['sale_kind'] as String?,
  saleId: json['sale_id'] as String?,
  description: json['description'] as String?,
  reversedAt: json['reversed_at'] as String?,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$CashEntryToJson(_CashEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'direction': instance.direction,
      'amount': instance.amount,
      'method': instance.method,
      'category': instance.category,
      'sale_kind': instance.saleKind,
      'sale_id': instance.saleId,
      'description': instance.description,
      'reversed_at': instance.reversedAt,
      'created_at': instance.createdAt,
    };

_EntryPage _$EntryPageFromJson(Map<String, dynamic> json) => _EntryPage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => CashEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CashEntry>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$EntryPageToJson(_EntryPage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };

_SessionPage _$SessionPageFromJson(Map<String, dynamic> json) => _SessionPage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => CashSession.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CashSession>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$SessionPageToJson(_SessionPage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };

_CashSummary _$CashSummaryFromJson(Map<String, dynamic> json) => _CashSummary(
  byMethod:
      (json['byMethod'] as List<dynamic>?)
          ?.map((e) => MethodTotal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MethodTotal>[],
  byCategory:
      (json['byCategory'] as List<dynamic>?)
          ?.map((e) => KeyedTotal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <KeyedTotal>[],
  byOrigin:
      (json['byOrigin'] as List<dynamic>?)
          ?.map((e) => KeyedTotal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <KeyedTotal>[],
  totalIn: json['totalIn'] as num? ?? 0,
  totalOut: json['totalOut'] as num? ?? 0,
  net: json['net'] as num? ?? 0,
);

Map<String, dynamic> _$CashSummaryToJson(_CashSummary instance) =>
    <String, dynamic>{
      'byMethod': instance.byMethod.map((e) => e.toJson()).toList(),
      'byCategory': instance.byCategory.map((e) => e.toJson()).toList(),
      'byOrigin': instance.byOrigin.map((e) => e.toJson()).toList(),
      'totalIn': instance.totalIn,
      'totalOut': instance.totalOut,
      'net': instance.net,
    };

_PaymentDetail _$PaymentDetailFromJson(Map<String, dynamic> json) =>
    _PaymentDetail(
      total: json['total'] as num? ?? 0,
      paid: json['paid'] as num? ?? 0,
      balance: json['balance'] as num? ?? 0,
      status: json['status'] as String? ?? 'a_receber',
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => CashEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CashEntry>[],
    );

Map<String, dynamic> _$PaymentDetailToJson(_PaymentDetail instance) =>
    <String, dynamic>{
      'total': instance.total,
      'paid': instance.paid,
      'balance': instance.balance,
      'status': instance.status,
      'entries': instance.entries.map((e) => e.toJson()).toList(),
    };

_CashierConfig _$CashierConfigFromJson(Map<String, dynamic> json) =>
    _CashierConfig(
      paymentMethods:
          (json['paymentMethods'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[
            'pix',
            'dinheiro',
            'cartao_credito',
            'cartao_debito',
            'outro',
          ],
      requireOpenSession: json['requireOpenSession'] as bool? ?? false,
      countCashOnly: json['countCashOnly'] as bool? ?? true,
    );

Map<String, dynamic> _$CashierConfigToJson(_CashierConfig instance) =>
    <String, dynamic>{
      'paymentMethods': instance.paymentMethods,
      'requireOpenSession': instance.requireOpenSession,
      'countCashOnly': instance.countCashOnly,
    };

_ExpenseTemplate _$ExpenseTemplateFromJson(Map<String, dynamic> json) =>
    _ExpenseTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: json['amount'] as String? ?? '0',
      category: json['category'] as String? ?? 'despesa',
      method: json['method'] as String?,
      status: json['status'] as String? ?? 'active',
    );

Map<String, dynamic> _$ExpenseTemplateToJson(_ExpenseTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'amount': instance.amount,
      'category': instance.category,
      'method': instance.method,
      'status': instance.status,
    };
