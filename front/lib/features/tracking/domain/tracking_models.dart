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

/// Foto pública da OS — `url` já utilizável em `Image.network`.
@freezed
abstract class PublicPhoto with _$PublicPhoto {
  const factory PublicPhoto({
    required String url,
    String? caption,
  }) = _PublicPhoto;

  factory PublicPhoto.fromJson(Map<String, dynamic> json) =>
      _$PublicPhotoFromJson(json);
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
    String? scheduledEnd,
    @Default(<PublicPhoto>[]) List<PublicPhoto> photos,
    @Default(<PublicEvent>[]) List<PublicEvent> timeline,
    @Default(PublicCompany()) PublicCompany company,
  }) = _PublicTrack;

  factory PublicTrack.fromJson(Map<String, dynamic> json) =>
      _$PublicTrackFromJson(json);
}

/// Mensagem do chat público. `sender` ∈ customer|staff (staff = oficina).
@freezed
abstract class PublicMessage with _$PublicMessage {
  const factory PublicMessage({
    @Default('staff') String sender,
    String? authorName,
    @Default('') String body,
    String? createdAt,
  }) = _PublicMessage;

  factory PublicMessage.fromJson(Map<String, dynamic> json) =>
      _$PublicMessageFromJson(json);
}
