
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/receivables/data/receivables_repository_impl.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_tab.dart';

/// Caminho REAL do fiado: `ReceivablesRepositoryImpl` sobre dio, com o payload
/// exato que o backend devolve (capturado de `GET /api/receivables`).
///
/// Os testes anteriores exercitavam o fake, então cobriam a UI mas não a
/// desserialização nem o transporte — que é onde um "carrega para sempre"
/// costuma morar.

/// Adapter que responde localmente, sem rede.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respostas);

  /// path → (status, corpo JSON)
  final Map<String, (int, String)> respostas;
  final List<String> chamadas = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    chamadas.add(options.path);
    final r = respostas[options.path];
    if (r == null) {
      return ResponseBody.fromString('{"message":"não mapeado"}', 404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
    }
    return ResponseBody.fromString(r.$2, r.$1, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

// Payload REAL do backend (dois devedores).
const _devedoresJson = '''
{
  "items": [
    {"customerId":"95af0fb8-3641-466f-b693-de86d43e0cf6","customerName":"João da Silva",
     "totalDue":645.6,"titleCount":2,"oldestAt":"2026-07-15T17:00:58.018Z"},
    {"customerId":"2c9e287c-3e47-41d2-a2e2-a56ecd5224d2","customerName":"Maria Oliveira",
     "totalDue":300,"titleCount":1,"oldestAt":"2026-07-18T14:00:58.018Z"}
  ],
  "totalDue": 945.6,
  "truncated": false
}
''';

const _titulosJson = '''
{
  "customerName": "João da Silva",
  "totalDue": 645.6,
  "items": [
    {"origin":"os","id":"bd377fcb-323b-4bb6-8988-445aa9c0271f","number":"OS-0001",
     "createdAt":"2026-07-15T17:00:58.018Z","total":295.6,"paid":0,"balance":295.6,
     "status":"a_receber",
     "items":[
       {"name":"Troca de Óleo e Filtro","kind":"service","quantity":1,"unitPrice":80,"total":80},
       {"name":"Óleo Motor 5W30 Sintético 1L","kind":"product","quantity":4,"unitPrice":45.9,"total":183.6}
     ]}
  ]
}
''';

Dio _dioCom(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x/api'));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// Online por padrão: sem isto a tela mostra o aviso "Fiado precisa de conexão"
/// (o estado inicial do controller não é `online`).
class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

void main() {
  group('desserialização do payload real', () {
    test('lista de devedores', () async {
      final adapter = _FakeAdapter({'/receivables': (200, _devedoresJson)});
      final repo = ReceivablesRepositoryImpl(_dioCom(adapter));

      final page = await repo.listDebtors();
      expect(page.items, hasLength(2));
      expect(page.items.first.customerName, 'João da Silva');
      expect(page.items.first.totalDue, 645.6);
      expect(page.items.first.titleCount, 2);
      expect(page.totalDue, 945.6);
      expect(page.truncated, isFalse);
    });

    test('títulos de um cliente, com itens', () async {
      final adapter = _FakeAdapter({'/receivables/c1': (200, _titulosJson)});
      final repo = ReceivablesRepositoryImpl(_dioCom(adapter));

      final d = await repo.titlesOf('c1');
      expect(d.customerName, 'João da Silva');
      expect(d.items, hasLength(1));
      expect(d.items.first.number, 'OS-0001');
      expect(d.items.first.balance, 295.6);
      expect(d.items.first.items, hasLength(2));
      expect(d.items.first.items.first.name, 'Troca de Óleo e Filtro');
      expect(d.items.first.items[1].unitPrice, 45.9);
    });

    test('vendas sem cliente usam a rota literal (não um uuid)', () async {
      final adapter = _FakeAdapter({
        '/receivables/sem-cliente': (200, '{"customerName":"Sem cliente","totalDue":0,"items":[]}'),
      });
      final repo = ReceivablesRepositoryImpl(_dioCom(adapter));

      await repo.titlesOf(null);
      expect(adapter.chamadas, ['/receivables/sem-cliente']);
    });

    test('carteira vazia desserializa sem erro', () async {
      final adapter = _FakeAdapter({
        '/receivables': (200, '{"items":[],"totalDue":0,"truncated":false}'),
      });
      final repo = ReceivablesRepositoryImpl(_dioCom(adapter));
      final page = await repo.listDebtors();
      expect(page.items, isEmpty);
    });
  });

  group('a tela RESOLVE o carregamento (não fica eterna)', () {
    Widget app(_FakeAdapter adapter) => ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(_OnlineConn.new),
            receivablesRepositoryProvider
                .overrideWithValue(ReceivablesRepositoryImpl(_dioCom(adapter))),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ReceivablesTab(canWrite: true)),
          ),
        );

    testWidgets('com dados: sai do spinner e mostra a carteira', (tester) async {
      final adapter = _FakeAdapter({'/receivables': (200, _devedoresJson)});
      await tester.pumpWidget(app(adapter));

      // Antes de resolver, spinner.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Depois de resolver, NENHUM spinner — é isto que "carrega para sempre"
      // violaria.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('João da Silva'), findsOneWidget);
      expect(find.text('R\$ 945,60'), findsOneWidget);
    });

    testWidgets('erro do servidor mostra ERRO, não spinner infinito',
        (tester) async {
      final adapter = _FakeAdapter({
        '/receivables': (500, '{"message":"quebrou"}'),
      });
      await tester.pumpWidget(app(adapter));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('404 (backend sem o módulo) também mostra erro', (tester) async {
      // Cenário real: backend antigo, sem a rota /receivables.
      final adapter = _FakeAdapter(const {});
      await tester.pumpWidget(app(adapter));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('chama o endpoint UMA vez (sem loop de refetch)',
        (tester) async {
      final adapter = _FakeAdapter({'/receivables': (200, _devedoresJson)});
      await tester.pumpWidget(app(adapter));
      await tester.pumpAndSettle();
      // Alguns pumps extras: um provider que se reinvalida apareceria aqui.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        adapter.chamadas.where((c) => c == '/receivables').length,
        1,
        reason: 'refetch a cada build deixaria a tela em loading eterno',
      );
    });
  });

  group('json malformado não pendura a tela', () {
    testWidgets('corpo inesperado vira erro tratado', (tester) async {
      final adapter = _FakeAdapter({'/receivables': (200, '[]')});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityControllerProvider.overrideWith(_OnlineConn.new),
            receivablesRepositoryProvider
                .overrideWithValue(ReceivablesRepositoryImpl(_dioCom(adapter))),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ReceivablesTab(canWrite: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
