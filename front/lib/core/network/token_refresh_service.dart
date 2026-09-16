// Named params with private fields can't use initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'access_token_store.dart';
import 'refresh_token_store.dart';
import 'single_flight_refresher.dart';

/// Performs the token refresh and persists the new pair, wrapped in a
/// [SingleFlightRefresher] so concurrent 401s collapse into ONE refresh call.
///
/// Uses a BARE dio (no auth interceptor) so the refresh request can never
/// recurse back into the 401 handler.
///
/// The refresh token is read from the in-memory [RefreshTokenStore] (set at
/// login / bootstrap). The rotated token is written back to memory always, and
/// to [SecureTokenStore] ONLY when the session opted into "keep me logged in"
/// ([RefreshTokenStore.remember]). This keeps the mid-session 401 refresh
/// working even when the user did not opt into persistence.
class TokenRefreshService {
  TokenRefreshService({
    required Dio bareDio,
    required AccessTokenStore accessStore,
    required RefreshTokenStore refreshStore,
    required SecureTokenStore secureStore,
  })  : _bareDio = bareDio,
        _accessStore = accessStore,
        _refreshStore = refreshStore,
        _secureStore = secureStore {
    coordinator = SingleFlightRefresher(_perform);
  }

  final Dio _bareDio;
  final AccessTokenStore _accessStore;
  final RefreshTokenStore _refreshStore;
  final SecureTokenStore _secureStore;

  late final SingleFlightRefresher<RefreshOutcome> coordinator;

  /// Returns true if a fresh access token is now in [AccessTokenStore].
  Future<bool> refresh() async => (await refreshDetailed()) == RefreshOutcome.ok;

  /// Same refresh, but saying WHY it failed — quem chama precisa distinguir
  /// "o servidor recusou a sessão" de "não deu para falar com o servidor".
  Future<RefreshOutcome> refreshDetailed() => coordinator.refresh();

  /// Token a apresentar: o PERSISTIDO na frente do que está em memória.
  ///
  /// Na web o armazenamento seguro é compartilhado entre as abas, mas a memória
  /// não. Com duas abas abertas (o caso comum: caixa numa, OS na outra), a aba
  /// que rotaciona grava o token novo e a outra continua com o antigo na
  /// memória. Quando a segunda aba refresca, apresenta um token já rotacionado
  /// — e o servidor trata reapresentação fora da janela de tolerância como
  /// ATAQUE DE REUSO: revoga a FAMÍLIA inteira, derrubando também a aba que
  /// estava com o token válido. As duas caem juntas.
  ///
  /// Reler o persistido antes de cada refresh faz a segunda aba usar o token
  /// que a primeira acabou de gravar. Se as duas refrescarem no mesmo instante,
  /// aí sim a janela de tolerância do servidor cobre — que é para isso que ela
  /// existe.
  Future<String?> _tokenMaisRecente() async {
    if (!_refreshStore.remember) return _refreshStore.token;
    try {
      return await _secureStore.readRefreshToken() ?? _refreshStore.token;
    } catch (_) {
      // Storage indisponível não pode impedir o refresh.
      return _refreshStore.token;
    }
  }

  Future<RefreshOutcome> _perform() async {
    final refreshToken = await _tokenMaisRecente();
    if (refreshToken == null) return RefreshOutcome.semToken;
    try {
      final res = await _bareDio.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = (res.data as Map).cast<String, dynamic>();
      _accessStore.set(data['accessToken'] as String);
      final rotated = data['refreshToken'] as String;
      _refreshStore.set(rotated);
      if (_refreshStore.remember) {
        await _secureStore.writeRefreshToken(rotated);
      }
      return RefreshOutcome.ok;
    } on DioException catch (e) {
      // Só o SERVIDOR pode declarar a sessão morta. Antes, qualquer exceção
      // apagava os tokens — inclusive timeout e queda de rede, que é o pão de
      // cada dia de uma oficina com wi-fi ruim: a sessão continuava válida no
      // servidor e mesmo assim o app deslogava o usuário. O bootstrap já fazia
      // essa distinção (ver B6 no SessionController); aqui não fazia.
      if (_ehRejeicaoDeAuth(e)) {
        _accessStore.clear();
        _refreshStore.clear();
        await _secureStore.clear();
        return RefreshOutcome.sessaoRejeitada;
      }
      // Rede: o access token continua vencido (a requisição vai falhar), mas a
      // sessão sobrevive e a próxima tentativa tem chance.
      return RefreshOutcome.falhaDeRede;
    } catch (_) {
      // Resposta inesperada (corpo fora do formato) — não é prova de que a
      // sessão morreu, então não derruba.
      return RefreshOutcome.falhaDeRede;
    }
  }

  static bool _ehRejeicaoDeAuth(DioException e) {
    final status = e.response?.statusCode;
    return status == 401 || status == 403;
  }
}

/// Desfecho de um refresh — ver [TokenRefreshService.refreshDetailed].
enum RefreshOutcome {
  ok,

  /// Não havia refresh token para apresentar.
  semToken,

  /// O servidor recusou (401/403): a sessão acabou de verdade.
  sessaoRejeitada,

  /// Não deu para falar com o servidor. A sessão pode continuar válida.
  falhaDeRede,
}
