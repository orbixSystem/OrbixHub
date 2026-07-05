import 'tracking_models.dart';

/// Acompanhamento público por token opaco de deep-link. Sem autenticação:
/// a impl real usa um Dio limpo, SEM bearer/refresh.
abstract interface class TrackingRepository {
  /// [token] deve já estar validado de formato pelo chamador.
  Future<PublicTrack> track(String token);

  /// Mensagens do chat (mais recente por último ou primeiro — a UI ordena).
  Future<List<PublicMessage>> messages(String token);

  /// Posta uma mensagem do cliente (rate-limited no servidor). Citação estilo
  /// WhatsApp: [replyToId] responde a uma mensagem; [photoId] cita uma foto da OS
  /// (a url é resolvida no servidor).
  Future<void> sendMessage(
    String token,
    String body, {
    String? authorName,
    String? replyToId,
    String? photoId,
  });

  /// Comentários de uma foto da OS (thread pública).
  Future<List<PublicPhotoComment>> photoComments(String token, String photoId);

  /// Adiciona um comentário do cliente numa foto da OS.
  Future<PublicPhotoComment> addPhotoComment(
    String token,
    String photoId,
    String body, {
    String? authorName,
  });
}
