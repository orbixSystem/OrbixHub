import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_screen.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/customers/data/fake_customers_repository.dart';
import 'package:orbixhub_front/features/customers/presentation/customers_screen.dart';
import 'package:orbixhub_front/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub_front/features/inventory/presentation/inventory_screen.dart';
import 'package:orbixhub_front/features/os/data/fake_os_repository.dart';
import 'package:orbixhub_front/features/os/presentation/os_list_screen.dart';
import 'package:orbixhub_front/features/os/presentation/os_providers.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';

import 'support/online_conn.dart';

/// Alvos de tutorial do Caixa precisam existir em DESKTOP e MOBILE.
///
/// Um alvo que só existe num tamanho faz o passo virar cartão centralizado
/// naquele outro — o tutorial não quebra, mas perde o holofote exatamente onde
/// ele explicaria a tela. Por isso os alvos são marcados em widgets comuns aos
/// dois layouts, e este teste prova isso em vez de confiar na leitura do código.

class _Dono extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(
        Me(
          user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
          activeTenant: Tenant(id: 't1', slug: 'demo', name: 'Demo'),
          role: 'owner',
          permissions: [
            'cashier.read',
            'cashier.write',
            'cashier.manage',
            'sale.read',
            'sale.write',
          ],
          modules: ['cashier', 'sale'],
        ),
      );
}

Future<void> _abrirCaixa(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // O fake nasce EXIGINDO caixa aberto; com a exigência ligada a tela mostra o
  // corpo "abra o caixa", que não tem ações nem lista — e os alvos não existiriam.
  // O padrão real do produto é desligada (migration 0037).
  final repo = FakeCashierRepository();
  await repo.updateConfig(requireOpenSession: false);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      onlineConnOverride,
      sessionControllerProvider.overrideWith(_Dono.new),
      cashierRepositoryProvider.overrideWithValue(repo),
      saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const CashierScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Todo alvo que o tutorial do Caixa aponta.
const _alvos = ['caixa.abas', 'caixa.acoes', 'caixa.ultimos'];


/// Telas que já têm holofote, com seus alvos. Cada uma é montada nos DOIS
/// tamanhos — é a garantia de que o tutorial não perde o destaque no celular.
final _telas = <String, ({Widget tela, List<String> alvos})>{
  'OS': (tela: const OsListScreen(), alvos: ['os.filtros', 'os.lista']),
  'Clientes': (
    tela: const CustomersScreen(),
    alvos: ['clientes.filtros', 'clientes.lista'],
  ),
  'Estoque': (
    tela: const InventoryScreen(),
    alvos: ['estoque.filtros', 'estoque.lista'],
  ),
  // FALTAM AQUI: Ficha do cliente, Veículo, Relatórios, Equipe e Planos. Os alvos JÁ ESTÃO marcados no
  // código (`cliente.abas`/`cliente.conteudo`, `veiculo.abas`/`veiculo.conteudo`),
  // em cabeçalhos compartilhados pelos dois layouts — mas não estão testados.
  //
  // Motivo: cada uma depende de dados/providers que este teste não monta —
  // ficha e veículo carregam por id (e o fake nasce vazio); Relatórios, Equipe e
  // Planos dependem dos providers do próprio módulo. Montá-las exige semear os
  // fakes e sobrescrever esses providers.
  //
  // Até então, o holofote delas está MARCADO no código mas NÃO verificado — ao
  // contrário das telas de lista acima, onde o teste prova alvo por alvo nos dois
  // tamanhos. Esta distinção é deliberada: teste que não exercita nada dá falsa
  // confiança.
};

Future<void> _abrir(WidgetTester tester, Widget tela, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      onlineConnOverride,
      sessionControllerProvider.overrideWith(_Dono.new),
      osRepositoryProvider.overrideWithValue(FakeOsRepository()),
      customersRepositoryProvider.overrideWithValue(FakeCustomersRepository()),
      inventoryRepositoryProvider.overrideWithValue(FakeInventoryRepository()),
      saleRepositoryProvider.overrideWithValue(FakeSaleRepository()),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: tela),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('alvos do Caixa existem no DESKTOP', (tester) async {
    await _abrirCaixa(tester, const Size(1400, 1000));
    for (final nome in _alvos) {
      expect(CoachTargets.live(nome), isNotNull, reason: 'alvo $nome ausente');
    }
  });

  testWidgets('alvos do Caixa existem no CELULAR', (tester) async {
    await _abrirCaixa(tester, const Size(390, 844));
    for (final nome in _alvos) {
      expect(CoachTargets.live(nome), isNotNull, reason: 'alvo $nome ausente');
    }
  });

  for (final entry in _telas.entries) {
    for (final caso in const [
      ('DESKTOP', Size(1400, 1000)),
      ('CELULAR', Size(390, 844)),
    ]) {
      testWidgets('alvos de ${entry.key} existem no ${caso.$1}', (tester) async {
        await _abrir(tester, entry.value.tela, caso.$2);
        for (final nome in entry.value.alvos) {
          expect(CoachTargets.live(nome), isNotNull,
              reason: '${entry.key}: alvo $nome ausente no ${caso.$1}');
        }
      });
    }
  }

  testWidgets('o alvo aponta um widget com tamanho real (não um ponto)',
      (tester) async {
    // Um alvo de tamanho zero recortaria um buraco invisível — pior que nada.
    await _abrirCaixa(tester, const Size(1400, 1000));
    for (final nome in _alvos) {
      final box = CoachTargets.live(nome)!.currentContext!.findRenderObject()
          as RenderBox;
      expect(box.size.width, greaterThan(50), reason: nome);
      expect(box.size.height, greaterThan(10), reason: nome);
    }
  });
}
