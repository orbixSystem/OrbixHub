import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracking_models.freezed.dart';

/// One step in the public service-tracking timeline (skeleton).
@freezed
abstract class TrackingStep with _$TrackingStep {
  const factory TrackingStep({
    required String label,
    required bool done,
  }) = _TrackingStep;
}

/// Public service-tracking status, resolved by an opaque deep-link token.
///
/// The real backend endpoint does not exist yet (Agente A/B will expose a
/// tenant-by-token resolver later), so this is populated by a mock repository.
@freezed
abstract class TrackingStatus with _$TrackingStatus {
  const factory TrackingStatus({
    required String token,
    required String vehicle,
    required String statusLabel,
    @Default(<TrackingStep>[]) List<TrackingStep> steps,
  }) = _TrackingStatus;
}
