import '../domain/notifications_models.dart';
import '../domain/notifications_repository.dart';

/// In-memory [NotificationsRepository] for tests/offline.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({List<AppNotification>? items}) {
    final seed = items ??
        const [
          AppNotification(
            id: 'n1',
            type: 'message',
            title: 'Nova mensagem de Maria Souza',
            body: 'Meu carro já está pronto?',
            refType: 'message',
            refId: 'c1',
          ),
        ];
    for (final n in seed) {
      _items[n.id] = n;
    }
  }

  final Map<String, AppNotification> _items = {};

  @override
  Future<NotificationsResult> list() async {
    final items = _items.values.toList();
    final unread = items.where((n) => !n.isRead).length;
    return NotificationsResult(items: items, unread: unread);
  }

  @override
  Future<void> markRead(String id) async {
    final cur = _items[id];
    if (cur != null) {
      _items[id] =
          cur.copyWith(readAt: DateTime.now().toUtc().toIso8601String());
    }
  }

  @override
  Future<void> markAllRead() async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in _items.entries.toList()) {
      _items[entry.key] = entry.value.copyWith(readAt: now);
    }
  }
}
