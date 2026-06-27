// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messages_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Conversation _$ConversationFromJson(Map<String, dynamic> json) =>
    _Conversation(
      id: json['id'] as String,
      title: json['title'] as String?,
      refLabel: json['ref_label'] as String?,
      refType: json['ref_type'] as String?,
      refId: json['ref_id'] as String?,
      staffUnread: (json['staff_unread'] as num?)?.toInt() ?? 0,
      lastMessageAt: json['last_message_at'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageSender: json['last_message_sender'] as String?,
      lastMessageRead: json['last_message_read'] as bool? ?? false,
    );

Map<String, dynamic> _$ConversationToJson(_Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'ref_label': instance.refLabel,
      'ref_type': instance.refType,
      'ref_id': instance.refId,
      'staff_unread': instance.staffUnread,
      'last_message_at': instance.lastMessageAt,
      'last_message': instance.lastMessage,
      'last_message_sender': instance.lastMessageSender,
      'last_message_read': instance.lastMessageRead,
    };

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  sender: json['sender'] as String? ?? 'customer',
  authorName: json['author_name'] as String?,
  body: json['body'] as String? ?? '',
  createdAt: json['created_at'] as String?,
  readAt: json['read_at'] as String?,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'sender': instance.sender,
  'author_name': instance.authorName,
  'body': instance.body,
  'created_at': instance.createdAt,
  'read_at': instance.readAt,
};

_ConversationPage _$ConversationPageFromJson(Map<String, dynamic> json) =>
    _ConversationPage(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => Conversation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Conversation>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 30,
    );

Map<String, dynamic> _$ConversationPageToJson(_ConversationPage instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };
