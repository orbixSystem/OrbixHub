import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/cashier/data/cashier_repository_impl.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';

/// Adapter de gravação: não sai da máquina, só captura a última request e
/// devolve uma resposta canônica — permite testar o que o repository ENVIA
/// (headers/query/body) sem subir um servidor real.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  Object? nextResponseData = <String, dynamic>{};
  int nextStatusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final bytes = utf8.encode(jsonEncode(nextResponseData));
    return ResponseBody.fromBytes(
      bytes,
      nextStatusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter;
  });

  group('CashierRepositoryImpl envia deviceId (ponto de caixa)', () {
    test('openSession envia deviceId no body', () async {
      adapter.nextResponseData = {'id': 'sess-1', 'status': 'open'};
      final repo = CashierRepositoryImpl(dio, () async => 'device-abc');

      final session = await repo.openSession(openingAmount: 10);

      expect(session.id, 'sess-1');
      final body = adapter.lastRequest!.data as Map;
      expect(adapter.lastRequest!.path, '/cashier/sessions/open');
      expect(body['deviceId'], 'device-abc');
      expect(body['openingAmount'], 10);
    });

    test('closeSession envia deviceId no body', () async {
      adapter.nextResponseData = {'id': 'sess-1', 'status': 'closed'};
      final repo = CashierRepositoryImpl(dio, () async => 'device-abc');

      await repo.closeSession(countedAmount: 50);

      final body = adapter.lastRequest!.data as Map;
      expect(adapter.lastRequest!.path, '/cashier/sessions/close');
      expect(body['deviceId'], 'device-abc');
      expect(body['countedAmount'], 50);
    });

    test('currentSession envia deviceId como query param', () async {
      adapter.nextResponseData = {'id': 'sess-1', 'status': 'open'};
      final repo = CashierRepositoryImpl(dio, () async => 'device-xyz');

      await repo.currentSession();

      expect(adapter.lastRequest!.path, '/cashier/sessions/current');
      expect(
        adapter.lastRequest!.queryParameters['deviceId'],
        'device-xyz',
      );
    });

    test('createEntry envia deviceId junto com os demais campos', () async {
      adapter.nextResponseData = {
        'id': 'entry-1',
        'direction': 'in',
        'method': 'dinheiro',
        'category': 'suprimento',
      };
      final repo = CashierRepositoryImpl(dio, () async => 'device-abc');

      await repo.createEntry(const EntryDraft(
        amount: 30,
        method: 'dinheiro',
        category: 'suprimento',
      ));

      final body = adapter.lastRequest!.data as Map;
      expect(adapter.lastRequest!.path, '/cashier/entries');
      expect(body['deviceId'], 'device-abc');
      expect(body['amount'], 30);
      expect(body['method'], 'dinheiro');
      expect(body['category'], 'suprimento');
    });

    test('deviceId é resolvido por chamada (troca entre requests)', () async {
      final ids = ['device-1', 'device-2'];
      var i = 0;
      adapter.nextResponseData = {'id': 'sess-1', 'status': 'open'};
      final repo = CashierRepositoryImpl(dio, () async => ids[i++]);

      await repo.openSession();
      expect((adapter.lastRequest!.data as Map)['deviceId'], 'device-1');

      await repo.openSession();
      expect((adapter.lastRequest!.data as Map)['deviceId'], 'device-2');
    });
  });

  group('degrade gracioso quando a fonte do deviceId falha', () {
    // O backend trata deviceId como opcional (ausente = ponto legado/NULL):
    // se a leitura do id falhar (ex.: SharedPreferences indisponível na
    // primeira leitura), a chamada segue SEM o campo em vez de estourar uma
    // exceção crua por fora do contrato AppException.
    CashierRepositoryImpl repoFalho(Dio dio) => CashierRepositoryImpl(
          dio,
          () async => throw StateError('prefs indisponível'),
        );

    test('openSession segue sem deviceId e a chamada tem sucesso', () async {
      adapter.nextResponseData = {'id': 'sess-1', 'status': 'open'};
      final session = await repoFalho(dio).openSession(openingAmount: 10);

      expect(session.id, 'sess-1');
      final body = adapter.lastRequest!.data as Map;
      expect(body.containsKey('deviceId'), isFalse);
      expect(body['openingAmount'], 10);
    });

    test('closeSession segue sem deviceId', () async {
      adapter.nextResponseData = {'id': 'sess-1', 'status': 'closed'};
      await repoFalho(dio).closeSession(countedAmount: 50);

      final body = adapter.lastRequest!.data as Map;
      expect(body.containsKey('deviceId'), isFalse);
      expect(body['countedAmount'], 50);
    });

    test('currentSession segue sem o query param deviceId', () async {
      adapter.nextResponseData = {'id': 'sess-1', 'status': 'open'};
      final session = await repoFalho(dio).currentSession();

      expect(session, isNotNull);
      expect(
        adapter.lastRequest!.queryParameters.containsKey('deviceId'),
        isFalse,
      );
    });

    test('createEntry segue sem deviceId', () async {
      adapter.nextResponseData = {
        'id': 'entry-1',
        'direction': 'in',
        'method': 'dinheiro',
        'category': 'suprimento',
      };
      final entry = await repoFalho(dio).createEntry(const EntryDraft(
        amount: 30,
        method: 'dinheiro',
        category: 'suprimento',
      ));

      expect(entry.id, 'entry-1');
      final body = adapter.lastRequest!.data as Map;
      expect(body.containsKey('deviceId'), isFalse);
      expect(body['amount'], 30);
    });
  });
}
