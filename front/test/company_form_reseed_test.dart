import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/settings/domain/settings_models.dart';
import 'package:orbixhub_front/features/settings/presentation/company_form.dart';

/// Sessão fake não-autenticada — evita o bootstrap real (secure storage).
class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState.unauthenticated();
}

SettingsBundle _bundle(String companyName) => SettingsBundle(
      company: {'companyName': companyName},
      sections: const [
        SettingsSection(
          key: 'company',
          title: 'Empresa',
          fields: [
            SettingsField(key: 'companyName', label: 'Nome fantasia', type: 'text'),
          ],
        ),
      ],
    );

void main() {
  testWidgets(
      'CompanyForm re-semeia os campos quando o company muda (sem dado de tenant anterior)',
      (tester) async {
    Widget host(SettingsBundle b) => ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(_FakeSession.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CompanyForm(bundle: b, company: b.company, embedded: true),
            ),
          ),
        );

    // Tenant A: nome fantasia "kaue".
    await tester.pumpWidget(host(_bundle('kaue')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'kaue'), findsOneWidget);

    // Troca para tenant B (mesmo widget, sem Key → State é reusado).
    // O campo DEVE refletir o novo company, não o do tenant anterior.
    await tester.pumpWidget(host(_bundle('Oficina Nova')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Oficina Nova'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'kaue'), findsNothing);
  });
}
