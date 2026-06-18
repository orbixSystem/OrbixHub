import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import 'order_form_dialog.dart';
import 'os_providers.dart';
import 'os_status.dart';

/// Lista de ordens de serviço: barra com filtro de status + busca + "Nova OS"
/// (gated `os.write`); linhas com nº, cliente, veículo, status (chip colorido)
/// e total. Toca → detalhe. Corpo apenas — a moldura é do shell.
class OsListScreen extends ConsumerStatefulWidget {
  const OsListScreen({super.key});

  @override
  ConsumerState<OsListScreen> createState() => _OsListScreenState();
}

class _OsListScreenState extends ConsumerState<OsListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _canWrite() {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('os.write');
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
    final listAsync = ref.watch(orderListProvider);
    final query = ref.watch(orderListQueryProvider);
    final notifier = ref.read(orderListQueryProvider.notifier);
    final canWrite = _canWrite();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Filtro de status: "Todas" + os 7 status, como chips.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: query.status == null,
                    onSelected: (_) => notifier.setStatus(null),
                  ),
                  for (final s in osStatuses)
                    ChoiceChip(
                      label: Text(osStatusLabel(s)),
                      selected: query.status == s,
                      onSelected: (_) => notifier.setStatus(s),
                    ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48)),
                    onPressed: () => context.go('/m/os/templates'),
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('Templates'),
                  ),
                  if (canWrite)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Nova OS'),
                    ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Buscar nº ou cliente',
                      ),
                      onChanged: notifier.setQuery,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: listAsync.when(
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40)),
                      onPressed: () => ref.invalidate(orderListProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar de novo'),
                    ),
                  ],
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(
                      child: Text('Nenhuma ordem de serviço encontrada.'));
                }
                return ListView.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final o = page.items[i];
                    return _OrderTile(
                      number: o.number,
                      customerName: o.customerName,
                      subjectLabel: o.subjectLabel,
                      status: o.status,
                      total: o.total,
                      onTap: () => context.go('/m/os/${o.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.number,
    required this.customerName,
    required this.subjectLabel,
    required this.status,
    required this.total,
    required this.onTap,
  });

  final String number;
  final String? customerName;
  final String? subjectLabel;
  final String status;
  final String? total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (customerName != null && customerName!.isNotEmpty) customerName!,
      if (subjectLabel != null && subjectLabel!.isNotEmpty) subjectLabel!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.build_outlined,
                  color: AppColors.brandDeep, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            OsStatusChip(status: status),
            const SizedBox(width: 16),
            Text(
              money(total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
