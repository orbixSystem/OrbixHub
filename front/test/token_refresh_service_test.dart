import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/network/access_token_store.dart';
import 'package:orbixhub_front/core/network/refresh_token_store.dart';
import 'package:orbixhub_front/core/network/token_refresh_service.dart';
import 'package:orbixhub_front/core/storage/secure_token_store.dart';

/// Os dois jeitos de o app se deslogar sozinho — ambos reproduzidos contra a
/// API antes de virarem teste.
///
/// 1. Queda de rede no refresh apagava os tokens. A sessão continuava VÁLIDA no
///    servidor e mesmo assim o usuário voltava para a tela de login. Numa
///    oficina com wi-fi instável isso acontece o dia todo.
/// 2. O token apresentado vinha só da memória. Na web o armazenamento seguro é
///    compartilhado entre abas e a memória não: a segunda aba apresentava um
///    token já rotacionado, o servidor lia como reuso e revogava a FAMÍLIA —
///    derrubando junto a aba que estava com o token bom.
class _FakeSecureStore implements SecureTokenStore {
  _FakeSecureStore([this._token]);
  String? _token;
  int escritas = 0;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async {
    escritas++;
    _token = token;
  }

  @override
  Future<void> clear() async => _token = null;
}

/// Dio que responde ao POST /auth/refresh conforme o roteiro.
Dio _dioQue({
  String? rotacionaPara,
  int? status,
  DioExceptionType? tipoDeErro,
  void Function(String apresentado)? aoReceber,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _AdapterFake(
    rotacionaPara: rotacionaPara,
    status: status,
    tipoDeErro: tipoDeErro,
    aoReceber: aoReceber,
  );
  return dio;
}

class _AdapterFake implements HttpClientAdapter {
  _AdapterFake({
    this.rotacionaPara,
    this.status,
    this.tipoDeErro,
    this.aoReceber,
  });
  final String? rotacionaPara;
  final int? status;
  final DioExceptionType? tipoDeErro;
  final void Function(String)? aoReceber;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _, Future<void>? _) async {
    final body = options.data as Map;
    aoReceber?.call(body['refreshToken'] as String);
    if (tipoDeErro != null) {
      throw DioException(requestOptions: options, type: tipoDeErro!);
    }
    if (status != null) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      '{"accessToken":"novo-access","refreshToken":"$rotacionaPara"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

({
  TokenRefreshService svc,
  AccessTokenStore access,
  RefreshTokenStore refresh,
  _FakeSecureStore secure,
})
_montar(Dio dio, {String? emMemoria, String? persistido, bool remember = true}) {
  final access = AccessTokenStore()..set('access-velho');
  final refresh = RefreshTokenStore()..remember = remember;
  if (emMemoria != null) refresh.set(emMemoria);
  final secure = _FakeSecureStore(persistido);
  return (
    svc: TokenRefreshService(
      bareDio: dio,
      accessStore: access,
      refreshStore: refresh,
      secureStore: secure,
    ),
    access: access,
    refresh: refresh,
    secure: secure,
  );
}

void main() {
  test('refresh normal: troca os tokens e persiste o rotacionado', () async {
    final m = _montar(
      _dioQue(rotacionaPara: 'r2'),
      emMemoria: 'r1',
      persistido: 'r1',
    );
    expect(await m.svc.refreshDetailed(), RefreshOutcome.ok);
    expect(m.access.token, 'novo-access');
    expect(m.refresh.token, 'r2');
    expect(await m.secure.readRefreshToken(), 'r2');
  });

  group('queda de rede NÃO pode deslogar', () {
    for (final tipo in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('$tipo preserva a sessão', () async {
        final m = _montar(
          _dioQue(tipoDeErro: tipo),
          emMemoria: 'r1',
          persistido: 'r1',
        );
        expect(await m.svc.refreshDetailed(), RefreshOutcome.falhaDeRede);
        // O servidor nunca disse que a sessão morreu — os tokens continuam.
        expect(m.refresh.token, 'r1');
        expect(await m.secure.readRefreshToken(), 'r1');
      });
    }
  });

  group('recusa do SERVIDOR derruba mesmo', () {
    for (final status in [401, 403]) {
      test('HTTP $status limpa tudo', () async {
        final m = _montar(
          _dioQue(status: status),
          emMemoria: 'r1',
          persistido: 'r1',
        );
        expect(await m.svc.refreshDetailed(), RefreshOutcome.sessaoRejeitada);
        expect(m.access.token, isNull);
        expect(m.refresh.token, isNull);
        expect(await m.secure.readRefreshToken(), isNull);
      });
    }

    test('500 do servidor NÃO derruba — não é prova de sessão morta', () async {
      final m = _montar(
        _dioQue(status: 500),
        emMemoria: 'r1',
        persistido: 'r1',
      );
      expect(await m.svc.refreshDetailed(), RefreshOutcome.falhaDeRede);
      expect(m.refresh.token, 'r1');
    });
  });

  test('apresenta o token PERSISTIDO, não o obsoleto da memória', () async {
    // É a segunda aba: a primeira já rotacionou r1→r2 e gravou r2. Mandar r1
    // aqui faria o servidor ler reuso e revogar a família das DUAS abas.
    String? apresentado;
    final m = _montar(
      _dioQue(rotacionaPara: 'r3', aoReceber: (t) => apresentado = t),
      emMemoria: 'r1',
      persistido: 'r2',
    );
    await m.svc.refreshDetailed();
    expect(apresentado, 'r2');
  });

  test('sem "manter conectado", usa a memória (não há persistido)', () async {
    String? apresentado;
    final m = _montar(
      _dioQue(rotacionaPara: 'r2', aoReceber: (t) => apresentado = t),
      emMemoria: 'r1',
      remember: false,
    );
    expect(await m.svc.refreshDetailed(), RefreshOutcome.ok);
    expect(apresentado, 'r1');
    // E não passa a persistir por acidente: quem não pediu para ser lembrado
    // não pode ter o token gravado no aparelho.
    expect(m.secure.escritas, 0);
  });

  test('sem token nenhum não vira falha de sessão', () async {
    final m = _montar(_dioQue(rotacionaPara: 'r2'));
    expect(await m.svc.refreshDetailed(), RefreshOutcome.semToken);
  });

  test('chamadas concorrentes colapsam num único refresh', () async {
    var chamadas = 0;
    final m = _montar(
      _dioQue(rotacionaPara: 'r2', aoReceber: (_) => chamadas++),
      emMemoria: 'r1',
      persistido: 'r1',
    );
    final r = await Future.wait([
      m.svc.refreshDetailed(),
      m.svc.refreshDetailed(),
      m.svc.refreshDetailed(),
    ]);
    expect(r, everyElement(RefreshOutcome.ok));
    // Mais de um refresh em voo é exatamente o que cria o token obsoleto.
    expect(chamadas, 1);
  });
}
