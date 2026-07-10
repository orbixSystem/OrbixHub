import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable per-install device id (uuid v4), persisted once under
/// `orbix_device_id`. Downstream offline code (outbox, sync push) stamps
/// local mutations with this id so authorship survives across app restarts
/// (S1: autoria no outbox/push) and the backend can recognize/replay pushes
/// idempotently per device.
class DeviceIdentity {
  const DeviceIdentity();

  static const _key = 'orbix_device_id';

  /// Returns the persisted device id, generating and persisting a new uuid v4
  /// on first call. Idempotent: subsequent calls (even across app restarts)
  /// always return the same id.
  Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = const Uuid().v4();
    await prefs.setString(_key, id);
    return id;
  }
}
