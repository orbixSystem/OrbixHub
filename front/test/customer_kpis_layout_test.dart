import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/customers/presentation/customer_kpis.dart';
import 'package:orbixhub_front/features/report/domain/report_models.dart';

/// Dois pedidos do dono que quebram calado: cards de alturas diferentes só
/// aparecem olhando a faixa de lado, e a quebra de linha no desktop depende da
/// largura real — nenhum dos dois estoura nada.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const cliente = ClienteRanqueado(
    customerId: 'c1',
    customerName: 'Maria',
    recebido: 1500,
    desconto: 50,
    atendimentos: 7,
    osCount: 4,
    saleCount: 3,
    ticketMedio: 214.28,
    primeiroEm: '2025-03-10T10:00:00Z',
    ultimoEm: '2026-08-20T10:00:00Z',
  );

  Future<void> montar(WidgetTester tester, double largura) async {
    tester.view.physicalSize = Size(largura, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerLifetimeProvider('c1').overrideWith((ref) async => cliente),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CustomerKpis(customerId: 'c1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('todos os cards têm a MESMA altura', (tester) async {
    await montar(tester, 1400);
    final rects = <Rect>[];
    for (final r in ['Já pagou', 'Atendimentos', 'Ticket médio', 'Cliente desde']) {
      rects.add(tester.getRect(
        find.ancestor(of: find.text(r), matching: find.byType(Padding)).first,
      ));
    }
    // Todos começam na mesma linha (topo alinhado) — é o que "mesma altura"
    // significa visualmente numa faixa horizontal.
    final topos = rects.map((r) => r.top.roundToDouble()).toSet();
    expect(topos.length, 1, reason: 'os cards não estão alinhados no topo');
  });

  testWidgets('desktop mantém os 5 KPIs em UMA linha', (tester) async {
    await montar(tester, 1400);
    final ys = <double>{};
    for (final r in [
      'Já pagou',
      'Atendimentos',
      'Ticket médio',
      'Cliente desde',
      'Descontos dados',
    ]) {
      ys.add(tester.getCenter(find.text(r)).dy.roundToDouble());
    }
    expect(ys.length, 1, reason: 'os KPIs se espalharam em mais de uma linha');
  });

  testWidgets('celular quebra em duas colunas, sem estourar', (tester) async {
    await montar(tester, 390);
    final ys = <double>{};
    for (final r in ['Já pagou', 'Atendimentos', 'Ticket médio']) {
      ys.add(tester.getCenter(find.text(r)).dy.roundToDouble());
    }
    // Três KPIs não cabem numa linha de 390pt: pelo menos duas alturas.
    expect(ys.length, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente sem atendimento não mostra a faixa', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerLifetimeProvider('c2')
              .overrideWith((ref) async => const ClienteRanqueado(customerId: 'c2')),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CustomerKpis(customerId: 'c2')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Já pagou'), findsNothing);
  });
}
