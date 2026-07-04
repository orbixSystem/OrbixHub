// Download de arquivos (CSV/PDF dos relatórios) — multiplataforma.
//
// Na web dispara o download do navegador (Blob + <a download>); em
// desktop/mobile salva o arquivo em disco. As duas impls expõem
// downloadBytes/downloadText com a mesma assinatura; o export condicional
// escolhe a certa por plataforma, evitando que package:web/dart:js_interop
// (web-only) sejam compilados para targets nativos (macOS/Android/iOS/Windows).
export 'report_download_io.dart'
    if (dart.library.js_interop) 'report_download_web.dart';
