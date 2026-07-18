import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/offline_routes.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';

Me _me(List<String> modules) => Me(
      user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
      role: 'owner',
      permissions: const [],
      modules: modules,
    );

void main() {
  group('isOnlineOnlyRoute', () {
    test('rotas 100% online-only bloqueiam (redirect + modal)', () {
      for (final loc in const [
        '/billing',
        '/m/invoice',
        '/m/invoice/abc',
        '/m/report',
        '/agenda',
        '/agenda/horarios',
        '/equipe',
      ]) {
        expect(isOnlineOnlyRoute(loc), isTrue, reason: loc);
      }
    });

    test('CRUD e telas parciais NÃO bloqueiam', () {
      for (final loc in const [
        '/', // dashboard (bloqueia por seção, não redireciona)
        '/m/os',
        '/m/os/1',
        '/m/customers',
        '/m/customers/9',
        '/m/inventory',
        '/m/sales',
        '/m/sales/nova',
        '/mensagens', // histórico legível offline
        '/mensagens/42',
        '/configuracoes', // Aparência funciona offline
      ]) {
        expect(isOnlineOnlyRoute(loc), isFalse, reason: loc);
      }
    });
  });

  group('offlineSafeRoute', () {
    test('prefere OS, depois clientes, depois estoque', () {
      expect(offlineSafeRoute(_me(['os', 'customers', 'inventory'])), '/m/os');
      expect(offlineSafeRoute(_me(['customers', 'inventory'])), '/m/customers');
      expect(offlineSafeRoute(_me(['inventory'])), '/m/inventory');
    });

    test('sem nenhum módulo de CRUD cai no Início', () {
      expect(offlineSafeRoute(_me(['report', 'invoice'])), '/');
    });
  });
}
