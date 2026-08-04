// Download/exportação de arquivos (CSV, PDF) — multiplataforma.
//
// Vive em `core/` porque é usado por VÁRIOS módulos (relatórios, OS, venda).
// Antes morava dentro de `features/report/`, e um módulo contratável não pode
// ser dependência dos outros: OS importando de report acoplaria os dois.
//
// Na web dispara o download do navegador (Blob + <a download>); em
// desktop/mobile salva o arquivo em disco (e no celular abre o compartilhar).
// As duas impls expõem downloadBytes/downloadText com a mesma assinatura; o
// export condicional escolhe a certa por plataforma, evitando que
// package:web/dart:js_interop (web-only) sejam compilados para targets nativos.
export 'file_download_io.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
