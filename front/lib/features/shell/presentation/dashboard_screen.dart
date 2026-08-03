import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../billing/presentation/billing_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../dashboard/presentation/widgets/kpi.dart';
import '../../dashboard/presentation/widgets/metric_card.dart';
import '../../dashboard/presentation/widgets/period_selector.dart';
import '../../dashboard/presentation/widgets/status_donut.dart';
import '../../messages/presentation/messages_providers.dart';
import '../../../di.dart';

/// Home ("Início"): saudação + visão geral (período + métricas role-aware) +
/// painel de OS em andamento + atalho de mensagens não lidas. Tudo gated por
/// `me` (módulo + permissão); a moldura é do shell, a tela só devolve o corpo.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Alvos do tutorial (spotlight).
  final _metricsKey = GlobalKey();
  final _ordersKey = GlobalKey();
  final _messagesKey = GlobalKey();

  List<CoachStep> _coachSteps() => [
        if (_metricsKey.currentContext != null)
          CoachStep(
            targetKey: _metricsKey,
            title: 'Sua visão geral',
            text:
                'Os números da oficina no período escolhido — faturamento, OS, estoque e clientes.',
          ),
        if (_ordersKey.currentContext != null)
          CoachStep(
            targetKey: _ordersKey,
            title: 'OS em andamento',
            text:
                'Acompanhe as ordens em execução e toque para abrir os detalhes.',
          ),
        if (_messagesKey.currentContext != null)
          CoachStep(
            targetKey: _messagesKey,
            title: 'Fale com o cliente',
            text:
                'Mensagens trocadas pelo link de acompanhamento da OS aparecem aqui.',
          ),
        // Passos SEM alvo: valem igual em desktop e mobile (não dependem de um
        // elemento que só existe num dos dois) e explicam o que a tela não
        // mostra sozinha.
        const CoachStep(
          title: 'O botão "+" cria de qualquer tela',
          text: 'Ordem de serviço, venda, despesa, cliente e produto saem dali '
              'sem navegar até o módulo. O que aparece depende dos módulos do '
              'seu plano e das suas permissões.',
        ),
        const CoachStep(
          title: 'Funciona sem internet',
          text: 'Se a conexão cair, você continua lançando: fica guardado no '
              'aparelho e sobe sozinho quando a rede voltar. Uma faixa avisa '
              'quando você está offline.',
        ),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachMark.maybeStart(context, id: 'dashboard', steps: _coachSteps());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final session = ref.watch(sessionControllerProvider);
    final me = session.meOrNull;
    if (me == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // O painel é 100% números calculados no servidor — offline não há o que
    // mostrar (em vez de uma tela vazia/quebrada, explicamos).
    if (ref.watch(isOfflineProvider)) {
      return const RequiresConnectionView(
        message: 'O painel mostra números calculados no servidor. Sem conexão '
            'não dá para atualizá-los — os módulos de OS, Clientes, Estoque e '
            'Caixa continuam funcionando normalmente.',
      );
    }
    final firstName = me.user.fullName.split(' ').first;
    final subAsync = ref.watch(subscriptionProvider);
    final sub = subAsync.asData?.value;
    final neu = context.neu;

    // `report.read` é o discriminador de visibilidade gerencial/financeira.
    // Owner/gerente veem o cockpit; mecânico/caixa veem o home operacional.
    final isManagement = me.hasPermission('report.read');
    final canSeeActiveOs = me.hasModule('os') && me.hasPermission('os.read');
    final canSeeInventory =
        me.hasModule('inventory') && me.hasPermission('inventory.read');
    final canSeeMessages = me.hasPermission('os.read');

    return ListView(
      padding: EdgeInsets.all(context.isMobile ? 16 : 28),
      children: [
        // Aviso de cobrança gated por kBillingNoticesEnabled — enquanto não há
        // como o usuário regularizar de fato, o banner só assusta.
        if (kBillingNoticesEnabled && sub != null && sub.isPastDue)
          const _PastDueBanner(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá, $firstName',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    isManagement
                        ? 'Aqui está o resumo de ${me.activeTenant?.name ?? 'sua oficina'}.'
                        : 'Seu dia de trabalho em um lugar só.',
                    style: TextStyle(color: neu.inkMuted, fontSize: 15),
                  ),
                ],
              ),
            ),
            NeuIconButton(
              icon: Icons.help_outline_rounded,
              tooltip: 'Rever tutorial',
              size: 42,
              onPressed: () =>
                  CoachMark.start(context, id: 'dashboard', steps: _coachSteps()),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (isManagement) ...[
          // GERENCIAL: período + KPIs + (status × OS em andamento) + (estoque
          // baixo × mensagens).
          const Align(alignment: Alignment.centerLeft, child: PeriodSelector()),
          const SizedBox(height: 18),
          KeyedSubtree(key: _metricsKey, child: const ManagementKpiStrip()),
          const SizedBox(height: 16),
          _TwoCol(
            leftFlex: 4,
            rightFlex: 5,
            left: const _StatusCard(),
            right: canSeeActiveOs
                ? KeyedSubtree(key: _ordersKey, child: const _ActiveOrdersPanel())
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _TwoCol(
            left: canSeeInventory ? const _LowStockPanel() : const SizedBox.shrink(),
            right: canSeeMessages
                ? KeyedSubtree(key: _messagesKey, child: const _UnreadMessagesCard())
                : const SizedBox.shrink(),
          ),
        ] else ...[
          // OPERACIONAL (mecânico/caixa): foco em ação.
          KeyedSubtree(
            key: _metricsKey,
            child: OperationalKpiStrip(userId: me.user.id),
          ),
          const SizedBox(height: 16),
          if (canSeeActiveOs) ...[
            _MyOverdueOrdersCard(assignedTo: me.user.id),
            KeyedSubtree(
              key: _ordersKey,
              child: _ActiveOrdersPanel(assignedTo: me.user.id),
            ),
          ],
          const SizedBox(height: 16),
          _TwoCol(
            left: canSeeInventory ? const _LowStockPanel() : const SizedBox.shrink(),
            right: canSeeMessages
                ? KeyedSubtree(key: _messagesKey, child: const _UnreadMessagesCard())
                : const SizedBox.shrink(),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Duas colunas no desktop/tablet (alturas iguais), empilhadas no mobile.
/// Colapsa quando um dos lados é vazio.
class _TwoCol extends StatelessWidget {
  const _TwoCol({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  bool _empty(Widget w) => w is SizedBox && w.child == null;

  @override
  Widget build(BuildContext context) {
    if (_empty(left) && _empty(right)) return const SizedBox.shrink();
    if (_empty(left)) return right;
    if (_empty(right)) return left;
    if (context.isMobile) {
      return Column(
        children: [left, const SizedBox(height: 16), right],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: 16),
          Expanded(flex: rightFlex, child: right),
        ],
      ),
    );
  }
}

/// Card "Ordens por status" com o donut (visão gerencial).
class _StatusCard extends ConsumerWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(osManagementMetricsProvider);
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: Icons.donut_large_rounded, index: 0, size: 38),
              const SizedBox(width: 12),
              Text('Ordens por status',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 18),
          async.when(
            loading: () => const MetricLoading(),
            error: (_, _) => MetricError(
                onRetry: () => ref.invalidate(osManagementMetricsProvider)),
            data: (m) => m.totalOrders == 0
                ? SizedBox(
                    height: 120,
                    child: Center(
                      child: Text('Sem OS no período.',
                          style: TextStyle(color: neu.inkMuted)),
                    ),
                  )
                : StatusDonut(byStatus: m.byStatus),
          ),
        ],
      ),
    );
  }
}

/// Painel "Estoque baixo": amostra de itens no/abaixo do mínimo.
class _LowStockPanel extends ConsumerWidget {
  const _LowStockPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryMetricsProvider);
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: Icons.inventory_2_outlined, index: 5, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Estoque baixo',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () => context.go('/m/inventory'),
                child: const Text('Ver estoque'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
            error: (_, _) => MetricError(
                onRetry: () => ref.invalidate(inventoryMetricsProvider)),
            data: (m) {
              final items = m.lowStockSample;
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: neu.success),
                      const SizedBox(width: 8),
                      Text('Tudo acima do mínimo',
                          style: TextStyle(color: neu.inkMuted)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: neu.line),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              items[i].name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: neu.ink,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          NeuStatusChip(
                            label:
                                '${items[i].currentStock}/${items[i].minStock ?? 0}',
                            color: neu.warning,
                            tint: neu.warningTint,
                            icon: Icons.warning_amber_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Painel "OS em andamento": até 5 OS mais recentes em `em_execucao`. Cada linha
/// abre o detalhe (`/m/os/:id`); o cabeçalho tem "Ver todas" (`/m/os`). Quando
/// [assignedTo] é informado (home operacional), mostra só as OS do mecânico.
class _ActiveOrdersPanel extends ConsumerWidget {
  const _ActiveOrdersPanel({this.assignedTo});

  final String? assignedTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeOrdersProvider(assignedTo));
    final neu = context.neu;

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(
                context,
                icon: Icons.build_circle_outlined,
                index: 1, // laranja
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('OS em andamento',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () => context.go('/m/os'),
                child: const Text('Ver todas'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MetricError(
                onRetry: () =>
                    ref.invalidate(activeOrdersProvider(assignedTo)),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: neu.inkMuted),
                      const SizedBox(width: 8),
                      Text('Nenhuma OS em execução',
                          style: TextStyle(color: neu.inkMuted)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: neu.line),
                    _ActiveOrderRow(active: items[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderRow extends StatelessWidget {
  const _ActiveOrderRow({required this.active});
  final ActiveOrder active;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final o = active.order;
    final elapsed = _elapsedLabel(o.startedAt);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/m/os/${o.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: neu.accentTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('#${o.number}',
                  style: TextStyle(
                      color: neu.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.customerName ?? 'Cliente',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active.assigneeName ?? 'Sem responsável',
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (elapsed != null) ...[
              const SizedBox(width: 10),
              Text(elapsed,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12)),
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: neu.inkMuted),
          ],
        ),
      ),
    );
  }

  /// "há X" desde `started_at` (ISO). Null se ausente/inválido.
  String? _elapsedLabel(String? startedAtIso) {
    if (startedAtIso == null) return null;
    final started = DateTime.tryParse(startedAtIso);
    if (started == null) return null;
    final d = DateTime.now().difference(started);
    if (d.inMinutes < 1) return 'há instantes';
    if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
    if (d.inHours < 24) return 'há ${d.inHours} h';
    return 'há ${d.inDays} d';
  }
}

/// "Minhas OS atrasadas": card de alerta com a contagem das minhas OS cujo prazo
/// (`scheduled_end`) já passou e que não foram concluídas. Some quando não há
/// nenhuma (ou em loading/erro — sinal best-effort). Toca → `/m/os`.
class _MyOverdueOrdersCard extends ConsumerWidget {
  const _MyOverdueOrdersCard({required this.assignedTo});

  final String assignedTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(myOverdueOrdersProvider(assignedTo));
    final count = async.asData?.value.length ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuCard(
        onTap: () => context.go('/m/os'),
        color: neu.dangerTint,
        padding: const EdgeInsets.all(16),
        radius: NeuTokens.rField,
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: neu.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? '1 OS atrasada — prazo vencido'
                    : '$count OS atrasadas — prazo vencido',
                style: TextStyle(
                    color: neu.danger, fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right, color: neu.danger),
          ],
        ),
      ),
    );
  }
}

/// Card de atalho para mensagens não lidas. Reusa
/// `unreadConversationsCountProvider` (mesmo do badge do menu).
class _UnreadMessagesCard extends ConsumerWidget {
  const _UnreadMessagesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadConversationsCountProvider);
    final neu = context.neu;
    final hasUnread = unread > 0;
    final accent = hasUnread ? neu.glyphs[1] : neu.info;

    return NeuCard(
      onTap: () => context.go('/mensagens'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          NeuIconChip(
            icon: hasUnread
                ? Icons.mark_chat_unread_outlined
                : Icons.chat_bubble_outline,
            color: accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasUnread
                      ? '$unread ${unread == 1 ? 'mensagem não lida' : 'mensagens não lidas'}'
                      : 'Nenhuma mensagem nova',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text('Abrir Mensagens',
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5)),
              ],
            ),
          ),
          Icon(Icons.arrow_outward_rounded, size: 18, color: neu.inkMuted),
        ],
      ),
    );
  }
}

class _PastDueBanner extends StatelessWidget {
  const _PastDueBanner();

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neu.dangerTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neu.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: neu.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pagamento pendente. Regularize a assinatura para manter o '
              'acesso de escrita aos módulos.',
              style: TextStyle(
                  color: neu.danger, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/billing'),
            child: const Text('Resolver'),
          ),
        ],
      ),
    );
  }
}
