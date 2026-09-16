/// Coordinates token refresh so that, no matter how many requests hit a 401 at
/// the same time, only ONE refresh call is in flight. Concurrent callers all
/// await the SAME future and observe the same result. Once it settles, the next
/// call starts a fresh refresh.
///
/// This pairs with the backend's ~10s reuse-tolerance window: a single refresh
/// under burst load avoids tripping refresh-family revocation on flaky networks.
///
/// The actual work is injected as [_perform] so this coordinator is
/// unit-testable without any HTTP. Genérico no resultado: quem coordena não
/// precisa saber se o refresh devolve um bool ou o motivo da falha.
class SingleFlightRefresher<T> {
  SingleFlightRefresher(this._perform);

  final Future<T> Function() _perform;
  Future<T>? _inFlight;

  /// Number of times the underlying [_perform] was actually invoked. Exposed for
  /// tests asserting the single-flight property.
  int performCount = 0;

  Future<T> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;

    performCount++;
    final future = _perform().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }
}
