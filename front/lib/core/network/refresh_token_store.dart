/// Holds the opaque refresh token IN MEMORY for the current session, plus the
/// [remember] flag that decides whether it is ALSO persisted to secure storage.
///
/// Why a memory layer: the 401 refresh flow needs the refresh token during the
/// session even when the user did NOT opt into "keep me logged in". With
/// [remember] = false we keep the token here (session-only) and never write it
/// to the secure store, so closing the app drops the session. With
/// [remember] = true the token is also written to [SecureTokenStore], so a cold
/// start restores the session. The access token still lives only in
/// [AccessTokenStore]; the refresh token is never on disk unless [remember].
class RefreshTokenStore {
  String? _token;

  /// Whether the current session's refresh token should be persisted to the
  /// secure store (opt-in "Manter conectado"). Defaults to off.
  bool remember = false;

  String? get token => _token;

  void set(String token) => _token = token;

  void clear() {
    _token = null;
    remember = false;
  }
}
