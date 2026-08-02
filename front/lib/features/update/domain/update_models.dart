import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_models.freezed.dart';
part 'update_models.g.dart';

/// O que o servidor informa sobre a última versão publicada do app instalado.
/// A URL vem pronta e assinada — o app nunca vê credencial do repositório.
@freezed
abstract class AppUpdate with _$AppUpdate {
  const AppUpdate._();

  const factory AppUpdate({
    @Default(false) bool enabled,
    String? platform,
    String? version,
    int? buildNumber,

    /// Menor versão que o servidor ainda atende. Abaixo disso o app precisa
    /// atualizar para continuar funcionando.
    String? minSupported,
    String? notes,
    String? url,

    /// Hash do arquivo; conferido antes de instalar.
    String? sha256,
    int? sizeBytes,
    String? publishedAt,
  }) = _AppUpdate;

  factory AppUpdate.fromJson(Map<String, dynamic> json) =>
      _$AppUpdateFromJson(json);

  /// Existe download utilizável?
  bool get hasDownload =>
      enabled && (url ?? '').isNotEmpty && (version ?? '').isNotEmpty;
}

/// Comparação de versões no formato "1.2.3" (partes faltantes contam como 0).
/// Devolve <0 se [a] é anterior a [b], 0 se iguais, >0 se posterior.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .trim()
      .split('+')
      .first // ignora o build ("1.2.3+45")
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();

  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Situação da versão instalada perante o servidor.
enum UpdateStatus {
  /// Nada a fazer (em dia, ou atualização desligada/indisponível).
  emDia,

  /// Há versão nova; o usuário pode adiar.
  disponivel,

  /// A versão instalada está abaixo do mínimo suportado — precisa atualizar
  /// para continuar (o servidor já não a atende direito).
  obrigatoria,
}

/// Decide o que fazer comparando a versão instalada com o que o servidor diz.
/// Função pura — é aqui que mora a regra, e por isso é testável sem rede.
UpdateStatus resolveUpdateStatus({
  required String installedVersion,
  required AppUpdate update,
}) {
  if (!update.hasDownload) return UpdateStatus.emDia;
  final min = update.minSupported;
  if (min != null &&
      min.isNotEmpty &&
      compareVersions(installedVersion, min) < 0) {
    return UpdateStatus.obrigatoria;
  }
  if (compareVersions(installedVersion, update.version!) < 0) {
    return UpdateStatus.disponivel;
  }
  return UpdateStatus.emDia;
}
