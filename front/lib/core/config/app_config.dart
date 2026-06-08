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
}
