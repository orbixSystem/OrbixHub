import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/receivables/data/fake_receivables_repository.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/combinar_prazo_dialog.dart';
import 'package:orbixhub_front/features/receivables/presentation/receivables_providers.dart';

/// Combinar prazo DEPOIS de fiar.
///
/// Este era o buraco da jornada de cobrança: dava para combinar data na hora de
/// fiar, mas não depois. Quem fiou sem prazo só conseguia dar uma abrindo
/// "Receber", apagando o valor que vem preenchido e clicando em "Deixar fiado"
/// — e quem combinou errado não tinha conserto, porque o servidor recusava um
/// segundo plano.
void main() {
  const titulo = ReceivableTitle(
    id: 't1',
    origin: 'sale',
    number: 'VND-0001',
    total: 300,
    paid: 100,
    balance: 200,
    status: 'parcial',
  );

  Future<FakeCashierRepository> abrir(
    WidgetTester t, {
    List<Installment> parcelasAtuais = const [],
  }) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final caixa = FakeCashierRepository();
    await t.pumpWidget(ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(caixa),
        receivablesRepositoryProvider
            .overrideWithValue(FakeReceivablesRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showCombinarPrazoDialog(
                ctx,
                titulo: titulo,
                parcelasAtuais: parcelasAtuais,
              ),
              child: const Text('abrir'),
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

  testWidgets('sem plano, o diálogo se chama "Combinar prazo"', (t) async {
    await abrir(t);
    expect(find.text('Combinar prazo'), findsOneWidget);
    expect(find.text('Prazo de pagamento'), findsNothing); // vira "Novo prazo"
    expect(find.text('Novo prazo'), findsOneWidget);
  });

  testWidgets('com plano pendente, vira "Alterar prazo" e avisa o que muda',
      (t) async {
    await abrir(t, parcelasAtuais: [
      Installment(
        id: 'p1',
        saleKind: 'sale',
        saleId: 't1',
        amount: '200.00',
        dueDate: '2099-01-10',
      ),
    ]);
    expect(find.text('Alterar prazo'), findsOneWidget);
    // O que o operador precisa saber antes de trocar: o dinheiro já recebido
    // não é afetado.
    expect(find.textContaining('Parcelas já pagas não mudam'), findsOneWidget);
  });

  testWidgets('grava o prazo sobre o SALDO, substituindo o pendente',
      (t) async {
    final caixa = await abrir(t);

    await t.tap(find.text('Data única'));
    await t.pumpAndSettle();
    await t.tap(find.text('Salvar prazo'));
    await t.pumpAndSettle();

    expect(caixa.planos, hasLength(1));
    final plano = caixa.planos.single;
    expect(plano.installmentCount, 1);
    // 200 em aberto (300 − 100 já pagos): recombina-se o que falta, não o total.
    expect(plano.totalAmount, 200);
    expect(plano.substituirPendentes, isTrue,
        reason: 'é o que permite corrigir um prazo já combinado');
  });

  testWidgets('"Sem prazo" não finge que gravou — explica o que fazer',
      (t) async {
    final caixa = await abrir(t);

    // "Sem prazo" é o padrão do bloco; salvar assim seria apagar o combinado
    // sem pôr outro, operação que o servidor não expõe.
    await t.tap(find.text('Salvar prazo'));
    await t.pumpAndSettle();

    expect(caixa.planos, isEmpty);
    expect(find.textContaining('Escolha uma data única'), findsOneWidget);
  });
}
