import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const String _envUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    // Android emulator: localhost refere-se ao próprio emulador; 10.0.2.2 é o host
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4400/api';
    return 'http://localhost:4400/api';
  }

  /// Base URL pública do app WEB (onde a página de acompanhamento
  /// `/#/t/<token>` é servida). Na web o origin vem de `Uri.base.origin`; em
  /// desktop/mobile não há origin http, então o link público usa este valor.
  /// Override: `--dart-define=APP_PUBLIC_URL=https://app.exemplo.com`.
  static const String publicWebUrl = String.fromEnvironment(
    'APP_PUBLIC_URL',
    defaultValue: 'http://localhost:8090',
  );
}
