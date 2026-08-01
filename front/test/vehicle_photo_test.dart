import 'dart:convert';

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
import 'package:orbixhub_front/features/customers/presentation/customer_detail_screen.dart';
import 'package:orbixhub_front/features/customers/presentation/subject_form_dialog.dart';
import 'package:orbixhub_front/features/customers/presentation/vehicle_ficha_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Foto do veículo: controles do formulário e presença na ficha impressa.

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
      permissions: ['subject.read', 'subject.write'],
      modules: ['customers'],
    ),
  );
}

const _config = CustomersConfig(
  subjectFields: [
    SubjectFieldConfig(chave: 'identifier', rotulo: 'Placa'),
    SubjectFieldConfig(chave: 'cor', rotulo: 'Cor'),
  ],
);

/// PNG 1x1 válido — suficiente para o pdf embutir uma imagem de verdade.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        connectivityControllerProvider.overrideWith(_FakeConn.new),
        sessionControllerProvider.overrideWith(_FakeSession.new),
        customersRepositoryProvider
            .overrideWithValue(FakeCustomersRepository()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
    );

void main() {
  testWidgets('com foto, trocar/remover são só ícones (o rótulo quebrava)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        const SubjectFormDialog(
          customerId: 'c1',
          config: _config,
          existing: Subject(
            id: 's1',
            customerId: 'c1',
            identifier: 'ABC1D23',
            photoUrl: 'http://localhost:3000/files/foto.jpg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Trocar foto'), findsOneWidget);
    expect(find.byTooltip('Remover foto'), findsOneWidget);
    // Sem rótulo de texto no botão — era ele que estourava na faixa da foto.
    expect(find.text('Trocar'), findsNothing);
  });

  testWidgets('no card do cliente, trocar/remover também são só ícones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const subject = Subject(
      id: 's1',
      customerId: 'c1',
      label: 'Carro do João',
      identifier: 'ABC1D23',
      photoUrl: 'http://localhost:3000/files/foto.jpg',
    );
    final repo = FakeCustomersRepository(
      customers: const [Customer(id: 'c1', name: 'João da Silva')],
      subjects: const [subject],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityControllerProvider.overrideWith(_FakeConn.new),
          sessionControllerProvider.overrideWith(_FakeSession.new),
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
    await tester.pumpAndSettle();

    // Expande o card do veículo para revelar o bloco da foto.
    await tester.tap(find.text('Carro do João'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Trocar foto'), findsOneWidget);
    expect(find.byTooltip('Remover foto'), findsOneWidget);
    expect(find.text('Trocar'), findsNothing);
    expect(find.text('Remover'), findsNothing);
  });

  group('ficha em PDF', () {
    const info = PlateInfo(
      placa: 'ABC1D23',
      marca: 'VW',
      modelo: 'CROSSFOX',
      cor: 'Prata',
      chassi: '9BWKB05Z174110137',
    );

    test('resumida: sai maior com a foto (a imagem foi embutida)', () async {
      final semFoto = await buildVehicleFichaPdf(info, PdfPageFormat.a4);
      final comFoto = await buildVehicleFichaPdf(
        info,
        PdfPageFormat.a4,
        photo: pw.MemoryImage(_png),
      );
      expect(comFoto.length, greaterThan(semFoto.length));
    });

    test('completa: sai maior com a foto (a imagem foi embutida)', () async {
      final semFoto = await buildVehicleFichaCompletaPdf(info, PdfPageFormat.a4);
      final comFoto = await buildVehicleFichaCompletaPdf(
        info,
        PdfPageFormat.a4,
        photo: pw.MemoryImage(_png),
      );
      expect(comFoto.length, greaterThan(semFoto.length));
    });

    test('sem foto continua gerando normalmente', () async {
      final bytes = await buildVehicleFichaPdf(info, PdfPageFormat.a4);
      expect(bytes.length, greaterThan(500));
    });
  });
}
