import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../billing/domain/billing_models.dart';
import '../../billing/presentation/billing_providers.dart';
import '../../dashboard/presentation/dashboard_section.dart';
import 'nav_items.dart';

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

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        if (sub != null && sub.isPastDue) const _PastDueBanner(),
        Text('Olá, $firstName 👋',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Aqui está o resumo de ${me.activeTenant?.name ?? 'sua oficina'}.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatTile(
              icon: Icons.workspace_premium_outlined,
              label: 'Plano atual',
              value: sub?.planKey.toUpperCase() ?? '—',
              accent: AppColors.brand,
            ),
            _StatTile(
              icon: Icons.toggle_on_outlined,
              label: 'Status',
              value: _statusLabel(sub),
              accent: _statusColor(sub),
            ),
            _StatTile(
              icon: Icons.widgets_outlined,
              label: 'Módulos ativos',
              value: '${me.modules.length}',
              accent: AppColors.info,
            ),
            _StatTile(
              icon: Icons.badge_outlined,
              label: 'Sua função',
              value: me.role,
              accent: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 32),
        DashboardMetricsSection(me: me),
        const SizedBox(height: 32),
        const _SectionTitle('Seus módulos'),
        const SizedBox(height: 14),
        if (me.modules.isEmpty)
          const _EmptyHint('Nenhum módulo habilitado no seu plano atual.')
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final key in me.modules) _ModuleCard(moduleKey: key),
            ],
          ),
        const SizedBox(height: 32),
        const _SectionTitle('Conta'),
        const SizedBox(height: 14),
        _AccountPanel(
          tenantName: me.activeTenant?.name ?? '—',
          role: me.role,
          permissions: me.permissions,
          subscription: sub,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _statusLabel(Subscription? s) {
    if (s == null) return '—';
    return switch (s.status) {
      'trialing' => 'Trial',
      'active' => 'Ativo',
      'past_due' => 'Pendente',
      'canceled' => 'Cancelado',
      _ => s.status,
    };
  }

  Color _statusColor(Subscription? s) {
    if (s == null) return AppColors.inkMuted;
    return switch (s.status) {
      'active' => AppColors.success,
      'past_due' => AppColors.danger,
      'canceled' => AppColors.inkMuted,
      _ => AppColors.warning,
    };
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 224,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.moduleKey});
  final String moduleKey;

  @override
  Widget build(BuildContext context) {
    final meta = moduleMeta[moduleKey] ?? (moduleKey, Icons.extension_outlined);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 268,
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/m/$moduleKey'),
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
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(meta.$2, color: AppColors.brandDeep, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.$1,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Abrir módulo',
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
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.tenantName,
    required this.role,
    required this.permissions,
    required this.subscription,
  });

  final String tenantName;
  final String role;
  final List<String> permissions;
  final Subscription? subscription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Oficina', tenantName),
          const Divider(height: 26),
          _row(context, 'Função', role),
          const Divider(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text('Permissões',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      permissions.map((p) => Chip(label: Text(p))).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: scheme.onSurface, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
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
