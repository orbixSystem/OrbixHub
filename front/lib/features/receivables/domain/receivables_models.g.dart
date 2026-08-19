// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receivables_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Debtor _$DebtorFromJson(Map<String, dynamic> json) => _Debtor(
  customerId: json['customerId'] as String?,
  customerName: json['customerName'] as String? ?? 'Sem cliente',
  totalDue: json['totalDue'] as num? ?? 0,
  titleCount: (json['titleCount'] as num?)?.toInt() ?? 0,
  oldestAt: json['oldestAt'] as String?,
);

Map<String, dynamic> _$DebtorToJson(_Debtor instance) => <String, dynamic>{
  'customerId': instance.customerId,
  'customerName': instance.customerName,
  'totalDue': instance.totalDue,
  'titleCount': instance.titleCount,
  'oldestAt': instance.oldestAt,
};

_PendingSettlement _$PendingSettlementFromJson(Map<String, dynamic> json) =>
    _PendingSettlement(
      count: (json['count'] as num?)?.toInt() ?? 0,
      total: json['total'] as num? ?? 0,
    );

Map<String, dynamic> _$PendingSettlementToJson(_PendingSettlement instance) =>
    <String, dynamic>{'count': instance.count, 'total': instance.total};

_DebtorsPage _$DebtorsPageFromJson(Map<String, dynamic> json) => _DebtorsPage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => Debtor.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Debtor>[],
  totalDue: json['totalDue'] as num? ?? 0,
  pendingSettlement: json['pendingSettlement'] == null
      ? const PendingSettlement()
      : PendingSettlement.fromJson(
          json['pendingSettlement'] as Map<String, dynamic>,
        ),
  truncated: json['truncated'] as bool? ?? false,
);

Map<String, dynamic> _$DebtorsPageToJson(_DebtorsPage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'totalDue': instance.totalDue,
      'pendingSettlement': instance.pendingSettlement.toJson(),
      'truncated': instance.truncated,
    };

_ReceivableItem _$ReceivableItemFromJson(Map<String, dynamic> json) =>
    _ReceivableItem(
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String?,
      quantity: json['quantity'] as num? ?? 0,
      unitPrice: json['unitPrice'] as num? ?? 0,
      total: json['total'] as num? ?? 0,
    );

Map<String, dynamic> _$ReceivableItemToJson(_ReceivableItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'kind': instance.kind,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'total': instance.total,
    };

_ReceivableTitle _$ReceivableTitleFromJson(Map<String, dynamic> json) =>
    _ReceivableTitle(
      id: json['id'] as String,
      origin: json['origin'] as String? ?? 'sale',
      number: json['number'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      total: json['total'] as num? ?? 0,
      paid: json['paid'] as num? ?? 0,
      balance: json['balance'] as num? ?? 0,
      status: json['status'] as String? ?? 'a_receber',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => ReceivableItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ReceivableItem>[],
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
    );

Map<String, dynamic> _$ReceivableTitleToJson(_ReceivableTitle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'origin': instance.origin,
      'number': instance.number,
      'createdAt': instance.createdAt,
      'total': instance.total,
      'paid': instance.paid,
      'balance': instance.balance,
      'status': instance.status,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'customerId': instance.customerId,
      'customerName': instance.customerName,
    };

_OpenTitlesPage _$OpenTitlesPageFromJson(Map<String, dynamic> json) =>
    _OpenTitlesPage(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => ReceivableTitle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ReceivableTitle>[],
      totalDue: json['totalDue'] as num? ?? 0,
      truncated: json['truncated'] as bool? ?? false,
    );

Map<String, dynamic> _$OpenTitlesPageToJson(_OpenTitlesPage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'totalDue': instance.totalDue,
      'truncated': instance.truncated,
    };

_DebtorDetail _$DebtorDetailFromJson(Map<String, dynamic> json) =>
    _DebtorDetail(
      customerName: json['customerName'] as String? ?? 'Sem cliente',
      totalDue: json['totalDue'] as num? ?? 0,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => ReceivableTitle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ReceivableTitle>[],
    );

Map<String, dynamic> _$DebtorDetailToJson(_DebtorDetail instance) =>
    <String, dynamic>{
      'customerName': instance.customerName,
      'totalDue': instance.totalDue,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };
