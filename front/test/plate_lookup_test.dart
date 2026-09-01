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
import 'package:orbixhub_front/verticals/veiculos/plate_labels.dart';
import 'package:orbixhub_front/features/customers/presentation/subject_form_dialog.dart';
import 'package:orbixhub_front/verticals/veiculos/vehicle_ficha_dialog.dart';

/// Consulta de placa (API Placas via backend): models, fake e autofill no
/// formulário de veículo, incluindo o contador de cota e o modo offline.

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
      permissions: ['customers.write', 'subject.read', 'subject.write'],
      modules: ['customers'],
      features: [
        'customers.identifierLookup',
        'customers.atributosCascata',
        'customers.fichaTecnica',
        'os.trackingLink',
      ],
    ),
  );
}

const _config = CustomersConfig(
  subjectFields: [
    SubjectFieldConfig(chave: 'identifier', rotulo: 'Placa', formato: 'placa'),
    SubjectFieldConfig(chave: 'marca', rotulo: 'Marca', fonte: 'fipe.marcas'),
    SubjectFieldConfig(chave: 'cor', rotulo: 'Cor'),
    SubjectFieldConfig(chave: 'ano', rotulo: 'Ano'),
  ],
);

Widget _wrap(Widget child, {required ConnStatus status}) {
  return ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(() => _FakeConn(status)),
      sessionControllerProvider.overrideWith(_FakeSession.new),
      customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  );
}

void main() {
  group('PlateInfo.fromJson', () {
    test('parseia a resposta real do backend (payload + cota)', () {
      final info = PlateInfo.fromJson(const {
        'placa': 'INT8C36',
        'placaAlternativa': 'INT8236',
        'marca': 'VW',
        'modelo': 'CROSSFOX',
        'ano': '2007',
        'anoModelo': '2007',
        'cor': 'PRATA',
        'chassi': '*****10137',
        'municipio': 'São Leopoldo',
        'uf': 'RS',
        'situacao': 'Sem restrição',
        'combustivel': 'Alcool / Gasolina',
        'fipe': {
          'codigoFipe': '005225-6',
          'modelo': 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
          'valor': r'R$ 29.570,00',
          'score': 81,
        },
        'cached': false,
        'usage': {
          'period': '2026-07',
          'used': 1,
          'limit': 1000,
          'remaining': 999,
          'enabled': true,
        },
      });
      expect(info.placa, 'INT8C36');
      expect(info.marca, 'VW');
      expect(info.fipe?.valor, r'R$ 29.570,00');
      expect(info.cached, isFalse);
      expect(info.usage?.remaining, 999);
    });
  });

  group('FakeCustomersRepository — placas', () {
    test('1ª consulta gasta cota; a 2ª vem do cache', () async {
      final repo = FakeCustomersRepository();
      final first = await repo.plateLookup('abc1d23');
      expect(first.placa, 'ABC1D23');
      expect(first.cached, isFalse);
      expect(first.usage?.used, 1);

      final second = await repo.plateLookup('abc1d23');
      expect(second.cached, isTrue);

      final usage = await repo.plateUsage();
      expect(usage.used, 2);
      expect(usage.remaining, 998);
    });
  });

  group('rótulos do bloco técnico', () {
    test('traduz chaves conhecidas e humaniza as desconhecidas', () {
      expect(plateFieldLabel('cap_maxima_tracao'), 'Cap. máxima de tração');
      expect(plateFieldLabel('restricao_1'), 'Restrição 1');
      expect(plateFieldLabel('s.especie'), 'Subespécie');
      // Chave nova que a API venha a mandar: aparece humanizada, nunca some.
      expect(plateFieldLabel('campo_novo_qualquer'), 'Campo novo qualquer');
    });

    test('omite o que já aparece nas seções principais e ordena', () {
      final rows = plateTechnicalRows(const {
        'peso_bruto_total': '158',
        'chassi': '9BW...', // já sai em Identificação
        'ano_modelo': '2007', // idem
        'eixos': '2',
        'vazio': '   ',
      });
      expect(rows.map((r) => r.$1), ['Eixos', 'Peso bruto total']);
    });
  });

  group('ficha do veículo (diálogo)', () {
    testWidgets('mostra dados técnicos, FIPE e as duas opções de PDF', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final info = await FakeCustomersRepository().plateLookup('ABC1D23');
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showVehicleFichaDialog(context, info: info),
              child: const Text('abrir'),
            ),
          ),
          status: ConnStatus.online,
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Ficha do veículo'), findsOneWidget);
      // Identificação com o chassi COMPLETO (o bloco técnico não vem mascarado).
      expect(find.text('9BWKB05Z174110137'), findsOneWidget);
      // Bloco técnico rotulado em PT-BR.
      expect(find.text('Peso bruto total'), findsOneWidget);
      expect(find.text('Cap. máxima de tração'), findsOneWidget);
      // TODAS as correspondências FIPE, não só a melhor.
      expect(find.textContaining('CROSSFOX 1.6 Mi Total Flex'), findsWidgets);
      expect(find.textContaining('CROSSFOX 1.6 T.Flex'), findsOneWidget);
      // As duas versões de impressão.
      expect(find.text('Ficha resumida'), findsOneWidget);
      expect(find.text('Ficha completa'), findsOneWidget);
    });
  });

  group('formulário de veículo — buscar pela placa', () {
    testWidgets('online: preenche marca/cor/ano e mostra o contador da cota', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const SubjectFormDialog(customerId: 'c1', config: _config),
          status: ConnStatus.online,
        ),
      );
      await tester.pumpAndSettle();

      // O botão de busca existe (o rótulo do identifier é "Placa").
      final button = find.byTooltip('Consultar Placa');
      expect(button, findsOneWidget);

      // Placa inválida → aviso, nada preenchido.
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Digite uma placa válida'),
        findsOneWidget,
      );
      // Deixa o snackbar do aviso expirar (senão o próximo fica na fila).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Digita uma placa válida e busca.
      await tester.enterText(
        find.byKey(const Key('subjectField-identifier')),
        'ABC1D23',
      );
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Marca vem do EQUIVALENTE FIPE (valor canônico do catálogo), não da
      // sigla crua do registro ("VW") — é o que mantém a cascata viva.
      expect(find.text('VW - VolksWagen'), findsWidgets);
      expect(find.text('VW'), findsNothing);
      expect(find.text('Prata'), findsOneWidget);
      expect(find.text('2007'), findsOneWidget);
      // Contador da cota no aviso + marca de revisão nos campos simples.
      expect(find.textContaining('consulta 1 de 1000'), findsOneWidget);
      expect(
        find.text('Preenchido pela consulta da placa'),
        findsNWidgets(2), // cor e ano (marca é Autocomplete, sem helper)
      );
    });

    testWidgets('offline: botão de busca fica inerte (Requer conexão)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const SubjectFormDialog(customerId: 'c1', config: _config),
          status: ConnStatus.offline,
        ),
      );
      await tester.pumpAndSettle();

      // O RequiresConnection envolve o botão com o tooltip padrão.
      expect(
        find.byTooltip(
          'Requer conexão — a consulta de placa é feita no servidor',
        ),
        findsOneWidget,
      );
    });
  });
}
