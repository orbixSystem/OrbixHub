import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../di.dart';
import 'session_state.dart';

/// Lists the user's workshops and switches the active tenant. Shown right after
/// login when there is more than one, and later from the sidebar.
class TenantPickerScreen extends ConsumerStatefulWidget {
  const TenantPickerScreen({super.key});

  @override
  ConsumerState<TenantPickerScreen> createState() => _TenantPickerScreenState();
}

class _TenantPickerScreenState extends ConsumerState<TenantPickerScreen> {
  String? _switchingTo;

  Future<void> _select(String tenantId) async {
    setState(() => _switchingTo = tenantId);
    try {
      await ref.read(sessionControllerProvider.notifier).switchTenant(tenantId);
      if (mounted) context.go('/');
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _switchingTo = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final me = session is SessionAuthenticated ? session.me : null;
    final memberships = me?.memberships ?? const [];
    final activeTenantId = me?.activeTenant?.id;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandMark(size: 28)),
                const SizedBox(height: 32),
                Text('Escolha a oficina',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text(
                  'Você tem acesso a mais de uma. Selecione para continuar.',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 15),
                ),
                const SizedBox(height: 22),
                for (final m in memberships)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WorkshopTile(
                      slug: m.tenantSlug,
                      role: m.role,
                      isActive: m.tenantId == activeTenantId,
                      isSwitching: _switchingTo == m.tenantId,
                      onTap: _switchingTo != null
                          ? null
                          : () => _select(m.tenantId),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkshopTile extends StatelessWidget {
  const _WorkshopTile({
    required this.slug,
    required this.role,
    required this.isActive,
    required this.isSwitching,
    required this.onTap,
  });

  final String slug;
  final String role;
  final bool isActive;
  final bool isSwitching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppColors.brand : AppColors.line,
              width: isActive ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.garage_rounded,
                    color: AppColors.brandDeep),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slug,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Papel: $role',
                        style: const TextStyle(
                            color: AppColors.inkMuted, fontSize: 13)),
                  ],
                ),
              ),
              if (isSwitching)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Ativa',
                      style: TextStyle(
                          color: AppColors.brandDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
