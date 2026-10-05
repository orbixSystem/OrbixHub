import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../../core/pdf/document_company.dart';
import '../../../core/util/cnpj.dart';
import '../../../di.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/session_state.dart';
import '../../dashboard/presentation/widgets/metric_card.dart'
    show formatMoney, MetricLoading;
import '../../os/presentation/os_status.dart'
    show osStatuses, osStatusLabel, OsStatusChip;
import '../../cashier/domain/cashier_format.dart' show methodLabel;
import '../domain/report_models.dart';
import 'widgets/charts/barras_por_dia.dart';
import 'widgets/charts/donut_card.dart';
import 'widgets/charts/ranking_barras.dart';
import '../domain/report_repository.dart';
import 'report_catalog.dart';
import 'report_tabs.dart';
import 'tabs/caixa_tab.dart';
import 'tabs/clientes_tab.dart';
import 'tabs/equipe_tab.dart';
import 'tabs/estoque_tab.dart';
import 'tabs/despesas_tab.dart';
import 'tabs/faturamento_tab.dart';
import 'tabs/ordens_tab.dart';
import 'tabs/resumo_tab.dart';
import 'tabs/visao_tab.dart';
import 'report_csv.dart';
import '../../../core/export/file_download.dart';
import 'report_pdf.dart';
import 'report_xlsx.dart';
import 'customers_ranking_card.dart';
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
    final me = session.meOrNull;
    if (me == null) {
      return const Center(child: MetricLoading());
    }
    // Relatórios são agregações calculadas no servidor — sem conexão não há
    // como gerá-los (nem exportar).
    if (ref.watch(isOfflineProvider)) {
      return const RequiresConnectionView(
        message:
            'Os relatórios são calculados no servidor. Conecte-se à '
            'internet para gerá-los e exportá-los.',
      );
    }

    final abas = abasDisponiveis(me);
    if (abas.isEmpty) {
      return const _Empty(
        message: 'Nenhum relatório disponível para o seu acesso.',
      );
    }
    final selecionada = ref.watch(selectedTabProvider);
    final aba = abas.firstWhere(
      (a) => a.tab == selecionada,
      orElse: () => abas.first,
    );
    final isMobile = context.isMobile;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 16 : 24,
        isMobile ? 16 : 24,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Cabecalho(aba: aba.tab),
          const SizedBox(height: 16),
          CoachTarget(
            'relatorios.picker',
            child: _AbasBar(abas: abas, selecionada: aba.tab),
          ),
          const SizedBox(height: 20),
          CoachTarget(
            'relatorios.conteudo',
            child: switch (aba.tab) {
              // As duas primeiras abas não são coleções de relatórios: são a
              // leitura do mês — uma em palavras, a outra em gráficos.
              ReportTab.resumo => const ResumoTab(),
              ReportTab.visao => const VisaoTab(),
              _ => _SecoesDaAba(me: me, aba: aba),
            },
          ),
        ],
      ),
    );
  }
}

/// Título + seletor de mês. O mês só aparece na Visão: as outras abas têm os
/// próprios filtros de período, contextuais a cada relatório, e dois seletores
/// de tempo na mesma tela seriam dois jeitos de responder "quando".
class _Cabecalho extends ConsumerWidget {
  const _Cabecalho({required this.aba});

  final ReportTab aba;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Relatórios', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          switch (aba) {
            ReportTab.resumo =>
              'A leitura escrita do mês: o que aconteceu e o que fazer agora.',
            ReportTab.visao =>
              'O mesmo mês em gráficos, um de cada assunto.',
            _ => 'Detalhamento por assunto, com exportação.',
          },
          style: TextStyle(color: neu.inkMuted),
        ),
      ],
    );
    // O seletor de mês aparece em TODAS as abas, porque agora ele governa
    // todas. Escondê-lo fora da Visão deixaria o usuário vendo números de
    // setembro numa aba sem nada na tela dizendo que o mês é setembro — nem
    // como trocá-lo sem voltar.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [titulo, const _SeletorDeMes()],
    );
  }
}

/// Escolhe o mês analisado. Meses FECHADOS mais o corrente — a leitura mensal
/// compara com o mês anterior, e um intervalo solto ("últimos 30 dias") não tem
/// mês anterior com que se comparar.
class _SeletorDeMes extends ConsumerWidget {
  const _SeletorDeMes();

  static const _nomes = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  /// Os últimos 12 meses, do corrente para trás.
  List<({String? valor, String rotulo})> _opcoes() {
    final hoje = DateTime.now();
    return [
      (valor: null, rotulo: 'Mês atual'),
      for (var i = 1; i <= 11; i++)
        () {
          final d = DateTime(hoje.year, hoje.month - i, 1);
          final mm = d.month.toString().padLeft(2, '0');
          return (
            valor: '${d.year}-$mm',
            rotulo: '${_nomes[d.month - 1]}/${d.year}',
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final atual = ref.watch(mesSelecionadoProvider);
    final opcoes = _opcoes();
    final rotulo = opcoes
        .firstWhere((o) => o.valor == atual, orElse: () => opcoes.first)
        .rotulo;

    return PopupMenuButton<String?>(
      tooltip: 'Escolher o mês',
      color: neu.surface,
      position: PopupMenuPosition.under,
      onSelected: (v) =>
          ref.read(mesSelecionadoProvider.notifier).select(v),
      itemBuilder: (_) => [
        for (final o in opcoes)
          PopupMenuItem(
            value: o.valor,
            child: Text(
              o.rotulo,
              style: TextStyle(
                color: neu.ink,
                fontSize: 14,
                fontWeight:
                    o.valor == atual ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
      ],
      child: NeuSurface(
        elevation: NeuElevation.raised,
        radius: NeuTokens.rChip,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 16, color: neu.inkMuted),
            const SizedBox(width: 8),
            Text(
              rotulo,
              style: TextStyle(
                color: neu.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: neu.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// As abas, no topo. Rolam na horizontal quando não cabem — no celular são
/// quatro, e espremê-las deixaria os rótulos ilegíveis.
class _AbasBar extends ConsumerWidget {
  const _AbasBar({required this.abas, required this.selecionada});

  final List<ReportTabSpec> abas;
  final ReportTab selecionada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final a in abas)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _AbaChip(
                spec: a,
                ativa: a.tab == selecionada,
                onTap: () =>
                    ref.read(selectedTabProvider.notifier).select(a.tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _AbaChip extends StatelessWidget {
  const _AbaChip({
    required this.spec,
    required this.ativa,
    required this.onTap,
  });

  final ReportTabSpec spec;
  final bool ativa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: ativa ? neu.navy : Colors.transparent,
          border: Border.all(color: ativa ? neu.navy : neu.line),
          borderRadius: BorderRadius.circular(NeuTokens.rChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              spec.icon,
              size: 16,
              color: ativa ? neu.onNavy : neu.inkMuted,
            ),
            const SizedBox(width: 8),
            Text(
              spec.label,
              style: TextStyle(
                color: ativa ? neu.onNavy : neu.inkMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Os relatórios de uma aba, empilhados com o próprio título.
///
/// Só a TABELA e a exportação: os números de resumo e os gráficos que antes
/// vinham aqui agora moram no painel, logo acima. Mostrar a mesma rosca duas
/// vezes na mesma rolagem não é reforço, é ruído — e faz o dono procurar a
/// diferença entre dois desenhos idênticos.
///
/// Empilhar em vez de pedir outra escolha: dentro de "Dinheiro" são três
/// lentes do mesmo assunto, e rolar é mais barato que decidir.
class _SecoesDaAba extends StatelessWidget {
  const _SecoesDaAba({required this.me, required this.aba});

  final Me me;
  final ReportTabSpec aba;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final specs = availableReports(me)
        .where((r) => aba.secoes.contains(r.kind))
        .toList()
      ..sort((a, b) =>
          aba.secoes.indexOf(a.kind).compareTo(aba.secoes.indexOf(b.kind)));

    // O painel da aba vem ANTES do detalhamento: a pergunta ("como foi o
    // faturamento?") se responde de um olhar, e a tabela fica para quem
    // precisa da linha exata. Abrir pela tabela obrigava a somar de cabeça.
    final painel = _painelDaAba(aba.tab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (painel != null) ...[
          painel,
          const SizedBox(height: 28),
          Divider(color: neu.line, height: 1),
          const SizedBox(height: 24),
        ],
        for (var i = 0; i < specs.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 28),
            Divider(color: neu.line, height: 1),
            const SizedBox(height: 24),
          ],
          // SEM cabeçalho de seção: cada aba tem um relatório só, e ele já traz
          // o próprio título junto dos botões de exportação. Dois títulos
          // seguidos dizendo a mesma coisa ("Despesas · Por categoria" e
          // "Despesas por categoria") é ruído que o olho precisa descartar
          // antes de chegar ao conteúdo.
          _ReportContent(me: me, spec: specs[i]),
        ],
      ],
    );
  }
}

/// O painel denso de cada aba, quando ela tem um.
///
/// `null` significa "esta aba ainda abre pelo detalhamento" — e não um painel
/// vazio, que pareceria defeito.
Widget? _painelDaAba(ReportTab aba) => switch (aba) {
      ReportTab.faturamento => const PainelDeFaturamento(),
      ReportTab.caixa => const PainelDeCaixa(),
      ReportTab.despesas => const PainelDeDespesas(),
      ReportTab.ordens => const PainelDeOrdens(),
      ReportTab.equipe => const PainelDeEquipe(),
      ReportTab.clientes => const PainelDeClientes(),
      ReportTab.estoque => const PainelDeEstoque(),
      _ => null,
    };

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
    // O período NÃO é mais escolhido aqui: quem manda é o seletor de mês do
    // cabeçalho, e ele governa todas as abas. Dois controles de tempo na mesma
    // tela faziam o cabeçalho dizer "Setembro" enquanto a aba mostrava os
    // últimos 30 dias — números diferentes para a mesma pergunta, sem nada que
    // dissesse qual valia.
    final filters = ref.watch(reportFiltersProvider);

    final member = _MemberFilter(
      value: filters.assignedTo,
      onChanged: (v) =>
          ref.read(reportFiltersProvider.notifier).setAssignedTo(v),
    );
    final status = _StatusFilter(
      value: filters.status,
      onChanged: (v) => ref.read(reportFiltersProvider.notifier).setStatus(v),
    );
    final kindFilter = _KindFilter(
      value: filters.kind,
      onChanged: (v) => ref.read(reportFiltersProvider.notifier).setKind(v),
    );
    final limitFilter = _LimitFilter(
      value: filters.limit,
      onChanged: (v) => ref.read(reportFiltersProvider.notifier).setLimit(v),
    );

    // Mobile: os campos pareados em 2 colunas, sem itens soltos empilhados
    // com muito respiro.
    if (context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kind == ReportKind.osOperational) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: member),
                const SizedBox(width: 12),
                Expanded(child: status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: _OsSearchField()),
                const SizedBox(width: 12),
                const _OsSortMenu(),
              ],
            ),
          ],
          if (kind == ReportKind.topItems) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: kindFilter),
                const SizedBox(width: 12),
                Expanded(child: limitFilter),
              ],
            ),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (kind == ReportKind.osOperational) ...[
          member,
          status,
          const _OsSearchField(),
          const _OsSortMenu(),
        ],
        if (kind == ReportKind.topItems) ...[kindFilter, limitFilter],
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
            const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
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
        decoration: const InputDecoration(labelText: 'Status', isDense: true),
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
        decoration: const InputDecoration(labelText: 'Tipo', isDense: true),
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
        decoration: const InputDecoration(labelText: 'Top', isDense: true),
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

  /// Empresa do cabeçalho: Configurações › Empresa (com logo, endereço e
  /// contato) — a MESMA fonte dos outros documentos. Enquanto ela não carrega,
  /// ou se falhar, cai nos dados do tenant: o relatório sai com menos dados no
  /// topo em vez de não sair.
  DocumentCompany? _company(WidgetRef ref) {
    final completa = ref.watch(companyForDocumentsProvider).value;
    if (completa != null) return completa;
    final t = me.activeTenant;
    if (t == null) return null;
    return DocumentCompany(
      name: t.name,
      legalName: t.legalName,
      cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
    );
  }

  String _periodLabel(WidgetRef ref) {
    final r = ref.read(reportRangeProvider);
    // Hífen simples, não meia-risca (U+2013): a Helvetica embutida no PDF não
    // desenha o caractere e o período saía com um BURACO entre as datas.
    return '${fmtDate(r.fromIso)} a ${fmtDate(r.toIso)}';
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
          company: _company(ref),
          period: _periodLabel(ref),
        );
      case ReportKind.revenue:
        return _AsyncReport(
          async: ref.watch(revenueReportProvider),
          retry: () => ref.invalidate(revenueReportProvider),
          tableOf: revenueTable,
          isEmpty: (r) => r.byDay.isEmpty,
          company: _company(ref),
          period: _periodLabel(ref),
        );
      case ReportKind.team:
        return _AsyncReport(
          async: ref.watch(teamReportProvider),
          retry: () => ref.invalidate(teamReportProvider),
          tableOf: (r) => teamTable(r, memberNames),
          isEmpty: (r) => r.rows.isEmpty,
          company: _company(ref),
          period: _periodLabel(ref),
        );
      case ReportKind.topItems:
        return _AsyncReport(
          async: ref.watch(topItemsReportProvider),
          retry: () => ref.invalidate(topItemsReportProvider),
          tableOf: topItemsTable,
          isEmpty: (r) => r.rows.isEmpty,
          company: _company(ref),
          period: _periodLabel(ref),
        );
      case ReportKind.inventoryPosition:
        // Estoque pode ter milhares de itens → paginado na tela; export (CSV/PDF
        // do relatório COMPLETO) é gerado no servidor. Caso dedicado (não o
        // genérico, que monta tudo em memória).
        return _InventoryReport(company: _company(ref));
      case ReportKind.expenses:
        // Sem gráfico, como o relatório de Caixa: a pergunta ("para onde vai o
        // dinheiro") é respondida pela ORDEM da tabela, que já vem do servidor
        // com o maior gasto primeiro. O resumo em cima dá o fechamento do período.
        return _AsyncReport(
          async: ref.watch(expensesReportProvider),
          retry: () => ref.invalidate(expensesReportProvider),
          tableOf: expensesTable,
          isEmpty: (r) => r.rows.isEmpty,
          // "Para onde vai o dinheiro" é uma pergunta de COMPOSIÇÃO, e é
          // exatamente o que um donut responde de um olhar. A tabela continua
          // embaixo, ordenada pelo maior gasto, para quem precisa do número.
          company: _company(ref),
          period: _periodLabel(ref),
        );
      case ReportKind.cashFlow:
        return _CashFlowReport(
          company: _company(ref),
          period: _periodLabel(ref),
        );
      case ReportKind.customers:
        // Clientes pode ter milhares de linhas no período → lista PAGINADA
        // (scroll infinito, render leve), como a OS operacional. O gráfico usa a
        // série agregada no servidor (independe da página); export (CSV/PDF do
        // relatório COMPLETO) é gerado no servidor.
        return _CustomersReport(company: _company(ref));
    }
  }
}

class _AsyncReport<T> extends StatelessWidget {
  const _AsyncReport({
    required this.async,
    required this.retry,
    required this.tableOf,
    required this.isEmpty,
    required this.company,
    required this.period,
  });

  final AsyncValue<T> async;
  final VoidCallback retry;
  final ReportTable Function(T) tableOf;
  final bool Function(T) isEmpty;
  final DocumentCompany? company;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // `Expanded` no título: num `Wrap`, `spaceBetween` não empurra nada,
                // porque ele se dimensiona pelo conteúdo — os botões ficavam
                // colados no título em vez de na borda do card.
                Expanded(child: Text(
                  table.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),),
                const SizedBox(width: 16),
                _ExportButtons(table: table, company: company, period: period),
              ],
            ),
            const SizedBox(height: 18),
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

  final DocumentCompany? company;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // `Expanded` no título: num `Wrap`, `spaceBetween` não empurra nada,
                // porque ele se dimensiona pelo conteúdo — os botões ficavam
                // colados no título em vez de na borda do card.
                Expanded(child: Text(
                  'Posição de estoque',
                  style: Theme.of(context).textTheme.titleLarge,
                ),),
                const SizedBox(width: 16),
                _ServerExportButtons(company: company),
              ],
            ),
            const SizedBox(height: 18),
            _SummaryStat(
              label: 'Valor em estoque',
              value: formatMoney(data.stockValue),
            ),
            const SizedBox(height: 18),
            if (empty)
              const _Empty(message: 'Sem itens em estoque.')
            else ...[
              // Onde o dinheiro está parado. Uma tabela de centenas de itens
              // não responde "o que concentra meu capital" — e é por aí que se
              // começa quando falta caixa.
              RankingBarras(
                titulo: 'Maior valor parado',
                total: formatMoney(data.stockValue),
                vazio: 'Nenhum item com valor em estoque.',
                itens: [
                  for (final r in data.rows)
                    BarraRanking(
                      rotulo: r.name,
                      valor: r.stockValue.toDouble(),
                      texto: formatMoney(r.stockValue),
                      detalhe: r.belowMin
                          ? 'abaixo do mínimo · ${r.currentStock} em estoque'
                          : '${r.currentStock} em estoque',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _DataTableCard(table: inventoryTable(data, includeTotal: false)),
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

  final DocumentCompany? company;

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
            content: Text('Não foi possível gerar o arquivo. Tente novamente.'),
          ),
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
      downloadBytes(bytes, 'posicao-de-estoque.csv', 'text/csv;charset=utf-8');
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
    if (context.isMobile) {
      final busy = _csvBusy || _pdfBusy;
      return NeuButton(
        label: 'Exportar',
        icon: Icons.file_download_outlined,
        loading: busy,
        onPressed: busy
            ? null
            : () => _showExportSheet(
                context,
                options: [
                  _ExportOption(
                    label: 'Exportar CSV',
                    icon: Icons.table_view_outlined,
                    onTap: _csv,
                  ),
                  _ExportOption(
                    label: 'Exportar PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: _pdf,
                  ),
                ],
              ),
      );
    }

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

/// Export do relatório de OS gerado no SERVIDOR (CSV/PDF do relatório COMPLETO,
/// respeitando os filtros ativos — período/técnico/status/busca/ordenação), não
/// só as linhas já roladas na tela. Spinner enquanto gera + SnackBar em erro.
class _OsExportButtons extends ConsumerStatefulWidget {
  const _OsExportButtons({required this.company});

  final DocumentCompany? company;

  @override
  ConsumerState<_OsExportButtons> createState() => _OsExportButtonsState();
}

class _OsExportButtonsState extends ConsumerState<_OsExportButtons> {
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
            content: Text('Não foi possível gerar o arquivo. Tente novamente.'),
          ),
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
      final f = ref.read(reportFiltersProvider);
      final bytes = await ref
          .read(reportRepositoryProvider)
          .osCsv(
            range: ref.read(reportRangeProvider),
            assignedTo: f.assignedTo,
            status: f.status,
            q: f.osQ,
            sort: f.osSort.key,
          );
      downloadBytes(bytes, 'os-operacional.csv', 'text/csv;charset=utf-8');
    },
  );

  Future<void> _pdf() => _run(
    isPdf: true,
    task: () async {
      final f = ref.read(reportFiltersProvider);
      final bytes = await ref
          .read(reportRepositoryProvider)
          .osPdf(
            range: ref.read(reportRangeProvider),
            assignedTo: f.assignedTo,
            status: f.status,
            q: f.osQ,
            sort: f.osSort.key,
            company: _exportCompany(),
          );
      downloadBytes(bytes, 'os-operacional.pdf', 'application/pdf');
    },
  );

  @override
  Widget build(BuildContext context) {
    const compact = Size(0, 40);
    const pad = EdgeInsets.symmetric(horizontal: 16);
    Widget spinner() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
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

class _CashFlowReport extends ConsumerWidget {
  const _CashFlowReport({required this.company, required this.period});
  final DocumentCompany? company;
  final String? period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashierRecebidoReportProvider);
    return async.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) => _ErrorBox(
        onRetry: () => ref.invalidate(cashierRecebidoReportProvider),
      ),
      data: (s) {
        final table = cashFlowTable(s);
        final empty = s.byMethod.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // `Expanded` no título: num `Wrap`, `spaceBetween` não empurra nada,
                // porque ele se dimensiona pelo conteúdo — os botões ficavam
                // colados no título em vez de na borda do card.
                Expanded(child: Text(
                  'Caixa — recebido por forma',
                  style: Theme.of(context).textTheme.titleLarge,
                ),),
                const SizedBox(width: 16),
                _ExportButtons(table: table, company: company, period: period),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'O que passou pelo caixa no período (recebido — não é faturamento).',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _SummaryStat(label: 'Recebido', value: formatMoney(s.totalIn)),
                _SummaryStat(label: 'Saídas', value: formatMoney(s.totalOut)),
                _SummaryStat(label: 'Saldo', value: formatMoney(s.net)),
              ],
            ),
            const SizedBox(height: 18),
            if (empty)
              const _Empty(message: 'Sem movimento no período.')
            else ...[
              // De que é feito o "recebido". A tabela abaixo tem os mesmos
              // números, mas responder "quase tudo é pix" exige comparar linha
              // por linha nela — e é a primeira pergunta que o dono faz.
              DonutCard(
                titulo: 'Como o dinheiro entrou',
                total: formatMoney(s.totalIn),
                vazio: 'Nenhuma entrada no período.',
                fatias: [
                  for (final m in s.byMethod)
                    FatiaDonut(
                      rotulo: methodLabel(m.method),
                      valor: m.inAmount.toDouble(),
                      texto: formatMoney(m.inAmount),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _DataTableCard(table: table),
            ],
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
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: neu.ink),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// --- Ordenação de tabela (heurística por conteúdo das células) ---------------

/// Tipo de coluna inferido do conteúdo (para alinhar/ordenar corretamente).
enum _ColType { number, date, text }

bool _isTotalRow(List<String> r) => r.isNotEmpty && r.first == 'TOTAL';

bool _isEmptyCell(String s) {
  final t = s.trim();
  return t.isEmpty || t == '—';
}

final _dateRe = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

/// Converte uma célula BR/moeda/qtd/ciclo em número ("R\$ 1.625,02" → 1625.02,
/// "3,4h" → 3.4, "40%" → 40). Retorna null se não for numérica.
double? _parseBrNumber(String raw) {
  var s = raw.replaceAll(RegExp(r'(R\$|\s|%)'), '');
  s = s.replaceAll(RegExp(r'[a-zA-Z]+$'), ''); // unidade do ciclo (h/d)
  if (s.isEmpty || !RegExp(r'^-?[\d.,]+$').hasMatch(s)) return null;
  s = s.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(s);
}

/// Chave numérica de ordenação (número, ou ms da data). Null → vai pro fim.
double? _numKey(String s, _ColType type) {
  if (_isEmptyCell(s)) return null;
  if (type == _ColType.date) {
    final m = _dateRe.firstMatch(s.trim());
    if (m == null) return null;
    return DateTime(
      int.parse(m[3]!),
      int.parse(m[2]!),
      int.parse(m[1]!),
    ).millisecondsSinceEpoch.toDouble();
  }
  return _parseBrNumber(s);
}

/// Infere o tipo de uma coluna a partir das células de dados (ignora TOTAL).
_ColType _colType(ReportTable t, int col) {
  var numeric = 0, date = 0, seen = 0;
  for (final r in t.rows) {
    if (_isTotalRow(r) || col >= r.length) continue;
    final s = r[col].trim();
    if (_isEmptyCell(s)) continue;
    seen++;
    if (_dateRe.hasMatch(s)) {
      date++;
    } else if (_parseBrNumber(s) != null) {
      numeric++;
    }
  }
  if (seen == 0) return _ColType.text;
  if (date >= seen * 0.6) return _ColType.date;
  if (numeric >= seen * 0.6) return _ColType.number;
  return _ColType.text;
}

/// Tabela responsiva: DataTable ordenável (desktop) ou lista de cards (mobile).
/// A linha de total (rótulo 'TOTAL') fica sempre fixada no fim e destacada.
class _DataTableCard extends StatefulWidget {
  const _DataTableCard({required this.table});
  final ReportTable table;

  @override
  State<_DataTableCard> createState() => _DataTableCardState();
}

class _DataTableCardState extends State<_DataTableCard> {
  /// Controlador PRÓPRIO da rolagem vertical da tabela. Sem ele, a barra e a
  /// lista podem acabar presas ao scroll da página, e o gesto vai parar no
  /// lugar errado.
  final _vertical = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  int? _sortCol;
  bool _asc = true;

  int _cmp(List<String> a, List<String> b, int col, _ColType type) {
    final av = col < a.length ? a[col] : '';
    final bv = col < b.length ? b[col] : '';
    final aEmpty = _isEmptyCell(av);
    final bEmpty = _isEmptyCell(bv);
    // Vazios ("—") sempre no fim, independente da direção.
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return 1;
    if (bEmpty) return -1;
    int r;
    if (type == _ColType.text) {
      r = av.toLowerCase().compareTo(bv.toLowerCase());
    } else {
      r = (_numKey(av, type) ?? 0).compareTo(_numKey(bv, type) ?? 0);
    }
    return _asc ? r : -r;
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    if (context.isMobile) return _MobileTableCards(table: table);

    final neu = context.neu;
    final headers = table.headers;
    final types = [for (var c = 0; c < headers.length; c++) _colType(table, c)];
    final dataRows = [
      for (final r in table.rows)
        if (!_isTotalRow(r)) r,
    ];
    final totalRows = [
      for (final r in table.rows)
        if (_isTotalRow(r)) r,
    ];
    if (_sortCol != null && _sortCol! < headers.length) {
      dataRows.sort((a, b) => _cmp(a, b, _sortCol!, types[_sortCol!]));
    }
    final ordered = [...dataRows, ...totalRows];

    // Tabela longa rola DENTRO do card, com barra sempre visível.
    //
    // Sem teto, um relatório de 240 linhas empurra a página por três telas e
    // tudo que vem depois (outros gráficos, o rodapé) fica inalcançável na
    // prática. Com teto e SEM barra visível seria pior ainda: pareceria que a
    // tabela acaba ali. Por isso `thumbVisibility` e a contagem no rodapé.
    final longa = ordered.length > 12;

    // Ocupa a largura toda do card: força a DataTable a no mínimo a largura
    // disponível (ela distribui o excedente entre as colunas); rola na
    // horizontal só se o conteúdo passar da tela.
    final Widget tabela = LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                sortColumnIndex: _sortCol,
                sortAscending: _asc,
                headingRowColor: WidgetStateProperty.all(neu.surfaceHi),
                headingTextStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: neu.inkMuted,
                  letterSpacing: 0.2,
                ),
                dataTextStyle: TextStyle(fontSize: 14, color: neu.ink),
                dividerThickness: 0.5,
                columns: [
                  for (var c = 0; c < headers.length; c++)
                    DataColumn(
                      label: Text(headers[c]),
                      numeric: types[c] == _ColType.number,
                      onSort: (i, asc) => setState(() {
                        _sortCol = i;
                        _asc = asc;
                      }),
                    ),
                ],
                rows: [
                  for (var i = 0; i < ordered.length; i++)
                    () {
                      final row = ordered[i];
                      final total = _isTotalRow(row);
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

    return NeuCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (longa)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: Scrollbar(
                  controller: _vertical,
                  // Barra SEMPRE visível: a lição do cronograma de parcelas —
                  // uma lista cortada por uma borda invisível parece completa,
                  // e o conteúdo some sem avisar.
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vertical,
                    primary: false,
                    child: tabela,
                  ),
                ),
              )
            else
              tabela,
            if (longa)
              Container(
                width: double.infinity,
                color: neu.surfaceHi,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  '${ordered.length} linhas — role dentro da tabela para ver todas',
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lista de cards compactos (mobile): 1ª coluna vira título; demais colunas
/// viram pares rótulo→valor. A linha de total ganha um card destacado.
class _MobileTableCards extends StatelessWidget {
  const _MobileTableCards({required this.table});
  final ReportTable table;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final headers = table.headers;
    final rows = table.rows;

    final cards = <Widget>[];
    for (final row in rows) {
      final total = _isTotalRow(row);
      if (total) {
        // Card de total: label→valor das colunas preenchidas (fora a 1ª).
        final pairs = <(String, String)>[
          for (var c = 1; c < row.length && c < headers.length; c++)
            if (!_isEmptyCell(row[c])) (headers[c], row[c]),
        ];
        cards.add(
          NeuCard(
            color: neu.accentTint,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: neu.navy,
                  ),
                ),
                const Spacer(),
                for (final p in pairs) ...[
                  Text(
                    '${p.$1}: ',
                    style: TextStyle(color: neu.inkMuted, fontSize: 14),
                  ),
                  Text(
                    p.$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: neu.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        );
        continue;
      }
      cards.add(
        NeuCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.isNotEmpty ? row.first : '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: neu.ink),
              ),
              const SizedBox(height: 8),
              for (var c = 1; c < row.length && c < headers.length; c++)
                if (!_isEmptyCell(row[c]))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            headers[c],
                            style: TextStyle(color: neu.inkMuted, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            row[c],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: neu.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cards[i],
        ],
      ],
    );
  }
}

/// Uma opção do menu de export (bottom sheet do mobile).
class _ExportOption {
  const _ExportOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Bottom sheet padrão do app (mesma "pega" e cantos do menu do shell) com as
/// opções de export. Usado no mobile para não empilhar 3 botões grandes.
void _showExportSheet(
  BuildContext context, {
  required List<_ExportOption> options,
}) {
  final neu = context.neu;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: neu.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: neu.inkFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Exportar relatório',
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuListTile(
                  leading: Icon(o.icon, color: neu.inkMuted, size: 22),
                  title: Text(o.label),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    o.onTap();
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Export do relatório: CSV (browser), Excel e PDF (Printing). No desktop são 3
/// botões; no mobile viram um único "Exportar" que abre um bottom sheet com as
/// 3 opções (economiza espaço vertical).
class _ExportButtons extends StatelessWidget {
  const _ExportButtons({
    required this.table,
    required this.company,
    required this.period,
  });

  final ReportTable table;
  final DocumentCompany? company;
  final String? period;

  void _csv() => downloadText(
    buildCsv(table),
    csvFileName(table.title),
    'text/csv;charset=utf-8',
  );

  void _excel() => downloadBytes(
    buildXlsx(table, company: company?.name, period: period),
    xlsxFileName(table.title),
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  void _pdf() => Printing.layoutPdf(
    onLayout: (format) =>
        buildReportPdf(table, format, company: company, periodLabel: period),
  );

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return NeuButton(
        label: 'Exportar',
        icon: Icons.file_download_outlined,
        onPressed: () => _showExportSheet(
          context,
          options: [
            _ExportOption(
              label: 'Exportar CSV',
              icon: Icons.table_view_outlined,
              onTap: _csv,
            ),
            _ExportOption(
              label: 'Exportar Excel',
              icon: Icons.grid_on_outlined,
              onTap: _excel,
            ),
            _ExportOption(
              label: 'Exportar PDF',
              icon: Icons.picture_as_pdf_outlined,
              onTap: _pdf,
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NeuButton(
          label: 'Exportar CSV',
          kind: NeuButtonKind.secondary,
          icon: Icons.table_view_outlined,
          onPressed: _csv,
        ),
        NeuButton(
          label: 'Exportar Excel',
          kind: NeuButtonKind.secondary,
          icon: Icons.grid_on_outlined,
          onPressed: _excel,
        ),
        NeuButton(
          label: 'Exportar PDF',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: _pdf,
        ),
      ],
    );
  }
}

/// Composição dos clientes novos no período por tipo (rosca PF × PJ) — aba
/// "Clientes". Parte-do-todo com legenda; cor por tipo (glyphs fixos).
/// Os dois gráficos de clientes, lado a lado no desktop.
///
/// A composição PF/PJ é um detalhe — informa, mas não muda o que se faz hoje —,
/// então fica num card pequeno. O que vale a área maior é a CHEGADA ao longo do
/// período: ela mostra se o movimento de clientes novos é constante ou se veio
/// de um pico (uma promoção, uma indicação) que não vai se repetir.
class _GraficosDeClientes extends StatelessWidget {
  const _GraficosDeClientes({required this.series});

  final List<CustomersSeriesPoint> series;

  @override
  Widget build(BuildContext context) {
    final chegada = _ChegadaDeClientes(series: series);
    final composicao = _ComposicaoDeClientes(series: series);
    if (context.isMobile) {
      return Column(
        children: [chegada, const SizedBox(height: 16), composicao],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: chegada),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: composicao),
      ],
    );
  }
}

/// Clientes novos por dia do período.
class _ChegadaDeClientes extends StatelessWidget {
  const _ChegadaDeClientes({required this.series});

  final List<CustomersSeriesPoint> series;

  @override
  Widget build(BuildContext context) {
    // A série vem quebrada por tipo; para a chegada só interessa o total do dia.
    final porDia = <String, int>{};
    for (final p in series) {
      porDia[p.day] = (porDia[p.day] ?? 0) + p.count;
    }
    final dias = porDia.keys.toList()..sort();
    final total = porDia.values.fold<int>(0, (a, b) => a + b);
    // Série CRONOLÓGICA, não ranking: quando todos os dias têm um cliente
    // novo, um ranking vira doze barras idênticas e não informa nada. Na linha
    // do tempo a mesma série responde o que se quer saber — se o movimento é
    // constante ou veio de um pico que não se repete.
    return BarrasPorDia(
      titulo: 'Quando os clientes novos chegaram',
      vazio: 'Nenhum cliente novo no período.',
      total: total == 1 ? '1 no mês' : '$total no mês',
      dias: [
        for (final d in dias)
          DiaDaSerie(
            dia: d,
            valor: porDia[d]!.toDouble(),
            texto: porDia[d] == 1 ? '1 cliente' : '${porDia[d]} clientes',
          ),
      ],
    );
  }
}

/// Pessoa física × pessoa jurídica entre os clientes novos.
class _ComposicaoDeClientes extends StatelessWidget {
  const _ComposicaoDeClientes({required this.series});

  final List<CustomersSeriesPoint> series;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    var pf = 0, pj = 0, outros = 0;
    for (final p in series) {
      // O servidor manda 'PF'/'PJ' em MAIÚSCULAS (é o que o CHECK da tabela
      // aceita). A comparação aqui era minúscula, então tudo caía em "Outros"
      // e o donut mostrava uma fatia só — parecia quebrado porque estava.
      switch (p.type.toUpperCase()) {
        case 'PF':
          pf += p.count;
        case 'PJ':
          pj += p.count;
        default:
          outros += p.count;
      }
    }
    final total = pf + pj + outros;
    return DonutCard(
      titulo: 'Pessoa física × jurídica',
      compacto: true,
      total: total > 0 ? '$total' : null,
      vazio: 'Nenhum cliente novo no período.',
      fatias: [
        FatiaDonut(
          rotulo: 'Pessoa física',
          valor: pf.toDouble(),
          texto: '$pf',
          cor: neu.glyphs[2],
        ),
        FatiaDonut(
          rotulo: 'Pessoa jurídica',
          valor: pj.toDouble(),
          texto: '$pj',
          cor: neu.glyphs[1],
        ),
        FatiaDonut(
          rotulo: 'Sem tipo',
          valor: outros.toDouble(),
          texto: '$outros',
          cor: neu.glyphs[4],
        ),
      ],
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
  final DocumentCompany? company;
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
        final empty = state.rows.isEmpty;
        final listHeight = (MediaQuery.of(context).size.height * 0.6).clamp(
          360.0,
          820.0,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // `Expanded` no título: num `Wrap`, `spaceBetween` não empurra nada,
                // porque ele se dimensiona pelo conteúdo — os botões ficavam
                // colados no título em vez de na borda do card.
                Expanded(child: Text(
                  'OS — Operacional',
                  style: Theme.of(context).textTheme.titleLarge,
                ),),
                const SizedBox(width: 16),
                _OsExportButtons(company: widget.company),
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
                  style: TextStyle(fontWeight: FontWeight.w700, color: neu.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 14),
                ),
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

/// Relatório de clientes: resumo (ativos/novos) + gráfico (série do servidor) +
/// lista PAGINADA com scroll infinito (render leve, um lote por vez) dentro de
/// um card de altura limitada — não monta milhares de linhas de uma vez.
/// Export (CSV/PDF do relatório COMPLETO) é gerado no servidor.
class _CustomersReport extends ConsumerStatefulWidget {
  const _CustomersReport({required this.company});

  final DocumentCompany? company;

  @override
  ConsumerState<_CustomersReport> createState() => _CustomersReportState();
}

class _CustomersReportState extends ConsumerState<_CustomersReport> {
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
      ref.read(customersReportListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customersReportListProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (e, _) =>
          _ErrorBox(onRetry: () => ref.invalidate(customersReportListProvider)),
      data: (state) {
        final empty = state.rows.isEmpty;
        final listHeight = (MediaQuery.of(context).size.height * 0.6).clamp(
          360.0,
          820.0,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              spacing: 16,
              children: [
                Text('Clientes', style: Theme.of(context).textTheme.titleLarge),
                _CustomersExportButtons(company: widget.company),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _SummaryStat(
                  label: 'Clientes ativos',
                  value: '${state.active}',
                ),
                _SummaryStat(
                  label: 'Novos no período',
                  value: '${state.newInRange}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!empty) ...[
              _GraficosDeClientes(series: state.series),
              const SizedBox(height: 18),
            ],
            // Melhores clientes: dinheiro e recorrência, lado a lado no
            // desktop e empilhados no celular. Fica ABAIXO do gráfico de novos
            // clientes de propósito — "quem entrou" é a pergunta do período,
            // "quem vale" é a que se leva embora.
            CustomersRankingCard(range: ref.watch(reportRangeProvider)),
            const SizedBox(height: 18),
            if (empty)
              const _Empty(message: 'Sem clientes novos no período.')
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
                          return _CustomerRowTile(row: state.rows[i]);
                        }
                        return _ListFooter(
                          loadingMore: state.loadingMore,
                          hasMore: state.hasMore,
                          total: state.total,
                          noun: 'cliente(s)',
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

/// Linha (tile) de um cliente no relatório: nome à esquerda; tipo + data de
/// cadastro à direita. Render leve (sem DataTable).
class _CustomerRowTile extends StatelessWidget {
  const _CustomerRowTile({required this.row});

  final CustomerReportRow row;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
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
                  row.name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: neu.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  customerTypeLabel(row.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fmtDate(row.createdAt),
            style: TextStyle(color: neu.inkMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Export do relatório de clientes gerado no SERVIDOR (CSV/PDF do relatório
/// COMPLETO do período), não só as linhas já roladas na tela. Espelha os botões
/// do relatório de OS. Spinner enquanto gera + SnackBar em erro.
class _CustomersExportButtons extends ConsumerStatefulWidget {
  const _CustomersExportButtons({required this.company});

  final DocumentCompany? company;

  @override
  ConsumerState<_CustomersExportButtons> createState() =>
      _CustomersExportButtonsState();
}

class _CustomersExportButtonsState
    extends ConsumerState<_CustomersExportButtons> {
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
            content: Text('Não foi possível gerar o arquivo. Tente novamente.'),
          ),
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
      final bytes = await ref
          .read(reportRepositoryProvider)
          .customersCsv(range: ref.read(reportRangeProvider));
      downloadBytes(bytes, 'clientes.csv', 'text/csv;charset=utf-8');
    },
  );

  Future<void> _pdf() => _run(
    isPdf: true,
    task: () async {
      final bytes = await ref
          .read(reportRepositoryProvider)
          .customersPdf(
            range: ref.read(reportRangeProvider),
            company: _exportCompany(),
          );
      downloadBytes(bytes, 'clientes.pdf', 'application/pdf');
    },
  );

  @override
  Widget build(BuildContext context) {
    const compact = Size(0, 40);
    const pad = EdgeInsets.symmetric(horizontal: 16);
    Widget spinner() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
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
            Text(
              value.label,
              style: TextStyle(fontWeight: FontWeight.w600, color: neu.ink),
            ),
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
      fontSize: 14,
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
