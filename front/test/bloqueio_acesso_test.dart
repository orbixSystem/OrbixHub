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
    // O texto do bloqueio TOTAL, nao o do modo consulta: uma edicao anterior
    // trocou um pelo outro e a tela passou a dizer "voce continua vendo tudo"
    // embaixo de um cadeado.
    expect(
      find.textContaining('nenhuma área do sistema está disponível'),
      findsOneWidget,
    );
    expect(find.text('Oficina Teste'), findsOneWidget);
    expect(find.textContaining('venceu em 1 de setembro'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Entendi, continuar'), findsNothing);
  });

  /// Bloqueio posto à mão pela Orbix: o acesso pago ainda está em dia, e a data
  /// não explica nada. Mostrá-la dizia "bloqueado agora" e "vence daqui a três
  /// semanas" na mesma tela, e o cliente ia esperar a data em vez de ligar.
  testWidgets('bloqueio manual não anuncia uma data de vencimento futura', (
    tester,
  ) async {
    final futuro = DateTime.now().add(const Duration(days: 21));
    await tester.pumpWidget(
      _emTela(
        BloqueioTotalView(
          me: Me(
            user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono Teste'),
            activeTenant: const Tenant(id: 't1', slug: 's1', name: 'Oficina Teste'),
            role: 'owner',
            assinatura: Assinatura(
              status: 'canceled',
              acessoAte: futuro,
              podeLer: false,
              podeEscrever: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Acesso bloqueado'), findsOneWidget);
    expect(find.textContaining('vence'), findsNothing);
    expect(find.textContaining('venceu'), findsNothing);
  });

  testWidgets('bloqueio de escrita avisa e deixa seguir', (tester) async {
    await tester.pumpWidget(_emTela(AvisoDeEscritaView(me: _me(podeEscrever: false))));
    await tester.pump();

    expect(find.text('Sistema em modo consulta'), findsOneWidget);
    expect(find.text('Entendi, continuar'), findsOneWidget);
  });

  /// O motivo é a razão de a pessoa estar nesta tela — e é o MESMO texto que
  /// ela recebeu por e-mail. Sem ele a tela só diz "bloqueado", que é a
  /// informação que ela já tinha.
  testWidgets('a tela mostra o motivo que veio do servidor', (tester) async {
    await tester.pumpWidget(
      _emTela(
        BloqueioTotalView(
          me: Me(
            user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
            activeTenant: const Tenant(id: 't1', slug: 's1', name: 'Oficina Teste'),
            role: 'owner',
            assinatura: const Assinatura(
              status: 'canceled',
              motivo: 'Acesso vencido — pagamento não identificado.',
              podeLer: false,
              podeEscrever: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Acesso vencido — pagamento não identificado.'),
      findsOneWidget,
    );
    expect(find.text('Falar com o suporte'), findsOneWidget);
  });
}
