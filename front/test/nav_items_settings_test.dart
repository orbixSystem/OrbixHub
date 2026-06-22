import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

Me _me({List<String> permissions = const []}) => Me(
      user: const User(id: 'u1', email: 'me@b.c', fullName: 'Me'),
      role: 'owner',
      permissions: permissions,
    );

void main() {
  test('Configurações aparece para quem tem settings.manage', () {
    final me = _me(permissions: ['settings.manage']);
    final items = gatedNavItems(me);
    expect(
      items.any((i) => i.route == '/configuracoes'),
      isTrue,
      reason: 'Esperado item com rota /configuracoes',
    );
  });

  test('Configurações some sem settings.manage', () {
    final me = _me(permissions: ['os.read']);
    final items = gatedNavItems(me);
    expect(
      items.any((i) => i.route == '/configuracoes'),
      isFalse,
      reason: 'Item /configuracoes não deve aparecer sem settings.manage',
    );
  });
}
