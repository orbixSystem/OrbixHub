import 'tracking_models.dart';

/// Acompanhamento público por token opaco de deep-link. Sem autenticação:
/// a impl real usa um Dio limpo, SEM bearer/refresh.
abstract interface class TrackingRepository {
  /// [token] deve já estar validado de formato pelo chamador.
  Future<PublicTrack> track(String token);

  /// Mensagens do chat (mais recente por último ou primeiro — a UI ordena).
  Future<List<PublicMessage>> messages(String token);

  /// Posta uma mensagem do cliente (rate-limited no servidor).
  Future<void> sendMessage(String token, String body, {String? authorName});
}
