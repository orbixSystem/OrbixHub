import 'app_reloader_io.dart' if (dart.library.js_interop) 'app_reloader_web.dart';

/// Reinicia o app do zero, descartando **todo** o estado em memória (todos os
/// providers Riverpod, o access token em memória, qualquer cache de feature).
///
/// É o reset à prova de bala usado no logout/expire: em vez de invalidar dezenas
/// de providers (frágil — cada módulo novo teria de lembrar de se incluir), faz
/// um reload completo. Combinado com `Cache-Control: no-store` (backend + serve
/// dev) e o service worker desativado, garante que NENHUM dado da conta anterior
/// sobreviva ao login de outra conta.
///
/// Na web: reload completo da página. Em outras plataformas: no-op (o redirect
/// do router para /login já cobre o caso, sem cache de página persistente).
abstract class AppReloader {
  void reload();

  factory AppReloader() = AppReloaderImpl;
}
