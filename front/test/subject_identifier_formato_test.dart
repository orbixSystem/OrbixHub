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
import 'package:orbixhub_front/features/customers/presentation/subject_form_dialog.dart';

/// Máscara e validação do identificador saem do `formato` que o NICHO declara,
/// não da `chave` do campo.
///
/// Suporte real: no nicho padrão (equipamentos), editar um equipamento chamado
/// "Sony FE 2.8/70 GM" mostrava "Placa inválida (ex.: ABC1D23)" e barrava o
/// salvamento — o front decidia por `chave == 'identifier'`, e o nicho genérico
/// também tem esse campo (rotulado "Identificação"/"Nome").

class _FakeConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

/// Sessão SEM `customers.identifierLookup`: é o caso do nicho genérico, e prova
/// que o formato não depende da capacidade de consulta em base externa.
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
    Me(
      user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
      role: 'owner',
      permissions: ['subject.read', 'subject.write'],
      modules: ['customers'],
      features: ['os.trackingLink'],
    ),
  );
}

/// Nicho padrão: identificador é texto livre (aqui rotulado "Nome", como o
/// tenant do suporte configurou).
const _equipamentos = CustomersConfig(
  subjectLabel: SubjectLabel(singular: 'Equipamento', plural: 'Equipamentos'),
  subjectFields: [
    SubjectFieldConfig(chave: 'identifier', rotulo: 'Nome'),
    SubjectFieldConfig(chave: 'tipo', rotulo: 'Tipo'),
  ],
);

/// Oficina: o pacote `veiculos` declara `formato: 'placa'`.
const _oficina = CustomersConfig(
  subjectLabel: SubjectLabel(singular: 'Veículo', plural: 'Veículos'),
  subjectFields: [
    SubjectFieldConfig(chave: 'identifier', rotulo: 'Placa', formato: 'placa'),
  ],
);

const _erroPlaca = 'Placa inválida (ex.: ABC1D23).';

/// Abre o dialog por uma rota de verdade — assim o "Salvar" pode dar pop.
Widget _host(CustomersConfig config) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(_FakeConn.new),
      sessionControllerProvider.overrideWith(_FakeSession.new),
      customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => SubjectFormDialog.show(
              ctx,
              customerId: 'cus-1',
              config: config,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _abrir(WidgetTester tester, CustomersConfig config) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(config));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nicho padrão: identificador aceita texto livre e salva',
      (tester) async {
    await _abrir(tester, _equipamentos);
    expect(find.text('Novo Equipamento'), findsOneWidget);

    const nome = 'Sony FE 2.8/70 GM';
    await tester.enterText(
      find.byKey(const Key('subjectField-identifier')),
      nome,
    );
    await tester.pumpAndSettle();

    // Sem máscara de placa: o texto sobrevive inteiro (minúsculas, espaços,
    // pontuação, mais de 7 caracteres).
    expect(find.text(nome), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Salvou (o dialog fechou) e nunca cobrou formato de placa.
    expect(find.text(_erroPlaca), findsNothing);
    expect(find.text('Novo Equipamento'), findsNothing);
  });

  testWidgets('oficina: identificador continua com máscara e validação de placa',
      (tester) async {
    await _abrir(tester, _oficina);
    expect(find.text('Novo Veículo'), findsOneWidget);

    // Máscara: MAIÚSCULO, só letras/dígitos, 7 caracteres.
    await tester.enterText(
      find.byKey(const Key('subjectField-identifier')),
      'sony fe 2.8/70 gm',
    );
    await tester.pumpAndSettle();
    expect(find.text('SONYFE2'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text(_erroPlaca), findsOneWidget);

    // Placa válida passa.
    await tester.enterText(
      find.byKey(const Key('subjectField-identifier')),
      'abc1d23',
    );
    await tester.pumpAndSettle();
    expect(find.text('ABC1D23'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text(_erroPlaca), findsNothing);
    expect(find.text('Novo Veículo'), findsNothing);
  });
}
