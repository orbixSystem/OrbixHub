// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Plan _$PlanFromJson(Map<String, dynamic> json) => _Plan(
  key: json['key'] as String,
  name: json['name'] as String,
  priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
  billingPeriod: json['billingPeriod'] as String,
  modules:
      (json['modules'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$PlanToJson(_Plan instance) => <String, dynamic>{
  'key': instance.key,
  'name': instance.name,
  'priceCents': instance.priceCents,
  'billingPeriod': instance.billingPeriod,
  'modules': instance.modules,
};

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      planKey: json['planKey'] as String,
      status: json['status'] as String,
      trialEndsAt: json['trialEndsAt'] == null
          ? null
          : DateTime.parse(json['trialEndsAt'] as String),
      currentPeriodStart: json['currentPeriodStart'] == null
          ? null
          : DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd: json['currentPeriodEnd'] == null
          ? null
          : DateTime.parse(json['currentPeriodEnd'] as String),
      canceledAt: json['canceledAt'] == null
          ? null
          : DateTime.parse(json['canceledAt'] as String),
    );

Map<String, dynamic> _$SubscriptionToJson(_Subscription instance) =>
    <String, dynamic>{
      'planKey': instance.planKey,
      'status': instance.status,
      'trialEndsAt': instance.trialEndsAt?.toIso8601String(),
      'currentPeriodStart': instance.currentPeriodStart?.toIso8601String(),
      'currentPeriodEnd': instance.currentPeriodEnd?.toIso8601String(),
      'canceledAt': instance.canceledAt?.toIso8601String(),
    };
