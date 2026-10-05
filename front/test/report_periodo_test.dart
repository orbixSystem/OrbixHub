import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/report/data/fake_report_repository.dart';
import 'package:orbixhub_front/features/report/domain/report_models.dart';
import 'package:orbixhub_front/features/report/presentation/report_providers.dart';
import 'package:orbixhub_front/features/report/presentation/report_tabs.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/filtro_de_periodo.dart';
import 'package:orbixhub_front/features/report/presentation/widgets/filtros_da_aba.dart';

/// O seletor de período.
///
/// É o filtro que governa todas as abas: errar a janela aqui não mostra um
/// número errado num card, mostra a página inteira falando de outro tempo. Os
/// testes cobrem as duas metades — a conta dos atalhos e o caminho até o
/// intervalo escolhido no calendário.

/// Uma quarta-feira no meio de setembro: longe de virada de mês e de ano, para
/// que os atalhos não acertem por acidente.
final _agora = DateTime(2026, 9, 16, 14, 30);

ReportRange _janela(PresetDePeriodo p) =>
    PeriodoDoRelatorio(preset: p).intervalo(_agora);

void main() {
  group('a conta de cada atalho', () {
    test('hoje começa à meia-noite e termina AGORA', () {
      final r = _janela(PresetDePeriodo.hoje);
      expect(r.from, DateTime(2026, 9, 16));
      // Não o fim do dia: somar as horas que ainda não aconteceram achataria
      // qualquer média por hora trabalhada.
      expect(r.to, _agora);
    });

    test('ontem é o dia inteiro — ele já acabou', () {
      final r = _janela(PresetDePeriodo.ontem);
      expect(r.from, DateTime(2026, 9, 15));
      expect(r.to, DateTime(2026, 9, 15, 23, 59, 59, 999));
    });

    test('últimos 7 dias inclui hoje, e são 7 — não 8', () {
      final r = _janela(PresetDePeriodo.ultimos7);
      expect(r.from, DateTime(2026, 9, 10));
      expect(r.to, _agora);
    });

    test('últimos 30 dias inclui hoje', () {
      expect(_janela(PresetDePeriodo.ultimos30).from, DateTime(2026, 8, 18));
    });

    test('este mês vai do dia 1º até agora', () {
      final r = _janela(PresetDePeriodo.esteMes);
      expect(r.from, DateTime(2026, 9, 1));
      expect(r.to, _agora);
    });

    test('mês passado é o mês fechado, do 1º ao último dia', () {
      final r = _janela(PresetDePeriodo.mesPassado);
      expect(r.from, DateTime(2026, 8, 1));
      expect(r.to, DateTime(2026, 8, 31, 23, 59, 59, 999));
    });

    test('este ano começa em 1º de janeiro', () {
      expect(_janela(PresetDePeriodo.esteAno).from, DateTime(2026, 1, 1));
    });

    test('o personalizado pega o dia inteiro nas duas pontas', () {
      final r = PeriodoDoRelatorio(
        preset: PresetDePeriodo.personalizado,
        de: DateTime(2026, 9, 3),
        ate: DateTime(2026, 9, 9),
      ).intervalo(_agora);

      expect(r.from, DateTime(2026, 9, 3));
      // Terminar à meia-noite perderia o movimento do último dia — e ninguém
      // na tela saberia por quê.
      expect(r.to, DateTime(2026, 9, 9, 23, 59, 59, 999));
    });

    test('personalizado sem as duas datas volta ao padrão', () {
      // Meia escolha não é um período: montar a janela com uma ponta
      // inventada daria um relatório que ninguém pediu.
      final r = const PeriodoDoRelatorio(preset: PresetDePeriodo.personalizado)
          .intervalo(_agora);
      expect(r.from, DateTime(2026, 9, 1));
    });
  });

  test('o padrão é este mês', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(periodoSelecionadoProvider).preset,
      PresetDePeriodo.esteMes,
    );
  });

  test('escolher um atalho apaga o intervalo personalizado', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(periodoSelecionadoProvider.notifier);

    n.usarIntervalo(DateTime(2026, 9, 3), DateTime(2026, 9, 9));
    n.usarPreset(PresetDePeriodo.ultimos7);

    // Datas antigas sobrando atrás de um atalho fariam o chip dizer uma coisa
    // e a consulta pedir outra.
    final p = container.read(periodoSelecionadoProvider);
    expect(p.de, isNull);
    expect(p.ate, isNull);
    expect(p.ehPersonalizado, isFalse);
  });

  group('o rótulo do chip', () {
    test('um atalho se chama pelo nome', () {
      expect(
        rotuloDoPeriodo(
          const PeriodoDoRelatorio(preset: PresetDePeriodo.ultimos30),
        ),
        'Últimos 30 dias',
      );
    });

    test('um intervalo se chama pelas suas pontas', () {
      expect(
        rotuloDoPeriodo(PeriodoDoRelatorio(
          preset: PresetDePeriodo.personalizado,
          de: DateTime(2026, 9, 3),
          ate: DateTime(2026, 9, 9),
        )),
        '03/09/2026 – 09/09/2026',
      );
    });
  });

  testWidgets('a folha traz os atalhos e o caminho do personalizado',
      (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      overrides: [
        reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: FiltrosDaAba(aba: ReportTab.caixa)),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('Este mês'));
    await t.pumpAndSettle();

    for (final atalho in const [
      'Hoje',
      'Ontem',
      'Últimos 7 dias',
      'Últimos 30 dias',
      'Mês passado',
      'Este ano',
      'Personalizado',
    ]) {
      expect(find.text(atalho), findsOneWidget, reason: 'falta "$atalho"');
    }

    // O calendário só aparece atrás de "Personalizado": presets e intervalo
    // são alternativas excludentes, e mostrar as duas ao mesmo tempo não
    // deixaria claro qual vale.
    expect(find.byType(CalendarDatePicker), findsNothing);
    await t.tap(find.text('Personalizado'));
    await t.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNWidgets(2));
    // E já abre SEMEADO com o período vigente: um calendário sem data
    // escolhida ainda assim destaca um dia, e o usuário via esse dia marcado
    // ao lado de um pedido para escolher as datas.
    expect(find.textContaining('até'), findsOneWidget);
    expect(find.text('Aplicar'), findsOneWidget);
  });

  testWidgets('escolher um atalho aplica e fecha', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final container = ProviderContainer(overrides: [
      reportRepositoryProvider.overrideWithValue(FakeReportRepository()),
    ]);
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: FiltrosDaAba(aba: ReportTab.caixa)),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('Este mês'));
    await t.pumpAndSettle();
    await t.tap(find.text('Últimos 7 dias'));
    await t.pumpAndSettle();

    expect(
      container.read(periodoSelecionadoProvider).preset,
      PresetDePeriodo.ultimos7,
    );
    // Fechou: o atalho é um clique só, e manter a folha aberta obrigaria a um
    // segundo para dispensá-la.
    expect(find.text('Hoje'), findsNothing);
    expect(find.text('Últimos 7 dias'), findsOneWidget); // agora é o chip
  });
}
