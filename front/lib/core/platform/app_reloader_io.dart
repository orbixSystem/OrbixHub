import 'app_reloader.dart';

/// Implementação não-web: no-op. Desktop/mobile não têm cache de página HTTP,
/// e o router já redireciona para /login ao ficar não-autenticado.
class AppReloaderImpl implements AppReloader {
  @override
  void reload() {
    // no-op fora da web
  }
}
