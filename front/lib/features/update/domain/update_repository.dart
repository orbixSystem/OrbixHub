import 'update_models.dart';

/// Contrato da atualização do app instalado. O servidor é quem sabe a versão
/// publicada e resolve o link de download (o repositório de releases é privado
/// — nenhuma credencial vive no cliente).
abstract interface class UpdateRepository {
  /// Última versão publicada para esta plataforma.
  Future<AppUpdate> latest(String platform);
}
