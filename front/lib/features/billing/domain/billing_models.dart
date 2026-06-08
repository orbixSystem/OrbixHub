import 'package:freezed_annotation/freezed_annotation.dart';

part 'billing_models.freezed.dart';
part 'billing_models.g.dart';

/// A subscribable plan from `GET /billing/plans`. Rendered DYNAMICALLY — the app
/// never hardcodes plan keys/names or the module list; everything comes from the
/// backend at runtime.
@freezed
abstract class Plan with _$Plan {
  const factory Plan({
    required String key,
    required String name,
    @Default(0) int priceCents,
    required String billingPeriod,
    @Default(<String>[]) List<String> modules,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);
}

/// The tenant's current subscription from `GET /billing/subscription`.
@freezed
abstract class Subscription with _$Subscription {
  const Subscription._();

  const factory Subscription({
    required String planKey,
    required String status,
    DateTime? trialEndsAt,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    DateTime? canceledAt,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  bool get isTrialing => status == 'trialing';
  bool get isActive => status == 'active';
  bool get isPastDue => status == 'past_due';
  bool get isCanceled => status == 'canceled';
}
