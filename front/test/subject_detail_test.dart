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
import 'package:orbixhub_front/features/customers/domain/customers_models.dart';
import 'package:orbixhub_front/features/customers/presentation/subject_detail_screen.dart';
import 'package:orbixhub_front/features/customers/presentation/subject_form_dialog.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';

/// Tela de detalhes do veículo + persistência do retorno da consulta de placa
/// nas colunas exclusivas (`plate_data`).

class _FakeConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
    Me(
      user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
      role: 'owner',
      permissions: ['subject.read', 'subject.write', 'customer.read', 'os.read'],
      modules: ['customers', 'os'],
    ),
  );
}

/// Fake com histórico injetável (o padrão devolve lista vazia).
class _RepoComHistorico extends FakeCustomersRepository {
  _RepoComHistorico({
    super.customers,
    super.subjects,
    this.historico = const [],
  });

  final List<SubjectHistoryEntry> historico;

  @override
  Future<List<SubjectHistoryEntry>> customerHistory(
    String customerId, {
    String? subjectId,
  }) async =>
      historico;
}

const _config = CustomersConfig(
  subjectFields: [
    SubjectFieldConfig(chave: 'identifier', rotulo: 'Placa'),
    SubjectFieldConfig(chave: 'cor', rotulo: 'Cor'),
  ],
);

const _customer = Customer(id: 'c1', name: 'João da Silva');

Widget _wrap(Widget child, {required CustomersRepositoryHolder repo}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(_FakeConn.new),
      sessionControllerProvider.overrideWith(_FakeSession.new),
      customersRepositoryProvider.overrideWithValue(repo.value),
      osRepositoryProvider.overrideWithValue(FakeOsRepository()),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  );
}

/// Wrapper simples para passar o fake (mantém o tipo do provider explícito).
class CustomersRepositoryHolder {
  CustomersRepositoryHolder(this.value);
  final FakeCustomersRepository value;
}

void main() {
  /// Payload da consulta como ele é persistido no veículo.
  Future<Map<String, dynamic>> plateDataFixture() async {
    final info = await FakeCustomersRepository().plateLookup('ABC1D23');
    return info.copyWith(cached: false, usage: null).toJson();
  }

  group('persistência da consulta no cadastro', () {
    testWidgets('salvar após buscar a placa grava plate_data no veículo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final fake = FakeCustomersRepository(customers: const [_customer]);
      await tester.pumpWidget(
        _wrap(
          const SubjectFormDialog(customerId: 'c1', config: _config),
          repo: CustomersRepositoryHolder(fake),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('subjectField-identifier')),
        'ABC1D23',
      );
      await tester.tap(find.byTooltip('Buscar dados do veículo pela placa'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final saved = (await fake.listSubjects(customerId: 'c1')).items.single;
      // O retorno da consulta ficou nas colunas exclusivas — não em attributes.
      expect(saved.plateData, isNotNull);
      expect(saved.plateInfo?.chassi, '9BWKB05Z174110137');
      expect(saved.plateInfo?.extra['peso_bruto_total'], '158');
      expect(saved.attributes.containsKey('plateData'), isFalse);
      // Campos de transporte não são persistidos (não descrevem o veículo).
      expect(saved.plateData!['usage'], isNull);
    });

    testWidgets('salvar sem buscar não manda plate_data (preserva o salvo)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final fake = FakeCustomersRepository(customers: const [_customer]);
      await tester.pumpWidget(
        _wrap(
          const SubjectFormDialog(customerId: 'c1', config: _config),
          repo: CustomersRepositoryHolder(fake),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('subjectField-identifier')),
        'XYZ9A88',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final saved = (await fake.listSubjects(customerId: 'c1')).items.single;
      expect(saved.plateData, isNull);
      expect(saved.plateInfo, isNull);
    });
  });

  group('tela de detalhes do veículo', () {
    testWidgets('aba de informações adicionais mostra o que foi consultado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final subject = Subject(
        id: 's1',
        customerId: 'c1',
        label: 'Carro do João',
        identifier: 'ABC1D23',
        attributes: const {'cor': 'Prata'},
        plateData: await plateDataFixture(),
        plateDataAt: '2026-08-01T12:00:00Z',
      );
      final fake = _RepoComHistorico(
        customers: const [_customer],
        subjects: [subject],
      );

      await tester.pumpWidget(
        _wrap(
          const SubjectDetailScreen(customerId: 'c1', subjectId: 's1'),
          repo: CustomersRepositoryHolder(fake),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carro do João'), findsOneWidget);

      await tester.tap(find.text('Informações adicionais'));
      await tester.pumpAndSettle();

      // Dados vieram do que está SALVO — nenhuma consulta nova foi feita.
      expect(find.text('9BWKB05Z174110137'), findsOneWidget);
      expect(find.text('Peso bruto total'), findsOneWidget);
      expect(find.textContaining('Consultado em 01/08/2026'), findsOneWidget);
      expect(find.text('Ficha / imprimir'), findsOneWidget);
      expect(find.text('Atualizar consulta'), findsOneWidget);
    });

    testWidgets('sem consulta salva, oferece consultar a placa', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final fake = _RepoComHistorico(
        customers: const [_customer],
        subjects: const [
          Subject(id: 's1', customerId: 'c1', identifier: 'ABC1D23'),
        ],
      );
      await tester.pumpWidget(
        _wrap(
          const SubjectDetailScreen(customerId: 'c1', subjectId: 's1'),
          repo: CustomersRepositoryHolder(fake),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Informações adicionais'));
      await tester.pumpAndSettle();

      expect(find.text('Sem informações da consulta'), findsOneWidget);

      // Consultar grava no veículo e a aba passa a mostrar os dados.
      await tester.tap(find.text('Consultar placa'));
      await tester.pumpAndSettle();

      final saved = (await fake.listSubjects(customerId: 'c1')).items.single;
      expect(saved.plateInfo?.marca, 'VW');
      expect(find.text('9BWKB05Z174110137'), findsOneWidget);
    });

    testWidgets('aba de OS lista as ordens com ação de imprimir em PDF', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final fake = _RepoComHistorico(
        customers: const [_customer],
        subjects: const [
          Subject(id: 's1', customerId: 'c1', identifier: 'ABC1D23'),
        ],
        historico: const [
          SubjectHistoryEntry(
            id: 'os-1',
            kind: 'os',
            title: 'OS-0001 — Revisão',
            status: 'em_execucao',
            occurredAt: '2026-07-20T10:00:00Z',
          ),
          // Entrada de outro tipo não vira "ordem de serviço".
          SubjectHistoryEntry(
            id: 'n-1',
            kind: 'note',
            title: 'Anotação',
            status: 'ok',
            occurredAt: '2026-07-21T10:00:00Z',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          const SubjectDetailScreen(customerId: 'c1', subjectId: 's1'),
          repo: CustomersRepositoryHolder(fake),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ordens de serviço'));
      await tester.pumpAndSettle();

      expect(find.text('OS-0001 — Revisão'), findsOneWidget);
      expect(find.text('Anotação'), findsNothing);
      expect(find.byTooltip('Imprimir OS em PDF'), findsOneWidget);
      expect(find.byTooltip('Ver relatório'), findsOneWidget);
    });
  });
}
