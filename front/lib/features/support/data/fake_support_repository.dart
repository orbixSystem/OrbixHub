import '../domain/support_models.dart';
import '../domain/support_repository.dart';

/// Fake para dev e teste. Guarda em memória e responde na hora.
class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({
    List<SupportTicket>? tickets,
    Map<String, List<SupportMessage>>? mensagens,
  })  : _tickets = [...?tickets],
        _msgs = {...?mensagens};

  final List<SupportTicket> _tickets;
  final Map<String, List<SupportMessage>> _msgs;

  int abertos = 0;
  int respondidos = 0;
  String? resolvido;

  @override
  Future<List<SupportTicket>> tickets() async => List.unmodifiable(_tickets);

  @override
  Future<List<SupportMessage>> mensagens(String ticketId) async =>
      List.unmodifiable(_msgs[ticketId] ?? const []);

  @override
  Future<SupportTicket> abrir(String subject, String body) async {
    abertos += 1;
    final t = SupportTicket(
      id: 'tk-$abertos',
      subject: subject,
      lastMessageAt: DateTime(2026, 8, 21, 10, abertos),
      createdAt: DateTime(2026, 8, 21, 10, abertos),
    );
    _tickets.insert(0, t);
    _msgs[t.id] = [
      SupportMessage(
        id: 'm-$abertos',
        body: body,
        createdAt: t.createdAt,
      ),
    ];
    return t;
  }

  @override
  Future<SupportMessage> responder(String ticketId, String body) async {
    respondidos += 1;
    final m = SupportMessage(
      id: 'r-$respondidos',
      body: body,
      createdAt: DateTime(2026, 8, 21, 11, respondidos),
    );
    (_msgs[ticketId] ??= []).add(m);
    return m;
  }

  @override
  Future<void> resolver(String ticketId) async => resolvido = ticketId;

  /// Guarda o último pedido de reabertura, para o teste conferir o que foi enviado.
  String? reaberturaPedidaDe;
  String? motivoDaReabertura;

  @override
  Future<SupportTicket> solicitarReabertura(String ticketId, String body) async {
    reaberturaPedidaDe = ticketId;
    motivoDaReabertura = body;
    final i = _tickets.indexWhere((t) => t.id == ticketId);
    final atualizado = _tickets[i].copyWith(status: 'reabertura_solicitada');
    _tickets[i] = atualizado;
    return atualizado;
  }

  @override
  Future<int> unread() async =>
      _tickets.fold<int>(0, (a, t) => a + t.naoLidas);
}
