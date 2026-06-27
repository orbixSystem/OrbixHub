import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notifications_models.dart';
import '../domain/notifications_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  throw UnimplementedError(
      'notificationsRepositoryProvider must be overridden in di.dart');
});

/// Intervalo do polling de notificações.
const _pollInterval = Duration(seconds: 15);

/// Notifier que mantém o estado de notificações e faz polling resiliente
/// (erros engolidos — nunca derruba a shell). O Timer para junto com o provider
/// (autoDispose): vive enquanto o sino estiver montado.
class NotificationsNotifier extends AsyncNotifier<NotificationsResult> {
  Timer? _timer;

  @override
  Future<NotificationsResult> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer ??= Timer.periodic(_pollInterval, (_) => _poll());
    return ref.read(notificationsRepositoryProvider).list();
  }

  /// Re-busca silenciosamente; erros são engolidos (mantém o último estado bom).
  Future<void> _poll() async {
    try {
      final next = await ref.read(notificationsRepositoryProvider).list();
      state = AsyncData(next);
    } catch (_) {
      // Polling resiliente: ignora falhas transitórias.
    }
  }

  /// Refresh manual (ex.: ao abrir o drawer).
  Future<void> refresh() => _poll();

  Future<void> markRead(String id) async {
    try {
      await ref.read(notificationsRepositoryProvider).markRead(id);
    } catch (_) {
      // ignora; o próximo poll reconcilia.
    }
    await _poll();
  }

  Future<void> markAllRead() async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
    } catch (_) {
      // ignora; o próximo poll reconcilia.
    }
    await _poll();
  }
}

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<NotificationsNotifier,
        NotificationsResult>(NotificationsNotifier.new);

/// Contagem de não-lidas — 0 enquanto carrega/erro (badge some).
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (r) => r.unread,
        orElse: () => 0,
      );
});
