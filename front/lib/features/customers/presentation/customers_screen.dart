import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/customers_models.dart';
import 'customer_form_dialog.dart';
import 'customers_providers.dart';

/// Lista de clientes com busca, criar/editar e arquivar. Corpo apenas — a
/// moldura (sidebar/título) é do shell.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _canWrite(WidgetRef ref) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission('customer.write');
  }

  Future<void> _create() async {
    final config =
        ref.read(customersConfigProvider).value ?? const CustomersConfig();
    final ok = await CustomerFormDialog.show(
      context,
      documentRequired: config.documentRequired,
    );
    if (ok == true) ref.invalidate(customersListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(customersListProvider);
    final showArchived = ref.watch(showArchivedProvider);
    final canWrite = _canWrite(ref);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Toggle: mostra/oculta os arquivados (off = só ativos).
              FilterChip(
                label: const Text('Arquivados'),
                avatar: Icon(
                  showArchived ? Icons.archive : Icons.archive_outlined,
                  size: 18,
                ),
                selected: showArchived,
                onSelected: (v) =>
                    ref.read(showArchivedProvider.notifier).set(v),
              ),
              const Spacer(),
              // Busca compacta, à direita.
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar cliente',
                  ),
                  onChanged: (v) =>
                      ref.read(customerQueryProvider.notifier).set(v),
                ),
              ),
              if (canWrite) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  // Global filled-button theme uses Size.fromHeight(50) (width =
                  // infinity); pin a finite min width when in a Row.
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo cliente'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  e is AppException ? e.message : 'Erro ao carregar clientes.',
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(child: Text('Nenhum cliente encontrado.'));
                }
                return ListView.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = page.items[i];
                    return _CustomerTile(
                      customer: c,
                      canWrite: canWrite,
                      onOpen: () => context.go('/m/customers/${c.id}'),
                      onArchiveToggle: () async {
                        final repo = ref.read(customersRepositoryProvider);
                        if (c.status == 'archived') {
                          await repo.unarchiveCustomer(c.id);
                        } else {
                          await repo.archiveCustomer(c.id);
                        }
                        ref.invalidate(customersListProvider);
                      },
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

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.canWrite,
    required this.onOpen,
    required this.onArchiveToggle,
  });

  final Customer customer;
  final bool canWrite;
  final VoidCallback onOpen;
  final Future<void> Function() onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (customer.document != null) customer.document!,
      if (customer.phone != null) customer.phone!,
    ].join(' · ');
    final archived = customer.status == 'archived';
    return ListTile(
      onTap: onOpen,
      leading: CircleAvatar(
        child: Text(customer.name.isNotEmpty
            ? customer.name.characters.first.toUpperCase()
            : '?'),
      ),
      title: Text(customer.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (archived)
            const Chip(label: Text('Arquivado'), visualDensity: VisualDensity.compact),
          if (canWrite)
            IconButton(
              tooltip: archived ? 'Desarquivar' : 'Arquivar',
              icon: Icon(archived ? Icons.unarchive_outlined : Icons.archive_outlined),
              onPressed: onArchiveToggle,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
