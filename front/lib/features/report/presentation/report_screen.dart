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
import '../domain/report_models.dart';
import '../domain/report_repository.dart';
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
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
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

    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: selected ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    final pageCount = report.pageSize <= 0
        ? 1
        : ((report.total + report.pageSize - 1) ~/ report.pageSize)
            .clamp(1, 1 << 30);
    final page = report.page.clamp(1, pageCount);
    final first =
        report.total == 0 ? 0 : (page - 1) * report.pageSize + 1;
    final last = (page * report.pageSize).clamp(0, report.total);

    void go(int p) => ref.read(inventoryPageProvider.notifier).set(p);

    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      spacing: 16,
      children: [
        Text('$first–$last de ${report.total} itens', style: muted),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: page > 1 ? () => go(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página $page de $pageCount', style: muted),
            IconButton(
              tooltip: 'Próxima página',
              onPressed: page < pageCount ? () => go(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
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
    const compact = Size(0, 40);
    const pad = EdgeInsets.symmetric(horizontal: 16);
    Widget spinner() => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _csvBusy ? null : _csv,
          style: OutlinedButton.styleFrom(minimumSize: compact, padding: pad),
          icon: _csvBusy
              ? spinner()
              : const Icon(Icons.table_view_outlined, size: 18),
          label: const Text('Exportar CSV'),
        ),
        FilledButton.icon(
          onPressed: _pdfBusy ? null : _pdf,
          style: FilledButton.styleFrom(minimumSize: compact, padding: pad),
          icon: _pdfBusy
              ? spinner()
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Exportar PDF'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12.5)),
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
    final scheme = Theme.of(context).colorScheme;
    bool isTotal(List<String> row) => row.isNotEmpty && row.first == 'TOTAL';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(scheme.surfaceContainerHigh),
          headingTextStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
          dataTextStyle: TextStyle(
            fontSize: 13.5,
            color: scheme.onSurface,
          ),
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
                        ? scheme.primary.withValues(alpha: 0.12)
                        : (i.isOdd
                            ? scheme.surfaceContainerHighest
                                .withValues(alpha: 0.4)
                            : null),
                  ),
                  cells: [
                    for (final cell in row)
                      DataCell(
                        Text(
                          cell,
                          style: total
                              ? TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
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
    // O tema global define minimumSize de altura cheia (Size.fromHeight(50)), o
    // que daria largura infinita aos botões e os esticaria/quebraria. Aqui forçamos
    // botões compactos do tamanho do conteúdo, lado a lado numa toolbar.
    const compact = Size(0, 40);
    const pad = EdgeInsets.symmetric(horizontal: 16);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              downloadText(buildCsv(table), csvFileName(table.title),
                  'text/csv;charset=utf-8'),
          style: OutlinedButton.styleFrom(minimumSize: compact, padding: pad),
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
          style: FilledButton.styleFrom(minimumSize: compact, padding: pad),
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
    final scheme = Theme.of(context).colorScheme;
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
                    color: scheme.primary,
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
    final scheme = Theme.of(context).colorScheme;
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
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant),
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
                    color: scheme.tertiary,
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 220,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 28),
          const SizedBox(height: 10),
          Text('Não foi possível carregar o relatório.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
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
      child: Text(message,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    final scheme = Theme.of(context).colorScheme;
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
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    controller: _scroll,
                    itemCount: state.rows.length + 1,
                    separatorBuilder: (_, i) => i >= state.rows.length - 1
                        ? const SizedBox.shrink()
                        : const Divider(height: 1),
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
    final scheme = Theme.of(context).colorScheme;
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                osStatusLabel(row.status),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney(row.total),
                style: const TextStyle(fontWeight: FontWeight.w700),
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
    final scheme = Theme.of(context).colorScheme;
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
                if (s == value)
                  Icon(Icons.check, size: 18, color: scheme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(value.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
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
      child: TextField(
        controller: _c,
        decoration: const InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.search, size: 20),
          hintText: 'Buscar nº ou cliente',
          border: OutlineInputBorder(),
        ),
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
