import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbixhub_front/core/error/error_surface.dart';
import 'package:orbixhub_front/features/notifications/domain/notifications_models.dart';
import 'package:orbixhub_front/features/notifications/domain/notifications_repository.dart';
import 'package:orbixhub_front/features/notifications/presentation/notifications_providers.dart';

/// O falso "chegou mensagem nova".
///
/// O sino toca o som ao VER o não-lido subir. Antes, `unreadCountProvider`
/// devolvia **0** enquanto carregava, então todo remount do sino (tutorial
/// abrindo, página de notificações no mobile) produzia a sequência `0 → 3` e o
/// app anunciava três mensagens novas que já estavam lá desde antes.
///
/// A correção é `null` para "ainda não sei": não se compara com o desconhecido.
void main() {
  group('unreadCountProvider', () {
    test('carregando devolve null (desconhecido), nunca 0', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            _RepoLento(unread: 3),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Primeiro frame: o notifier ainda está resolvendo o future.
      expect(container.read(unreadCountProvider), isNull);

      await container.read(notificationsProvider.future);
      expect(container.read(unreadCountProvider), 3);
    });

    test('erro também é desconhecido, não zero', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(_RepoQueFalha()),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(notificationsProvider.future),
        throwsA(anything),
      );
      // Zero aqui diria "tudo lido", que é uma afirmação que não podemos fazer.
      expect(container.read(unreadCountProvider), isNull);
    });
  });

  group('regra do alerta (o que o sino faz com a sequência)', () {
    // Espelha a condição do build: só alerta entre duas contagens CONHECIDAS.
    bool alerta(int? anterior, int? atual) =>
        anterior != null && atual != null && atual > anterior;

    test('remount (desconhecido → 3) NÃO alerta — era o bug', () {
      expect(alerta(null, 3), isFalse);
    });

    test('mensagem nova de verdade (1 → 2) alerta', () {
      expect(alerta(1, 2), isTrue);
    });

    test('ler notificações (3 → 0) não alerta', () {
      expect(alerta(3, 0), isFalse);
    });

    test('contagem estável (2 → 2) não alerta', () {
      expect(alerta(2, 2), isFalse);
    });

    test('perder a conexão no meio (2 → desconhecido) não alerta', () {
      expect(alerta(2, null), isFalse);
    });

    test('desconhecido → 0 não alerta (nem toca com caixa vazia)', () {
      expect(alerta(null, 0), isFalse);
    });
  });

  group('superfície de erro amigável', () {
    testWidgets('exceção no build não mostra o texto técnico em release',
        (tester) async {
      // `detalhe: null` é o que o builder passa fora do debug.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FalhaDeWidget(),
        ),
      );
      expect(
        find.text('Não foi possível exibir esta parte da tela.'),
        findsOneWidget,
      );
    });

    testWidgets('não depende de Theme nem de Directionality herdados',
        (tester) async {
      // Sem MaterialApp e sem Directionality em volta: o substituto tem de
      // sobreviver sozinho, senão o Flutter cai no vermelho que evitamos.
      await tester.pumpWidget(
        const FalhaDeWidget(detalhe: 'Bad state: algo quebrou'),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('algo quebrou'), findsOneWidget);
    });

    testWidgets('instalar troca o ErrorWidget.builder padrão', (tester) async {
      final original = ErrorWidget.builder;
      addTearDown(() => ErrorWidget.builder = original);

      installFriendlyErrorSurface();
      final w = ErrorWidget.builder(
        FlutterErrorDetails(exception: StateError('x')),
      );
      expect(w, isA<FalhaDeWidget>());
    });
  });
}

/// Repo que resolve num microtask — deixa observar o estado de carregamento.
class _RepoLento implements NotificationsRepository {
  _RepoLento({required this.unread});
  final int unread;

  @override
  Future<NotificationsResult> list() async {
    await Future<void>.delayed(Duration.zero);
    return NotificationsResult(items: const [], unread: unread);
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}

class _RepoQueFalha implements NotificationsRepository {
  @override
  Future<NotificationsResult> list() async => throw StateError('sem rede');

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}
