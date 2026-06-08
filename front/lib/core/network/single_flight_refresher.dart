/// Coordinates token refresh so that, no matter how many requests hit a 401 at
/// the same time, only ONE refresh call is in flight. Concurrent callers all
/// await the SAME future and observe the same result. Once it settles, the next
/// call starts a fresh refresh.
///
/// This pairs with the backend's ~10s reuse-tolerance window: a single refresh
/// under burst load avoids tripping refresh-family revocation on flaky networks.
///
/// The actual work is injected as [_perform] (returns true on success) so this
/// coordinator is unit-testable without any HTTP.
class SingleFlightRefresher {
  SingleFlightRefresher(this._perform);

  final Future<bool> Function() _perform;
  Future<bool>? _inFlight;

  /// Number of times the underlying [_perform] was actually invoked. Exposed for
  /// tests asserting the single-flight property.
  int performCount = 0;

  Future<bool> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;

    performCount++;
    final future = _perform().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }
}
