import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/tracking/domain/tracking_models.dart';
import 'package:orbixhub_front/features/tracking/domain/tracking_repository.dart';
import 'package:orbixhub_front/features/tracking/presentation/public_tracking_screen.dart';

/// A página que o CLIENTE da oficina abre pelo link.
///
/// Ela tem dois layouts distintos (celular em coluna única, desktop com barra
/// lateral fixa) e é a única tela do produto que uma pessoa de fora vê — um
/// overflow aqui é a primeira impressão da oficina. Estes testes montam a tela
/// com carga realista (timeline com foto embutida, várias fotos, textos
/// longos) nos dois tamanhos e falham se qualquer coisa estourar o layout.
class _FakeRepo implements TrackingRepository {
  @override
  Future<PublicTrack> track(String token) async => PublicTrack(
        number: 'OS-0042',
        status: 'em_execucao',
        statusLabel: 'Em execução',
        subjectLabel: 'Volkswagen CrossFox 1.6 Total Flex — ABC1D23',
        diagnosis: 'Bieletas e coxins desgastados; disco dianteiro empenado; '
            'necessária troca do kit de embreagem por desgaste avançado.',
        scheduledEnd: '2026-08-20T18:00:00.000Z',
        responsibleName: 'Carlos Eduardo de Almeida',
        company: const PublicCompany(name: 'Oficina do Zé Mecânica e Funilaria'),
        photos: const [
          PublicPhoto(id: 'p1', url: 'https://example.test/1.jpg'),
          PublicPhoto(id: 'p2', url: 'https://example.test/2.jpg'),
        ],
        timeline: const [
          PublicEvent(
            kind: 'photo',
            message: 'Troquei a correia dentada',
            createdAt: '2026-08-11T15:00:00.000Z',
            photoUrl: 'https://example.test/1.jpg',
          ),
          PublicEvent(
            kind: 'note',
            message: 'Peça adicionada: Correia dentada Gates',
            createdAt: '2026-08-11T14:00:00.000Z',
          ),
          PublicEvent(
            kind: 'status_change',
            message: 'Em execução',
            statusSnapshot: 'em_execucao',
            createdAt: '2026-08-10T09:00:00.000Z',
          ),
        ],
      );

  @override
  Future<List<PublicMessage>> messages(String token) async => const [];

  @override
  Future<void> sendMessage(String token, String body,
      {String? authorName, String? replyToId, String? photoId}) async {}

  @override
  Future<List<PublicPhotoComment>> photoComments(
          String token, String photoId) async =>
      const [];

  @override
  Future<PublicPhotoComment> addPhotoComment(
          String token, String photoId, String body,
          {String? authorName}) async =>
      const PublicPhotoComment(body: 'x');
}

Future<void> _semOverflow(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackingRepositoryProvider.overrideWithValue(_FakeRepo()),
      ],
      child: const MaterialApp(
        home: PublicTrackingScreen(token: 'tok-abc123'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(
    tester.takeException(),
    isNull,
    reason: 'layout do acompanhamento estourou em '
        '${size.width.toInt()}x${size.height.toInt()}',
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('celular (390x844): coluna única', (tester) async {
    await _semOverflow(tester, const Size(390, 844));
  });

  testWidgets('celular estreito (360x640)', (tester) async {
    await _semOverflow(tester, const Size(360, 640));
  });

  testWidgets('desktop (1440x900): barra lateral + conteúdo', (tester) async {
    await _semOverflow(tester, const Size(1440, 900));
    // A navegação lateral tem de estar visível SEM rolar — é o que diz ao
    // cliente onde ele está e para onde pode ir.
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Conversa'), findsOneWidget);
  });
}
