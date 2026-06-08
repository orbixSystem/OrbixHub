import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

/// Criterion 4: navigation items appear/disappear by role + enabled module.
void main() {
  Me makeMe({
    required String role,
    required List<String> modules,
    required List<String> permissions,
  }) {
    return Me(
      user: const User(id: 'u1', email: 'a@b.c', fullName: 'U'),
      activeTenant: const Tenant(id: 't1', slug: 's1', name: 'N1'),
      role: role,
      permissions: permissions,
      modules: modules,
    );
  }

  test('owner sees enabled modules + Planos, not disabled modules', () {
    final me = makeMe(
      role: 'owner',
      modules: ['os', 'customers'],
      permissions: ['billing.manage'],
    );
    final labels = gatedNavItems(me).map((i) => i.label).toList();

    expect(labels, contains('Início'));
    expect(labels, contains('Ordens de Serviço')); // os enabled
    expect(labels, contains('Clientes')); // customers enabled
    expect(labels, contains('Planos')); // billing.manage
    expect(labels, isNot(contains('Estoque'))); // inventory NOT enabled
  });

  test('mechanic without billing.manage never sees Planos', () {
    final me = makeMe(
      role: 'mechanic',
      modules: ['os'],
      permissions: ['os.read', 'os.write'],
    );
    final labels = gatedNavItems(me).map((i) => i.label).toList();

    expect(labels, contains('Ordens de Serviço'));
    expect(labels, isNot(contains('Planos')));
    expect(labels, isNot(contains('Clientes')));
  });

  test('unknown module key falls back to its key as label', () {
    final me = makeMe(role: 'owner', modules: ['fiscal'], permissions: []);
    final labels = gatedNavItems(me).map((i) => i.label).toList();
    expect(labels, contains('fiscal'));
  });

  test('selectedNavIndex picks the longest matching route', () {
    final me = makeMe(
      role: 'owner',
      modules: ['os'],
      permissions: ['billing.manage'],
    );
    final items = gatedNavItems(me);
    expect(selectedNavIndex(items, '/'), 0);
    expect(items[selectedNavIndex(items, '/m/os')].route, '/m/os');
    expect(items[selectedNavIndex(items, '/billing')].route, '/billing');
  });
}
