import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orbixhub_front/core/devtools/dev_inbox_overlay.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_screen.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/customers/presentation/customers_screen.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_screen.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/order_edit_dialog.dart';
import 'package:orbixhub_front/features/os/presentation/os_detail_screen.dart';
import 'package:orbixhub_front/features/os/presentation/os_list_screen.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';

/// Layout em CELULAR, com conteúdo do pior caso.
///
/// Overflow no Flutter não quebra o app: ele pinta a faixa amarela e listra a
/// borda — em produção o usuário vê "linha quebrada", texto cortado, coluna
/// escapando. Em teste, o mesmo overflow vira exceção, então basta renderizar
/// cada tela numa largura de celular real e conferir que nada estourou.
///
/// 360x640 é o piso que ainda aparece em aparelhos Android em uso; se passa
/// aqui, passa nos maiores.
const _telaPequena = Size(360, 640);
const _telaComum = Size(390, 844);

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
    Me(
      user: User(id: 'u1', email: 'a@b.c', fullName: 'Gabriel Inácio'),
      role: 'owner',
      permissions: [
        'os.read',
        'os.write',
        'os.approve',
        'customer.read',
        'customer.write',
        'subject.read',
        'inventory.read',
        'inventory.write',
        'cashier.read',
        'cashier.write',
        'cashier.manage',
        'report.read',
      ],
      modules: ['os', 'customers', 'inventory', 'cashier'],
      features: [
        'customers.identifierLookup',
        'customers.atributosCascata',
        'customers.fichaTecnica',
        'os.trackingLink',
      ],
      activeTenant: Tenant(
        id: 't1',
        name: 'Oficina do Gabriel Automóveis e Serviços',
        slug: 'oficina',
      ),
    ),
  );
}

/// OS com os textos longos que a vida real produz — é o que expõe layout frágil.
const _osPesada = ServiceOrder(
  id: 'os-1',
  number: 'OS-0042',
  customerId: 'c1',
  customerName: 'Maria Aparecida de Souza Albuquerque Filha',
  subjectId: 's1',
  subjectLabel: 'Volkswagen CrossFox 1.6 Total Flex — ABC1D23',
  status: 'aguardando_aprovacao',
  complaint: 'Cliente relata barulho na suspensão dianteira ao passar em '
      'lombadas, além de vibração no volante acima de 80 km/h e cheiro de '
      'queimado depois de rodar mais de meia hora.',
  diagnosis: 'Bieletas e coxins desgastados; disco dianteiro empenado; '
      'necessária troca do kit de embreagem por desgaste avançado.',
  publicToken: 'tok-123',
  discount: '0',
  total: '4587.90',
  items: [
    OrderItem(
      id: 'i1',
      name: 'Kit de embreagem completo (platô, disco e atuador hidráulico)',
      kind: 'product',
      quantity: '1',
      unitPrice: '1899.90',
      total: '1899.90',
    ),
    OrderItem(
      id: 'i2',
      name: 'Mão de obra — substituição do kit de embreagem e sangria',
      kind: 'service',
      quantity: '4',
      unitPrice: '672.00',
      total: '2688.00',
    ),
  ],
  events: [
    OrderEvent(
      id: 'e1',
      kind: 'note',
      message: 'Peça encomendada no fornecedor; prazo de entrega de dois dias '
          'úteis conforme confirmado por telefone.',
    ),
  ],
);

Widget _wrap(Widget child, {List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(_OnlineConn.new),
      sessionControllerProvider.overrideWith(_FakeSession.new),
      osRepositoryProvider
          .overrideWithValue(FakeOsRepository(orders: const [_osPesada])),
      customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
      cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
      ...extra,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

/// Monta a tela no tamanho dado e falha se qualquer coisa estourou o layout.
Future<void> _semOverflow(
  WidgetTester tester,
  Widget tela, {
  Size size = _telaPequena,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(tela));
  await tester.pumpAndSettle();

  final erro = tester.takeException();
  expect(
    erro,
    isNull,
    reason: 'layout estourou em ${size.width.toInt()}x${size.height.toInt()}: '
        '$erro',
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR', null));

  group('detalhe da OS (a tela mais densa do app)', () {
    testWidgets('tela pequena (360x640)', (tester) async {
      await _semOverflow(tester, const OsDetailScreen(orderId: 'os-1'));
    });

    testWidgets('celular comum (390x844)', (tester) async {
      await _semOverflow(
        tester,
        const OsDetailScreen(orderId: 'os-1'),
        size: _telaComum,
      );
    });

    testWidgets('rolando até o fim da OS', (tester) async {
      tester.view.physicalSize = _telaPequena;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const OsDetailScreen(orderId: 'os-1')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('datas de previsão nos formulários de OS', () {
    // Em meia tela de celular, "Previsão início (opcional)" + a data não cabem:
    // o texto aperta e a linha quebra. Empilhados, cada campo tem a largura toda.
    testWidgets('editar OS: celular empilha os dois campos', (tester) async {
      tester.view.physicalSize = _telaComum;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const OrderEditDialog(order: _osPesada)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Empilhado: os dois rótulos aparecem em X iguais (mesma coluna).
      final inicio = tester.getTopLeft(find.text('Previsão início (opcional)'));
      final fim = tester.getTopLeft(find.text('Previsão fim (opcional)'));
      expect(inicio.dx, fim.dx, reason: 'devem estar na mesma coluna');
      expect(fim.dy, greaterThan(inicio.dy), reason: 'fim abaixo do início');
    });

    testWidgets('editar OS: desktop mantém lado a lado', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const OrderEditDialog(order: _osPesada)),
      );
      await tester.pumpAndSettle();

      final inicio = tester.getTopLeft(find.text('Previsão início (opcional)'));
      final fim = tester.getTopLeft(find.text('Previsão fim (opcional)'));
      expect(fim.dx, greaterThan(inicio.dx), reason: 'lado a lado');
      expect(fim.dy, inicio.dy, reason: 'na mesma altura');
    });
  });

  group('acesso ao logout', () {
    // No celular não há sidebar nem drawer (a navegação é a barra de baixo),
    // então sem este botão não havia como encerrar a sessão no aparelho.
    testWidgets('celular: o chrome oferece "Sair"', (tester) async {
      tester.view.physicalSize = _telaComum;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const Stack(children: [SizedBox.expand(), GlobalControls()])),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Sair'), findsOneWidget);
    });

    testWidgets('desktop: não duplica (já existe na sidebar)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const Stack(children: [SizedBox.expand(), GlobalControls()])),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Sair'), findsNothing);
    });
  });

  group('demais telas em celular', () {
    testWidgets('lista de OS', (tester) async {
      await _semOverflow(tester, const OsListScreen());
    });

    testWidgets('clientes', (tester) async {
      await _semOverflow(tester, const CustomersScreen());
    });

    testWidgets('estoque', (tester) async {
      await _semOverflow(tester, const InventoryScreen());
    });

    testWidgets('caixa', (tester) async {
      await _semOverflow(tester, const CashierScreen());
    });
  });
}
