import '../domain/tracking_models.dart';
import '../domain/tracking_repository.dart';

/// Mock tracking source until the real public endpoint ships. Returns a fixed
/// timeline keyed by the (already format-validated) token.
class FakeTrackingRepository implements TrackingRepository {
  const FakeTrackingRepository();

  @override
  Future<TrackingStatus> fetchByToken(String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return TrackingStatus(
      token: token,
      vehicle: 'Honda Civic • ABC-1D23',
      statusLabel: 'Em serviço',
      steps: const [
        TrackingStep(label: 'Recebido', done: true),
        TrackingStep(label: 'Diagnóstico', done: true),
        TrackingStep(label: 'Em reparo', done: false),
        TrackingStep(label: 'Pronto para retirada', done: false),
      ],
    );
  }
}
