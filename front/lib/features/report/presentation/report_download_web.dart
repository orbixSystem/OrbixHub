import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Impl WEB: dispara o download no navegador. Cria um Blob, uma URL temporária
/// e um `<a download>` programático; revoga a URL em seguida.
void downloadBytes(Uint8List bytes, String filename, String mime) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

/// Texto (ex.: CSV) em UTF-8 com BOM para o Excel reconhecer acentos.
void downloadText(String content, String filename, String mime) {
  final withBom = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
  downloadBytes(Uint8List.fromList(withBom), filename, mime);
}
