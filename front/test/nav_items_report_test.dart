import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

/// Relatórios é o único módulo com visibilidade gerencial: além do módulo
/// `report` habilitado, exige `report.read` (owner/gerente). Mecânico/caixa não
/// veem o item no menu.
Me _me({
  List<String> modules = const [],
  List<String> permissions = const [],
  String role = 'owner',
}) =>
    Me(
      user: const User(id: 'u1', email: 'me@b.c', fullName: 'Me'),
      activeTenant: const Tenant(id: 't1', slug: 's1', name: 'N1'),
      role: role,
      permissions: permissions,
      modules: modules,
    );

void main() {
  test('Relatórios aparece para quem tem o módulo report E report.read', () {
    final me = _me(
      modules: ['os', 'report'],
      permissions: ['os.read', 'report.read'],
    );
    final routes = gatedNavItems(me).map((i) => i.route);
    expect(routes, contains('/m/report'));
  });

  test('Relatórios NÃO aparece sem report.read (mecânico)', () {
    final me = _me(
      role: 'mechanic',
      modules: ['os', 'report'], // módulo habilitado no tenant…
      permissions: ['os.read'], // …mas o mecânico não tem report.read
    );
    final routes = gatedNavItems(me).map((i) => i.route);
    expect(routes, isNot(contains('/m/report')));
    // Outros módulos do tenant continuam visíveis.
    expect(routes, contains('/m/os'));
  });
}
