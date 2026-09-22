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

    /// Build mínimo aceito DENTRO da mesma versão. Necessário porque o número
    /// da versão não muda a cada publicação: sem isto, 1.0.0+13 não seria
    /// reconhecido como mais novo que 1.0.0+12.
    int? minSupportedBuild,
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

/// Compara (versão, build): o build só desempata quando a versão é igual.
int _compare(String vA, int bA, String vB, int bB) {
  final byVersion = compareVersions(vA, vB);
  return byVersion != 0 ? byVersion : bA - bB;
}

/// Decide o que fazer comparando o que está instalado com o que o servidor diz.
/// Função pura — é aqui que mora a regra, e por isso é testável sem rede.
///
/// O build entra na conta porque publicar não muda o número da versão: entre
/// 1.0.0+12 e 1.0.0+13 só o build difere, e ignorá-lo faria toda atualização
/// passar despercebida.
UpdateStatus resolveUpdateStatus({
  required String installedVersion,
  required AppUpdate update,
  int installedBuild = 0,
}) {
  if (!update.hasDownload) return UpdateStatus.emDia;

  final min = update.minSupported;
  if (min != null && min.isNotEmpty) {
    final atrasado = _compare(
          installedVersion,
          installedBuild,
          min,
          update.minSupportedBuild ?? 0,
        ) <
        0;
    if (atrasado) return UpdateStatus.obrigatoria;
  }

  final maisNovoDisponivel = _compare(
        installedVersion,
        installedBuild,
        update.version!,
        update.buildNumber ?? 0,
      ) <
      0;
  return maisNovoDisponivel ? UpdateStatus.disponivel : UpdateStatus.emDia;
}

/// Identidade da versão publicada, para lembrar o que o usuário já dispensou.
///
/// Versão **e** build: o pubspec fica em 1.0.0 por várias publicações, então só
/// a versão não distingue 1.0.0+13 de 1.0.0+14 — adiar uma silenciaria todas as
/// seguintes.
String chaveDaVersao(AppUpdate u) => '${u.version ?? ''}+${u.buildNumber ?? 0}';

/// ONDE o aviso de atualização aparece.
enum AvisoAtualizacao {
  /// Nada a mostrar.
  nenhum,

  /// Tela cheia: a versão não é mais atendida pelo servidor. Sem "depois".
  bloqueio,

  /// Faixa no topo, com "Depois" — há trabalho em curso e a decisão é do
  /// usuário.
  banner,

  /// Só no sino. É o destino do "Depois": o aviso não desaparece (a
  /// atualização continua pendente), mas para de interromper.
  sino,
}

/// Decide onde avisar. Função pura — a regra que decide se a oficina é
/// interrompida no meio do expediente não deveria depender de rede para ser
/// testada.
///
/// [adiada] é a [chaveDaVersao] que o usuário dispensou (persistida entre
/// sessões). Duas consequências deliberadas:
///
/// - adiar NUNCA silencia uma atualização obrigatória — ali seguir usando daria
///   erro a cada ação, então não há "depois" a respeitar;
/// - adiar vale para AQUELA versão. Quando sai uma nova, o banner volta: quem
///   disse "depois" para a 1.0.13 não disse para a 1.0.14.
///
/// E, adiado, o aviso não é esquecido: vai para o sino e fica lá enquanto a
/// atualização estiver pendente. Ressurgir como banner a cada hora é o que
/// treina o usuário a ignorar avisos.
AvisoAtualizacao resolveAviso({
  required UpdateStatus status,
  required AppUpdate update,
  required String? adiada,
}) {
  switch (status) {
    case UpdateStatus.emDia:
      return AvisoAtualizacao.nenhum;
    case UpdateStatus.obrigatoria:
      return AvisoAtualizacao.bloqueio;
    case UpdateStatus.disponivel:
      return adiada == chaveDaVersao(update)
          ? AvisoAtualizacao.sino
          : AvisoAtualizacao.banner;
  }
}
