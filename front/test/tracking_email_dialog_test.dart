import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/send_tracking_email_dialog.dart';

/// Confirmação do destinatário do link de acompanhamento. O ponto do diálogo é
/// não deixar a OS de um cliente cair no e-mail de outro: o endereço vem do
/// cadastro, mas quem confirma é o atendente.

const _order = ServiceOrder(
  id: 'os-1',
  number: 'OS-0001',
  customerId: 'c1',
  customerName: 'João da Silva',
  status: 'em_execucao',
  total: '150.00',
  publicToken: 'tok-1',
);

/// Repo cujo envio falha como o backend falharia (503 do SMTP, 403 de permissão).
class _FailingRepo extends FakeOsRepository {
  _FailingRepo({required this.onSend});

  final AppException onSend;

  @override
  Future<String?> trackingRecipientEmail(String orderId) async =>
      'cadastro@ex.com';

  @override
  Future<void> sendTrackingLinkEmail(String orderId, String email) async =>
      throw onSend;
}

Future<String?> _open(WidgetTester tester, FakeOsRepository repo) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await SendTrackingEmailDialog.show(
                context,
                repo: repo,
                order: _order,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

/// Texto atual do campo de e-mail (único TextField do diálogo).
String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('abre com o e-mail do cadastro para o atendente conferir',
      (tester) async {
    final repo = FakeOsRepository(orders: [_order])
      ..trackingEmails['os-1'] = 'joao@ex.com';

    await _open(tester, repo);

    expect(find.text('Enviar link por e-mail'), findsOneWidget);
    expect(find.textContaining('João da Silva'), findsOneWidget);
    expect(_fieldText(tester), 'joao@ex.com');
  });

  testWidgets('cliente sem e-mail cadastrado: campo abre vazio',
      (tester) async {
    final repo = FakeOsRepository(orders: [_order]);

    await _open(tester, repo);

    expect(_fieldText(tester), '');
  });

  testWidgets('envia para o endereço CORRIGIDO e devolve o e-mail usado',
      (tester) async {
    final repo = FakeOsRepository(orders: [_order])
      ..trackingEmails['os-1'] = 'errado@ex.com';

    await _open(tester, repo);
    await tester.enterText(find.byType(TextField), 'certo@ex.com');
    await tester.tap(find.text('Confirmar e enviar'));
    await tester.pumpAndSettle();

    expect(repo.sentTrackingLinks, [(orderId: 'os-1', email: 'certo@ex.com')]);
    // O diálogo fecha devolvendo o endereço, que a tela mostra no snackbar.
    expect(find.text('Enviar link por e-mail'), findsNothing);
  });

  testWidgets('e-mail malformado nem chega a chamar o backend', (tester) async {
    final repo = FakeOsRepository(orders: [_order]);

    await _open(tester, repo);
    await tester.enterText(find.byType(TextField), 'joao@');
    await tester.tap(find.text('Confirmar e enviar'));
    await tester.pumpAndSettle();

    expect(repo.sentTrackingLinks, isEmpty);
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });

  testWidgets('falha no envio mostra a mensagem do backend e mantém o diálogo',
      (tester) async {
    final repo = _FailingRepo(
      onSend: const AppException(
        statusCode: 503,
        error: 'Service Unavailable',
        message:
            'Não foi possível enviar o e-mail agora. Tente novamente em instantes.',
      ),
    );

    await _open(tester, repo);
    await tester.tap(find.text('Confirmar e enviar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não foi possível enviar o e-mail agora'),
      findsOneWidget,
    );
    expect(find.text('Enviar link por e-mail'), findsOneWidget);
  });
}
