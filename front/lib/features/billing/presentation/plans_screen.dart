import 'package:flutter/material.dart';
import '../../../core/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import '../domain/billing_models.dart';
import 'billing_providers.dart';

/// Renders subscribable plans DYNAMICALLY from `GET /billing/plans` (no hardcoded
/// names/modules) as premium pricing cards; owner can subscribe / change plan.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String? _busyPlanKey;

  String _price(int cents) => cents == 0
      ? 'Grátis'
      : 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _choose(String planKey, Subscription? current) async {
    setState(() => _busyPlanKey = planKey);
    final repo = ref.read(billingRepositoryProvider);
    try {
      if (current != null && current.isActive) {
        await repo.changePlan(planKey);
      } else {
        await repo.subscribe(planKey);
      }
      ref.invalidate(subscriptionProvider);
      ref.invalidate(plansProvider);
      await ref.read(sessionControllerProvider.notifier).reloadMe();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Plano "$planKey" ativado.')));
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyPlanKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Planos/assinatura vivem no servidor de billing.
    if (ref.watch(isOfflineProvider)) {
      return const RequiresConnectionView(
        message:
            'Os planos e a assinatura são consultados no servidor. '
            'Conecte-se à internet para vê-los ou trocar de plano.',
      );
    }
    final plansAsync = ref.watch(plansProvider);
    final current = ref.watch(subscriptionProvider).asData?.value;

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is AppException ? e.message : 'Erro ao carregar planos.'),
      ),
      data: (plans) => ListView(
        padding: const EdgeInsets.all(28),
        children: [
          if (current != null) ...[
            // Layout único (ListView + Wrap): os alvos valem nos dois tamanhos.
            CoachTarget('planos.atual', child: _CurrentStatus(sub: current)),
            const SizedBox(height: 24),
          ],
          Text(
            'Escolha seu plano',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Faça upgrade quando precisar. Sem fidelidade.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 15),
          ),
          const SizedBox(height: 22),
          if (plans.isEmpty)
            const Text('Nenhum plano disponível no momento.')
          else
            CoachTarget(
              'planos.grade',
              child: Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final p in plans)
                    _PlanCard(
                      plan: p,
                      price: _price(p.priceCents),
                      isCurrent: current?.planKey == p.key,
                      busy: _busyPlanKey == p.key,
                      ctaLabel: current != null && current.isActive
                          ? 'Trocar para este'
                          : 'Assinar agora',
                      onChoose: () => _choose(p.key, current),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.isCurrent,
    required this.busy,
    required this.ctaLabel,
    required this.onChoose,
  });

  final Plan plan;
  final String price;
  final bool isCurrent;
  final bool busy;
  final String ctaLabel;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? AppColors.brand : scheme.outlineVariant,
          width: isCurrent ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Plano atual',
                    style: TextStyle(
                      color: AppColors.brandDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${plan.billingPeriod}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Inclui os módulos:',
            style: TextStyle(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ...plan.modules.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    m,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (isCurrent)
            OutlinedButton(onPressed: null, child: const Text('Seu plano'))
          else
            FilledButton(
              onPressed: busy ? null : onChoose,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(ctaLabel),
            ),
        ],
      ),
    );
  }
}

class _CurrentStatus extends StatelessWidget {
  const _CurrentStatus({required this.sub});
  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pastDue = sub.isPastDue;
    final bg = pastDue ? AppColors.dangerTint : scheme.surfaceContainerHigh;
    final fg = pastDue ? AppColors.danger : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pastDue
              ? AppColors.danger.withValues(alpha: 0.25)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            pastDue ? Icons.warning_amber_rounded : Icons.info_outline,
            color: fg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pastDue
                  ? 'Assinatura "${sub.planKey}" com pagamento pendente (past_due).'
                  : 'Assinatura atual: ${sub.planKey} • ${sub.status}',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
