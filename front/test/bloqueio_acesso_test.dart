import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/billing/presentation/bloqueio_view.dart';

/// O bloqueio só serve se o cliente VIR o bloqueio. Um 403 silencioso faz a
/// oficina achar que o sistema quebrou — e ligar para o suporte em vez de
/// pagar.

Me _me({String? status, bool podeLer = true, bool podeEscrever = true}) => Me(
  user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono Teste'),
  activeTenant: const Tenant(id: 't1', slug: 's1', name: 'Oficina Teste'),
  role: 'owner',
  assinatura: Assinatura(
    status: status,
    acessoAte: DateTime(2026, 9, 1),
    podeLer: podeLer,
    podeEscrever: podeEscrever,
  ),
);

Widget _emTela(Widget child) => ProviderScope(
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('a régua vem decidida do /me', () {
    test('só leitura é ler sem escrever', () {
      expect(_me(podeEscrever: false).somenteLeitura, isTrue);
      expect(_me().somenteLeitura, isFalse);
      expect(
        _me(podeLer: false, podeEscrever: false).somenteLeitura,
        isFalse,
        reason: 'bloqueio total não é "só leitura" — é tela cheia',
      );
    });

    /// Backend antigo não manda o bloco. Negar acesso por causa de um campo que
    /// não veio seria pior erro que deixar passar.
    test('sem o bloco de assinatura, libera', () {
      const me = Me(
        user: User(id: 'u1', email: 'a@b.c', fullName: 'D'),
        role: 'owner',
      );
      expect(me.podeLer, isTrue);
      expect(me.podeEscrever, isTrue);
      expect(me.somenteLeitura, isFalse);
    });
  });

  testWidgets('bloqueio total diz o que houve e não oferece saída para dentro', (
    tester,
  ) async {
    await tester.pumpWidget(
      _emTela(BloqueioTotalView(me: _me(podeLer: false, podeEscrever: false))),
    );
    await tester.pump();

    expect(find.text('Acesso bloqueado'), findsOneWidget);
    expect(find.text('Oficina Teste'), findsOneWidget);
    expect(find.textContaining('venceu em 1 de setembro'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Entendi, continuar'), findsNothing);
  });

  testWidgets('bloqueio de escrita avisa e deixa seguir', (tester) async {
    await tester.pumpWidget(_emTela(AvisoDeEscritaView(me: _me(podeEscrever: false))));
    await tester.pump();

    expect(find.text('Sistema em modo consulta'), findsOneWidget);
    expect(find.text('Entendi, continuar'), findsOneWidget);
  });
}
