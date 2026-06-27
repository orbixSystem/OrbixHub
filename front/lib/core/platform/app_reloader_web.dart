import 'package:web/web.dart' as web;

import 'app_reloader.dart';

/// Implementação web: reload completo da página, descartando todo o estado.
class AppReloaderImpl implements AppReloader {
  @override
  void reload() => web.window.location.reload();
}
