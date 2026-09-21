import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_providers.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
import 'package:orbixhub_front/features/receivables/presentation/receive_title_dialog.dart';

/// Escolher QUAIS parcelas quitar.
///
/// O fluxo antigo mirava só a próxima em aberto, e quem queria pagar duas ou
/// três de uma vez tinha de repetir a operação. A regra que a checklist
/// carrega: marcar é sempre da mais antiga para a frente. Cobrar salteado
/// deixaria parcela vencida ATRÁS de uma paga, e o cronograma passaria a
/// discordar do "vencido" que a carteira mostra.

/// Caixa que registra as quitações, para o teste ver quais parcelas foram.
class _SpyCaixa extends FakeCashierRepository {
  final pagas = <String>[];
  final metodos = <String>[];

  @override
  Future<Installment> payInstallment({
    required String installmentId,
    required String method,
    String? description,
    double discount = 0,
    String? discountReason,
  }) async {
    pagas.add(installmentId);
    metodos.add(method);
    return Installment(
      id: installmentId,
      saleKind: 'sale',
      saleId: 'v-1',
      amount: '30.00',
      dueDate: '2026-10-10',
      paidAt: DateTime.now().toIso8601String(),
    );
  }
}

const _titulo = ReceivableTitle(
  id: 'v-1',
  origin: 'sale',
  number: 'VND-0004',
  total: 90,
  paid: 0,
  balance: 90,
  status: 'a_receber',
);

/// Três em aberto: a 1ª já vencida, as outras no futuro.
final _emAberto = [
  const Installment(
    id: 'p1',
    saleKind: 'sale',
    saleId: 'v-1',
    amount: '30.00',
    dueDate: '2020-01-10',
  ),
  const Installment(
    id: 'p2',
    saleKind: 'sale',
    saleId: 'v-1',
    amount: '30.00',
    dueDate: '2099-02-10',
  ),
  const Installment(
    id: 'p3',
    saleKind: 'sale',
    saleId: 'v-1',
    amount: '30.00',
    dueDate: '2099-03-10',
  ),
];

Future<_SpyCaixa> _abrir(
  WidgetTester t, {
  List<Installment>? emAberto,
  /// Altura da janela — baixa é onde falta espaço e o scroll importa.
  double altura = 1600,
}) async {
  t.view.physicalSize = Size(1200, altura);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);

  final caixa = _SpyCaixa();
  final parcelas = emAberto ?? _emAberto;
  await t.pumpWidget(ProviderScope(
    overrides: [cashierRepositoryProvider.overrideWithValue(caixa)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Consumer(
        builder: (ctx, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showReceiveTitleDialog(
                ctx,
                ref,
                config: const CashierConfig(),
                title: _titulo,
                parcela: parcelas.first,
                parcelasEmAberto: parcelas,
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
  testWidgets('mostra a lista de parcelas em aberto, com a vencida em destaque',
      (t) async {
    await _abrir(t);

    expect(find.text('Quais parcelas receber'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.textContaining('Vencida · 10/01/2020'), findsOneWidget);
    // Abre com a mais antiga já marcada: é o caso comum e a fila honesta.
    expect(find.text('1 parcela'), findsOneWidget);
    expect(find.text('Receber 1 parcela'), findsOneWidget);
  });

  testWidgets('marcar a 3ª marca também a 1ª e a 2ª (nunca deixa buraco)',
      (t) async {
    await _abrir(t);

    await t.tap(find.byType(Checkbox).at(2));
    await t.pumpAndSettle();

    expect(find.text('3 parcelas'), findsOneWidget);
    expect(find.text('Receber 3 parcelas'), findsOneWidget);
    // Soma das três.
    expect(find.text('R\$ 90,00'), findsWidgets);
    final marcados = t
        .widgetList<Checkbox>(find.byType(Checkbox))
        .map((c) => c.value)
        .toList();
    expect(marcados, [true, true, true]);
  });

  testWidgets('desmarcar a 2ª solta a 3ª também', (t) async {
    await _abrir(t);
    await t.tap(find.byType(Checkbox).at(2)); // marca as três
    await t.pumpAndSettle();

    await t.tap(find.byType(Checkbox).at(1)); // desmarca da 2ª para frente
    await t.pumpAndSettle();

    final marcados = t
        .widgetList<Checkbox>(find.byType(Checkbox))
        .map((c) => c.value)
        .toList();
    expect(marcados, [true, false, false]);
    expect(find.text('1 parcela'), findsOneWidget);
  });

  testWidgets('a mais antiga não pode ser desmarcada', (t) async {
    await _abrir(t);
    final primeira = t.widget<Checkbox>(find.byType(Checkbox).first);
    // Receber sem quitar a mais antiga não existe neste fluxo.
    expect(primeira.onChanged, isNull);
  });

  testWidgets('quita UMA chamada por parcela, da mais antiga para a frente',
      (t) async {
    final caixa = await _abrir(t);
    await t.tap(find.byType(Checkbox).at(1)); // 1ª + 2ª
    await t.pumpAndSettle();

    await t.tap(find.text('Receber 2 parcelas'));
    await t.pumpAndSettle();

    // Cada parcela ganha o seu lançamento: é o que permite conferir depois
    // "esta entrada pagou qual parcela".
    expect(caixa.pagas, ['p1', 'p2']);
  });

  testWidgets('a forma de pagamento escolhida vale para todas as marcadas',
      (t) async {
    final caixa = await _abrir(t);
    await t.tap(find.byType(Checkbox).at(1));
    await t.pumpAndSettle();

    await t.tap(find.text('Dinheiro'));
    await t.pumpAndSettle();
    await t.tap(find.text('Receber 2 parcelas'));
    await t.pumpAndSettle();

    // Uma escolha só: o operador recebeu as duas do mesmo jeito. Herdar 'pix'
    // (o default) em alguma delas sujaria a conferência de caixa por forma.
    expect(caixa.metodos, ['dinheiro', 'dinheiro']);
  });

  testWidgets('com MUITAS parcelas em janela baixa, a lista é alcançável',
      (t) async {
    // O relato: acima de três parcelas, as de baixo não apareciam.
    final muitas = [
      for (var i = 1; i <= 8; i++)
        Installment(
          id: 'p$i',
          saleKind: 'sale',
          saleId: 'v-1',
          amount: '30.00',
          dueDate: '2099-0$i-10',
        ),
    ];
    await _abrir(t, emAberto: muitas, altura: 700);

    expect(find.byType(Checkbox), findsNWidgets(8));
    final ultima = find.byType(Checkbox).last;
    await t.ensureVisible(ultima);
    await t.pumpAndSettle();
    await t.tap(ultima);
    await t.pumpAndSettle();

    // Marcou até a 8ª: 8 × 30.
    expect(find.text('8 parcelas'), findsOneWidget);
    expect(find.text('R\$ 240,00'), findsWidgets);
  });

  testWidgets('com UMA parcela em aberto, segue o fluxo antigo (sem checklist)',
      (t) async {
    await _abrir(t, emAberto: [_emAberto.first]);

    expect(find.text('Quais parcelas receber'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Registrar'), findsOneWidget);
  });
}
