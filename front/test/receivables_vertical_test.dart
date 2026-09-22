import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/receivables/data/fake_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_screen.dart';

/// "A receber" é GENÉRICO: serve oficina, assistência técnica, clínica.
///
/// Cobrança não muda com o nicho — quem deve, quanto e desde quando são as
/// mesmas perguntas. O que muda no produto é o "objeto" atendido (Veículo /
/// Equipamento), e ele não aparece nesta tela. O risco que estes testes pegam é
/// casca de oficina vazando: "placa", "veículo", "carro" hardcoded.
///
/// "OS" NÃO é casca: o pacote PADRÃO do produto (equipamentos) também diz
/// "OS aberta"/"OS cancelada". É vocabulário do sistema, não do nicho.

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

/// Oficina: vertical `veiculos`, com o vocabulário que o servidor manda.
class _SessaoOficina extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'dono@oficina.dev', fullName: 'Dono'),
          activeTenant: Tenant(id: 't1', slug: 'oficina', name: 'Oficina'),
          role: 'owner',
          permissions: ['cashier.read', 'cashier.write'],
          modules: ['cashier'],
          vertical: 'veiculos',
          vocab: {
            'objeto.singular': 'Veículo',
            'objeto.plural': 'Veículos',
            'objeto.identificador': 'Placa',
          },
        ),
      );
}

/// Nicho genérico (pacote padrão): assistência de equipamentos.
class _SessaoGenerica extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u2', email: 'dono@assistencia.dev', fullName: 'Dono'),
          activeTenant: Tenant(id: 't2', slug: 'assistencia', name: 'Assistência'),
          role: 'owner',
          permissions: ['cashier.read', 'cashier.write'],
          modules: ['cashier'],
          vertical: 'equipamentos',
          vocab: {
            'objeto.singular': 'Equipamento',
            'objeto.plural': 'Equipamentos',
            'objeto.identificador': 'Nome',
          },
        ),
      );
}

Widget _app(SessionController Function() sessao) => ProviderScope(
      overrides: [
        connectivityControllerProvider.overrideWith(_OnlineConn.new),
        sessionControllerProvider.overrideWith(sessao),
        receivablesRepositoryProvider
            .overrideWithValue(FakeReceivablesRepository(titulos: const [
          ReceivableTitle(
            id: 'x-os',
            origin: 'os',
            number: 'OS-0042',
            customerId: 'c1',
            customerName: 'João Silva',
            total: 480,
            balance: 480,
          ),
          ReceivableTitle(
            id: 'x-venda',
            origin: 'sale',
            number: '15',
            customerName: 'Zeca',
            total: 150,
            balance: 150,
          ),
        ])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ReceivablesScreen()),
      ),
    );

/// Palavras que só fazem sentido numa oficina. Se alguma aparecer, a tela
/// deixou de servir os outros nichos.
const _cascaDeOficina = ['Veículo', 'veículo', 'Placa', 'placa', 'Carro', 'carro'];

void main() {
  for (final caso in [
    ('oficina (veiculos)', _SessaoOficina.new),
    ('genérico (equipamentos)', _SessaoGenerica.new),
  ]) {
    group(caso.$1, () {
      testWidgets('a carteira funciona igual', (t) async {
        await t.pumpWidget(_app(caso.$2));
        await t.pumpAndSettle();

        expect(find.text('A receber'), findsOneWidget);
        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('Zeca'), findsOneWidget);
        expect(find.text('R\$ 630,00'), findsWidgets); // 480 + 150
      });

      testWidgets('nenhuma palavra de oficina na tela', (t) async {
        await t.pumpWidget(_app(caso.$2));
        await t.pumpAndSettle();

        for (final palavra in _cascaDeOficina) {
          expect(
            find.textContaining(palavra),
            findsNothing,
            reason: '"$palavra" é vocabulário de oficina e não pode aparecer '
                'numa tela genérica de cobrança',
          );
        }
      });

      testWidgets('os filtros continuam funcionando', (t) async {
        await t.pumpWidget(_app(caso.$2));
        await t.pumpAndSettle();

        // Origem é conceito do SISTEMA (OS x venda de balcão), não do nicho.
        await t.tap(find.text('OS'));
        await t.pumpAndSettle();
        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('Zeca'), findsNothing);
      });

      testWidgets('abrir o devedor mostra os títulos', (t) async {
        t.view.physicalSize = const Size(1200, 1400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);

        await t.pumpWidget(_app(caso.$2));
        await t.pumpAndSettle();
        await t.tap(find.text('João Silva'));
        await t.pumpAndSettle();

        expect(find.text('OS-0042'), findsOneWidget);
        for (final palavra in _cascaDeOficina) {
          expect(find.textContaining(palavra), findsNothing);
        }
      });
    });
  }
}
