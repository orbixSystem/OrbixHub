import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/app_shell.dart';

/// Ações rápidas (menu "+"): MÓDULO + PERMISSÃO, função pura — mesmo padrão de
/// `gatedNavItems`, testado por fora da árvore de widgets (o `AppShell` exige
/// GoRouter, e montá-lo só para conferir uma lista é frágil).
///
/// "Nova despesa" mudou de dono: era lançamento do Caixa (`cashier.manage` +
/// diálogo de saída) e passou a ser cadastro de **conta a pagar** do módulo
/// `expenses` (`finance.write`). O gasto continua caindo no caixa — pela baixa da
/// conta —, mas agora com vencimento, categoria e fornecedor.

Me _me({required List<String> permissoes, required List<String> modulos}) => Me(
      user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
      activeTenant: const Tenant(id: 't1', slug: 'demo', name: 'Oficina Demo'),
      role: 'owner',
      permissions: permissoes,
      modules: modulos,
    );

Iterable<String> _labels(Me me) => quickActionsFor(me).map((a) => a.label);

void main() {
  test('com o módulo expenses e finance.write, Nova despesa aparece', () {
    final labels = _labels(_me(
      permissoes: ['finance.write', 'sale.write'],
      modulos: ['expenses', 'sale'],
    ));
    expect(labels, contains('Nova venda'));
    expect(labels, contains('Nova despesa'));
  });

  test('cashier.manage já NÃO basta: despesa não é mais ação do caixa', () {
    // Regressão que este teste guarda: se alguém reapontar a ação para o
    // diálogo do caixa, o gating volta e este caso falha.
    final labels = _labels(_me(
      permissoes: ['cashier.manage', 'cashier.write', 'sale.write'],
      modulos: ['cashier', 'sale'],
    ));
    expect(labels, contains('Nova venda'));
    expect(labels, isNot(contains('Nova despesa')));
  });

  test('sem o módulo expenses, não oferece despesa', () {
    final labels = _labels(_me(
      permissoes: ['finance.write', 'sale.write'],
      modulos: ['sale'],
    ));
    expect(labels, isNot(contains('Nova despesa')));
  });

  test('só leitura de financeiro não oferece despesa', () {
    final labels = _labels(_me(
      permissoes: ['finance.read'],
      modulos: ['expenses'],
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
        'finance.write',
        'customer.write',
        'inventory.write',
      ],
      modulos: ['os', 'sale', 'expenses', 'customers', 'inventory'],
    ));
    final chaves = acoes.map((a) => a.key).toList();
    expect(chaves.toSet().length, chaves.length);
    expect(chaves, contains('expense'));
  });

  test('a ação de despesa existe no switch de execução', () {
    final acoes = quickActionsFor(_me(
      permissoes: ['finance.write'],
      modulos: ['expenses'],
    ));
    expect(acoes.single.key, 'expense');
  });
}
