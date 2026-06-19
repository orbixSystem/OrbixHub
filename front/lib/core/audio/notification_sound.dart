import 'package:audioplayers/audioplayers.dart';

/// Som de aviso de mensagem/notificação nova. "Nice to have": qualquer falha
/// (autoplay bloqueado pelo navegador antes de uma interação, plataforma sem
/// áudio, etc.) é engolida — nunca quebra a UI.
class NotificationSound {
  NotificationSound._();

  static final AudioPlayer _player = AudioPlayer(playerId: 'orbix-notify')
    ..setReleaseMode(ReleaseMode.stop);

  /// Toca o "ding" de notificação. O AssetSource resolve para
  /// `assets/sounds/notify.wav` (registrado no pubspec).
  static Future<void> play() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/notify.wav'));
    } catch (_) {
      // silencioso de propósito
    }
  }
}
