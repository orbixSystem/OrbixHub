import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/billing/domain/billing_models.dart';

/// Parses the EXACT payloads observed against the real backend (smoke test on
/// 2026-06-05), pinning the contract → models mapping (criteria 6 & 7).
void main() {
  test('parses /me from the real contract', () {
    final me = Me.fromJson({
      'user': {
        'id': 'u1',
        'email': 'dono@teste.com',
        'fullName': 'Dono Teste',
        'emailVerified': false,
      },
      'activeTenant': {'id': 't1', 'slug': 'oficina-teste', 'name': 'Oficina Teste'},
      'role': 'owner',
      'permissions': ['os.read', 'os.write', 'billing.manage', 'tenant.manage'],
      'modules': ['os', 'customers'],
      'memberships': [
        {'tenantId': 't1', 'tenantSlug': 'oficina-teste', 'role': 'owner'},
      ],
    });

    expect(me.role, 'owner');
    expect(me.user.email, 'dono@teste.com');
    expect(me.hasModule('os'), isTrue);
    expect(me.hasModule('inventory'), isFalse);
    expect(me.hasPermission('billing.manage'), isTrue);
    expect(me.hasMultipleTenants, isFalse);
    expect(me.memberships.single.tenantSlug, 'oficina-teste');
  });

  test('parses a /billing/plans entry (with priceCents)', () {
    final plan = Plan.fromJson({
      'key': 'pro',
      'name': 'Pro',
      'priceCents': 9900,
      'billingPeriod': 'monthly',
      'modules': ['os', 'inventory', 'customers'],
    });

    expect(plan.key, 'pro');
    expect(plan.priceCents, 9900);
    expect(plan.billingPeriod, 'monthly');
    expect(plan.modules, hasLength(3));
  });

  test('parses /billing/subscription (trialing, with trialEndsAt + nulls)', () {
    final sub = Subscription.fromJson({
      'planKey': 'trial',
      'status': 'trialing',
      'trialEndsAt': '2026-06-19T18:00:10.382Z',
      'currentPeriodStart': null,
      'currentPeriodEnd': null,
      'canceledAt': null,
    });

    expect(sub.planKey, 'trial');
    expect(sub.isTrialing, isTrue);
    expect(sub.isPastDue, isFalse);
    expect(sub.trialEndsAt, isNotNull);
    expect(sub.currentPeriodStart, isNull);
  });
}
