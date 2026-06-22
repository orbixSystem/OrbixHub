import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

Me _me({List<String> permissions = const []}) => Me(
      user: const User(id: 'u1', email: 'me@b.c', fullName: 'Me'),
      role: 'owner',
      permissions: permissions,
    );

void main() {
  // Req: Configurações visível a QUALQUER membro autenticado — a tela interna
  // é que gatea empresa/módulos por settings.manage.
  test('Configurações aparece para quem tem settings.manage', () {
    final me = _me(permissions: ['settings.manage']);
    final items = gatedNavItems(me);
    expect(
      items.any((i) => i.route == '/configuracoes'),
      isTrue,
      reason: 'Esperado item com rota /configuracoes',
    );
  });

  test('Configurações TAMBÉM aparece para quem NÃO tem settings.manage (aparência é para todos)', () {
    final me = _me(permissions: ['os.read']);
    final items = gatedNavItems(me);
    expect(
      items.any((i) => i.route == '/configuracoes'),
      isTrue,
      reason: 'Item /configuracoes deve aparecer para qualquer membro autenticado',
    );
  });

  test('Configurações aparece para membro sem nenhuma permissão', () {
    final me = _me(permissions: []);
    final items = gatedNavItems(me);
    expect(
      items.any((i) => i.route == '/configuracoes'),
      isTrue,
      reason: 'Item /configuracoes deve aparecer independente de permissões',
    );
  });
}
