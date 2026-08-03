import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/di.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/auth/presentation/session_controller.dart';
import 'package:orbixhub_front/features/auth/presentation/session_state.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_detail_dialog.dart';
import 'package:orbixhub_front/features/sale/presentation/sale_providers.dart';

/// Detalhe da venda de balcão.
///
/// O histórico do caixa mostrava só o lançamento de dinheiro ("Venda avulsa ·
/// R$ 150"), sem dizer o que foi vendido nem permitir agir. Editar uma venda
/// registrada não existe por decisão de produto — o dinheiro já passou pelo
/// caixa — então corrigir é CANCELAR e REFAZER, e "excluir" é cancelar (o
/// projeto não faz hard delete).

const _venda = Sale(
  id: 'v1',
  number: 'VND-0007',
  customerName: 'Maria Souza',
  status: 'active',
  total: '270.00',
  paymentStatus: 'a_receber',
  createdAt: '2026-08-01T13:00:00Z',
  items: [
    SaleItem(
      id: 'i1',
      kind: 'product',
      name: 'Palheta dianteira',
      quantity: '2',
      unitPrice: '60.00',
      subtotal: '120.00',
    ),
    SaleItem(
      id: 'i2',
      kind: 'service',
      name: 'Higienização de ar-condicionado',
      quantity: '1',
      unitPrice: '150.00',
      subtotal: '150.00',
    ),
  ],
);

class _Sessao extends SessionController {
  _Sessao({this.podeVender = true});
  final bool podeVender;

  @override
  SessionState build() => SessionState.authenticated(
        Me(
          user: const User(id: 'u1', email: 'a@b.c', fullName: 'Dono'),
          role: 'owner',
          permissions: [
            'cashier.read',
            'cashier.write',
            if (podeVender) 'sale.write',
            'sale.read',
          ],
          modules: const ['cashier', 'sale'],
        ),
      );
}

Future<void> _abrir(
  WidgetTester tester, {
  Sale venda = _venda,
  bool podeVender = true,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider
            .overrideWith(() => _Sessao(podeVender: podeVender)),
        saleRepositoryProvider
            .overrideWithValue(FakeSaleRepository(sales: [venda])),
        cashierRepositoryProvider.overrideWithValue(FakeCashierRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showSaleDetailDialog(context, saleId: venda.id),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('o que foi vendido', () {
    testWidgets('mostra cada item com quantidade, preço e subtotal',
        (tester) async {
      await _abrir(tester);

      expect(find.text('Palheta dianteira'), findsOneWidget);
      expect(find.text('Higienização de ar-condicionado'), findsOneWidget);
      expect(find.text('2 × R\$ 60,00'), findsOneWidget);
      expect(find.text('1 × R\$ 150,00'), findsOneWidget);
      expect(find.text('R\$ 120,00'), findsOneWidget);
    });

    testWidgets('mostra número, cliente e total', (tester) async {
      await _abrir(tester);

      expect(find.text('Venda VND-0007'), findsOneWidget);
      expect(find.textContaining('Maria Souza'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      // 270 aparece duas vezes e as duas estão certas: é o total dos itens e,
      // como nada foi recebido, também o saldo a receber.
      expect(find.text('R\$ 270,00'), findsNWidgets(2));
    });

    testWidgets('mostra os recebimentos: pago e a receber', (tester) async {
      await _abrir(tester);

      expect(find.text('Recebimentos'), findsOneWidget);
      expect(find.text('Pago'), findsOneWidget);
      // Duas vezes, ambas corretas: a tag de status da venda e o rótulo do saldo.
      expect(find.text('A receber'), findsNWidgets(2));
      expect(find.text('R\$ 0,00'), findsOneWidget); // nada pago ainda
    });
  });

  group('ações', () {
    testWidgets('oferece cancelar e corrigir para quem pode vender',
        (tester) async {
      await _abrir(tester);

      expect(find.text('Cancelar venda'), findsOneWidget);
      expect(find.text('Corrigir (refazer)'), findsOneWidget);
    });

    testWidgets('sem sale.write não oferece nenhuma ação', (tester) async {
      await _abrir(tester, podeVender: false);

      expect(find.text('Cancelar venda'), findsNothing);
      expect(find.text('Corrigir (refazer)'), findsNothing);
    });

    testWidgets('explica por que não existe "editar"', (tester) async {
      await _abrir(tester);
      expect(
        find.textContaining('não se edita'),
        findsOneWidget,
        reason: 'a ausência de edição precisa ser explicada, não só omitida',
      );
    });

    testWidgets('cancelar exige motivo', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Cancelar venda'));
      await tester.pumpAndSettle();

      // Diálogo de motivo, com o campo vazio (sem texto pré-pronto).
      expect(find.text('Motivo *'), findsOneWidget);
      expect(find.textContaining('estoque'), findsWidgets);
    });

    testWidgets('corrigir sugere o motivo já preenchido', (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Corrigir (refazer)'));
      await tester.pumpAndSettle();

      // Refazer é sempre correção — não faz sentido obrigar a digitar isso.
      expect(find.text('Correção de lançamento'), findsOneWidget);
      expect(find.text('Cancelar e refazer'), findsOneWidget);
    });

    testWidgets('motivo curto é recusado antes de ir ao servidor',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Cancelar venda'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'ab');
      await tester.tap(find.text('Cancelar venda').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('mínimo 3 letras'), findsOneWidget);
    });
  });

  group('venda cancelada', () {
    const cancelada = Sale(
      id: 'v2',
      number: 'VND-0008',
      status: 'canceled',
      total: '100.00',
      items: [
        SaleItem(
          id: 'i1',
          name: 'Item',
          quantity: '1',
          unitPrice: '100.00',
          subtotal: '100.00',
        ),
      ],
    );

    testWidgets('aparece marcada e não oferece cancelar de novo',
        (tester) async {
      await _abrir(tester, venda: cancelada);

      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('Cancelar venda'), findsNothing);
      expect(find.text('Corrigir (refazer)'), findsNothing);
      // Continua legível: cancelar não apaga o histórico.
      expect(find.text('Item'), findsOneWidget);
    });
  });

  group('refazer preenche a nova venda', () {
    test('converte os itens da venda em linhas editáveis', () {
      // A conversão acontece no initState do diálogo de criação; aqui garantimos
      // que os campos que ele lê (String decimal) são parseáveis.
      for (final i in _venda.items) {
        expect(double.tryParse(i.quantity.replaceAll(',', '.')), isNotNull);
        expect(double.tryParse(i.unitPrice.replaceAll(',', '.')), isNotNull);
      }
    });
  });
}
