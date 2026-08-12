import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

/// Chave de módulo sem rótulo/ícone declarado é estrutura interna (entitlement
/// legado como `sales`, módulo sem tela ainda) e não pode chegar ao cliente.
/// Antes ela virava um item cru: a chave em inglês + ícone de quebra-cabeça.
Me _me({List<String> modules = const [], List<String> permissions = const []}) =>
    Me(
      user: const User(id: 'u1', email: 'me@b.c', fullName: 'Me'),
      activeTenant: const Tenant(id: 't1', slug: 's1', name: 'N1'),
      role: 'owner',
      permissions: permissions,
      modules: modules,
    );

void main() {
  test('módulo legado `sales` nunca vira item de menu', () {
    final me = _me(
      modules: ['os', 'sales', 'sale'],
      permissions: ['os.read'],
    );
    final items = gatedNavItems(me);
    expect(items.map((i) => i.route), isNot(contains('/m/sales')));
    expect(items.map((i) => i.route), isNot(contains('/m/sale')));
    expect(items.map((i) => i.label), isNot(contains('sales')));
    // O que é conhecido continua aparecendo.
    expect(items.map((i) => i.route), contains('/m/os'));
  });

  test('qualquer chave desconhecida é ignorada, não vira item genérico', () {
    final me = _me(
      modules: ['os', 'modulo_que_nao_existe'],
      permissions: ['os.read'],
    );
    final items = gatedNavItems(me);
    expect(items.map((i) => i.route), isNot(contains('/m/modulo_que_nao_existe')));
    expect(items.length, gatedNavItems(_me(modules: ['os'], permissions: ['os.read'])).length);
  });

  test('todo módulo com rótulo declarado continua navegável', () {
    final me = _me(
      modules: ['os', 'customers', 'inventory', 'cashier'],
      permissions: ['os.read'],
    );
    final routes = gatedNavItems(me).map((i) => i.route);
    expect(routes, containsAll(['/m/os', '/m/customers', '/m/inventory', '/m/cashier']));
  });
}
