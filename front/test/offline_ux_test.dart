import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/offline/widgets/offline_notices.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_screen.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/customers/domain/customers_models.dart';
import 'package:orbixhub_front/features/customers/presentation/subject_form_dialog.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/inventory/presentation/item_form_dialog.dart';
import 'package:orbixhub_front/features/invoice/data/fake_invoice_repository.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/domain/os_repository.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';
import 'package:orbixhub_front/features/os/presentation/os_detail_screen.dart';
import 'package:orbixhub_front/features/os/presentation/os_list_screen.dart';
import 'package:orbixhub_front/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub_front/features/team/presentation/team_screen.dart';

/// Fake do controller de conectividade (B3): nunca assina o platform channel
/// real — o teste força online/offline.
class _FakeConn extends ConnectivityController {
  _FakeConn(this._status);
  final ConnStatus _status;

  @override
  ConnState build() => ConnState(status: _status);
}

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
          role: 'owner',
          permissions: [
            'os.write',
            'os.approve',
            'os.read',
            'invoice.issue',
            'inventory.write',
            'customers.write',
            'cashier.write',
            'cashier.manage',
          ],
          modules: ['os', 'invoice', 'inventory', 'customers', 'cashier'],
        ),
      );
}

/// Monta a tela com a sessão fixa e a conectividade forçada. Os repositórios
/// são sempre fakes (nenhum toca a rede).
Widget _wrap(
  Widget child, {
  required ConnStatus status,
  OsRepository? os,
}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(() => _FakeConn(status)),
      sessionControllerProvider.overrideWith(_FakeSession.new),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      osRepositoryProvider.overrideWithValue(os ?? FakeOsRepository()),
      invoiceRepositoryProvider.overrideWithValue(FakeInvoiceRepository()),
      inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
      customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

const _order = ServiceOrder(
  id: 'os-1',
  number: 'OS-0001',
  customerId: 'c1',
  customerName: 'João da Silva',
  subjectLabel: 'Gol 2012',
  status: 'em_execucao',
  diagnosis: 'Correia gasta',
  publicToken: 'tok-123',
  total: '150.00',
  photos: [OrderPhoto(id: 'p1', url: '')],
  events: [OrderEvent(id: 'e1', kind: 'note', message: 'Peça encomendada')],
);

FakeOsRepository _osRepo() => FakeOsRepository(orders: const [_order]);

const _config = CustomersConfig(
  subjectFields: [
    SubjectFieldConfig(chave: 'marca', rotulo: 'Marca', fonte: 'fipe.marcas'),
    SubjectFieldConfig(
      chave: 'modelo',
      rotulo: 'Modelo',
      fonte: 'fipe.modelos',
      dependeDe: 'marca',
    ),
    SubjectFieldConfig(chave: 'identifier', rotulo: 'Placa'),
  ],
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Telas largas: o detalhe da OS usa layout de duas colunas no desktop.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('detalhe da OS', () {
    testWidgets('offline: aviso vermelho em fotos, diagnóstico e notas; link '
        'de acompanhamento e NF desabilitados', (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        const OsDetailScreen(orderId: 'os-1'),
        status: ConnStatus.offline,
        os: _osRepo(),
      ));
      await tester.pumpAndSettle();

      // Um aviso vermelho por seção: diagnóstico, linha do tempo e fotos.
      expect(find.byType(OfflinePendingNoticeBody), findsNWidgets(3));
      expect(
        find.textContaining('Será enviado ao sistema quando a conexão voltar'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Notas criadas agora'),
        findsOneWidget,
      );
      expect(find.textContaining('As fotos adicionadas agora'), findsOneWidget);

      // Ações que exigem servidor: link de acompanhamento + emitir NF.
      final blocked = tester
          .widgetList<IgnorePointer>(find.descendant(
            of: find.byType(RequiresConnection),
            matching: find.byType(IgnorePointer),
          ))
          .toList();
      expect(blocked, hasLength(2));
      expect(blocked.every((w) => w.ignoring), isTrue);
      expect(
        find.byTooltip(
          'Requer conexão — o envio do link ao cliente exige internet',
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip(
          'Requer conexão — a nota é emitida pelo servidor fiscal',
        ),
        findsOneWidget,
      );
    });

    testWidgets('online: nenhum aviso vermelho e ações liberadas',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        const OsDetailScreen(orderId: 'os-1'),
        status: ConnStatus.online,
        os: _osRepo(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OfflinePendingNoticeBody), findsNothing);
      // Online o RequiresConnection não bloqueia nada (não injeta IgnorePointer
      // nem tooltip) e as ações seguem tocáveis.
      expect(
        find.descendant(
          of: find.byType(RequiresConnection),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
      );
      expect(find.textContaining('Requer conexão'), findsNothing);
      expect(find.text('Copiar link'), findsOneWidget);
    });
  });

  group('lista de OS', () {
    testWidgets('número provisório OS-P… ganha o selo "pendente de envio"',
        (tester) async {
      final repo = FakeOsRepository(
        orders: const [
          ServiceOrder(
            id: 'os-p',
            number: 'OS-P1',
            customerId: 'c1',
            customerName: 'Maria',
          ),
          ServiceOrder(
            id: 'os-1',
            number: 'OS-0001',
            customerId: 'c2',
            customerName: 'João',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(
        const OsListScreen(),
        status: ConnStatus.offline,
        os: repo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('OS-P1'), findsOneWidget);
      expect(find.text('OS-0001'), findsOneWidget);
      // Só a OS provisória é badgeada.
      expect(find.byType(PendingSyncBadge), findsOneWidget);
      expect(find.text('Pendente de envio'), findsOneWidget);
    });
  });

  group('estoque — formulário de item', () {
    testWidgets('offline: lookup por código de barras desabilitado + mensagem',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ItemFormDialog(),
        status: ConnStatus.offline,
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'a consulta automática por código de barras não está disponível',
        ),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Buscar e preencher'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull); // desabilitado
    });

    testWidgets('online: lookup habilitado, sem mensagem offline',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ItemFormDialog(),
        status: ConnStatus.online,
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('a consulta automática por código de barras'),
        findsNothing,
      );
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Buscar e preencher'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('clientes — formulário de veículo', () {
    testWidgets('offline: cascata FIPE vira texto livre com dica',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const SubjectFormDialog(customerId: 'c1', config: _config),
        status: ConnStatus.offline,
      ));
      await tester.pumpAndSettle();

      // Sem Autocomplete (a cascata sumiu) e com a dica em cada campo de fonte.
      expect(find.byType(Autocomplete<LookupOption>), findsNothing);
      expect(find.text('Sem conexão — digite manualmente'), findsNWidgets(2));
      expect(find.byKey(const Key('subjectField-marca')), findsOneWidget);
      expect(find.byKey(const Key('subjectField-modelo')), findsOneWidget);
    });

    testWidgets('online: a cascata FIPE (Autocomplete) continua',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const SubjectFormDialog(customerId: 'c1', config: _config),
        status: ConnStatus.online,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Autocomplete<LookupOption>), findsNWidgets(2));
      expect(find.text('Sem conexão — digite manualmente'), findsNothing);
    });
  });

  group('caixa', () {
    testWidgets('offline: aviso permanente de que os lançamentos só sobem '
        'quando a conexão voltar', (tester) async {
      await tester.pumpWidget(_wrap(
        const CashierScreen(),
        status: ConnStatus.offline,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineScreenNotice), findsOneWidget);
      expect(
        find.textContaining(
          'só serão efetivados no sistema quando a conexão voltar',
        ),
        findsOneWidget,
      );
    });

    testWidgets('online: sem aviso', (tester) async {
      await tester.pumpWidget(_wrap(
        const CashierScreen(),
        status: ConnStatus.online,
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('só serão efetivados no sistema'),
        findsNothing,
      );
    });
  });

  group('telas online-only', () {
    testWidgets('equipe offline → RequiresConnectionView', (tester) async {
      await tester.pumpWidget(_wrap(
        const TeamScreen(),
        status: ConnStatus.offline,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RequiresConnectionView), findsOneWidget);
      expect(find.text('Requer conexão'), findsOneWidget);
    });
  });
}
