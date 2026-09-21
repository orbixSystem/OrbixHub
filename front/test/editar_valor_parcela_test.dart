import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/receivables/presentation/editar_parcela_dialog.dart';

/// Corrigir o VALOR de uma parcela em aberto.
///
/// O plano divide o total igualmente; a combinação real raramente é ("essa eu
/// pago 500, as outras menores"). Antes a única saída era refazer o plano
/// inteiro, o que reescreve as datas — quem só queria mudar um número perdia o
/// prazo combinado.
///
/// O que estes testes protegem é a CONFERÊNCIA: mexer numa parcela mexe no que
/// o cronograma soma, e essa soma tem de fechar com a dívida. Descobrir a
/// diferença depois, conferindo à mão, é o que fazia essa conta ser evitada.

/// Três parcelas de 30 num título que deve 90; a primeira é a que se edita.
const _parcela = Installment(
  id: 'p1',
  saleKind: 'sale',
  saleId: 'v-1',
  amount: '30.00',
  dueDate: '2026-10-10',
);

Future<FakeCashierRepository> _abrir(
  WidgetTester t, {
  double saldo = 90,
  double outras = 60,
}) async {
  t.view.physicalSize = const Size(1000, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final caixa = FakeCashierRepository();
  await t.pumpWidget(ProviderScope(
    overrides: [cashierRepositoryProvider.overrideWithValue(caixa)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showEditarParcelaDialog(
                ctx,
                parcela: _parcela,
                ordem: 1,
                total: 3,
                saldoDoTitulo: saldo,
                outrasEmAberto: outras,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await t.pumpAndSettle();
  await t.tap(find.text('abrir'));
  await t.pumpAndSettle();
  return caixa;
}

void main() {
  testWidgets('abre com o valor atual e diz que o cronograma fecha', (t) async {
    await _abrir(t);

    expect(find.text('Valor da 1ª parcela'), findsOneWidget);
    expect(find.text('Parcela 1 de 3 · vence em 10/10/2026'), findsOneWidget);
    // 60 das outras + 30 desta = 90, o saldo.
    expect(
      find.textContaining('somam R\$ 90,00 — fecha'),
      findsOneWidget,
    );
  });

  testWidgets('aumentar a parcela avisa que passa do que o cliente deve',
      (t) async {
    await _abrir(t);

    await t.enterText(find.byType(TextFormField).first, '500');
    await t.pumpAndSettle();

    // 60 + 500 = 560, contra 90 de dívida. O aviso é ANTES de gravar: depois,
    // só um confronto manual entre cronograma e saldo mostraria isso.
    expect(
      find.textContaining('R\$ 30,00 a MENOS'),
      findsNothing,
    );
    expect(
      find.textContaining('somar R\$ 560,00: R\$ 470,00 MAIS'),
      findsOneWidget,
    );
  });

  testWidgets('diminuir avisa que falta cobrir a dívida', (t) async {
    await _abrir(t);

    await t.enterText(find.byType(TextFormField).first, '10');
    await t.pumpAndSettle();

    // 60 + 10 = 70, contra 90.
    expect(
      find.textContaining('somar R\$ 70,00: R\$ 20,00 a MENOS'),
      findsOneWidget,
    );
  });

  testWidgets('salvar manda o novo valor para o caixa', (t) async {
    final caixa = await _abrir(t);

    await t.enterText(find.byType(TextFormField).first, '45,50');
    await t.pumpAndSettle();
    await t.tap(find.text('Salvar valor'));
    await t.pumpAndSettle();

    expect(caixa.valoresCorrigidos, [(id: 'p1', amount: 45.50)]);
    // Fecha sozinho: quem corrigiu o valor quer voltar para a lista.
    expect(find.text('Valor da 1ª parcela'), findsNothing);
  });

  testWidgets('valor zero ou negativo não sai daqui', (t) async {
    final caixa = await _abrir(t);

    await t.enterText(find.byType(TextFormField).first, '0');
    await t.pumpAndSettle();
    await t.tap(find.text('Salvar valor'));
    await t.pumpAndSettle();

    // Parcela de zero não é parcela — e o servidor recusaria de qualquer forma.
    expect(caixa.valoresCorrigidos, isEmpty);
    expect(find.text('Valor da 1ª parcela'), findsOneWidget);
  });

  testWidgets('cancelar não grava nada', (t) async {
    final caixa = await _abrir(t);

    await t.enterText(find.byType(TextFormField).first, '999');
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();

    expect(caixa.valoresCorrigidos, isEmpty);
  });
}
