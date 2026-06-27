import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/report/presentation/report_catalog.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

/// A feature `report` é gated por módulo `report` + `report.read`. Cada relatório
/// exige adicionalmente o seu módulo-fonte (os/inventory/customers). O item de
/// menu "Relatórios" aparece via `me.modules` (vem do backend), não hardcoded.
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
  test('sem módulo report → nenhum relatório', () {
    final me = _me(
      modules: ['os', 'inventory', 'customers'],
      permissions: ['report.read', 'os.read'],
    );
    expect(availableReports(me), isEmpty);
  });

  test('com módulo report mas sem report.read → nenhum relatório', () {
    final me = _me(
      modules: ['report', 'os'],
      permissions: ['os.read'],
    );
    expect(availableReports(me), isEmpty);
  });

  test('owner com report + os/inventory/customers → todos os relatórios', () {
    final me = _me(
      modules: ['report', 'os', 'inventory', 'customers'],
      permissions: ['report.read'],
    );
    final kinds = availableReports(me).map((r) => r.kind).toSet();

    expect(kinds, contains(ReportKind.osOperational));
    expect(kinds, contains(ReportKind.revenue));
    expect(kinds, contains(ReportKind.team));
    expect(kinds, contains(ReportKind.topItems));
    expect(kinds, contains(ReportKind.inventoryPosition));
    expect(kinds, contains(ReportKind.customers));
  });

  test('report habilitado mas sem o módulo inventory → sem relatório de estoque',
      () {
    final me = _me(
      modules: ['report', 'os'], // sem inventory/customers
      permissions: ['report.read'],
    );
    final kinds = availableReports(me).map((r) => r.kind).toSet();

    expect(kinds, contains(ReportKind.osOperational));
    expect(kinds, isNot(contains(ReportKind.inventoryPosition)));
    expect(kinds, isNot(contains(ReportKind.customers)));
  });

  test('menu inclui "Relatórios" em /m/report quando report está em me.modules',
      () {
    final me = _me(
      modules: ['report'],
      permissions: ['report.read'],
    );
    final routes = gatedNavItems(me).map((i) => i.route).toList();
    expect(routes, contains('/m/report'));

    final reportItem =
        gatedNavItems(me).firstWhere((i) => i.route == '/m/report');
    expect(reportItem.label, 'Relatórios');
  });

  test('sem o módulo report → "Relatórios" não aparece no menu', () {
    final me = _me(modules: ['os'], permissions: ['os.read']);
    final routes = gatedNavItems(me).map((i) => i.route).toList();
    expect(routes, isNot(contains('/m/report')));
  });
}
