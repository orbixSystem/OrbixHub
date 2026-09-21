import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/data/cashier_repository_impl.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/receivables/data/receivables_repository_impl.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_screen.dart';

/// Controle de parcelas na tela "A receber" — o caminho COMPLETO, sobre HTTP.
///
/// Os testes de tela usam o fake, que não fala de parcelas; os do fake não
/// passam pelo transporte. O que o operador reclamou vive exatamente no meio:
/// abrir um devedor SEM CADASTRO (apelido) e ver o cronograma — parcelas pagas,
/// qual é a próxima. Aqui a cadeia inteira roda: tela → provider → impl → HTTP.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respostas);

  /// path (sem query) → (status, corpo)
  final Map<String, (int, String)> respostas;
  final List<String> chamadas = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    chamadas.add(options.uri.toString());
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

class _OnlineConn extends ConnectivityController {
  @override
  ConnState build() => const ConnState(status: ConnStatus.online);
}

class _Dono extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
          activeTenant: Tenant(id: 't1', slug: 'demo', name: 'Demo'),
          role: 'owner',
          permissions: ['cashier.read', 'cashier.write'],
          modules: ['cashier'],
        ),
      );
}

/// Devedor SEM CADASTRO: `customerId` nulo e o apelido como nome. É este que
/// abre pela rota literal `/receivables/sem-cliente?nome=...`.
const _carteiraApelido = '''
{
  "items": [
    {"customerId": null, "customerName": "Zé Motoboy", "totalDue": 90,
     "titleCount": 1, "oldestAt": "2026-09-19T10:00:00Z",
     "phone": null, "nextDueAt": "2026-10-10", "overdue": false}
  ],
  "total": 1, "page": 1, "pageSize": 20,
  "totalDue": 90, "overdueTotal": 0, "overdueCount": 0,
  "pendingSettlement": {"count": 0, "total": 0}, "truncated": false
}
''';

const _tituloDoApelido = '''
{
  "customerName": "Zé Motoboy",
  "totalDue": 90,
  "items": [
    {"origin": "sale", "id": "v-1", "number": "VND-0004",
     "createdAt": "2026-09-19T10:00:00Z", "total": 90, "paid": 30,
     "balance": 60, "status": "parcial", "items": []}
  ]
}
''';

/// Plano de 3 parcelas: a primeira PAGA, as outras em aberto.
///
/// snake_case de propósito: é o que o servidor devolve (linhas do Prisma) e o
/// que `Installment.fromJson` lê. Em camelCase o parse falha, e como o
/// `installmentsProvider` é lido com `.value ?? []`, o cronograma
/// simplesmente NÃO aparece — sem erro na tela.
const _parcelas = '''
[
  {"id": "p1", "sale_kind": "sale", "sale_id": "v-1", "amount": "30.00",
   "due_date": "2026-09-20", "paid_at": "2026-09-20T10:00:00Z"},
  {"id": "p2", "sale_kind": "sale", "sale_id": "v-1", "amount": "30.00",
   "due_date": "2026-10-10", "paid_at": null},
  {"id": "p3", "sale_kind": "sale", "sale_id": "v-1", "amount": "30.00",
   "due_date": "2026-11-10", "paid_at": null}
]
''';

Future<_FakeAdapter> _abrir(WidgetTester t, {String? parcelas}) async {
  t.view.physicalSize = const Size(1200, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final adapter = _FakeAdapter({
    '/receivables': (200, _carteiraApelido),
    '/receivables/sem-cliente': (200, _tituloDoApelido),
    if (parcelas != null) '/cashier/installments': (200, parcelas),
  });
  Dio dio() {
    final d = Dio(BaseOptions(baseUrl: 'http://x/api'));
    d.httpClientAdapter = adapter;
    return d;
  }

  await t.pumpWidget(ProviderScope(
    overrides: [
      connectivityControllerProvider.overrideWith(_OnlineConn.new),
      sessionControllerProvider.overrideWith(_Dono.new),
      receivablesRepositoryProvider
          .overrideWithValue(ReceivablesRepositoryImpl(dio())),
      // O impl do caixa quer o id do DEVICE (ponto de caixa) além do dio.
      cashierRepositoryProvider.overrideWithValue(
        CashierRepositoryImpl(dio(), () async => 'device-de-teste'),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: ReceivablesScreen()),
    ),
  ));
  await t.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets('devedor sem cadastro aparece na carteira', (t) async {
    await _abrir(t, parcelas: _parcelas);
    expect(find.text('Zé Motoboy'), findsOneWidget);
    expect(find.text('Sem cadastro'), findsOneWidget);
  });

  testWidgets('clicar no apelido ABRE os títulos (rota sem-cliente + nome)',
      (t) async {
    final adapter = await _abrir(t, parcelas: _parcelas);

    await t.tap(find.text('Zé Motoboy'));
    await t.pumpAndSettle();

    // O diálogo abriu com o título de verdade, não vazio.
    expect(find.text('Venda VND-0004'), findsOneWidget);
    expect(find.text('Nada em aberto para este cliente.'), findsNothing);

    // E foi pela rota literal, levando o apelido como chave — sem isso, o
    // servidor devolveria os títulos de TODOS os anônimos juntos.
    final chamada = adapter.chamadas
        .firstWhere((c) => c.contains('/receivables/sem-cliente'));
    expect(chamada, contains('nome=Z'));
  });

  testWidgets('parcelado se anuncia no cabeçalho, sem abrir a lista', (t) async {
    await _abrir(t, parcelas: _parcelas);
    await t.tap(find.text('Zé Motoboy'));
    await t.pumpAndSettle();

    // O selo responde "isto é parcelado" de longe — é o que muda o que o
    // operador vai fazer aqui (cobrar parcela, não o saldo).
    expect(find.text('Parcelado 3x'), findsOneWidget);
    // E o cabeçalho do cronograma responde o resto sem gastar altura: um plano
    // de 12 parcelas abria 12 linhas e enterrava o título seguinte.
    expect(find.text('Parcelado em 3x'), findsOneWidget);
    expect(find.text('1 de 3 pagas'), findsOneWidget);
    expect(find.textContaining('Próxima: 10/10/2026'), findsOneWidget);
    // Fechado: as linhas da lista ainda não existem.
    expect(find.text('Paga'), findsNothing);
    // A ação mira a PRÓXIMA parcela em aberto, não o saldo todo.
    expect(find.text('Receber parcela'), findsOneWidget);
  });

  testWidgets('abrindo o cronograma, aparecem as pagas e as que faltam',
      (t) async {
    await _abrir(t, parcelas: _parcelas);
    await t.tap(find.text('Zé Motoboy'));
    await t.pumpAndSettle();

    await t.tap(find.text('Parcelado em 3x'));
    await t.pumpAndSettle();

    expect(find.text('Paga'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('10/11/2026'), findsOneWidget);
    // Lápis só nas DUAS em aberto: o valor de uma parcela paga já virou
    // lançamento no caixa.
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));

    // UMA rolagem no diálogo (a do próprio NeuDialog). O cronograma não tem
    // caixa de rolagem própria: scroll dentro de scroll rolava, mas a barra do
    // desktop só aparece depois que você já está rolando — a lista parecia
    // completa e as parcelas de baixo não existiam para quem olhava.
    expect(
      find.descendant(
        of: find.byType(NeuDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('título sem plano não inventa cronograma', (t) async {
    await _abrir(t, parcelas: '[]');
    await t.tap(find.text('Zé Motoboy'));
    await t.pumpAndSettle();

    expect(find.textContaining('Parcelado em'), findsNothing);
    // Sem plano, o botão recebe o saldo — e há como combinar um prazo.
    expect(find.text('Receber'), findsOneWidget);
    expect(find.text('Combinar prazo'), findsOneWidget);
  });

  testWidgets('parcelas indisponíveis não escondem o título', (t) async {
    // `installmentsProvider` falhando (rota 404, backend antigo, 403) cai em
    // lista vazia: o título continua visível e recebível. Some o cronograma,
    // não a dívida.
    await _abrir(t); // sem mapear /cashier/installments → 404
    await t.tap(find.text('Zé Motoboy'));
    await t.pumpAndSettle();

    expect(find.text('Venda VND-0004'), findsOneWidget);
    expect(find.text('Deve R\$ 60,00'), findsOneWidget);
  });
}
