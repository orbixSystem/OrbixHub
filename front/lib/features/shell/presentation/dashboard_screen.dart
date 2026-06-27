import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../billing/presentation/billing_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../dashboard/presentation/dashboard_section.dart';
import '../../dashboard/presentation/widgets/inventory_widget.dart';
import '../../dashboard/presentation/widgets/metric_card.dart';
import '../../messages/presentation/messages_providers.dart';
import '../../../di.dart';

/// Home ("Início"): saudação + visão geral (período + métricas role-aware) +
/// painel de OS em andamento + atalho de mensagens não lidas. Tudo gated por
/// `me` (módulo + permissão); a moldura é do shell, a tela só devolve o corpo.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Center(child: CircularProgressIndicator());
    }
    final me = session.me;
    final firstName = me.user.fullName.split(' ').first;
    final subAsync = ref.watch(subscriptionProvider);
    final sub = subAsync.asData?.value;
    final scheme = Theme.of(context).colorScheme;

    // `report.read` é o discriminador de visibilidade gerencial/financeira.
    // Owner/gerente veem o cockpit; mecânico/caixa veem o home operacional.
    final isManagement = me.hasPermission('report.read');
    final canSeeActiveOs = me.hasModule('os') && me.hasPermission('os.read');
    final canSeeInventory =
        me.hasModule('inventory') && me.hasPermission('inventory.read');
    final canSeeMessages = me.hasPermission('os.read');

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        if (sub != null && sub.isPastDue) const _PastDueBanner(),
        Text('Olá, $firstName 👋',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          isManagement
              ? 'Aqui está o resumo de ${me.activeTenant?.name ?? 'sua oficina'}.'
              : 'Seu dia de trabalho em um lugar só.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
        ),
        const SizedBox(height: 28),
        if (isManagement) ...[
          // GERENCIAL: período + métricas + OS em andamento (todas) + chat.
          DashboardMetricsSection(me: me),
          if (canSeeActiveOs) ...[
            const SizedBox(height: 32),
            const _ActiveOrdersPanel(),
          ],
          if (canSeeMessages) ...[
            const SizedBox(height: 24),
            const _UnreadMessagesCard(),
          ],
        ] else ...[
          // OPERACIONAL (mecânico/caixa): foco em ação, sem período nem métricas
          // de gestão. Minhas OS em execução + minhas atrasadas + estoque (sem
          // valor) + chat.
          if (canSeeActiveOs) ...[
            _MyOverdueOrdersCard(assignedTo: me.user.id),
            _ActiveOrdersPanel(assignedTo: me.user.id),
          ],
          if (canSeeInventory) ...[
            const SizedBox(height: 24),
            const InventoryWidget(showValue: false),
          ],
          if (canSeeMessages) ...[
            const SizedBox(height: 24),
            const _UnreadMessagesCard(),
          ],
        ],
        const SizedBox(height: 24),
      ],
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.build_circle_outlined,
                    color: AppColors.brand, size: 19),
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
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('Nenhuma OS em execução',
                          style:
                              TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
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
    final scheme = Theme.of(context).colorScheme;
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
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('#${o.number}',
                  style: const TextStyle(
                      color: AppColors.brandDeep,
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
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (elapsed != null) ...[
              const SizedBox(width: 10),
              Text(elapsed,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 20, color: scheme.onSurfaceVariant),
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
    final async = ref.watch(myOverdueOrdersProvider(assignedTo));
    final count = async.asData?.value.length ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/m/os'),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    count == 1
                        ? '1 OS atrasada — prazo vencido'
                        : '$count OS atrasadas — prazo vencido',
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.danger),
              ],
            ),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final hasUnread = unread > 0;
    final accent = hasUnread ? AppColors.brand : AppColors.info;

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/mensagens'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    hasUnread
                        ? Icons.mark_chat_unread_outlined
                        : Icons.chat_bubble_outline,
                    color: accent,
                    size: 22),
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
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastDueBanner extends StatelessWidget {
  const _PastDueBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pagamento pendente. Regularize a assinatura para manter o '
              'acesso de escrita aos módulos.',
              style: TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w600),
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
