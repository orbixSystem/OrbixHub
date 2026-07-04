import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Impl NÃO-WEB (desktop/mobile): salva o arquivo em disco. Tenta a pasta
/// Downloads do usuário; se não houver acesso (ex.: sandbox do macOS), cai para
/// o diretório temporário do sistema. Mantém a mesma API da impl web para o
/// import condicional em report_download.dart.
void downloadBytes(Uint8List bytes, String filename, String mime) {
  final dir = _targetDir();
  File('${dir.path}/$filename').writeAsBytesSync(bytes);
}

/// Texto (ex.: CSV) em UTF-8 com BOM para o Excel reconhecer acentos.
void downloadText(String content, String filename, String mime) {
  final withBom = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
  downloadBytes(Uint8List.fromList(withBom), filename, mime);
}

Directory _targetDir() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null) {
    final downloads = Directory('$home/Downloads');
    try {
      if (downloads.existsSync()) return downloads;
    } catch (_) {
      // sem acesso (sandbox) — cai para o temp
    }
  }
  return Directory.systemTemp;
}
