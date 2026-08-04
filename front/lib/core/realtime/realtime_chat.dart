import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// Base do WebSocket = origin do API (sem o sufixo `/api`). O socket.io fica na
/// raiz do servidor (o prefixo global `/api` é só das rotas HTTP).
String _wsBaseUrl() {
  final uri = Uri.parse(AppConfig.apiBaseUrl);
  return '${uri.scheme}://${uri.authority}';
}

/// Assinatura de chat em tempo real (socket.io). Conecta, entra na sala certa
/// (cliente público via token; staff via JWT + conversa) e chama [onMessage] a
/// cada evento `message`. Reentra na sala ao reconectar (a sala não persiste no
/// servidor). Chame [dispose] ao sair da tela.
///
/// É um complemento ao polling — se o WS cair, o polling ainda atualiza a tela.
class RealtimeChat {
  RealtimeChat();

  io.Socket? _socket;
  bool _disposed = false;

  /// Cliente público (sem auth): entra na sala da OS pelo token do link.
  void connectPublic({
    required String token,
    required void Function(Map<String, dynamic> message) onMessage,
  }) {
    _connect(onMessage, (s) => s.emit('subscribe:public', {'token': token}));
  }

  /// Staff (com JWT): entra na sala do tenant (inbox) e, se informado, na sala da
  /// conversa aberta (thread).
  void connectStaff({
    required String accessToken,
    String? conversationId,
    required void Function(Map<String, dynamic> message) onMessage,
    /// Mudança numa ORDEM DE SERVIÇO do tenant (`{orderId, kind}`).
    ///
    /// Opcional para não obrigar as telas de mensagem a tratar um evento que não
    /// é delas: a sala do tenant é a mesma, mas cada tela escuta o que lhe importa.
    void Function(Map<String, dynamic> evt)? onOsChanged,
  }) {
    _connect(
      onMessage,
      (s) => s.emit('subscribe:staff', {
        'accessToken': accessToken,
        'conversationId': ?conversationId,
      }),
      onOsChanged: onOsChanged,
    );
  }

  void _connect(
    void Function(Map<String, dynamic>) onMessage,
    void Function(io.Socket socket) subscribe, {
    void Function(Map<String, dynamic>)? onOsChanged,
  }) {
    final socket = io.io(
      _wsBaseUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          // Conexão nova por instância: sem isto, o socket.io-client reusa um
          // socket em cache para a mesma URL. Ao navegar inbox→thread, o inbox
          // dá dispose() no socket compartilhado e a thread recebe esse socket
          // morto — onConnect nunca dispara, a sala nunca é assinada e a tela
          // fica "sem realtime". forceNew garante um socket próprio por tela.
          .enableForceNew()
          .build(),
    );
    _socket = socket;
    // (Re)assina a sala a cada conexão — cobre o reconnect automático.
    socket.onConnect((_) {
      if (!_disposed) subscribe(socket);
    });
    socket.on('message', (data) {
      if (_disposed) return;
      if (data is Map) onMessage(data.cast<String, dynamic>());
    });
    if (onOsChanged != null) {
      socket.on('os', (data) {
        if (_disposed) return;
        if (data is Map) onOsChanged(data.cast<String, dynamic>());
      });
    }
  }

  void dispose() {
    _disposed = true;
    _socket?.dispose();
    _socket = null;
  }
}
