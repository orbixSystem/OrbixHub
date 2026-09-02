import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/os_detail_screen.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';

/// A barra de ações da ficha da OS: UM indicador de status no cabeçalho (não
/// tocável) + UMA ação primária rotulada (Finalizar OS / Reabrir OS); o resto
/// — inclusive cancelar, que é destrutiva — fica separado: no celular atrás do
/// menu "Mais" (onde a largura é escassa), no desktop à vista mas marcado.
/// Tocar na ação avança AUTOMATICAMENTE pelo caminho mais
/// curto de passos reais da FSM, preservando os efeitos colaterais de cada
/// passo (a baixa de estoque dispara por transição real). Sem gate manual de
/// aprovação: a FSM já tem saída direta de 'aberta' pra 'em_execucao'.
class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

class _FakeSession extends SessionController {
  _FakeSession({this.canApprove = true});
  final bool canApprove;

  @override
  SessionState build() => SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'Gabriel Inácio'),
          role: 'owner',
          permissions: [
            'os.read',
            'os.write',
            if (canApprove) 'os.approve',
          ],
          modules: const ['os'],
          activeTenant: Tenant(id: 't1', name: 'Oficina', slug: 'oficina'),
        ),
      );
}

/// Grava a SEQUÊNCIA de status reais chamados via `changeStatus`, para provar
/// que o avanço automático dispara passo a passo (não pula pro fim).
class _RecordingOsRepository extends FakeOsRepository {
  _RecordingOsRepository({required super.orders});
  final List<String> calls = [];

  @override
  Future<ServiceOrder> changeStatus(String id, String status) async {
    calls.add(status);
    return super.changeStatus(id, status);
  }
}

ServiceOrder _os(String status) => ServiceOrder(
      id: 'os-1',
      number: 'OS-0001',
      customerId: 'c1',
      customerName: 'Cliente Teste',
      status: status,
      total: '100',
      discount: '0',
    );

Widget _wrap(
  Widget child,
  _RecordingOsRepository repo, {
  bool canApprove = true,
}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(_OnlineConn.new),
      sessionControllerProvider
          .overrideWith(() => _FakeSession(canApprove: canApprove)),
      osRepositoryProvider.overrideWithValue(repo),
      customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    'aberta: badge mostra "Em andamento" e o botão é "Finalizar OS" — avança até entregue, sem gate de confirmação',
    (tester) async {
      final repo = _RecordingOsRepository(orders: [_os('aberta')]);
      await tester.pumpWidget(
        _wrap(const OsDetailScreen(orderId: 'os-1'), repo),
      );
      await tester.pumpAndSettle();

      // Um indicador SÓ, não um seletor de 3 estados.
      expect(find.text('Em andamento'), findsOneWidget);
      expect(find.text('Finalizada'), findsNothing);
      expect(find.text('Cancelada'), findsNothing);

      // "Confirmar entrega?" não existe mais — era um passo sem sentido
      // próprio. Finalizar age direto (a OS de teste não tem módulo cashier,
      // então não há diálogo de pagamento pra aguardar também).
      await tester.tap(find.text('Finalizar OS'));
      await tester.pumpAndSettle();

      // A FSM tem uma saída DIRETA de 'aberta' pra 'em_execucao' — o caminho
      // automático usa o mais curto, sem passar pela aprovação (que "deixou
      // de ser um gate").
      expect(repo.calls, ['em_execucao', 'concluida', 'entregue']);
    },
  );

  testWidgets(
      'cancelar é destrutiva e separada da primária: pede confirmação e '
      'cancela num passo só', (tester) async {
    final repo = _RecordingOsRepository(orders: [_os('aberta')]);
    await tester.pumpWidget(
      _wrap(const OsDetailScreen(orderId: 'os-1'), repo),
    );
    await tester.pumpAndSettle();

    // No desktop as ações extras ficam todas à vista (o menu "Mais" é só do
    // celular) — mas cancelar vem marcada como destrutiva e longe da primária.
    expect(find.text('Mais'), findsNothing);
    await tester.tap(find.text('Cancelar OS'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar OS?'), findsOneWidget);
    // .last: o botão original (por baixo) e o do diálogo têm o MESMO rótulo.
    await tester.tap(find.text('Cancelar OS').last);
    await tester.pumpAndSettle();

    expect(repo.calls, ['cancelada']);
  });

  testWidgets(
    'concluida: badge mostra "Finalizada" e o único botão é "Finalizar OS" (falta o último passo)',
    (tester) async {
      final repo = _RecordingOsRepository(orders: [_os('concluida')]);
      await tester.pumpWidget(
        _wrap(const OsDetailScreen(orderId: 'os-1'), repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finalizada'), findsOneWidget);
      // Nem "Cancelar OS" (a FSM não permite mais).
      expect(find.text('Cancelar OS'), findsNothing);

      await tester.tap(find.text('Finalizar OS'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['entregue']);
    },
  );

  testWidgets(
    'entregue: sem avanço nem cancelamento, mas REABRE (pedindo confirmação)',
    (tester) async {
      final repo = _RecordingOsRepository(orders: [_os('entregue')]);
      await tester.pumpWidget(
        _wrap(const OsDetailScreen(orderId: 'os-1'), repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finalizada'), findsOneWidget);
      expect(find.text('Finalizar OS'), findsNothing);
      // Cancelar segue proibido: a FSM não deixa uma OS finalizada virar
      // cancelada, nem passando por uma reabertura silenciosa.
      expect(find.text('Cancelar OS'), findsNothing);

      // Reabrir avisa o que muda antes de mexer em número já fechado.
      await tester.tap(find.text('Reabrir OS'));
      await tester.pumpAndSettle();
      expect(find.text('Reabrir OS finalizada?'), findsOneWidget);
      // .last: o botão original (por baixo) e o do diálogo têm o MESMO rótulo.
      await tester.tap(find.text('Reabrir OS').last);
      await tester.pumpAndSettle();

      // Volta para `em_execucao`, NÃO para `aberta` — os dois consomem estoque,
      // então corrigir não faz a peça ir e voltar da prateleira.
      expect(repo.calls, ['em_execucao']);
    },
  );

  testWidgets(
    'entregue sem os.approve: nem reabrir nem excluir — só a nota',
    (tester) async {
      final repo = _RecordingOsRepository(orders: [_os('entregue')]);
      await tester.pumpWidget(
        _wrap(const OsDetailScreen(orderId: 'os-1'), repo, canApprove: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reabrir OS'), findsNothing);
      expect(find.text('Excluir OS'), findsNothing);
      expect(
        find.text('OS entregue — somente leitura. Reabra para corrigir algo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'entregue com os.approve: "Excluir OS" existe e pede confirmação',
    (tester) async {
      final repo = _RecordingOsRepository(orders: [_os('entregue')]);
      await tester.pumpWidget(
        _wrap(const OsDetailScreen(orderId: 'os-1'), repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Excluir OS'));
      await tester.pumpAndSettle();

      // A confirmação diz as duas consequências invisíveis: sai do faturamento
      // e as peças voltam ao estoque.
      expect(find.text('Excluir OS OS-0001?'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelada: reabrir exige os.approve — sem a permissão, nenhum botão aparece',
    (tester) async {
      final repo = _RecordingOsRepository(orders: [_os('cancelada')]);
      await tester.pumpWidget(
        _wrap(const OsDetailScreen(orderId: 'os-1'), repo, canApprove: false),
      );
      await tester.pumpAndSettle();

      // Sem permissão, nenhum botão de ação aparece — só o indicador e a nota.
      expect(find.text('Reabrir OS'), findsNothing);
      expect(find.text('OS cancelada.'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelada: COM os.approve, toca "Reabrir" e chama changeStatus(aberta) sem confirmação',
    (tester) async {
      final repo = _RecordingOsRepository(orders: [_os('cancelada')]);
      await tester.pumpWidget(
        _wrap(const OsDetailScreen(orderId: 'os-1'), repo, canApprove: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reabrir OS'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['aberta']);
    },
  );
}
