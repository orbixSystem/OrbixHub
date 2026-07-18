import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/invoice/data/fake_invoice_config_repository.dart';
import 'package:orbixhub_front/features/invoice/domain/invoice_config_models.dart';
import 'package:orbixhub_front/features/invoice/presentation/invoice_config_controller.dart';
import 'package:orbixhub_front/features/invoice/presentation/invoice_config_screen.dart';

/// Sessão fake autenticada com a permissão `invoice.config` (necessária para
/// habilitar os campos/ações de gestão fiscal nesta tela).
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'dono@teste.com', fullName: 'Dono'),
          activeTenant: Tenant(id: 't1', slug: 'oficina', name: 'Oficina'),
          role: 'owner',
          permissions: ['invoice.config'],
          modules: ['invoice'],
        ),
      );
}

/// Controller fixo que pula a resolução de tenant/sessão do `build()` real —
/// só interessa aqui exercitar `registerEmpresa`/`save` (herdados), que
/// delegam ao repositório fake.
class _FixedInvoiceConfigController extends InvoiceConfigController {
  @override
  Future<InvoiceFiscalConfig> build() async => const InvoiceFiscalConfig();
}

void main() {
  testWidgets(
      'registrar a empresa não sobrescreve série NFS-e digitada e ainda não salva',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(_FakeSession.new),
      invoiceConfigRepositoryProvider
          .overrideWith((ref) => FakeInvoiceConfigRepository()),
      invoiceConfigControllerProvider
          .overrideWith(_FixedInvoiceConfigController.new),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: InvoiceConfigScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Usuário digita uma nova série NFS-e mas NÃO clica em "Salvar".
    final serieField = find.byType(TextFormField).first;
    await tester.enterText(serieField, '77');
    await tester.pump();
    expect(find.text('77'), findsOneWidget);

    // Em vez de "Salvar", o cadastro da empresa no provedor é concluído — ação
    // que só muda `empresaRegistrada` no servidor, não a série. Chamamos o
    // controller diretamente (equivalente a clicar em "Cadastrar empresa no
    // provedor"), evitando fragilidade de hit-testing num botão que pode ficar
    // fora da área visível do viewport de teste.
    await container
        .read(invoiceConfigControllerProvider.notifier)
        .registerEmpresa();
    await tester.pumpAndSettle();

    // A empresa foi registrada (novo AsyncData chegou, reconstruindo o body)...
    expect(find.text('Registrada'), findsOneWidget);
    // ...mas o texto digitado na série NFS-e continua intacto.
    expect(find.text('77'), findsOneWidget);
  });
}
