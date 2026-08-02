import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hashlib/hashlib.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Progresso do download (0..1) — null quando o servidor não informa o tamanho.
typedef UpdateProgress = void Function(double? fraction);

/// Erro de atualização com mensagem pronta para o usuário.
class UpdateFailure implements Exception {
  const UpdateFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Baixa o instalador, CONFERE o hash e abre a instalação.
///
/// A verificação do sha256 não é decoração: o app está prestes a executar um
/// binário. Se o arquivo não bate com o que o servidor anunciou (download
/// corrompido, proxy intrometido), abortamos em vez de instalar.
class UpdateInstaller {
  UpdateInstaller(this._dio);

  /// Dio SEM o interceptor de auth: a URL é assinada e aponta para outro host
  /// (o storage do provedor) — mandar nosso bearer para lá seria vazá-lo.
  final Dio _dio;

  /// Nome de arquivo por plataforma; o instalador só abre com a extensão certa.
  static String fileNameFor(String platform, String version) =>
      platform == 'windows'
          ? 'OrbixHubSetup-$version.exe'
          : 'orbixhub-$version.apk';

  Future<void> downloadAndInstall({
    required String url,
    required String platform,
    required String version,
    String? expectedSha256,
    UpdateProgress? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${fileNameFor(platform, version)}');
    if (await file.exists()) await file.delete();

    try {
      await _dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          onProgress?.call(total > 0 ? received / total : null);
        },
      );
    } on DioException catch (e) {
      throw UpdateFailure(
        'Não foi possível baixar a atualização (${e.type.name}).',
      );
    }

    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final digest = await sha256.file(file);
      if (digest.hex().toLowerCase() != expectedSha256.toLowerCase()) {
        await file.delete();
        throw const UpdateFailure(
          'O arquivo baixado não confere com a versão publicada. '
          'A atualização foi cancelada por segurança.',
        );
      }
    }

    if (Platform.isWindows) {
      // O instalador roda por fora e substitui os arquivos do app — por isso
      // ele precisa iniciar destacado, e o app fecha em seguida.
      await Process.start(
        file.path,
        const ['/SILENT', '/NOCANCEL'],
        mode: ProcessStartMode.detached,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      exit(0);
    }

    // Android: abre o pacote; o sistema pede a confirmação do usuário
    // (o app declara REQUEST_INSTALL_PACKAGES no manifesto).
    final res = await OpenFilex.open(file.path);
    if (res.type != ResultType.done) {
      throw UpdateFailure(
        'Não foi possível abrir o instalador: ${res.message}',
      );
    }
  }
}
