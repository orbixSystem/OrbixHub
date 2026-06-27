import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';

/// A single dev-inbox entry. The backend returns the latest artifacts that are
/// normally delivered by e-mail (invite links, verification / reset tokens) so
/// they can be inspected without a mailbox in dev.
///
/// `type` ∈ invite | email_verify | password_reset. For `invite`, [value] is a
/// full URL; for the others it is a bare token.
class DevInboxEntry {
  const DevInboxEntry({
    required this.type,
    required this.label,
    required this.value,
    this.createdAt,
  });

  final String type;
  final String label;
  final String value;
  final DateTime? createdAt;

  factory DevInboxEntry.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return DevInboxEntry(
      type: (json['type'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      createdAt: created == null ? null : DateTime.tryParse(created.toString()),
    );
  }
}

/// Reads the dev-only `GET /dev/inbox` endpoint. In production the route does
/// not exist (404) — any [DioException] is swallowed and treated as "empty".
class DevInboxRepository {
  DevInboxRepository(this._dio);

  final Dio _dio;

  Future<List<DevInboxEntry>> fetch() async {
    try {
      final res = await _dio.get<Object?>('/dev/inbox');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      return list.map(DevInboxEntry.fromJson).toList();
    } on DioException {
      return [];
    }
  }
}

final devInboxRepositoryProvider =
    Provider<DevInboxRepository>((ref) => DevInboxRepository(ref.read(dioProvider)));

final devInboxProvider = FutureProvider<List<DevInboxEntry>>(
    (ref) => ref.read(devInboxRepositoryProvider).fetch());
