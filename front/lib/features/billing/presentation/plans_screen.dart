import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import '../domain/billing_models.dart';
import 'billing_providers.dart';

/// Renders subscribable plans DYNAMICALLY from `GET /billing/plans` (no hardcoded
/// names/modules) and lets the owner subscribe / change plan.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String? _busyPlanKey;

  String _price(int cents) =>
      cents == 0 ? 'Grátis' : 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _choose(String planKey, Subscription? current) async {
    setState(() => _busyPlanKey = planKey);
    final repo = ref.read(billingRepositoryProvider);
    try {
      // Active paid sub → change-plan; otherwise (trial/none) → subscribe.
      if (current != null && current.isActive) {
        await repo.changePlan(planKey);
      } else {
        await repo.subscribe(planKey);
      }
      // Entitlements may have changed → refresh subscription, plans and /me.
      ref.invalidate(subscriptionProvider);
      ref.invalidate(plansProvider);
      await ref.read(sessionControllerProvider.notifier).reloadMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plano "$planKey" ativado.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyPlanKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    final subAsync = ref.watch(subscriptionProvider);
    final current = subAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Planos & Assinatura')),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is AppException ? e.message : 'Erro ao carregar planos.'),
        ),
        data: (plans) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (current != null) _CurrentStatus(sub: current),
            const SizedBox(height: 12),
            if (plans.isEmpty)
              const Text('Nenhum plano disponível no momento.')
            else
              ...plans.map((p) {
                final isCurrent = current?.planKey == p.key;
                final busy = _busyPlanKey == p.key;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(p.name,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(width: 12),
                            Text('${_price(p.priceCents)} / ${p.billingPeriod}'),
                            const Spacer(),
                            if (isCurrent)
                              const Chip(label: Text('Plano atual'))
                            else
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => _choose(p.key, current),
                                child: busy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Text(current != null && current.isActive
                                        ? 'Trocar para este'
                                        : 'Assinar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              p.modules.map((m) => Chip(label: Text(m))).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pastDue ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(pastDue ? Icons.warning_amber : Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pastDue
                  ? 'Assinatura "${sub.planKey}" com pagamento pendente (past_due).'
                  : 'Assinatura atual: ${sub.planKey} • ${sub.status}',
            ),
          ),
        ],
      ),
    );
  }
}
