import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/core/ui/ui.dart';
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
  /// Altura da janela. Baixa é onde falta espaço — e onde o scroll importa.
  double altura = 1600,
}) async {
  t.view.physicalSize = Size(1100, altura);
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

  testWidgets('com MUITAS parcelas, TODOS os campos existem e são editáveis',
      (t) async {
    // O relato: acima de três parcelas, as de baixo não apareciam. A lista
    // rolava por dentro de uma caixa de 280px (a altura de exatos três campos),
    // e a barra do desktop só aparece depois que você já está rolando — então a
    // lista PARECIA completa. Agora quem rola é o diálogo, e todos os campos
    // estão na árvore.
    final muitas = [
      for (var i = 1; i <= 6; i++)
        Installment(
          id: 'p$i',
          saleKind: 'sale',
          saleId: 'v-1',
          amount: '30.00',
          dueDate: '2026-0$i-10',
        ),
    ];
    // Tela BAIXA de propósito: é onde falta espaço.
    final caixa = await _abrir(
      t,
      parcelas: muitas,
      saldo: 300,
      totalDepois: 300,
      altura: 700,
    );
    await t.tap(find.text('Editar à mão'));
    await t.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(6));
    final ultima = find.text('6ª parcela · vence em 10/06/2026');
    expect(ultima, findsOneWidget);

    // UMA rolagem só no diálogo — a do próprio NeuDialog (cabeçalho e ações
    // ficam fixos, o conteúdo rola). Duas era o defeito: a de fora sem
    // extensão e a de dentro cortando a lista atrás de uma borda invisível.
    expect(
      find.descendant(
        of: find.byType(NeuDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
      reason: 'scroll dentro de scroll é o que escondia as parcelas de baixo',
    );

    // E o gesto sobre a lista rola de fato.
    final campoAntes = t.getRect(find.byType(TextFormField).first).top;
    await t.drag(find.byType(TextFormField).first, const Offset(0, -200));
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(TextFormField).first).top,
        lessThan(campoAntes));

    // E a 6ª é editável de fato.
    await t.ensureVisible(ultima);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(5), '50');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Salvar parcelas'));
    await t.tap(find.text('Salvar parcelas'));
    await t.pumpAndSettle();

    expect(caixa.valoresCorrigidos, [(id: 'p6', amount: 50.0)]);
  });

  testWidgets('a prévia do recálculo mostra TODAS as parcelas', (t) async {
    final muitas = [
      for (var i = 1; i <= 6; i++)
        Installment(
          id: 'p$i',
          saleKind: 'sale',
          saleId: 'v-1',
          amount: '30.00',
          dueDate: '2026-0$i-10',
        ),
    ];
    await _abrir(
      t,
      parcelas: muitas,
      saldo: 300,
      totalDepois: 300,
      altura: 700,
    );

    // O ponto da prévia é ver o que vai ser aplicado ANTES de aplicar; cortar
    // as últimas linhas atrás de uma borda invisível desmancharia isso.
    expect(find.text('6ª · 10/06/2026'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsNWidgets(6));
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
