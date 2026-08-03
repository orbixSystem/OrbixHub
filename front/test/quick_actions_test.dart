import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/app_shell.dart';

/// Ações rápidas (menu "+"): MÓDULO + PERMISSÃO, função pura — mesmo padrão de
/// `gatedNavItems`, testado por fora da árvore de widgets (o `AppShell` exige
/// GoRouter, e montá-lo só para conferir uma lista é frágil).
///
/// "Nova despesa" exige `cashier.manage`, não `cashier.write`: o backend recusa
/// despesa a quem só pode lançar recebimento, então oferecer a ação a esse cargo
/// seria convidar o usuário a um erro.

Me _me({required List<String> permissoes, required List<String> modulos}) => Me(
      user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
      activeTenant: const Tenant(id: 't1', slug: 'demo', name: 'Oficina Demo'),
      role: 'owner',
      permissions: permissoes,
      modules: modulos,
    );

Iterable<String> _labels(Me me) => quickActionsFor(me).map((a) => a.label);

void main() {
  test('com cashier.manage, Nova despesa entra ao lado de Nova venda', () {
    final labels = _labels(_me(
      permissoes: ['cashier.manage', 'cashier.write', 'sale.write'],
      modulos: ['cashier', 'sale'],
    ));
    expect(labels, contains('Nova venda'));
    expect(labels, contains('Nova despesa'));
  });

  test('só com cashier.write NÃO oferece despesa (o backend recusaria)', () {
    final labels = _labels(_me(
      permissoes: ['cashier.write', 'sale.write'],
      modulos: ['cashier', 'sale'],
    ));
    expect(labels, contains('Nova venda'));
    expect(labels, isNot(contains('Nova despesa')));
  });

  test('sem o módulo cashier, não oferece despesa', () {
    final labels = _labels(_me(
      permissoes: ['cashier.manage', 'sale.write'],
      modulos: ['sale'],
    ));
    expect(labels, isNot(contains('Nova despesa')));
  });

  test('sem módulo nem permissão nenhuma, o menu fica vazio', () {
    expect(quickActionsFor(_me(permissoes: [], modulos: [])), isEmpty);
  });

  test('cada ação tem chave única (o switch do _run casa por chave)', () {
    final acoes = quickActionsFor(_me(
      permissoes: [
        'os.write',
        'sale.write',
        'cashier.manage',
        'customer.write',
        'inventory.write',
      ],
      modulos: ['os', 'sale', 'cashier', 'customers', 'inventory'],
    ));
    final chaves = acoes.map((a) => a.key).toList();
    expect(chaves.toSet().length, chaves.length);
    expect(chaves, contains('expense'));
  });
}
