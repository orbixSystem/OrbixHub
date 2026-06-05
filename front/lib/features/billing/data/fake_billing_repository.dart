import '../domain/billing_models.dart';
import '../domain/billing_repository.dart';

/// In-memory [BillingRepository] mirroring the contract for tests/offline.
class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({List<Plan>? plans, Subscription? subscription})
      : _plans = plans ?? _defaultPlans,
        _subscription = subscription ?? _defaultSubscription;

  final List<Plan> _plans;
  Subscription? _subscription;

  static const _defaultPlans = [
    Plan(
      key: 'pro',
      name: 'Pro',
      priceCents: 9900,
      billingPeriod: 'monthly',
      modules: ['os', 'inventory', 'customers'],
    ),
  ];

  static const _defaultSubscription = Subscription(
    planKey: 'trial',
    status: 'trialing',
  );

  @override
  Future<List<Plan>> fetchPlans() async => _plans;

  @override
  Future<Subscription?> fetchSubscription() async => _subscription;

  @override
  Future<Subscription> subscribe(String planKey) async {
    _subscription = Subscription(planKey: planKey, status: 'active');
    return _subscription!;
  }

  @override
  Future<Subscription> changePlan(String planKey) async {
    _subscription = Subscription(planKey: planKey, status: 'active');
    return _subscription!;
  }
}
