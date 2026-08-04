import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Salva bytes e abre o diálogo de compartilhamento nativo no mobile
/// (Android/iOS). No desktop, salva diretamente na pasta Downloads.
Future<void> downloadBytes(Uint8List bytes, String filename, String mime) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime, name: filename)],
    );
  } else {
    final dir = _targetDir();
    File('${dir.path}/$filename').writeAsBytesSync(bytes);
  }
}

/// Texto (ex.: CSV) em UTF-8 com BOM para o Excel reconhecer acentos.
Future<void> downloadText(String content, String filename, String mime) async {
  final withBom = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(content)]);
  await downloadBytes(withBom, filename, mime);
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
