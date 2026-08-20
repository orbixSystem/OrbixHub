import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/os_models.dart';
import 'order_form_dialog.dart';
import 'os_providers.dart';
import 'os_quick_actions.dart';
import 'os_status.dart';
import 'payment_status.dart';

/// Lista de ordens de serviço — adaptativa (spec 2026-07-04):
/// desktop = linhas densas + paginação numerada; mobile = cards grandes +
/// pull-to-refresh + infinite scroll + FAB "Nova OS".
/// Corpo apenas — a moldura é do shell.
class OsListScreen extends ConsumerStatefulWidget {
  const OsListScreen({super.key});

  @override
  ConsumerState<OsListScreen> createState() => _OsListScreenState();
}

class _OsListScreenState extends ConsumerState<OsListScreen> {
  final _search = TextEditingController();
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
    _search.dispose();
    super.dispose();
  }

  /// Infinite scroll (mobile): dispara o próximo lote perto do fim.
  void _onScroll() {
    if (!_scroll.hasClients || !mounted || !context.isMobile) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(orderListProvider.notifier).loadMore();
    }
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission('os.write') ?? false;
  }

  Future<void> _create() async {
    final ok = await OrderFormDialog.show(context);
    if (ok is String) {
      ref.invalidate(orderListProvider);
      if (mounted) context.go('/m/os/$ok');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _canWrite();
    final isMobile = context.isMobile;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isMobile && canWrite)
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: context.neu.navy,
              foregroundColor: context.neu.onNavy,
              icon: const Icon(Icons.add),
              label: const Text('Nova OS'),
            )
          : null,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alvos marcados na _Toolbar e no _Body inteiros: os dois existem
            // em desktop E mobile (cada um monta seu layout por dentro), então o
            // holofote vale nos dois sem duplicar conteúdo de tutorial.
            CoachTarget(
              'os.filtros',
              child: _Toolbar(
                search: _search,
                canWrite: canWrite,
                onCreate: _create,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CoachTarget(
                'os.lista',
                child: _Body(
                  scroll: _scroll,
                  onCreate: _create,
                  canWrite: canWrite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de filtros/ações: busca cavada + status + ordenar + templates +
/// "Nova OS" (desktop; no mobile a criação vira FAB).
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.search,
    required this.canWrite,
    required this.onCreate,
  });

  final TextEditingController search;
  final bool canWrite;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(orderListQueryProvider);
    final notifier = ref.read(orderListQueryProvider.notifier);
    final isMobile = context.isMobile;

    // 4 chips (Todas + os 3 grupos simplificados) — os 7 chips de status real
    // sumiram junto com o stepper de 7 estados: "aquele monte de filtros que
    // não existem" na visão do usuário.
    final statusChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _StatusChip(
            label: 'Todas',
            selected: query.status == null,
            onTap: () => notifier.setStatus(null),
          ),
          for (final s in OsSimpleStatus.values)
            _StatusChip(
              label: osSimpleStatusLabel(s),
              selected: query.status == s,
              onTap: () => notifier.setStatus(s),
            ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: NeuSearchBar(
                  hint: 'Buscar nº ou cliente',
                  controller: search,
                  onChanged: notifier.setQuery,
                ),
              ),
              const SizedBox(width: 10),
              _SortMenu(value: query.sort, onChanged: notifier.setSort),
            ],
          ),
          const SizedBox(height: 10),
          statusChips,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: NeuSearchBar(
                  hint: 'Buscar nº ou cliente',
                  controller: search,
                  onChanged: notifier.setQuery,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _SortMenu(value: query.sort, onChanged: notifier.setSort),
            if (canWrite) ...[
              const SizedBox(width: 12),
              NeuButton(
                label: 'Nova OS',
                icon: Icons.add_rounded,
                onPressed: onCreate,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        statusChips,
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? neu.navy : neu.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? null : neu.raised(),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? neu.onNavy : neu.inkMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.scroll,
    required this.onCreate,
    required this.canWrite,
  });

  final ScrollController scroll;
  final VoidCallback onCreate;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(orderListProvider);
    final isMobile = context.isMobile;

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e is AppException
                  ? e.message
                  : 'Erro ao carregar ordens de serviço.',
            ),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(orderListProvider),
            ),
          ],
        ),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return NeuEmptyState(
            icon: Icons.build_outlined,
            title: 'Nenhuma OS encontrada',
            message:
                'Crie uma ordem de serviço para registrar o trabalho de um veículo — orçamento, peças e progresso ficam todos aqui.',
            actionLabel: 'Criar primeira OS',
            onAction: onCreate,
          );
        }

        final list = ListView.separated(
          controller: scroll,
          padding: EdgeInsets.only(bottom: isMobile ? 88 : 8),
          itemCount: page.items.length + (isMobile ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (isMobile && i >= page.items.length) {
              return NeuListFooter(
                loading: page.loadingMore,
                hasMore: page.hasMore,
                total: page.total,
              );
            }
            final o = page.items[i];
            // Mobile ganha um card vertical grande (número em destaque, cliente/
            // veículo legíveis, rodapé com pagamento + valor); desktop usa a linha
            // densa. O tile denso apertava tudo numa Row só → número/cliente
            // viravam "…" e a cauda estourava.
            if (isMobile) {
              return _OrderCardMobile(
                order: o,
                canWrite: canWrite,
                onTap: () => context.go('/m/os/${o.id}'),
              );
            }
            return _OrderTile(
              order: o,
              canWrite: canWrite,
              dense: true,
              onTap: () => context.go('/m/os/${o.id}'),
            );
          },
        );

        if (isMobile) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orderListProvider),
            child: list,
          );
        }

        // Desktop: lista + controles de página numerados.
        return Column(
          children: [
            Expanded(child: list),
            const SizedBox(height: 12),
            NeuPageControls(
              page: page.page,
              pageSize: page.pageSize,
              total: page.total,
              onPage: (p) =>
                  ref.read(orderListProvider.notifier).goToPage(p),
            ),
          ],
        );
      },
    );
  }
}

/// Pill de status FORTE (fundo sólido na cor do grupo simplificado) — bem mais
/// visível que o tint suave do [OsStatusChip] antigo. É o "cores bem visíveis
/// com base no status" pedido pro card da lista.
/// Previsão do serviço no card: "10/08 → 15/08", ou só a ponta que existe.
///
/// Some quando a OS não tem previsão — um "—" ali seria uma linha inteira para
/// dizer nada. Quando o fim previsto já passou e a OS continua aberta, a linha
/// vira aviso de ATRASO: é o único jeito de a lista responder "o que está
/// estourando o prazo?" sem abrir OS por OS.
class _LinhaPrevisao extends StatelessWidget {
  const _LinhaPrevisao({required this.order});

  final ServiceOrder order;

  static String? _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ini = _fmt(order.scheduledStart);
    final fim = _fmt(order.scheduledEnd);
    if (ini == null && fim == null) return const SizedBox.shrink();

    // Atraso só faz sentido em OS viva: entregue/cancelada não estoura prazo.
    final fimData = DateTime.tryParse(order.scheduledEnd ?? '')?.toLocal();
    final aberta = !osIsTerminal(order.status);
    final atrasada =
        aberta && fimData != null && fimData.isBefore(DateTime.now());
    final cor = atrasada ? neu.danger : neu.inkFaint;

    final texto = ini != null && fim != null
        ? '$ini → $fim'
        : (ini != null ? 'Início $ini' : 'Entrega $fim');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            atrasada
                ? Icons.event_busy_outlined
                : Icons.event_outlined,
            size: 14,
            color: cor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              atrasada ? '$texto · atrasada' : texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cor,
                fontSize: 12.5,
                fontWeight: atrasada ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrongStatusPill extends StatelessWidget {
  const _StrongStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final simple = osSimpleStatusOf(status);
    // Fundo SÓLIDO com rótulo branco: a paleta gráfica não serve aqui (branco
    // sobre o verde #10B981 dá 2,5:1). A variante clara do matiz é escura o
    // bastante para o branco passar em ≥5,8:1 nos dois temas.
    final color = osSimpleStatusInk(simple, Brightness.light);
    return ConstrainedBox(
      // Cap explícito: sem ele, o rótulo mais longo do grupo simplificado
      // ("Em andamento") cresce mais que o chip antigo e rouba espaço demais
      // do título ao lado (nº da OS + selo de sync), que não tem como reagir.
      constraints: const BoxConstraints(maxWidth: 108),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(osSimpleStatusIcon(simple), size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                osSimpleStatusLabel(simple),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ações rápidas do card (Concluir/Cancelar/Exportar PDF) — a MESMA lógica de
/// transição do seletor da ficha (`os_quick_actions.dart`), só que num menu
/// compacto pra não competir por espaço no card. "Sem precisar entrar na
/// tela" — é o que o dono pediu.
class _QuickActionsMenu extends ConsumerWidget {
  const _QuickActionsMenu({required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podeConcluir = osSimpleTransitionEnabled(
      order,
      OsSimpleStatus.finalizada,
      canWrite: canWrite,
      canApprove: false,
    );
    final podeCancelar = osSimpleTransitionEnabled(
      order,
      OsSimpleStatus.cancelada,
      canWrite: canWrite,
      canApprove: false,
    );
    final podeVerPagamentos = canViewOsPayments(ref, order);
    return PopupMenuButton<String>(
      tooltip: 'Ações rápidas',
      // Sem padding próprio: no card/linha, cada pixel some do título junto
      // dela — o toque continua confortável (a área do PopupMenuButton some
      // com o InkResponse, não com este padding).
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onSelected: (action) async {
        switch (action) {
          case 'concluir':
            await runOsSimpleTransition(
              context,
              ref,
              order,
              OsSimpleStatus.finalizada,
            );
          case 'cancelar':
            await runOsSimpleTransition(
              context,
              ref,
              order,
              OsSimpleStatus.cancelada,
            );
          case 'pdf':
            await exportOsPdfById(context, ref, order.id);
          case 'pagamentos':
            await showOsPaymentsDialog(context, ref, order);
        }
      },
      itemBuilder: (_) => [
        if (podeConcluir)
          const PopupMenuItem(
            value: 'concluir',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline_rounded),
              title: Text('Concluir'),
            ),
          ),
        if (podeCancelar)
          PopupMenuItem(
            value: 'cancelar',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cancel_outlined, color: AppColors.danger),
              title: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        // Estado de reversão: mesmo já PAGA, o dono pode precisar estornar
        // (calote, lançamento errado) — devolve pra a receber/parcial.
        if (podeVerPagamentos)
          const PopupMenuItem(
            value: 'pagamentos',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('Pagamentos'),
            ),
          ),
        if (podeConcluir || podeCancelar || podeVerPagamentos)
          const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'pdf',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('Exportar PDF'),
          ),
        ),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.canWrite,
    required this.dense,
    required this.onTap,
  });

  final ServiceOrder order;
  final bool canWrite;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if ((order.customerName ?? '').isNotEmpty) order.customerName!,
      if ((order.subjectLabel ?? '').isNotEmpty) order.subjectLabel!,
    ].join(' · ');
    final color = osSimpleStatusColor(osSimpleStatusOf(order.status));
    return NeuListTile(
      dense: dense,
      onTap: onTap,
      // Ícone tingido na cor do status: "cores bem visíveis" já no primeiro
      // olhar, antes até de ler o pill.
      leading: Container(
        width: dense ? 40 : 44,
        height: dense ? 40 : 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.build_outlined,
            color: osStatusInk(order.status, Theme.of(context).brightness),
            size: 20),
      ),
      // OS criada offline (número provisório OS-P…) ganha o selo "pendente de
      // envio" — Wrap para não estourar o tile no mobile.
      title: isPendingOsNumber(order.number)
          ? Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(order.number),
                SyncRowBadge(
                  entity: 'service_order',
                  id: order.id,
                  dense: true,
                ),
              ],
            )
          : Text(order.number),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaymentTag(status: order.paymentStatus, dense: true),
          const SizedBox(width: 8),
          _StrongStatusPill(status: order.status),
          const SizedBox(width: 14),
          OsAmountDue(total: order.total, payment: order.payment),
          _QuickActionsMenu(order: order, canWrite: canWrite),
        ],
      ),
    );
  }
}

/// Card de OS para mobile: layout vertical e arejado.
/// - Cabeçalho: ícone tingido pelo status + número em destaque + pill forte.
/// - Corpo: cliente · veículo + relato (quando existe) — "mais detalhes".
/// - Rodapé: situação de pagamento à esquerda; valor + ações à direita.
class _OrderCardMobile extends StatelessWidget {
  const _OrderCardMobile({
    required this.order,
    required this.canWrite,
    required this.onTap,
  });

  final ServiceOrder order;
  final bool canWrite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final subtitle = [
      if ((order.customerName ?? '').isNotEmpty) order.customerName!,
      if ((order.subjectLabel ?? '').isNotEmpty) order.subjectLabel!,
    ].join(' · ');
    final relato = order.complaint?.trim() ?? '';
    final color = osSimpleStatusColor(osSimpleStatusOf(order.status));

    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: NeuTokens.rField,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: número (destaque) + status.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone tingido na cor do status — "cores bem visíveis" desde o
              // primeiro olhar, antes até de ler o pill.
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.build_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    // OS offline (número provisório) mostra o selo de envio.
                    if (isPendingOsNumber(order.number)) ...[
                      const SizedBox(height: 6),
                      SyncRowBadge(
                        entity: 'service_order',
                        id: order.id,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Flexible: com o rótulo curto do grupo simplificado ("Em
              // andamento") já sobra mais espaço que o chip de 7 estados
              // antigo, mas ainda cede se o número da OS for longo.
              Flexible(child: _StrongStatusPill(status: order.status)),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
          // Relato do cliente ("mais detalhes" — o card estava cru demais):
          // é o contexto que faz a lista dizer algo sobre o TRABALHO, não só
          // sobre cliente/valor.
          if (relato.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 14, color: neu.inkFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    relato,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
          // Quando o serviço está previsto — a informação que transforma a
          // lista em planejamento ("o que entrega hoje?") em vez de só um
          // cadastro. Sinaliza atraso: prazo vencido com a OS ainda aberta.
          _LinhaPrevisao(order: order),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: neu.inkFaint.withValues(alpha: .15)),
          const SizedBox(height: 12),
          // Rodapé: pagamento + valor + ações rápidas. As ações foram tiradas
          // do cabeçalho (que já disputa espaço com nº/badge de sync/pill) e
          // vieram pra cá, onde o valor tem `Expanded` pra cedar.
          Row(
            children: [
              Flexible(child: PaymentTag(status: order.paymentStatus)),
              const SizedBox(width: 8),
              Expanded(
                child: OsAmountDue(
                  total: order.total,
                  payment: order.payment,
                  fontSize: 17,
                ),
              ),
              _QuickActionsMenu(order: order, canWrite: canWrite),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: neu.inkFaint, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}

/// Menu de ordenação: gatilho neumórfico que abre a lista de opções.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final OsSort value;
  final ValueChanged<OsSort> onChanged;

  static IconData _iconFor(OsSort s) => switch (s) {
        OsSort.recent => Icons.schedule,
        OsSort.oldest => Icons.history,
        OsSort.numberAsc => Icons.sort,
        OsSort.numberDesc => Icons.sort,
        OsSort.customerAsc => Icons.sort_by_alpha,
        OsSort.customerDesc => Icons.sort_by_alpha,
        OsSort.totalDesc => Icons.trending_up,
        OsSort.totalAsc => Icons.trending_down,
        OsSort.status => Icons.flag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return PopupMenuButton<OsSort>(
      tooltip: 'Ordenar',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final s in OsSort.values)
          PopupMenuItem<OsSort>(
            value: s,
            child: Row(
              children: [
                Icon(_iconFor(s), size: 18, color: neu.inkMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(s.label)),
                if (s == value)
                  Icon(Icons.check, size: 18, color: neu.accent),
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
            if (!context.isMobile) ...[
              const SizedBox(width: 8),
              Text(
                value.label,
                style: TextStyle(
                  color: neu.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Icon(Icons.arrow_drop_down, color: neu.inkMuted),
          ],
        ),
      ),
    );
  }
}
