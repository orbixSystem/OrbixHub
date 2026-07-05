import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/cnpj.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';
import '../../dashboard/presentation/dashboard_providers.dart'
    show osManagementMetricsProvider;
import '../../dashboard/presentation/widgets/kpi.dart' show KpiTile;
import '../../dashboard/presentation/widgets/metric_card.dart'
    show formatMoney, MetricLoading;
import '../../dashboard/presentation/widgets/period_selector.dart';
import '../../os/presentation/os_status.dart'
    show osStatuses, osStatusColor, osStatusLabel, OsStatusChip;
import '../domain/report_models.dart';
import '../domain/report_repository.dart';
import 'report_catalog.dart';
import 'report_csv.dart';
import 'report_download.dart';
import 'report_pdf.dart';
import 'report_xlsx.dart';
import 'report_providers.dart';
import 'report_tables.dart';

/// Tela de Relatórios (`/m/report`): seletor de relatório (agrupado por módulo) +
/// filtros contextuais + tabela/gráfico + export CSV/PDF. Gated no menu/rota por
/// módulo `report` + `report.read`; cada relatório exige seu módulo-fonte. A UI
/// só fala com o repository (via providers).
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Center(child: MetricLoading());
    }
    final me = session.me;
    final reports = availableReports(me);

    if (reports.isEmpty) {
      return const _Empty(
        message: 'Nenhum relatório disponível para o seu acesso.',
      );
    }

    // Default: primeiro relatório disponível (uma vez, ao montar).
    final selected = ref.watch(selectedReportProvider) ?? reports.first.kind;
    final spec = reports.firstWhere(
      (r) => r.kind == selected,
      orElse: () => reports.first,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final picker = _ReportPicker(reports: reports, selected: spec.kind);
        final content = _ReportContent(me: me, spec: spec);

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relatórios',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Lentes detalhadas sobre os dados dos seus módulos.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        );

        // Desktop: cabeçalho + picker FIXOS; só o conteúdo rola. O picker fica
        // "grudado" no topo mesmo com o relatório rolando (sidebar fixa).
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sidebar fixa (rola internamente só se houver muitos
                      // relatórios), não acompanha o scroll do conteúdo.
                      SizedBox(
                        width: 240,
                        child: SingleChildScrollView(child: picker),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: SingleChildScrollView(child: content),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile/estreito: tudo empilhado num scroll só (picker no topo).
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 20),
              picker,
              const SizedBox(height: 20),
              content,
            ],
          ),
        );
      },
    );
  }
}

/// Seletor de relatório agrupado por módulo-fonte. Só mostra os grupos cujos
/// relatórios estão disponíveis (`availableReports` já filtrou por módulo).
class _ReportPicker extends ConsumerWidget {
  const _ReportPicker({required this.reports, required this.selected});

  final List<ReportSpec> reports;
  final ReportKind selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String, List<ReportSpec>>{};
    for (final r in reports) {
      groups.putIfAbsent(r.group, () => []).add(r);
    }

    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: neu.inkFaint,
                ),
              ),
            ),
            for (final r in entry.value)
              _PickerItem(
                label: r.label,
                selected: r.kind == selected,
                onTap: () =>
                    ref.read(selectedReportProvider.notifier).select(r.kind),
              ),
          ],
        ],
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  const _PickerItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? neu.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(NeuTokens.rChip),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: selected ? neu.navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? neu.ink : neu.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corpo do relatório selecionado: filtros + export + tabela/gráfico.
class _ReportContent extends ConsumerWidget {
  const _ReportContent({required this.me, required this.spec});

  final Me me;
  final ReportSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FiltersBar(kind: spec.kind),
        const SizedBox(height: 18),
        _ReportBody(me: me, spec: spec),
      ],
    );
  }
}

/// Barra de filtros contextual por relatório. Período sempre (exceto estoque,
/// point-in-time); técnico+status só na OS operacional; kind+limit no top-itens.
class _FiltersBar extends ConsumerWidget {
  const _FiltersBar({required this.kind});

  final ReportKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesPeriod = kind != ReportKind.inventoryPosition;
    final filters = ref.watch(reportFiltersProvider);

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (usesPeriod) const PeriodSelector(),
        if (kind == ReportKind.osOperational) ...[
          _MemberFilter(
            value: filters.assignedTo,
            onChanged: (v) =>
                ref.read(reportFiltersProvider.notifier).setAssignedTo(v),
          ),
          _StatusFilter(
            value: filters.status,
            onChanged: (v) =>
                ref.read(reportFiltersProvider.notifier).setStatus(v),
          ),
          const _OsSearchField(),
          const _OsSortMenu(),
        ],
        if (kind == ReportKind.topItems) ...[
          _KindFilter(
            value: filters.kind,
            onChanged: (v) =>
                ref.read(reportFiltersProvider.notifier).setKind(v),
          ),
          _LimitFilter(
            value: filters.limit,
            onChanged: (v) =>
                ref.read(reportFiltersProvider.notifier).setLimit(v),
          ),
        ],
      ],
    );
  }
}

class _MemberFilter extends ConsumerWidget {
  const _MemberFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(reportMembersProvider);
    return membersAsync.when(
      loading: () => const SizedBox(
        width: 200,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (members) => SizedBox(
        width: 220,
        child: DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Técnico',
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todos'),
            ),
            for (final m in members)
              DropdownMenuItem<String?>(value: m.id, child: Text(m.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Status',
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
          for (final s in osStatuses)
            DropdownMenuItem<String?>(value: s, child: Text(osStatusLabel(s))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _KindFilter extends StatelessWidget {
  const _KindFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tipo',
          isDense: true,
        ),
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('Todos')),
          DropdownMenuItem<String?>(value: 'product', child: Text('Produtos')),
          DropdownMenuItem<String?>(value: 'service', child: Text('Serviços')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _LimitFilter extends StatelessWidget {
  const _LimitFilter({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Top',
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 5, child: Text('Top 5')),
          DropdownMenuItem(value: 10, child: Text('Top 10')),
          DropdownMenuItem(value: 20, child: Text('Top 20')),
          DropdownMenuItem(value: 50, child: Text('Top 50')),
        ],
        onChanged: (v) => onChanged(v ?? 10),
      ),
    );
  }
}

/// Mapeia o relatório selecionado para o AsyncValue do seu provider, constrói a
/// [ReportTable] (fonte de CSV/PDF) e renderiza tabela + gráfico onde agrega valor.
class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.me, required this.spec});

  final Me me;
  final ReportSpec spec;

  ReportCompany? _company() {
    final t = me.activeTenant;
    if (t == null) return null;
    return ReportCompany(
      name: t.name,
      legalName: t.legalName,
      cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
    );
  }

  String _periodLabel(WidgetRef ref) {
    final r = ref.read(reportRangeProvider);
    return '${fmtDate(r.fromIso)} – ${fmtDate(r.toIso)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // {id -> nome} dos membros (mesma lista do dropdown "Técnico"), para resolver
    // o `assigned_to` (uuid) para o nome nas tabelas/gráficos de OS e equipe.
    final memberNames = <String, String>{
      for (final m
          in ref.watch(reportMembersProvider).value ??
              const <ReportMemberOption>[])
        m.id: m.name,
    };

    switch (spec.kind) {
      case ReportKind.overview:
        // Painel BI: KPIs + gráficos sobre os dados JÁ existentes do período.
        // Sem tabela/export — é um dashboard.
        return _OverviewReport(me: me, memberNames: memberNames);
      case ReportKind.osOperational:
        // OS pode ter milhares de linhas → lista PAGINADA (scroll infinito,
        // render leve). Evita montar uma DataTable gigante de uma vez (causa do
        // travamento anterior). Busca + ordenação ficam na barra de filtros.
        return _OsOperationalReport(
          memberNames: memberNames,
          company: _company(),
          period: _periodLabel(ref),
        );
      case ReportKind.revenue:
        return _AsyncReport(
          async: ref.watch(revenueReportProvider),
          retry: () => ref.invalidate(revenueReportProvider),
          tableOf: revenueTable,
          isEmpty: (r) => r.byDay.isEmpty,
          chartOf: (r) => _RevenueChart(report: r),
          summaryOf: (r) => [
            ('Receita total', formatMoney(r.total)),
            ('Ticket médio', formatMoney(r.avgTicket)),
          ],
          company: _company(),
          period: _periodLabel(ref),
        );
      case ReportKind.team:
        return _AsyncReport(
          async: ref.watch(teamReportProvider),
          retry: () => ref.invalidate(teamReportProvider),
          tableOf: (r) => teamTable(r, memberNames),
          isEmpty: (r) => r.rows.isEmpty,
          chartOf: (r) => _TeamChart(report: r, names: memberNames),
          company: _company(),
          period: _periodLabel(ref),
        );
      case ReportKind.topItems:
        return _AsyncReport(
          async: ref.watch(topItemsReportProvider),
          retry: () => ref.invalidate(topItemsReportProvider),
          tableOf: topItemsTable,
          isEmpty: (r) => r.rows.isEmpty,
          chartOf: null,
          company: _company(),
          period: _periodLabel(ref),
        );
      case ReportKind.inventoryPosition:
        // Estoque pode ter milhares de itens → paginado na tela; export (CSV/PDF
        // do relatório COMPLETO) é gerado no servidor. Caso dedicado (não o
        // genérico, que monta tudo em memória).
        return _InventoryReport(company: _company());
      case ReportKind.customers:
        return _AsyncReport(
          async: ref.watch(customersReportProvider),
          retry: () => ref.invalidate(customersReportProvider),
          tableOf: customersTable,
          isEmpty: (r) => r.rows.isEmpty,
          chartOf: null,
          summaryOf: (r) => [
            ('Clientes ativos', '${r.active}'),
            ('Novos no período', '${r.newInRange}'),
          ],
          company: _company(),
          period: _periodLabel(ref),
        );
    }
  }
}

/// Painel BI da "Visão geral": KPIs + gráficos sobre os dados JÁ existentes do
/// período selecionado. O faturamento é obrigatório (módulo `os`); clientes e
/// estoque só entram quando o tenant tem esses módulos. Sem tabela/export — é um
/// dashboard. Respeita o seletor de período (via `revenueReportProvider` etc.).
class _OverviewReport extends ConsumerWidget {
  const _OverviewReport({required this.me, required this.memberNames});

  final Me me;
  final Map<String, String> memberNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Faturamento é a fonte obrigatória: dita loading/erro do painel inteiro.
    final revenueAsync = ref.watch(revenueReportProvider);
    return revenueAsync.when(
      loading: () => const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) =>
          _ErrorBox(onRetry: () => ref.invalidate(revenueReportProvider)),
      data: (revenue) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Visão geral', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          _OverviewKpis(me: me, revenue: revenue),
          const SizedBox(height: 20),
          _OverviewCharts(
            revenue: revenue,
            memberNames: memberNames,
          ),
        ],
      ),
    );
  }
}

/// Faixa de KPIs da Visão geral. Faturamento/Nº de OS/Ticket médio saem do
/// `RevenueReport`; "OS atrasadas" da métrica gerencial de OS (mesmo período);
/// "Novos clientes"/"Valor em estoque" só aparecem se o módulo-fonte existir.
class _OverviewKpis extends ConsumerWidget {
  const _OverviewKpis({required this.me, required this.revenue});

  final Me me;
  final RevenueReport revenue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    // Nº de OS no período = soma das contagens por status do faturamento.
    final osCount =
        revenue.byStatus.values.fold<int>(0, (a, b) => a + b.count);
    // "Atrasadas" não vem do RevenueReport (não há esse recorte lá); usa a
    // métrica gerencial de OS, que reage ao MESMO período selecionado.
    final osMetrics = ref.watch(osManagementMetricsProvider);
    final overdue = osMetrics.asData?.value.overdue ?? 0;

    final tiles = <Widget>[
      KpiTile(
        icon: Icons.payments_outlined,
        glyphIndex: 2,
        label: 'Faturamento',
        value: formatMoney(revenue.total),
        valueColor: neu.success,
      ),
      KpiTile(
        icon: Icons.receipt_long_outlined,
        glyphIndex: 1,
        label: 'Nº de OS',
        value: '$osCount',
      ),
      KpiTile(
        icon: Icons.calculate_outlined,
        glyphIndex: 0,
        label: 'Ticket médio',
        value: formatMoney(revenue.avgTicket),
      ),
      KpiTile(
        icon: Icons.warning_amber_rounded,
        glyphIndex: 4,
        label: 'OS atrasadas',
        loading: osMetrics.isLoading,
        value: '$overdue',
        valueColor: overdue > 0 ? neu.danger : null,
      ),
    ];

    if (me.hasModule('customers')) {
      final cust = ref.watch(customersReportProvider);
      final data = cust.asData?.value;
      tiles.add(KpiTile(
        icon: Icons.people_alt_outlined,
        glyphIndex: 3,
        label: 'Novos clientes',
        loading: cust.isLoading,
        value: '${data?.newInRange ?? 0}',
        sub: data != null && data.active > 0 ? '${data.active} ativos' : null,
      ));
    }

    if (me.hasModule('inventory')) {
      final inv = ref.watch(inventoryReportProvider);
      tiles.add(KpiTile(
        icon: Icons.inventory_2_outlined,
        glyphIndex: 5,
        label: 'Valor em estoque',
        loading: inv.isLoading,
        value: formatMoney(inv.asData?.value.stockValue ?? 0),
      ));
    }

    return _OverviewKpiGrid(tiles: tiles);
  }
}

/// Grade de KPIs sem buracos: escolhe o nº de colunas que divide os tiles
/// (linhas cheias) e faz cada tile Expanded. Espelha o grid do dashboard.
class _OverviewKpiGrid extends StatelessWidget {
  const _OverviewKpiGrid({required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        final n = tiles.length;
        final maxCols = (c.maxWidth / 210).floor().clamp(1, 4);
        var cols = n <= maxCols ? n : maxCols;
        for (var k = maxCols; k >= 2; k--) {
          if (n % k == 0) {
            cols = k;
            break;
          }
        }
        final rows = <Widget>[];
        for (var i = 0; i < n; i += cols) {
          final slice = tiles.skip(i).take(cols).toList();
          rows.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < slice.length; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(child: slice[j]),
                  ],
                ],
              ),
            ),
          ));
        }
        return Column(children: rows);
      },
    );
  }
}

/// Grade de gráficos da Visão geral: 2 colunas no desktop, 1 no mobile.
/// Faturamento no tempo (linha/área) + OS por status (rosca) do RevenueReport;
/// Top produtos/serviços + Rendimento da equipe assistem seus próprios providers.
class _OverviewCharts extends ConsumerWidget {
  const _OverviewCharts({required this.revenue, required this.memberNames});

  final RevenueReport revenue;
  final Map<String, String> memberNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamReportProvider);
    final topItems = ref.watch(topItemsReportProvider);

    final cards = <Widget>[
      _RevenueLineCard(report: revenue),
      _StatusDonutCard(report: revenue),
      _OverviewTopItemsCard(async: topItems),
      _OverviewTeamCard(async: team, names: memberNames),
    ];

    if (context.isMobile) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            cards[i],
          ],
        ],
      );
    }

    const gap = 16.0;
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      final right = i + 1 < cards.length ? cards[i + 1] : null;
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: gap),
            Expanded(child: right ?? const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Faturamento no tempo (linha suave com área preenchida) — `RevenueReport.byDay`.
class _RevenueLineCard extends StatelessWidget {
  const _RevenueLineCard({required this.report});
  final RevenueReport report;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final days = report.byDay;
    if (days.isEmpty) {
      return const NeuChartCard(
          title: 'Faturamento no tempo', child: _ChartEmpty());
    }
    final maxY = days
        .map((d) => d.revenue.toDouble())
        .fold<double>(0, (a, b) => b > a ? b : a);
    final spots = <FlSpot>[
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].revenue.toDouble()),
    ];

    return NeuChartCard(
      title: 'Faturamento no tempo',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY <= 0 ? 1 : maxY) / 3,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: neu.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => neu.navy,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    formatMoney(s.y),
                    TextStyle(
                      color: neu.onNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              barWidth: 3,
              color: neu.accent,
              dotData: FlDotData(show: days.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    neu.accent.withValues(alpha: .28),
                    neu.accent.withValues(alpha: .02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// OS por status (rosca) — `RevenueReport.byStatus`, cor por `osStatusColor`.
/// Legenda ao lado com contagem por status.
class _StatusDonutCard extends StatelessWidget {
  const _StatusDonutCard({required this.report});
  final RevenueReport report;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    // Ordena pelo fluxo canônico dos status; inclui só os presentes (count > 0).
    final entries = <MapEntry<String, CountRevenue>>[
      for (final s in osStatuses)
        if ((report.byStatus[s]?.count ?? 0) > 0)
          MapEntry(s, report.byStatus[s]!),
      // Defensivo: status fora da lista canônica (se o backend enviar).
      for (final e in report.byStatus.entries)
        if (!osStatuses.contains(e.key) && e.value.count > 0) e,
    ];
    if (entries.isEmpty) {
      return const NeuChartCard(
          title: 'OS por status', child: _ChartEmpty());
    }

    return NeuChartCard(
      title: 'OS por status',
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value.count.toDouble(),
                      color: osStatusColor(e.key),
                      title: '${e.value.count}',
                      radius: 46,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: osStatusColor(e.key),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            osStatusLabel(e.key),
                            style:
                                TextStyle(color: neu.inkMuted, fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${e.value.count}',
                          style: TextStyle(
                            color: neu.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top produtos/serviços (barras) — assiste `topItemsReportProvider`.
class _OverviewTopItemsCard extends StatelessWidget {
  const _OverviewTopItemsCard({required this.async});
  final AsyncValue<TopItemsReport> async;

  @override
  Widget build(BuildContext context) {
    const title = 'Top produtos/serviços';
    return async.when(
      loading: () => const NeuChartCard(title: title, child: _ChartLoading()),
      error: (_, _) => const NeuChartCard(
        title: title,
        child: _ChartEmpty(message: 'Não foi possível carregar.'),
      ),
      data: (report) {
        final neu = context.neu;
        final rows = report.rows.take(8).toList();
        if (rows.isEmpty) {
          return const NeuChartCard(title: title, child: _ChartEmpty());
        }
        final maxY = rows
            .map((r) => r.revenue.toDouble())
            .fold<double>(0, (a, b) => b > a ? b : a);

        return NeuChartCard(
          title: title,
          child: BarChart(
            BarChartData(
              maxY: maxY <= 0 ? 1 : maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY <= 0 ? 1 : maxY) / 3,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: neu.line, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= rows.length) {
                        return const SizedBox.shrink();
                      }
                      final label = rows[i].name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label.length > 8
                              ? '${label.substring(0, 8)}…'
                              : label,
                          style: TextStyle(fontSize: 10, color: neu.inkMuted),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData:
                  neuBarTouch(context, label: (i, v) => formatMoney(v)),
              barGroups: [
                for (var i = 0; i < rows.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      neuBarRod(
                        context,
                        rows[i].revenue.toDouble(),
                        width: 16,
                        color: neu.glyphs[i % neu.glyphs.length],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Rendimento da equipe (barras) — assiste `teamReportProvider`; reusa o
/// `_TeamChart` já existente quando há dados.
class _OverviewTeamCard extends StatelessWidget {
  const _OverviewTeamCard({required this.async, required this.names});
  final AsyncValue<TeamReport> async;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    const title = 'Faturamento por responsável';
    return async.when(
      loading: () => const NeuChartCard(title: title, child: _ChartLoading()),
      error: (_, _) => const NeuChartCard(
        title: title,
        child: _ChartEmpty(message: 'Não foi possível carregar.'),
      ),
      data: (report) => report.rows.isEmpty
          ? const NeuChartCard(title: title, child: _ChartEmpty())
          : _TeamChart(report: report, names: names),
    );
  }
}

/// Corpo vazio de um gráfico (dentro do `NeuChartCard`, altura fixa).
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({this.message = 'Sem dados no período.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: context.neu.inkMuted, fontSize: 13),
      ),
    );
  }
}

/// Corpo de carregamento de um gráfico (spinner centralizado).
class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
  }
}

/// Renderiza um `AsyncValue` com loading/erro/empty elegantes; quando há dados,
/// monta a [ReportTable], os botões de export e a tabela + gráfico opcional.
class _AsyncReport<T> extends StatelessWidget {
  const _AsyncReport({
    required this.async,
    required this.retry,
    required this.tableOf,
    required this.isEmpty,
    required this.company,
    required this.period,
    this.chartOf,
    this.summaryOf,
  });

  final AsyncValue<T> async;
  final VoidCallback retry;
  final ReportTable Function(T) tableOf;
  final bool Function(T) isEmpty;
  final Widget Function(T)? chartOf;
  final List<(String, String)> Function(T)? summaryOf;
  final ReportCompany? company;
  final String? period;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) => _ErrorBox(onRetry: retry),
      data: (data) {
        final table = tableOf(data);
        final empty = isEmpty(data);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do relatório: título à esquerda, ações de export à direita.
            // Quebra para baixo em telas estreitas (Wrap com alinhamento entre as
            // extremidades).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 16,
              children: [
                Text(
                  table.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _ExportButtons(
                  table: table,
                  company: company,
                  period: period,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (summaryOf != null) ...[
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final s in summaryOf!(data))
                    _SummaryStat(label: s.$1, value: s.$2),
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (!empty && chartOf != null) ...[
              chartOf!(data),
              const SizedBox(height: 18),
            ],
            if (empty)
              const _Empty(message: 'Sem dados no período.')
            else
              _DataTableCard(table: table),
          ],
        );
      },
    );
  }
}

/// Relatório de estoque dedicado: tabela PAGINADA (uma página por vez, render
/// leve) + KPI de valor total + export gerado no servidor. Evita carregar/
/// renderizar milhares de itens de uma vez (causa da lentidão anterior).
class _InventoryReport extends ConsumerWidget {
  const _InventoryReport({required this.company});

  final ReportCompany? company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryReportProvider);
    return async.when(
      // Mantém a página anterior visível enquanto a próxima carrega (paginador
      // sem flicker de spinner cheio).
      skipLoadingOnReload: true,
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) =>
          _ErrorBox(onRetry: () => ref.invalidate(inventoryReportProvider)),
      data: (data) {
        final empty = data.rows.isEmpty && data.total == 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 16,
              children: [
                Text('Posição de estoque',
                    style: Theme.of(context).textTheme.titleLarge),
                _ServerExportButtons(company: company),
              ],
            ),
            const SizedBox(height: 18),
            _SummaryStat(
                label: 'Valor em estoque',
                value: formatMoney(data.stockValue)),
            const SizedBox(height: 18),
            if (empty)
              const _Empty(message: 'Sem itens em estoque.')
            else ...[
              _DataTableCard(
                  table: inventoryTable(data, includeTotal: false)),
              const SizedBox(height: 12),
              _InventoryPager(report: data),
            ],
          ],
        );
      },
    );
  }
}

/// Paginador do relatório de estoque: "X–Y de N" + navegação anterior/próxima.
class _InventoryPager extends ConsumerWidget {
  const _InventoryPager({required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NeuPageControls(
      page: report.page <= 0 ? 1 : report.page,
      pageSize: report.pageSize <= 0 ? 20 : report.pageSize,
      total: report.total,
      onPage: (p) => ref.read(inventoryPageProvider.notifier).set(p),
    );
  }
}

/// Botões de export do estoque que baixam o arquivo COMPLETO gerado no servidor
/// (CSV/PDF). Mostra spinner enquanto o servidor gera + trata erro com SnackBar.
class _ServerExportButtons extends ConsumerStatefulWidget {
  const _ServerExportButtons({required this.company});

  final ReportCompany? company;

  @override
  ConsumerState<_ServerExportButtons> createState() =>
      _ServerExportButtonsState();
}

class _ServerExportButtonsState extends ConsumerState<_ServerExportButtons> {
  bool _csvBusy = false;
  bool _pdfBusy = false;

  ReportExportCompany? _exportCompany() {
    final c = widget.company;
    if (c == null) return null;
    return ReportExportCompany(
      name: c.name,
      legalName: c.legalName,
      cnpj: c.cnpj,
    );
  }

  Future<void> _run({
    required bool isPdf,
    required Future<void> Function() task,
  }) async {
    setState(() => isPdf ? _pdfBusy = true : _csvBusy = true);
    try {
      await task();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Não foi possível gerar o arquivo. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isPdf ? _pdfBusy = false : _csvBusy = false);
      }
    }
  }

  Future<void> _csv() => _run(
        isPdf: false,
        task: () async {
          final bytes = await ref.read(reportRepositoryProvider).inventoryCsv();
          downloadBytes(bytes, 'posicao-de-estoque.csv',
              'text/csv;charset=utf-8');
        },
      );

  Future<void> _pdf() => _run(
        isPdf: true,
        task: () async {
          final bytes = await ref
              .read(reportRepositoryProvider)
              .inventoryPdf(company: _exportCompany());
          downloadBytes(bytes, 'posicao-de-estoque.pdf', 'application/pdf');
        },
      );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NeuButton(
          label: 'Exportar CSV',
          kind: NeuButtonKind.secondary,
          icon: Icons.table_view_outlined,
          loading: _csvBusy,
          onPressed: _csvBusy ? null : _csv,
        ),
        NeuButton(
          label: 'Exportar PDF',
          icon: Icons.picture_as_pdf_outlined,
          loading: _pdfBusy,
          onPressed: _pdfBusy ? null : _pdf,
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: neu.ink),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Tabela responsiva (DataTable em scroll horizontal) com a última linha de
/// total destacada quando o builder a inclui (rótulo 'TOTAL').
class _DataTableCard extends StatelessWidget {
  const _DataTableCard({required this.table});
  final ReportTable table;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    bool isTotal(List<String> row) => row.isNotEmpty && row.first == 'TOTAL';

    return NeuCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(neu.surfaceHi),
            headingTextStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: neu.inkMuted,
              letterSpacing: 0.2,
            ),
            dataTextStyle: TextStyle(fontSize: 13.5, color: neu.ink),
            dividerThickness: 0.5,
            columns: [
              for (final h in table.headers) DataColumn(label: Text(h)),
            ],
            rows: [
              for (var i = 0; i < table.rows.length; i++)
                () {
                  final row = table.rows[i];
                  final total = isTotal(row);
                  return DataRow(
                    color: WidgetStateProperty.all(
                      total
                          ? neu.accentTint
                          : (i.isOdd
                              ? neu.base.withValues(alpha: 0.5)
                              : null),
                    ),
                    cells: [
                      for (final cell in row)
                        DataCell(
                          Text(
                            cell,
                            style: total
                                ? TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: neu.navy,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  );
                }(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botões "Exportar CSV" (baixa via browser) e "Exportar PDF" (Printing).
class _ExportButtons extends StatelessWidget {
  const _ExportButtons({
    required this.table,
    required this.company,
    required this.period,
  });

  final ReportTable table;
  final ReportCompany? company;
  final String? period;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NeuButton(
          label: 'Exportar CSV',
          kind: NeuButtonKind.secondary,
          icon: Icons.table_view_outlined,
          onPressed: () => downloadText(
              buildCsv(table), csvFileName(table.title),
              'text/csv;charset=utf-8'),
        ),
        NeuButton(
          label: 'Exportar Excel',
          kind: NeuButtonKind.secondary,
          icon: Icons.grid_on_outlined,
          onPressed: () => downloadBytes(
            buildXlsx(
              table,
              company: company?.name,
              period: period,
            ),
            xlsxFileName(table.title),
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
        NeuButton(
          label: 'Exportar PDF',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: () => Printing.layoutPdf(
            onLayout: (format) => buildReportPdf(
              table,
              format,
              company: company,
              periodLabel: period,
            ),
          ),
        ),
      ],
    );
  }
}

/// Gráfico de barras do faturamento por dia (série temporal).
class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.report});
  final RevenueReport report;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final days = report.byDay;
    if (days.isEmpty) return const SizedBox.shrink();
    final maxY = days
        .map((d) => d.revenue.toDouble())
        .fold<double>(0, (a, b) => b > a ? b : a);

    return NeuChartCard(
      title: 'Evolução do faturamento',
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY <= 0 ? 1 : maxY) / 3,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: neu.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            leftTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: neuBarTouch(
            context,
            label: (i, v) => formatMoney(v),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  neuBarRod(
                    context,
                    days[i].revenue.toDouble(),
                    width: days.length > 20 ? 5 : 12,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de barras horizontais do faturamento por responsável.
class _TeamChart extends StatelessWidget {
  const _TeamChart({required this.report, required this.names});
  final TeamReport report;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final rows = report.rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxY = rows
        .map((r) => r.revenue.toDouble())
        .fold<double>(0, (a, b) => b > a ? b : a);

    return NeuChartCard(
      title: 'Faturamento por responsável',
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY <= 0 ? 1 : maxY) / 3,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: neu.line, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= rows.length) {
                    return const SizedBox.shrink();
                  }
                  final label = assignedLabel(rows[i].assignedTo, names);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label.length > 8 ? '${label.substring(0, 8)}…' : label,
                      style: TextStyle(fontSize: 10, color: neu.inkMuted),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: neuBarTouch(context, label: (i, v) => formatMoney(v)),
          barGroups: [
            for (var i = 0; i < rows.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  neuBarRod(
                    context,
                    rows[i].revenue.toDouble(),
                    width: 18,
                    color: neu.glyphs[i % neu.glyphs.length],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: NeuEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Não foi possível carregar',
        message: 'Tente novamente em instantes.',
        actionLabel: 'Tentar novamente',
        onAction: onRetry,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: NeuEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Sem dados',
        message: message,
      ),
    );
  }
}

/// Relatório operacional de OS: lista PAGINADA com scroll infinito (render leve,
/// um lote por vez) dentro de um card de altura limitada — não monta milhares de
/// linhas de uma vez. Export (CSV/PDF) cobre as linhas já carregadas.
class _OsOperationalReport extends ConsumerStatefulWidget {
  const _OsOperationalReport({
    required this.memberNames,
    required this.company,
    required this.period,
  });

  final Map<String, String> memberNames;
  final ReportCompany? company;
  final String? period;

  @override
  ConsumerState<_OsOperationalReport> createState() =>
      _OsOperationalReportState();
}

class _OsOperationalReportState extends ConsumerState<_OsOperationalReport> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(osOperationalReportProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(osOperationalReportProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) =>
          _ErrorBox(onRetry: () => ref.invalidate(osOperationalReportProvider)),
      data: (state) {
        // Tabela só com as linhas já carregadas — alimenta o export CSV/PDF.
        final table = osOperationalTable(
          OsOperationalReport(rows: state.rows),
          widget.memberNames,
        );
        final empty = state.rows.isEmpty;
        final listHeight =
            (MediaQuery.of(context).size.height * 0.6).clamp(360.0, 820.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 16,
              children: [
                Text('OS — Operacional',
                    style: Theme.of(context).textTheme.titleLarge),
                _ExportButtons(
                  table: table,
                  company: widget.company,
                  period: widget.period,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (empty)
              const _Empty(message: 'Sem OS no período.')
            else
              SizedBox(
                height: listHeight.toDouble(),
                child: NeuCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(NeuTokens.rCard),
                    child: ListView.separated(
                    controller: _scroll,
                    itemCount: state.rows.length + 1,
                    separatorBuilder: (_, i) => i >= state.rows.length - 1
                        ? const SizedBox.shrink()
                        : Divider(height: 1, color: context.neu.line),
                    itemBuilder: (_, i) {
                      if (i < state.rows.length) {
                        return _OsRowTile(
                          row: state.rows[i],
                          names: widget.memberNames,
                        );
                      }
                      return _ListFooter(
                        loadingMore: state.loadingMore,
                        hasMore: state.hasMore,
                        total: state.total,
                        noun: 'OS',
                      );
                    },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Linha (tile) de uma OS no relatório operacional: nº + cliente à esquerda;
/// status + valor à direita; abertura/técnico na 2ª linha. Render leve (sem DataTable).
class _OsRowTile extends StatelessWidget {
  const _OsRowTile({required this.row, required this.names});

  final OsReportRow row;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final subtitle =
        '${fmtDate(row.openedAt)} · ${assignedLabel(row.assignedTo, names)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.number} · ${row.customerName}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: neu.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: neu.inkMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OsStatusChip(status: row.status),
              const SizedBox(height: 4),
              Text(
                formatMoney(row.total),
                style: TextStyle(fontWeight: FontWeight.w800, color: neu.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Menu de ordenação do relatório de OS (mesmo visual do menu de Estoque).
class _OsSortMenu extends ConsumerWidget {
  const _OsSortMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final value = ref.watch(reportFiltersProvider).osSort;
    return PopupMenuButton<OsReportSort>(
      tooltip: 'Ordenar',
      initialValue: value,
      onSelected: (s) => ref.read(reportFiltersProvider.notifier).setOsSort(s),
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final s in OsReportSort.values)
          PopupMenuItem<OsReportSort>(
            value: s,
            child: Row(
              children: [
                Expanded(child: Text(s.label)),
                if (s == value) Icon(Icons.check, size: 18, color: neu.accent),
              ],
            ),
          ),
      ],
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: neu.inkMuted),
            const SizedBox(width: 8),
            Text(value.label,
                style: TextStyle(fontWeight: FontWeight.w600, color: neu.ink)),
            Icon(Icons.arrow_drop_down, color: neu.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Campo de busca do relatório de OS (nº ou cliente). Mantém o próprio controller
/// para não perder o cursor quando a barra de filtros rebuilda.
class _OsSearchField extends ConsumerStatefulWidget {
  const _OsSearchField();

  @override
  ConsumerState<_OsSearchField> createState() => _OsSearchFieldState();
}

class _OsSearchFieldState extends ConsumerState<_OsSearchField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: NeuSearchBar(
        hint: 'Buscar nº ou cliente',
        controller: _c,
        onChanged: (v) => ref.read(reportFiltersProvider.notifier).setOsQ(v),
      ),
    );
  }
}

/// Rodapé da lista paginada: spinner ao buscar o próximo lote; convite a rolar
/// quando há mais; contagem total quando tudo foi carregado.
class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.loadingMore,
    required this.hasMore,
    required this.total,
    required this.noun,
  });

  final bool loadingMore;
  final bool hasMore;
  final int total;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
    );
    final Widget child;
    if (loadingMore) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (hasMore) {
      child = Text('Role para carregar mais', style: style);
    } else {
      child = Text('$total $noun no total', style: style);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(child: child),
    );
  }
}
