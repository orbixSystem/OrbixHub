import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../di.dart';
import 'session_state.dart';

/// Lists the user's workshops and switches the active tenant. Reachable right
/// after login (when there is more than one) and later from the shell menu.
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
      appBar: AppBar(title: const Text('Escolha a oficina')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            itemCount: memberships.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = memberships[i];
              final isActive = m.tenantId == activeTenantId;
              final isSwitching = _switchingTo == m.tenantId;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.store_mall_directory_outlined),
                  title: Text(m.tenantSlug),
                  subtitle: Text('Papel: ${m.role}'),
                  trailing: isSwitching
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : isActive
                          ? const Chip(label: Text('Ativa'))
                          : const Icon(Icons.chevron_right),
                  onTap: _switchingTo != null ? null : () => _select(m.tenantId),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
