import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracking_models.freezed.dart';
part 'tracking_models.g.dart';

/// Empresa (oficina) que dona a OS — usada no cabeçalho da página pública.
@freezed
abstract class PublicCompany with _$PublicCompany {
  const factory PublicCompany({
    @Default('') String name,
    String? logoUrl,
    String? primaryColor,
  }) = _PublicCompany;

  factory PublicCompany.fromJson(Map<String, dynamic> json) =>
      _$PublicCompanyFromJson(json);
}

/// Foto pública da OS — `url` já utilizável em `Image.network`. `id` permite ao
/// cliente citar a foto no chat e comentar nela.
@freezed
abstract class PublicPhoto with _$PublicPhoto {
  const factory PublicPhoto({
    String? id,
    required String url,
    String? caption,
  }) = _PublicPhoto;

  factory PublicPhoto.fromJson(Map<String, dynamic> json) =>
      _$PublicPhotoFromJson(json);
}

/// Preview de uma mensagem citada (reply-to) no chat público.
@freezed
abstract class PublicQuote with _$PublicQuote {
  const factory PublicQuote({
    @Default('staff') String sender,
    @JsonKey(name: 'author_name') String? authorName,
    @Default('') String body,
  }) = _PublicQuote;

  factory PublicQuote.fromJson(Map<String, dynamic> json) =>
      _$PublicQuoteFromJson(json);
}

/// Comentário numa foto (thread pública). `authorKind` ∈ staff|customer.
@freezed
abstract class PublicPhotoComment with _$PublicPhotoComment {
  const factory PublicPhotoComment({
    @JsonKey(name: 'authorKind') @Default('staff') String authorKind,
    @JsonKey(name: 'authorName') String? authorName,
    @Default('') String body,
    String? createdAt,
  }) = _PublicPhotoComment;

  factory PublicPhotoComment.fromJson(Map<String, dynamic> json) =>
      _$PublicPhotoCommentFromJson(json);
}

/// Evento da linha do tempo pública. `kind` ∈ created|status_change|note|photo.
/// O backend devolve em ordem decrescente (mais recente primeiro).
@freezed
abstract class PublicEvent with _$PublicEvent {
  const factory PublicEvent({
    @Default('note') String kind,
    String? message,
    String? statusSnapshot,
    String? createdAt,
    /// Foto DESTE evento, quando ele nasceu de um anexo. Deixa a imagem
    /// aparecer no momento em que foi tirada, em vez de só numa galeria à
    /// parte — é o que transforma a lista num acompanhamento de verdade.
    String? photoUrl,
  }) = _PublicEvent;

  factory PublicEvent.fromJson(Map<String, dynamic> json) =>
      _$PublicEventFromJson(json);
}

/// Status público da OS resolvido por um token opaco de deep-link. Sem auth.
@freezed
abstract class PublicTrack with _$PublicTrack {
  const factory PublicTrack({
    @Default('') String number,
    @Default('') String status,
    @Default('') String statusLabel,
    String? subjectLabel,
    String? responsibleName,
    String? scheduledEnd,
    String? diagnosis,
    @Default(<PublicPhoto>[]) List<PublicPhoto> photos,
    @Default(<PublicEvent>[]) List<PublicEvent> timeline,
    @Default(PublicCompany()) PublicCompany company,
    /// Vocabulário do nicho, resolvido pelo servidor. A página é pública (sem
    /// sessão), então não tem como resolver isso sozinha — e é aqui que mais
    /// importa: quem lê é o cliente final da empresa.
    @Default(PublicVocab()) PublicVocab vocab,
  }) = _PublicTrack;

  factory PublicTrack.fromJson(Map<String, dynamic> json) =>
      _$PublicTrackFromJson(json);
}

/// Palavras do nicho usadas na página pública.
@freezed
abstract class PublicVocab with _$PublicVocab {
  const factory PublicVocab({
    @Default('item') String objeto,
    @Default('itens') String objetoPlural,
  }) = _PublicVocab;

  factory PublicVocab.fromJson(Map<String, dynamic> json) =>
      _$PublicVocabFromJson(json);
}

/// Mensagem do chat público. `sender` ∈ customer|staff (staff = oficina).
@freezed
abstract class PublicMessage with _$PublicMessage {
  const factory PublicMessage({
    /// Id da mensagem no servidor — usado para responder (citar) via `replyToId`.
    String? id,
    @Default('staff') String sender,
    String? authorName,
    @Default('') String body,
    String? createdAt,
    /// Quando a oficina (staff) leu esta mensagem do cliente (recibo de leitura).
    String? readAt,
    /// Citação (estilo WhatsApp): mensagem respondida + foto da OS citada.
    @JsonKey(name: 'replyTo') PublicQuote? replyTo,
    @JsonKey(name: 'photoUrl') String? photoUrl,
  }) = _PublicMessage;

  factory PublicMessage.fromJson(Map<String, dynamic> json) =>
      _$PublicMessageFromJson(json);
}
