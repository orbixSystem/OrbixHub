import '../domain/support_models.dart';
import '../domain/support_repository.dart';

/// Fake para dev e teste. Guarda em memória e responde na hora.
class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({List<SupportMessage>? inicial})
      : _msgs = [...?inicial];

  final List<SupportMessage> _msgs;
  int enviadas = 0;

  @override
  Future<List<SupportMessage>> thread() async => List.unmodifiable(_msgs);

  @override
  Future<int> unread() async => _msgs.where((m) => m.fromOrbix).length;

  @override
  Future<SupportMessage> enviar(String body) async {
    enviadas += 1;
    final m = SupportMessage(
      id: 'fake-$enviadas',
      body: body,
      createdAt: DateTime(2026, 8, 21, 10, enviadas),
    );
    _msgs.add(m);
    return m;
  }
}
