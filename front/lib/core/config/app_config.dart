/// App configuration sourced from `--dart-define` at build/run time.
///
/// No secrets here — only the backend base URL. Default points at the local
/// Nest dev server (`/api` prefix). Override with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com/api
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  /// Base URL pública do app WEB (onde a página de acompanhamento
  /// `/#/t/<token>` é servida). Na web o origin vem de `Uri.base.origin`; em
  /// desktop/mobile não há origin http, então o link público usa este valor.
  /// Override: `--dart-define=APP_PUBLIC_URL=https://app.exemplo.com`.
  static const String publicWebUrl = String.fromEnvironment(
    'APP_PUBLIC_URL',
    defaultValue: 'http://localhost:8090',
  );
}
