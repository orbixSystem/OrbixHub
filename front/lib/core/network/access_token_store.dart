/// Holds the short-lived JWT access token IN MEMORY only. Never written to disk
/// or secure storage — a fresh access token is obtained from the refresh token
/// on every cold start (silent login). Cleared on logout / refresh failure.
class AccessTokenStore {
  String? _token;

  String? get token => _token;
  bool get hasToken => _token != null;

  void set(String token) => _token = token;
  void clear() => _token = null;
}
