import 'billing_models.dart';

/// Billing contract: list plans, read the current subscription, and (owner-only)
/// subscribe / change plan. Backend enforces `billing.manage`; the client only
/// reflects it for UX. Real (dio) + fake impls, swapped via Riverpod.
abstract interface class BillingRepository {
  Future<List<Plan>> fetchPlans();

  Future<Subscription?> fetchSubscription();

  Future<Subscription> subscribe(String planKey);

  Future<Subscription> changePlan(String planKey);
}
