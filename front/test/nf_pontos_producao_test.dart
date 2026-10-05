import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/config/feature_flags.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_create_dialog.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';
import 'package:orbixhub_front/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub_front/features/settings/domain/settings_models.dart';
import 'package:orbixhub_front/features/settings/domain/settings_repository.dart';
import 'package:orbixhub_front/features/settings/presentation/settings_screen.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';
import 'package:orbixhub_front/features/shell/presentation/sidebar.dart';

import 'support/online_conn.dart';

/// Os pontos de NF no estado em que o cliente vai receber o app.
///
/// `nf_em_breve_test.dart` cobre a REGRA (injetando o flag nos dois lados);
/// aqui se confere o que efetivamente vai no build: com `kInvoiceEnabled` no
/// default, cada lugar que fala de nota fiscal precisa estar inerte e marcado.
///
/// Este arquivo existe porque o flag já foi `!kReleaseMode` — ligado em debug —
/// e ninguém conseguia ver, rodando o app, o que o cliente veria. A checagem do
/// próprio default é a primeira linha de defesa contra isso voltar.
const _me = Me(
  user: User(id: 'u1', email: 'dono@x.dev', fullName: 'Dono'),
  activeTenant: Tenant(id: 't1', slug: 'x', name: 'Oficina X'),
  role: 'owner',
  permissions: ['os.read', 'cashier.read', 'invoice.issue', 'invoice.read'],
  modules: ['os', 'cashier', 'invoice'],
);

class _SessaoDono extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'dono@x.dev', fullName: 'Dono'),
          activeTenant: Tenant(id: 't1', slug: 'x', name: 'Oficina X'),
          role: 'owner',
          permissions: ['settings.manage', 'invoice.config', 'invoice.issue'],
          modules: ['invoice'],
        ),
      );
}

/// Config com a seção do módulo `invoice` — é o que o registry do servidor
/// publica quando o módulo está habilitado no plano.
class _SettingsComNf extends FakeSettingsRepository {
  @override
  Future<SettingsBundle> fetch() async => const SettingsBundle(
        company: {},
        sections: [
          SettingsSection(
            key: 'invoice',
            title: 'Nota Fiscal',
            moduleKey: 'invoice',
            editable: true,
            fields: [],
            values: {},
          ),
        ],
      );
}

void main() {
  test('o flag sai DESLIGADO por padrão — é o que vai no build', () {
    expect(
      kInvoiceEnabled,
      isFalse,
      reason: 'ligado por padrão, o cliente receberia a NF funcionando',
    );
  });

  testWidgets('menu lateral: "Notas Fiscais" fica com o selo "Em breve"',
      (t) async {
    t.view.physicalSize = const Size(1400, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SidebarContent(
            me: _me,
            items: gatedNavItems(_me),
            selectedIndex: 0,
            onNavigate: (_) {},
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    // Aparece (o módulo está no plano) e diz o que é.
    expect(find.text('Notas Fiscais'), findsOneWidget);
    expect(find.byType(NeuEmBreveTag), findsOneWidget);
  });

  testWidgets('configurações: a seção fiscal fica marcada e sem porta de '
      'entrada', (t) async {
    t.view.physicalSize = const Size(1400, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      overrides: [
        onlineConnOverride,
        settingsRepositoryProvider
            .overrideWithValue(_SettingsComNf() as SettingsRepository),
        sessionControllerProvider.overrideWith(_SessaoDono.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SettingsScreen()),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('Nota Fiscal').first);
    await t.pumpAndSettle();

    expect(find.byType(NeuEmBreveTag), findsOneWidget);
    // O botão que levaria à tela fiscal existe, mas inerte: a tela de verdade
    // fala com um backend que o cliente ainda não vai usar.
    final botao = t.widget<NeuButton>(
      find.widgetWithText(NeuButton, 'Abrir configuração fiscal'),
    );
    expect(botao.onPressed, isNull);
  });

  testWidgets('venda no caixa: a opção de nota aparece marcada e não é '
      'clicável', (t) async {
    t.view.physicalSize = const Size(1500, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
        saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
        inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
        customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showSaleCreateDialog(ctx),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    expect(find.text('Emitir nota fiscal'), findsOneWidget);
    expect(find.byType(NeuEmBreveTag), findsOneWidget);
    final check = t.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(check.onChanged, isNull, reason: 'inerte: não entra na venda');
    expect(check.value, isFalse);
  });
}
