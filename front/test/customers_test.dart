import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/customers/domain/customers_models.dart';
import 'package:orbixhub_front/features/customers/presentation/customer_detail_screen.dart';
import 'package:orbixhub_front/features/customers/presentation/customers_screen.dart';
import 'package:orbixhub_front/features/customers/presentation/subject_form_dialog.dart';

const _me = Me(
  user: User(id: 'u1', email: 'dono@teste.com', fullName: 'Dono Teste'),
  activeTenant: Tenant(id: 't1', slug: 's1', name: 'Oficina'),
  role: 'owner',
  permissions: ['customer.read', 'customer.write', 'subject.read', 'subject.write'],
  modules: ['customers'],
  memberships: [Membership(tenantId: 't1', tenantSlug: 's1', role: 'owner')],
);

class _AuthedSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(_me);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model parsing (contract)', () {
    test('Customer.fromJson maps the backend shape', () {
      final c = Customer.fromJson({
        'id': 'c1',
        'name': 'João',
        'type': 'PF',
        'document': '123',
        'phone': '119',
        'status': 'active',
      });
      expect(c.id, 'c1');
      expect(c.name, 'João');
      expect(c.document, '123');
    });

    test('Subject.fromJson reads customer_id and attributes', () {
      final s = Subject.fromJson({
        'id': 's1',
        'customer_id': 'c1',
        'label': 'Gol do João',
        'identifier': 'ABC1D23',
        'attributes': {'marca': 'VW'},
        'status': 'active',
      });
      expect(s.customerId, 'c1');
      expect(s.identifier, 'ABC1D23');
      expect(s.attributes['marca'], 'VW');
    });

    test('CustomersConfig.fromJson reads dynamic label + fields', () {
      final cfg = CustomersConfig.fromJson({
        'usaSubjects': true,
        'subjectLabel': {'singular': 'Pet', 'plural': 'Pets'},
        'subjectFields': [
          {'chave': 'raca', 'rotulo': 'Raça', 'tipo': 'text', 'obrigatorio': true},
        ],
        'documentRequired': false,
      });
      expect(cfg.subjectLabel.singular, 'Pet');
      expect(cfg.subjectFields.single.rotulo, 'Raça');
      expect(cfg.subjectFields.single.obrigatorio, true);
    });
  });

  group('fake repository', () {
    test('create -> list -> archive keeps the row (no hard delete)', () async {
      final repo = FakeCustomersRepository();
      final c = await repo.createCustomer(const CustomerDraft(name: 'Maria'));
      expect((await repo.listCustomers(status: 'active')).items, hasLength(1));

      await repo.archiveCustomer(c.id);
      expect((await repo.listCustomers(status: 'active')).items, isEmpty);
      expect((await repo.listCustomers(status: 'archived')).items, hasLength(1));
    });

    test('search matches name, document and phone', () async {
      final repo = FakeCustomersRepository();
      await repo.createCustomer(
        const CustomerDraft(name: 'Fernanda', document: 'D9', phone: '777'),
      );
      await repo.createCustomer(const CustomerDraft(name: 'Outro'));
      expect((await repo.listCustomers(q: 'fern')).items, hasLength(1));
      expect((await repo.listCustomers(q: 'D9')).items, hasLength(1));
      expect((await repo.listCustomers(q: '777')).items, hasLength(1));
    });

    test('soft delete hides the customer from active and all lists', () async {
      final repo = FakeCustomersRepository();
      final c = await repo.createCustomer(const CustomerDraft(name: 'Z'));
      await repo.deleteCustomer(c.id);
      expect((await repo.listCustomers(status: 'active')).items, isEmpty);
      expect((await repo.listCustomers(status: 'all')).items, isEmpty);
      // the row still exists (soft delete) — fetchable by id
      expect((await repo.getCustomer(c.id)).status, 'deleted');
    });

    test('subject history is empty by default', () async {
      final repo = FakeCustomersRepository();
      final c = await repo.createCustomer(const CustomerDraft(name: 'X'));
      final s = await repo.createSubject(
        c.id,
        const SubjectDraft(identifier: 'ABC'),
      );
      expect(await repo.subjectHistory(s.id), isEmpty);
    });
  });

  testWidgets('CustomersScreen lists customers and shows the new-customer action',
      (tester) async {
    // Use the real AppTheme + a wide surface: the global FilledButton theme sets
    // an infinite width, which only explodes inside a Row under the real theme.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeCustomersRepository(
      customers: const [Customer(id: 'c1', name: 'João Silva')],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_AuthedSession.new),
          customersRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CustomersScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('João Silva'), findsOneWidget);
    expect(find.text('Novo cliente'), findsOneWidget);
  });

  testWidgets('CustomerDetailScreen renders header + subjects section',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeCustomersRepository(
      customers: const [Customer(id: 'c1', name: 'João Silva', phone: '119')],
      subjects: const [
        Subject(id: 's1', customerId: 'c1', identifier: 'ABC1D23'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_AuthedSession.new),
          customersRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CustomerDetailScreen(customerId: 'c1'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('João Silva'), findsOneWidget);
    // default config plural label
    expect(find.text('Veículos'), findsOneWidget);
    expect(find.text('ABC1D23'), findsWidgets);
  });

  testWidgets('campo com fonte sugere marcas e a cascata limpa o modelo',
      (tester) async {
    final fake = FakeCustomersRepository();
    const config = CustomersConfig(
      subjectFields: [
        SubjectFieldConfig(
          chave: 'marca',
          rotulo: 'Marca',
          fonte: 'fipe.marcas',
        ),
        SubjectFieldConfig(
          chave: 'modelo',
          rotulo: 'Modelo',
          fonte: 'fipe.modelos',
          dependeDe: 'marca',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SubjectFormDialog(customerId: 'cus-1', config: config),
          ),
        ),
      ),
    );

    // digitar na Marca dispara o lookup e mostra as opções
    await tester.enterText(find.byKey(const Key('subjectField-marca')), 'f');
    await tester.pumpAndSettle();
    expect(find.text('Ford'), findsWidgets);

    // escolher Ford
    await tester.tap(find.text('Ford').last);
    await tester.pumpAndSettle();

    // agora Modelo sugere modelos da marca
    await tester.enterText(find.byKey(const Key('subjectField-modelo')), 'k');
    await tester.pumpAndSettle();
    expect(find.text('Ka'), findsWidgets);
  });
}
