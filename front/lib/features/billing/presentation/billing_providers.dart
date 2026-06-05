import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../domain/billing_models.dart';

/// Plans from `GET /billing/plans` — rendered dynamically, never hardcoded.
final plansProvider = FutureProvider<List<Plan>>((ref) {
  return ref.read(billingRepositoryProvider).fetchPlans();
});

/// Current subscription from `GET /billing/subscription` (null if none).
final subscriptionProvider = FutureProvider<Subscription?>((ref) {
  return ref.read(billingRepositoryProvider).fetchSubscription();
});
