// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicCompany _$PublicCompanyFromJson(Map<String, dynamic> json) =>
    _PublicCompany(
      name: json['name'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      primaryColor: json['primaryColor'] as String?,
    );

Map<String, dynamic> _$PublicCompanyToJson(_PublicCompany instance) =>
    <String, dynamic>{
      'name': instance.name,
      'logoUrl': instance.logoUrl,
      'primaryColor': instance.primaryColor,
    };

_PublicPhoto _$PublicPhotoFromJson(Map<String, dynamic> json) => _PublicPhoto(
  id: json['id'] as String?,
  url: json['url'] as String,
  caption: json['caption'] as String?,
);

Map<String, dynamic> _$PublicPhotoToJson(_PublicPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'caption': instance.caption,
    };

_PublicQuote _$PublicQuoteFromJson(Map<String, dynamic> json) => _PublicQuote(
  sender: json['sender'] as String? ?? 'staff',
  authorName: json['author_name'] as String?,
  body: json['body'] as String? ?? '',
);

Map<String, dynamic> _$PublicQuoteToJson(_PublicQuote instance) =>
    <String, dynamic>{
      'sender': instance.sender,
      'author_name': instance.authorName,
      'body': instance.body,
    };

_PublicPhotoComment _$PublicPhotoCommentFromJson(Map<String, dynamic> json) =>
    _PublicPhotoComment(
      authorKind: json['authorKind'] as String? ?? 'staff',
      authorName: json['authorName'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
    );

Map<String, dynamic> _$PublicPhotoCommentToJson(_PublicPhotoComment instance) =>
    <String, dynamic>{
      'authorKind': instance.authorKind,
      'authorName': instance.authorName,
      'body': instance.body,
      'createdAt': instance.createdAt,
    };

_PublicEvent _$PublicEventFromJson(Map<String, dynamic> json) => _PublicEvent(
  kind: json['kind'] as String? ?? 'note',
  message: json['message'] as String?,
  statusSnapshot: json['statusSnapshot'] as String?,
  createdAt: json['createdAt'] as String?,
  photoUrl: json['photoUrl'] as String?,
);

Map<String, dynamic> _$PublicEventToJson(_PublicEvent instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'message': instance.message,
      'statusSnapshot': instance.statusSnapshot,
      'createdAt': instance.createdAt,
      'photoUrl': instance.photoUrl,
    };

_PublicOrderItem _$PublicOrderItemFromJson(Map<String, dynamic> json) =>
    _PublicOrderItem(
      kind: json['kind'] as String? ?? 'service',
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$PublicOrderItemToJson(_PublicOrderItem instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'name': instance.name,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'discount': instance.discount,
      'total': instance.total,
    };

_PublicTrack _$PublicTrackFromJson(Map<String, dynamic> json) => _PublicTrack(
  number: json['number'] as String? ?? '',
  status: json['status'] as String? ?? '',
  statusLabel: json['statusLabel'] as String? ?? '',
  subjectLabel: json['subjectLabel'] as String?,
  responsibleName: json['responsibleName'] as String?,
  scheduledEnd: json['scheduledEnd'] as String?,
  diagnosis: json['diagnosis'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => PublicOrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PublicOrderItem>[],
  total: (json['total'] as num?)?.toDouble() ?? 0,
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => PublicPhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PublicPhoto>[],
  timeline:
      (json['timeline'] as List<dynamic>?)
          ?.map((e) => PublicEvent.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PublicEvent>[],
  company: json['company'] == null
      ? const PublicCompany()
      : PublicCompany.fromJson(json['company'] as Map<String, dynamic>),
  vocab: json['vocab'] == null
      ? const PublicVocab()
      : PublicVocab.fromJson(json['vocab'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PublicTrackToJson(_PublicTrack instance) =>
    <String, dynamic>{
      'number': instance.number,
      'status': instance.status,
      'statusLabel': instance.statusLabel,
      'subjectLabel': instance.subjectLabel,
      'responsibleName': instance.responsibleName,
      'scheduledEnd': instance.scheduledEnd,
      'diagnosis': instance.diagnosis,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
      'photos': instance.photos.map((e) => e.toJson()).toList(),
      'timeline': instance.timeline.map((e) => e.toJson()).toList(),
      'company': instance.company.toJson(),
      'vocab': instance.vocab.toJson(),
    };

_PublicVocab _$PublicVocabFromJson(Map<String, dynamic> json) => _PublicVocab(
  objeto: json['objeto'] as String? ?? 'item',
  objetoPlural: json['objetoPlural'] as String? ?? 'itens',
);

Map<String, dynamic> _$PublicVocabToJson(_PublicVocab instance) =>
    <String, dynamic>{
      'objeto': instance.objeto,
      'objetoPlural': instance.objetoPlural,
    };

_PublicMessage _$PublicMessageFromJson(Map<String, dynamic> json) =>
    _PublicMessage(
      id: json['id'] as String?,
      sender: json['sender'] as String? ?? 'staff',
      authorName: json['authorName'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
      readAt: json['readAt'] as String?,
      replyTo: json['replyTo'] == null
          ? null
          : PublicQuote.fromJson(json['replyTo'] as Map<String, dynamic>),
      photoUrl: json['photoUrl'] as String?,
    );

Map<String, dynamic> _$PublicMessageToJson(_PublicMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sender': instance.sender,
      'authorName': instance.authorName,
      'body': instance.body,
      'createdAt': instance.createdAt,
      'readAt': instance.readAt,
      'replyTo': instance.replyTo?.toJson(),
      'photoUrl': instance.photoUrl,
    };
