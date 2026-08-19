import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

/// A ordem da sidebar é decisão de produto e mora em `gatedNavItems` — não na
/// ordem em que `/me` devolve `modules[]`. Este teste trava a ordem pedida pelo
/// dono: o que se usa todo dia primeiro (caixa → OS → despesas → estoque →
/// mensagens), o resto depois.
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
  test('menu completo sai na ordem de produto, não na ordem do /me', () {
    final me = _me(
      // Ordem PROPOSITALMENTE embaralhada (é o que o backend manda hoje): o
      // menu não pode herdá-la.
      modules: ['os', 'inventory', 'customers', 'report', 'expenses', 'cashier'],
      permissions: ['os.read', 'report.read', 'users.manage'],
    );

    expect(
      gatedNavItems(me).map((i) => i.label).toList(),
      [
        'Início',
        'Caixa',
        'Ordens de Serviço',
        'Despesas',
        'Estoque',
        'Mensagens',
        'Clientes',
        'Relatórios',
        'Agenda',
        'Equipe',
        'Configurações',
      ],
    );
  });

  test('Início continua sendo o primeiro item (selectedNavIndex conta com isso)',
      () {
    final items = gatedNavItems(
      _me(modules: ['cashier', 'os'], permissions: ['os.read']),
    );
    expect(items.first.route, '/');
    expect(selectedNavIndex(items, '/'), 0);
  });

  test('a ordem se mantém com o tenant tendo só parte dos módulos', () {
    final me = _me(
      modules: ['inventory', 'cashier'], // sem OS, sem despesas
      permissions: ['os.read'],
    );
    expect(
      gatedNavItems(me).map((i) => i.label).toList(),
      ['Início', 'Caixa', 'Estoque', 'Mensagens', 'Configurações'],
    );
  });
}
