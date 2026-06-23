import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/dashboard/presentation/dashboard_registry.dart';

/// `dashboardWidgets(me)` é puro e espelha `gatedNavItems`: um widget só entra
/// se `me.modules` tem o módulo E `me.hasPermission` a permissão. OS é role-aware
/// (report.read → gerencial; senão operacional).
Me _me({
  required List<String> modules,
  required List<String> permissions,
  String role = 'owner',
}) =>
    Me(
      user: const User(id: 'u1', email: 'a@b.c', fullName: 'U'),
      activeTenant: const Tenant(id: 't1', slug: 's1', name: 'N1'),
      role: role,
      permissions: permissions,
      modules: modules,
    );

void main() {
  test('owner: OS gerencial + estoque + clientes', () {
    final me = _me(
      modules: ['os', 'inventory', 'customers'],
      permissions: [
        'os.read',
        'inventory.read',
        'customer.read',
        'report.read',
      ],
    );
    final kinds = dashboardWidgets(me).map((s) => s.kind).toList();

    expect(kinds, contains(DashboardWidgetKind.osManagement));
    expect(kinds, isNot(contains(DashboardWidgetKind.osOperational)));
    expect(kinds, contains(DashboardWidgetKind.inventory));
    expect(kinds, contains(DashboardWidgetKind.customers));
  });

  test('mecânico (os.read, sem report.read): só OS operacional', () {
    final me = _me(
      role: 'mechanic',
      modules: ['os', 'inventory', 'customers'],
      permissions: ['os.read'], // sem inventory.read / customer.read
    );
    final kinds = dashboardWidgets(me).map((s) => s.kind).toList();

    expect(kinds, [DashboardWidgetKind.osOperational]);
    expect(kinds, isNot(contains(DashboardWidgetKind.osManagement)));
    // Sem inventory.read → SEM widget de estoque, mesmo com o módulo habilitado.
    expect(kinds, isNot(contains(DashboardWidgetKind.inventory)));
    expect(kinds, isNot(contains(DashboardWidgetKind.customers)));
  });

  test('mecânico sem os.read: nenhum widget de OS', () {
    final me = _me(
      role: 'mechanic',
      modules: ['os'],
      permissions: [], // sem os.read
    );
    expect(dashboardWidgets(me), isEmpty);
  });

  test('tenant sem o módulo inventory: widget de estoque ausente', () {
    final me = _me(
      modules: ['os', 'customers'], // inventory NÃO habilitado
      permissions: [
        'os.read',
        'inventory.read', // tem a permissão, mas não o módulo
        'customer.read',
        'report.read',
      ],
    );
    final kinds = dashboardWidgets(me).map((s) => s.kind).toList();

    expect(kinds, contains(DashboardWidgetKind.osManagement));
    expect(kinds, isNot(contains(DashboardWidgetKind.inventory)));
    expect(kinds, contains(DashboardWidgetKind.customers));
  });

  test('cada spec declara o módulo e a permissão exigidos', () {
    final me = _me(
      modules: ['os', 'inventory', 'customers'],
      permissions: [
        'os.read',
        'inventory.read',
        'customer.read',
        'report.read',
      ],
    );
    for (final spec in dashboardWidgets(me)) {
      expect(me.hasModule(spec.moduleKey), isTrue);
      expect(me.hasPermission(spec.permission), isTrue);
    }
  });
}
