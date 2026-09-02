import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/widgets/offline_notices.dart';
import 'package:orbixhub_front/core/offline/widgets/pending_changes_panel.dart';
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
import 'package:orbixhub_front/features/os/presentation/order_edit_dialog.dart';
import 'package:orbixhub_front/features/os/presentation/os_detail_screen.dart';
import 'package:orbixhub_front/features/os/presentation/os_list_screen.dart';
import 'package:orbixhub_front/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub_front/features/settings/presentation/settings_screen.dart';
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
      features: [
        'customers.identifierLookup',
        'customers.atributosCascata',
        'customers.fichaTecnica',
        'os.trackingLink',
      ],
    ),
  );
}

/// Monta a tela com a sessão fixa e a conectividade forçada. Os repositórios
/// são sempre fakes (nenhum toca a rede).
Widget _wrap(
  Widget child, {
  required ConnStatus status,
  OsRepository? os,
  List<Override> extra = const [],
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
      ...extra,
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
    SubjectFieldConfig(chave: 'identifier', rotulo: 'Placa', formato: 'placa'),
  ],
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Telas largas: o detalhe da OS usa layout de duas colunas no desktop.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('detalhe da OS', () {
    testWidgets(
        'offline: cada aba avisa o que fica pendente — diagnóstico (Serviço), '
        'notas (Histórico), fotos (Fotos) e link do cliente (Cliente)',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const OsDetailScreen(orderId: 'os-1'),
          status: ConnStatus.offline,
          os: _osRepo(),
        ),
      );
      await tester.pumpAndSettle();

      // A ficha agora é dividida em abas: o aviso de cada seção vive na aba
      // dela. Percorrer as quatro é o teste de que nenhuma perdeu o seu.
      Future<void> abrir(String aba) async {
        await tester.tap(find.text(aba));
        await tester.pumpAndSettle();
      }

      // Serviço (aba inicial): diagnóstico.
      expect(find.byType(OfflinePendingNoticeBody), findsOneWidget);
      expect(
        find.textContaining('Será enviado ao sistema quando a conexão voltar'),
        findsOneWidget,
      );

      await abrir('Histórico');
      expect(find.textContaining('Notas criadas agora'), findsOneWidget);

      await abrir('Fotos');
      expect(find.textContaining('As fotos adicionadas agora'), findsOneWidget);
      // Remover foto exige o registro NO SERVIDOR (não há op de sync para a
      // remoção): o botão fica visível e explicado, em vez de sumir.
      expect(find.byTooltip('Requer conexão — remover foto'), findsOneWidget);

      await abrir('Cliente');
      expect(
        find.byTooltip(
          'Requer conexão — o envio do link ao cliente exige internet',
        ),
        findsOneWidget,
      );
      // A emissão de NF foi retirada do front (kInvoiceEnabled=false).
      expect(
        find.byTooltip(
          'Requer conexão — a nota é emitida pelo servidor fiscal',
        ),
        findsNothing,
      );
      final blocked = tester
          .widgetList<IgnorePointer>(
            find.descendant(
              of: find.byType(RequiresConnection),
              matching: find.byType(IgnorePointer),
            ),
          )
          .toList();
      expect(blocked, isNotEmpty);
      expect(blocked.every((w) => w.ignoring), isTrue);
    });

    testWidgets('online: nenhum aviso vermelho e ações liberadas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const OsDetailScreen(orderId: 'os-1'),
          status: ConnStatus.online,
          os: _osRepo(),
        ),
      );
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
      await tester.tap(find.text('Cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Copiar link'), findsOneWidget);
    });
  });

  group('OrderEditDialog', () {
    testWidgets(
      'offline: aviso vermelho no responsável e nas datas de serviço',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const OrderEditDialog(order: _order),
            status: ConnStatus.offline,
            os: _osRepo(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'A troca de responsável só será enviada ao sistema '
            'quando a conexão voltar',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'As datas de serviço só serão enviadas ao sistema '
            'quando a conexão voltar',
          ),
          findsOneWidget,
        );
        expect(find.byType(OfflinePendingNoticeBody), findsNWidgets(2));
      },
    );

    testWidgets('online: nenhum aviso no dialog', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OrderEditDialog(order: _order),
          status: ConnStatus.online,
          os: _osRepo(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflinePendingNoticeBody), findsNothing);
    });
  });

  group('configurações', () {
    testWidgets('offline: Aparência (tema local) continua utilizável; o resto '
        'pede conexão', (tester) async {
      // Viewport alta: a tela é uma ListView (aparência em cima, "requer
      // conexão" embaixo) — no viewport padrão o segundo bloco não é montado.
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(const SettingsScreen(), status: ConnStatus.offline),
      );
      await tester.pumpAndSettle();

      // A seção local de aparência está lá (modo claro/escuro/sistema).
      expect(find.text('Aparência'), findsOneWidget);
      expect(find.text('Modo'), findsOneWidget);
      // E o restante (empresa/módulos, do servidor) é explicado.
      expect(find.byType(RequiresConnectionView), findsOneWidget);
    });
  });

  group('lista de OS', () {
    testWidgets('número provisório OS-P… ganha o selo "pendente de envio"', (
      tester,
    ) async {
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
      await tester.pumpWidget(
        _wrap(const OsListScreen(), status: ConnStatus.offline, os: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('OS-P1'), findsOneWidget);
      expect(find.text('OS-0001'), findsOneWidget);
      // Só a OS provisória é badgeada.
      expect(find.byType(PendingSyncBadge), findsOneWidget);
      expect(find.text('Pendente de envio'), findsOneWidget);
    });
  });

  group('falhas de sync (I4)', () {
    testWidgets(
      'linha cuja mutação FALHOU ganha o selo VERMELHO (não o neutro de pendente)',
      (tester) async {
        final repo = FakeOsRepository(
          orders: const [
            ServiceOrder(
              id: 'os-p',
              number: 'OS-P1',
              customerId: 'c1',
              customerName: 'Maria',
            ),
          ],
        );
        await tester.pumpWidget(
          _wrap(
            const OsListScreen(),
            status: ConnStatus.online,
            os: repo,
            extra: [
              failedIdsProvider(
                'service_order',
              ).overrideWith((ref) async => {'os-p'}),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FailedSyncBadge), findsOneWidget);
        expect(find.text('Falhou ao enviar'), findsOneWidget);
        expect(find.byType(PendingSyncBadge), findsNothing);
      },
    );

    testWidgets(
      'painel do indicador mostra a mensagem do servidor e o retry re-arma a mutação',
      (tester) async {
        final db = LocalDb(NativeDatabase.memory());
        addTearDown(db.close);
        await db.enqueue(
          LocalMutation(
            clientMutationId: 'm1',
            authorUserId: 'u1',
            entity: 'customer',
            op: 'create',
            payload: '{"id":"c1"}',
            clientUpdatedAt: DateTime.utc(2026, 7, 1),
          ),
        );
        await db.markOutbox('m1', 'failed', 'Documento já cadastrado.');

        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showPendingChangesPanel(context),
                child: const Text('abrir'),
              ),
            ),
            status: ConnStatus.online,
            extra: [
              localDbProvider.overrideWithValue(db),
              syncEngineProvider.overrideWithValue(null),
            ],
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();

        // A falha é nomeada em PT-BR, com o motivo VINDO DO SERVIDOR.
        expect(find.text('Alterações pendentes'), findsOneWidget);
        expect(find.text('Cliente — criação'), findsOneWidget);
        expect(find.text('Documento já cadastrado.'), findsOneWidget);
        expect(find.text('Falhou ao enviar'), findsOneWidget);

        await tester.tap(find.text('Tentar de novo'));
        await tester.pumpAndSettle();

        // Re-armada: volta para a fila (pending) e o SyncEngine a reenvia.
        expect(await db.failedIds('customer'), isEmpty);
        expect(await db.pendingFor('u1'), hasLength(1));
      },
    );
  });

  group('estoque — formulário de item', () {
    testWidgets(
      'offline: lookup por código de barras desabilitado + mensagem',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const ItemFormDialog(), status: ConnStatus.offline),
        );
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
      },
    );

    testWidgets('online: lookup habilitado, sem mensagem offline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ItemFormDialog(), status: ConnStatus.online),
      );
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
    testWidgets('offline: cascata FIPE vira texto livre com dica', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SubjectFormDialog(customerId: 'c1', config: _config),
          status: ConnStatus.offline,
        ),
      );
      await tester.pumpAndSettle();

      // Sem Autocomplete (a cascata sumiu) e com a dica em cada campo de fonte.
      expect(find.byType(Autocomplete<LookupOption>), findsNothing);
      expect(find.text('Sem conexão — digite manualmente'), findsNWidgets(2));
      expect(find.byKey(const Key('subjectField-marca')), findsOneWidget);
      expect(find.byKey(const Key('subjectField-modelo')), findsOneWidget);
    });

    testWidgets('online: a cascata FIPE (Autocomplete) continua', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SubjectFormDialog(customerId: 'c1', config: _config),
          status: ConnStatus.online,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Autocomplete<LookupOption>), findsNWidgets(2));
      expect(find.text('Sem conexão — digite manualmente'), findsNothing);
    });
  });

  group('caixa', () {
    testWidgets('offline: aviso permanente de que os lançamentos só sobem '
        'quando a conexão voltar', (tester) async {
      await tester.pumpWidget(
        _wrap(const CashierScreen(), status: ConnStatus.offline),
      );
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
      await tester.pumpWidget(
        _wrap(const CashierScreen(), status: ConnStatus.online),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('só serão efetivados no sistema'),
        findsNothing,
      );
    });
  });

  group('telas online-only', () {
    testWidgets('equipe offline → RequiresConnectionView', (tester) async {
      await tester.pumpWidget(
        _wrap(const TeamScreen(), status: ConnStatus.offline),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RequiresConnectionView), findsOneWidget);
      expect(find.text('Requer conexão'), findsOneWidget);
    });
  });
}
