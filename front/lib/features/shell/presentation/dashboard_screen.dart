import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../billing/domain/billing_models.dart';
import '../../billing/presentation/billing_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is! SessionAuthenticated) {
      return const Center(child: CircularProgressIndicator());
    }
    final me = session.me;
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(me.user.fullName)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          subAsync.maybeWhen(
            data: (sub) => sub != null && sub.isPastDue
                ? const _PastDueBanner()
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          Text('Bem-vindo, ${me.user.fullName}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Oficina: ${me.activeTenant?.name ?? '—'}  •  Papel: ${me.role}'),
          const SizedBox(height: 24),
          _InfoCard(
            title: 'Módulos habilitados',
            child: me.modules.isEmpty
                ? const Text('Nenhum módulo habilitado.')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        me.modules.map((m) => Chip(label: Text(m))).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Assinatura',
            child: subAsync.when(
              data: (sub) => _SubscriptionSummary(sub: sub),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Não foi possível carregar.'),
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Permissões',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: me.permissions
                  .map((p) => Chip(
                        label: Text(p),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSummary extends StatelessWidget {
  const _SubscriptionSummary({required this.sub});
  final Subscription? sub;

  @override
  Widget build(BuildContext context) {
    if (sub == null) return const Text('Sem assinatura ativa.');
    return Row(
      children: [
        Chip(label: Text(sub!.planKey)),
        const SizedBox(width: 8),
        Chip(label: Text(sub!.status)),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/billing'),
          child: const Text('Ver planos'),
        ),
      ],
    );
  }
}

class _PastDueBanner extends StatelessWidget {
  const _PastDueBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pagamento pendente. Regularize a assinatura para manter o acesso '
              'de escrita aos módulos.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
