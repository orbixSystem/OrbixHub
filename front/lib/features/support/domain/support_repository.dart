import 'support_models.dart';

/// Chamados de suporte do ambiente com a Orbix.
abstract interface class SupportRepository {
  /// Chamados do tenant, o de movimento mais recente primeiro.
  Future<List<SupportTicket>> tickets();

  /// Mensagens de um chamado. Buscar marca as respostas da Orbix como lidas —
  /// abrir o chamado É a leitura.
  Future<List<SupportMessage>> mensagens(String ticketId);

  /// Abre um chamado com a primeira mensagem.
  Future<SupportTicket> abrir(String subject, String body);

  Future<SupportMessage> responder(String ticketId, String body);

  /// Pede a reabertura de um chamado fechado, dizendo o motivo. Quem reabre de
  /// fato é a Orbix — aqui o pedido fica registrado e visível para ela.
  Future<SupportTicket> solicitarReabertura(String ticketId, String body);

  Future<void> resolver(String ticketId);

  /// Total de respostas não lidas, somando os chamados.
  Future<int> unread();
}
