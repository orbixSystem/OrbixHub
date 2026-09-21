import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/ajustar_parcelas_dialog.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';

/// Mudou o valor de um título PARCELADO — o cronograma não muda sozinho.
///
/// O silêncio é o pior desfecho: a dívida passa a ser uma coisa e a cobrança,
/// outra, e ninguém descobre até a última parcela não fechar a conta. As três
/// saídas são legítimas e o operador escolhe — não há padrão aplicado às cegas.

/// Três parcelas de 30 combinadas quando a venda era 90.
final _emAberto = [
  const Installment(
    id: 'p1',
    saleKind: 'sale',
    saleId: 'v-1',
    amount: '30.00',
    dueDate: '2026-10-10',
  ),
  const Installment(
    id: 'p2',
    saleKind: 'sale',
    saleId: 'v-1',
    amount: '30.00',
    dueDate: '2026-11-10',
  ),
  const Installment(
    id: 'p3',
    saleKind: 'sale',
    saleId: 'v-1',
    amount: '30.00',
    dueDate: '2026-12-10',
  ),
];

Future<FakeCashierRepository> _abrir(
  WidgetTester t, {
  double totalDepois = 150,
  double saldo = 150,
  List<Installment>? parcelas,
}) async {
  t.view.physicalSize = const Size(1100, 1600);
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
              onPressed: () => showAjustarParcelasDialog(
                ctx,
                rotuloTitulo: 'A venda 15',
                totalAntes: 90,
                totalDepois: totalDepois,
                saldo: saldo,
                parcelasEmAberto: parcelas ?? _emAberto,
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
  testWidgets('diz o que mudou, quanto as parcelas somam e o que se deve',
      (t) async {
    await _abrir(t);

    expect(find.text('As parcelas acompanham a mudança?'), findsOneWidget);
    expect(
      find.textContaining(
        'A venda 15 subiu de R\$ 90,00 para R\$ 150,00',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('continuam somando R\$ 90,00'), findsOneWidget);
    // As três saídas, nenhuma escolhida por padrão.
    expect(find.text('Recalcular'), findsOneWidget);
    expect(find.text('Editar à mão'), findsOneWidget);
    expect(find.text('Deixar como está'), findsOneWidget);
  });

  testWidgets('mostra a prévia do recálculo antes de aplicar', (t) async {
    await _abrir(t);

    // 150 / 3 = 50 em cada, de → para. Aplicar um número que ninguém viu é o
    // que faz o operador desconfiar do botão.
    expect(find.text('R\$ 50,00'), findsNWidgets(3));
    expect(find.text('1ª · 10/10/2026'), findsOneWidget);
  });

  testWidgets('recalcular divide o saldo e MANTÉM as datas', (t) async {
    final caixa = await _abrir(t);

    await t.tap(find.text('Recalcular'));
    await t.pumpAndSettle();

    // Uma chamada por parcela, só de valor: nenhuma recriação de plano, que
    // reescreveria os vencimentos combinados.
    expect(caixa.valoresCorrigidos, [
      (id: 'p1', amount: 50.0),
      (id: 'p2', amount: 50.0),
      (id: 'p3', amount: 50.0),
    ]);
  });

  testWidgets('o centavo que não divide cai na ÚLTIMA parcela', (t) async {
    // 100 / 3 = 33,33 + 33,33 + 33,34 — mesma regra do servidor ao criar plano.
    final caixa = await _abrir(t, totalDepois: 100, saldo: 100);

    await t.tap(find.text('Recalcular'));
    await t.pumpAndSettle();

    expect(caixa.valoresCorrigidos, [
      (id: 'p1', amount: 33.33),
      (id: 'p2', amount: 33.33),
      (id: 'p3', amount: 33.34),
    ]);
  });

  testWidgets('"deixar como está" não toca em nenhuma parcela', (t) async {
    final caixa = await _abrir(t);

    await t.tap(find.text('Deixar como está'));
    await t.pumpAndSettle();

    // Legítimo: o operador pode ter acertado outra coisa com o cliente. A
    // divergência fica visível no cronograma.
    expect(caixa.valoresCorrigidos, isEmpty);
  });

  testWidgets('editar à mão confere a soma contra a dívida', (t) async {
    final caixa = await _abrir(t);

    await t.tap(find.text('Editar à mão'));
    await t.pumpAndSettle();

    expect(find.text('1ª parcela · vence em 10/10/2026'), findsOneWidget);
    // Abre com os valores ANTIGOS: 90 contra 150 de dívida.
    expect(find.textContaining('R\$ 60,00 menos que a dívida'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).first, '100');
    await t.pumpAndSettle();
    // 100 + 30 + 30 = 160, dez a mais.
    expect(find.textContaining('R\$ 10,00 mais que a dívida'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).first, '90');
    await t.pumpAndSettle();
    expect(find.textContaining('fecha com a dívida'), findsOneWidget);

    await t.tap(find.text('Salvar parcelas'));
    await t.pumpAndSettle();

    // Só a que mudou é enviada — parcela intocada não vira "alterada" no log.
    expect(caixa.valoresCorrigidos, [(id: 'p1', amount: 90.0)]);
  });

  testWidgets('no manual, parcela zerada barra o salvamento', (t) async {
    final caixa = await _abrir(t);
    await t.tap(find.text('Editar à mão'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextFormField).at(1), '0');
    await t.pumpAndSettle();
    await t.tap(find.text('Salvar parcelas'));
    await t.pumpAndSettle();

    // A 1ª não mudou, então nada foi enviado antes de barrar na 2ª.
    expect(caixa.valoresCorrigidos, isEmpty);
    expect(find.text('Salvar parcelas'), findsOneWidget);
  });
}
