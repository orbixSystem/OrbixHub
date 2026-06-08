import 'tracking_models.dart';

/// Resolves a public tracking status from an opaque deep-link token. No auth.
/// Backed by a mock until the real public endpoint ships.
abstract interface class TrackingRepository {
  /// [token] must already be validated for format by the caller.
  Future<TrackingStatus> fetchByToken(String token);
}
