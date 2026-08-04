// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExpenseCategory _$ExpenseCategoryFromJson(Map<String, dynamic> json) =>
    _ExpenseCategory(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? 'outros',
      color: json['color'] as String? ?? '#6B7280',
      tracksSupplier: json['tracks_supplier'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
    );

Map<String, dynamic> _$ExpenseCategoryToJson(_ExpenseCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'color': instance.color,
      'tracks_supplier': instance.tracksSupplier,
      'status': instance.status,
    };

_Expense _$ExpenseFromJson(Map<String, dynamic> json) => _Expense(
  id: json['id'] as String,
  description: json['description'] as String? ?? '',
  amount: json['amount'] == null
      ? 0
      : const _Decimal().fromJson(json['amount']),
  dueDate: json['due_date'] as String,
  categoryId: json['category_id'] as String?,
  recurrenceId: json['recurrence_id'] as String?,
  paidAt: json['paid_at'] as String?,
  paidAmount: const _DecimalOrNull().fromJson(json['paid_amount']),
  paidMethod: json['paid_method'] as String?,
  cashEntryId: json['cash_entry_id'] as String?,
  notes: json['notes'] as String?,
  installmentNo: (json['installment_no'] as num?)?.toInt(),
  installmentTotal: (json['installment_total'] as num?)?.toInt(),
  installmentGroupId: json['installment_group_id'] as String?,
  supplierName: json['supplier_name'] as String?,
  supplierDoc: json['supplier_doc'] as String?,
  status: json['status'] as String? ?? 'active',
);

Map<String, dynamic> _$ExpenseToJson(_Expense instance) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'amount': const _Decimal().toJson(instance.amount),
  'due_date': instance.dueDate,
  'category_id': instance.categoryId,
  'recurrence_id': instance.recurrenceId,
  'paid_at': instance.paidAt,
  'paid_amount': const _DecimalOrNull().toJson(instance.paidAmount),
  'paid_method': instance.paidMethod,
  'cash_entry_id': instance.cashEntryId,
  'notes': instance.notes,
  'installment_no': instance.installmentNo,
  'installment_total': instance.installmentTotal,
  'installment_group_id': instance.installmentGroupId,
  'supplier_name': instance.supplierName,
  'supplier_doc': instance.supplierDoc,
  'status': instance.status,
};

_ExpenseRecurrence _$ExpenseRecurrenceFromJson(Map<String, dynamic> json) =>
    _ExpenseRecurrence(
      id: json['id'] as String,
      description: json['description'] as String? ?? '',
      amount: json['amount'] == null
          ? 0
          : const _Decimal().fromJson(json['amount']),
      categoryId: json['category_id'] as String?,
      frequency: json['frequency'] as String? ?? 'monthly',
      dayOfMonth: (json['day_of_month'] as num?)?.toInt() ?? 1,
      monthOfYear: (json['month_of_year'] as num?)?.toInt(),
      method: json['method'] as String?,
      notes: json['notes'] as String?,
      endsOn: json['ends_on'] as String?,
      status: json['status'] as String? ?? 'active',
    );

Map<String, dynamic> _$ExpenseRecurrenceToJson(_ExpenseRecurrence instance) =>
    <String, dynamic>{
      'id': instance.id,
      'description': instance.description,
      'amount': const _Decimal().toJson(instance.amount),
      'category_id': instance.categoryId,
      'frequency': instance.frequency,
      'day_of_month': instance.dayOfMonth,
      'month_of_year': instance.monthOfYear,
      'method': instance.method,
      'notes': instance.notes,
      'ends_on': instance.endsOn,
      'status': instance.status,
    };

_ExpenseDraft _$ExpenseDraftFromJson(Map<String, dynamic> json) =>
    _ExpenseDraft(
      description: json['description'] as String?,
      amount: json['amount'] as num?,
      dueDate: json['dueDate'] as String?,
      categoryId: json['categoryId'] as String?,
      notes: json['notes'] as String?,
      recorrencia: json['recorrencia'] == null
          ? null
          : ExpenseRecurrenceDraft.fromJson(
              json['recorrencia'] as Map<String, dynamic>,
            ),
      parcelas: (json['parcelas'] as num?)?.toInt(),
      installmentIds: (json['installmentIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      installmentGroupId: json['installmentGroupId'] as String?,
      supplierName: json['supplierName'] as String?,
      supplierDoc: json['supplierDoc'] as String?,
      limparCategoria: json['limparCategoria'] as bool? ?? false,
      limparFornecedor: json['limparFornecedor'] as bool? ?? false,
    );

Map<String, dynamic> _$ExpenseDraftToJson(_ExpenseDraft instance) =>
    <String, dynamic>{
      'description': instance.description,
      'amount': instance.amount,
      'dueDate': instance.dueDate,
      'categoryId': instance.categoryId,
      'notes': instance.notes,
      'recorrencia': instance.recorrencia?.toJson(),
      'parcelas': instance.parcelas,
      'installmentIds': instance.installmentIds,
      'installmentGroupId': instance.installmentGroupId,
      'supplierName': instance.supplierName,
      'supplierDoc': instance.supplierDoc,
      'limparCategoria': instance.limparCategoria,
      'limparFornecedor': instance.limparFornecedor,
    };

_ExpenseRecurrenceDraft _$ExpenseRecurrenceDraftFromJson(
  Map<String, dynamic> json,
) => _ExpenseRecurrenceDraft(
  frequency: json['frequency'] as String? ?? 'monthly',
  dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
  monthOfYear: (json['monthOfYear'] as num?)?.toInt(),
  endsOn: json['endsOn'] as String?,
);

Map<String, dynamic> _$ExpenseRecurrenceDraftToJson(
  _ExpenseRecurrenceDraft instance,
) => <String, dynamic>{
  'frequency': instance.frequency,
  'dayOfMonth': instance.dayOfMonth,
  'monthOfYear': instance.monthOfYear,
  'endsOn': instance.endsOn,
};

_ExpensesMonth _$ExpensesMonthFromJson(Map<String, dynamic> json) =>
    _ExpensesMonth(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Expense>[],
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => ExpenseCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ExpenseCategory>[],
      installmentGroups:
          (json['installmentGroups'] as List<dynamic>?)
              ?.map(
                (e) =>
                    InstallmentGroupSummary.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <InstallmentGroupSummary>[],
      recurrences:
          (json['recurrences'] as List<dynamic>?)
              ?.map(
                (e) => ExpenseRecurrence.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <ExpenseRecurrence>[],
      totalPrevisto: json['totalPrevisto'] as num? ?? 0,
      totalPago: json['totalPago'] as num? ?? 0,
      totalEmAberto: json['totalEmAberto'] as num? ?? 0,
      totalVencido: json['totalVencido'] as num? ?? 0,
    );

Map<String, dynamic> _$ExpensesMonthToJson(_ExpensesMonth instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'categories': instance.categories.map((e) => e.toJson()).toList(),
      'installmentGroups': instance.installmentGroups
          .map((e) => e.toJson())
          .toList(),
      'recurrences': instance.recurrences.map((e) => e.toJson()).toList(),
      'totalPrevisto': instance.totalPrevisto,
      'totalPago': instance.totalPago,
      'totalEmAberto': instance.totalEmAberto,
      'totalVencido': instance.totalVencido,
    };

_InstallmentGroupSummary _$InstallmentGroupSummaryFromJson(
  Map<String, dynamic> json,
) => _InstallmentGroupSummary(
  groupId: json['groupId'] as String? ?? '',
  total: json['total'] as num? ?? 0,
  count: (json['count'] as num?)?.toInt() ?? 0,
  paidCount: (json['paidCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$InstallmentGroupSummaryToJson(
  _InstallmentGroupSummary instance,
) => <String, dynamic>{
  'groupId': instance.groupId,
  'total': instance.total,
  'count': instance.count,
  'paidCount': instance.paidCount,
};

_ExpenseSupplierLookup _$ExpenseSupplierLookupFromJson(
  Map<String, dynamic> json,
) => _ExpenseSupplierLookup(
  doc: json['doc'] as String? ?? '',
  razaoSocial: json['razaoSocial'] as String? ?? '',
  nomeFantasia: json['nomeFantasia'] as String?,
  situacao: json['situacao'] as String?,
);

Map<String, dynamic> _$ExpenseSupplierLookupToJson(
  _ExpenseSupplierLookup instance,
) => <String, dynamic>{
  'doc': instance.doc,
  'razaoSocial': instance.razaoSocial,
  'nomeFantasia': instance.nomeFantasia,
  'situacao': instance.situacao,
};

_ExpenseDetail _$ExpenseDetailFromJson(Map<String, dynamic> json) =>
    _ExpenseDetail(
      expense: Expense.fromJson(json['expense'] as Map<String, dynamic>),
      recurrence: json['recurrence'] == null
          ? null
          : ExpenseRecurrence.fromJson(
              json['recurrence'] as Map<String, dynamic>,
            ),
      parcelas:
          (json['parcelas'] as List<dynamic>?)
              ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Expense>[],
    );

Map<String, dynamic> _$ExpenseDetailToJson(_ExpenseDetail instance) =>
    <String, dynamic>{
      'expense': instance.expense.toJson(),
      'recurrence': instance.recurrence?.toJson(),
      'parcelas': instance.parcelas.map((e) => e.toJson()).toList(),
    };
