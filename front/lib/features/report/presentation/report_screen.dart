import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/util/cnpj.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';
import '../../dashboard/presentation/widgets/metric_card.dart'
    show formatMoney, MetricLoading;
import '../../dashboard/presentation/widgets/period_selector.dart';
import '../../os/presentation/os_status.dart' show osStatuses, osStatusLabel;
import '../../../core/theme/app_colors.dart';
import '../domain/report_models.dart';
import 'report_catalog.dart';
import 'report_csv.dart';
import 'report_download.dart';
import 'report_pdf.dart';
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Relatórios',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Lentes detalhadas sobre os dados dos seus módulos.',
                style: TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 240, child: picker),
                    const SizedBox(width: 24),
                    Expanded(child: content),
                  ],
                )
              else ...[
                picker,
                const SizedBox(height: 20),
                content,
              ],
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.inkMuted,
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        color: selected ? AppColors.brandTint : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              color: selected ? AppColors.brand : Colors.transparent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.brandDeep : null,
                ),
              ),
            ),
          ],
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
            border: OutlineInputBorder(),
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
          border: OutlineInputBorder(),
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
          border: OutlineInputBorder(),
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
          border: OutlineInputBorder(),
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
      case ReportKind.osOperational:
        return _AsyncReport(
          async: ref.watch(osOperationalReportProvider),
          retry: () => ref.invalidate(osOperationalReportProvider),
          tableOf: (r) => osOperationalTable(r, memberNames),
          isEmpty: (r) => r.rows.isEmpty,
          chartOf: null,
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
        return _AsyncReport(
          async: ref.watch(inventoryReportProvider),
          retry: () => ref.invalidate(inventoryReportProvider),
          tableOf: inventoryTable,
          isEmpty: (r) => r.rows.isEmpty,
          chartOf: null,
          summaryOf: (r) => [('Valor em estoque', formatMoney(r.stockValue))],
          company: _company(),
          period: null,
        );
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
            // Título do relatório em largura cheia, ACIMA do corpo (era um filho
            // sem flex de um Row ao lado dos botões de export, o que o espremia
            // numa coluna de ~1 caractere e o fazia quebrar verticalmente).
            Text(
              table.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _ExportButtons(
              table: table,
              company: company,
              period: period,
            ),
            const SizedBox(height: 14),
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

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
      ],
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surfaceSunken),
          columns: [
            for (final h in table.headers) DataColumn(label: Text(h)),
          ],
          rows: [
            for (final row in table.rows)
              DataRow(
                color: row.isNotEmpty && row.first == 'TOTAL'
                    ? WidgetStateProperty.all(AppColors.brandTint)
                    : null,
                cells: [
                  for (final cell in row)
                    DataCell(
                      Text(
                        cell,
                        style: row.isNotEmpty && row.first == 'TOTAL'
                            ? const TextStyle(fontWeight: FontWeight.w700)
                            : null,
                      ),
                    ),
                ],
              ),
          ],
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
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              downloadText(buildCsv(table), csvFileName(table.title),
                  'text/csv;charset=utf-8'),
          icon: const Icon(Icons.table_view_outlined, size: 18),
          label: const Text('Exportar CSV'),
        ),
        FilledButton.icon(
          onPressed: () => Printing.layoutPdf(
            onLayout: (format) => buildReportPdf(
              table,
              format,
              company: company,
              periodLabel: period,
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Exportar PDF'),
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
    final days = report.byDay;
    if (days.isEmpty) return const SizedBox.shrink();
    final maxY = days
        .map((d) => d.revenue.toDouble())
        .fold<double>(0, (a, b) => b > a ? b : a);

    return _ChartCard(
      title: 'Evolução do faturamento',
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: const FlGridData(show: false),
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
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: days[i].revenue.toDouble(),
                    color: AppColors.brand,
                    width: days.length > 20 ? 4 : 10,
                    borderRadius: BorderRadius.circular(3),
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
    final rows = report.rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxY = rows
        .map((r) => r.revenue.toDouble())
        .fold<double>(0, (a, b) => b > a ? b : a);

    return _ChartCard(
      title: 'Faturamento por responsável',
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          gridData: const FlGridData(show: false),
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
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < rows.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: rows[i].revenue.toDouble(),
                    color: AppColors.graphite,
                    width: 16,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: child),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 28),
          const SizedBox(height: 10),
          Text('Não foi possível carregar o relatório.',
              style: TextStyle(color: AppColors.inkMuted)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Text(message, style: TextStyle(color: AppColors.inkMuted)),
    );
  }
}
