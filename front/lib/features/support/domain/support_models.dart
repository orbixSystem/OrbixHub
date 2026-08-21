import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_models.freezed.dart';
part 'support_models.g.dart';

/// Uma mensagem da conversa com o suporte da Orbix.
///
/// `fromOrbix` distingue os dois lados. Só existem dois, então é booleano e não
/// um enum de remetente — não admite terceiro estado inválido.
@freezed
abstract class SupportMessage with _$SupportMessage {
  const factory SupportMessage({
    required String id,
    required String body,
    @Default(false) bool fromOrbix,
    String? authorName,
    required DateTime createdAt,
  }) = _SupportMessage;

  factory SupportMessage.fromJson(Map<String, dynamic> json) =>
      _$SupportMessageFromJson(json);
}
