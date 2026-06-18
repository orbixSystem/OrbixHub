import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/os_models.dart';
import 'item_picker_dialog.dart';
import 'order_edit_dialog.dart';
import 'os_providers.dart';
import 'os_status.dart';

const _maxContentWidth = 940.0;

/// Ficha da OS: cabeçalho (nº/cliente/veículo/status) editável, lista de itens
/// (adicionar via picker do estoque ou avulso, editar, remover) com totais ao
/// vivo, e botões de status com as transições válidas. Corpo apenas — moldura
/// é do shell.
class OsDetailScreen extends ConsumerWidget {
  const OsDetailScreen({super.key, required this.orderId});

  final String orderId;

  bool _has(WidgetRef ref, String perm) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission(perm);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final canWrite = _has(ref, 'os.write');
    final canApprove = _has(ref, 'os.approve');

    return orderAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is AppException ? e.message : 'Erro ao carregar a OS.'),
      ),
      data: (order) => _Bounded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/m/os'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Voltar'),
              ),
            ),
            const SizedBox(height: 8),
            _Header(
              order: order,
              canWrite: canWrite,
              onEdit: () => _edit(context, ref, order),
              onDelete: () => _delete(context, ref, order),
            ),
            const SizedBox(height: 20),
            _StatusBar(
              order: order,
              canWrite: canWrite,
              canApprove: canApprove,
              onChange: (target) => _changeStatus(context, ref, order, target),
            ),
            const SizedBox(height: 24),
            _ItemsSection(order: order, canWrite: canWrite),
            const SizedBox(height: 24),
            _TotalsCard(order: order),
            const SizedBox(height: 24),
            _TimelineSection(order: order, canWrite: canWrite),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ServiceOrder order,
  ) async {
    final ok = await OrderEditDialog.show(context, order: order);
    if (ok == true) ref.invalidate(orderProvider(orderId));
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    ServiceOrder order,
    String target,
  ) async {
    try {
      await ref.read(osRepositoryProvider).changeStatus(order.id, target);
      ref.invalidate(orderProvider(orderId));
      ref.invalidate(orderListProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ServiceOrder order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir OS'),
        content: Text(
          'Excluir "${order.number}"? A ordem sai das listagens '
          '(fica preservada no sistema).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(osRepositoryProvider).deleteOrder(order.id);
      ref.invalidate(orderListProvider);
      if (context.mounted) context.go('/m/os');
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _Bounded extends StatelessWidget {
  const _Bounded({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: child,
        ),
      );
}

// ===================== Cabeçalho =====================

class _Header extends StatelessWidget {
  const _Header({
    required this.order,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
  });

  final ServiceOrder order;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final facts = <(String, String?)>[
      ('Cliente', order.customerName),
      ('Veículo', order.subjectLabel),
      ('Responsável', order.assignedTo),
      ('Relato', order.complaint),
      ('Diagnóstico', order.diagnosis),
      ('Previsão início', order.scheduledStart),
      ('Previsão fim', order.scheduledEnd),
    ];
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
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.build_outlined,
                    color: AppColors.brandDeep, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.number,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    OsStatusChip(status: order.status),
                  ],
                ),
              ),
              if (canWrite) ...[
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline),
                  color: scheme.error,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 28,
            runSpacing: 4,
            children: [
              for (final (label, value) in facts)
                if (value != null && value.isNotEmpty)
                  _InlineFact(label: label, value: value),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineFact extends StatelessWidget {
  const _InlineFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ===================== Barra de status (workflow) =====================

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.order,
    required this.canWrite,
    required this.canApprove,
    required this.onChange,
  });

  final ServiceOrder order;
  final bool canWrite;
  final bool canApprove;
  final void Function(String target) onChange;

  @override
  Widget build(BuildContext context) {
    if (!canWrite) return const SizedBox.shrink();
    final targets = osTransitions[order.status] ?? const <String>[];
    // "Aprovar" só aparece com a permissão os.approve.
    final visible = targets
        .where((t) => t != 'aprovada' || canApprove)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final target in visible)
          target == 'cancelada'
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: () => onChange(target),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(osTransitionLabel(target)),
                )
              : FilledButton.icon(
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => onChange(target),
                  icon: Icon(_transitionIcon(target), size: 18),
                  label: Text(osTransitionLabel(target)),
                ),
      ],
    );
  }

  IconData _transitionIcon(String target) {
    switch (target) {
      case 'aguardando_aprovacao':
        return Icons.outbox_outlined;
      case 'aprovada':
        return Icons.check_circle_outline;
      case 'aberta':
        return Icons.undo;
      case 'em_execucao':
        return Icons.play_arrow_outlined;
      case 'concluida':
        return Icons.task_alt;
      case 'entregue':
        return Icons.local_shipping_outlined;
      default:
        return Icons.arrow_forward;
    }
  }
}

// ===================== Itens =====================

class _ItemsSection extends ConsumerWidget {
  const _ItemsSection({required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await ItemPickerDialog.show(context);
    if (draft == null) return;
    try {
      await ref.read(osRepositoryProvider).addItem(order.id, draft);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    OrderItem item,
  ) async {
    try {
      await ref.read(osRepositoryProvider).deleteItem(order.id, item.id);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Itens',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (canWrite)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar item'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: order.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Nenhum item ainda.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < order.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _ItemRow(
                        order: order,
                        item: order.items[i],
                        canWrite: canWrite,
                        onRemove: () => _remove(context, ref, order.items[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.order,
    required this.item,
    required this.canWrite,
    required this.onRemove,
  });

  final ServiceOrder order;
  final OrderItem item;
  final bool canWrite;
  final VoidCallback onRemove;

  Future<void> _editQty(
    BuildContext context,
    WidgetRef ref,
    OrderItemPatch patch,
  ) async {
    try {
      await ref.read(osRepositoryProvider).updateItem(order.id, item.id, patch);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isService = item.kind == 'service';
    final disc = double.tryParse(item.discount) ?? 0;
    final detail = [
      '${item.quantity} × ${money(item.unitPrice)}',
      if (disc > 0) '- ${money(item.discount)}',
    ].join('  ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isService
                ? Icons.design_services_outlined
                : Icons.inventory_2_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(money(item.total),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (canWrite) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Mais ações',
              onSelected: (action) async {
                if (action == 'editar') {
                  final patch = await _ItemEditDialog.show(context, item);
                  if (patch != null && context.mounted) {
                    await _editQty(context, ref, patch);
                  }
                } else if (action == 'remover') {
                  onRemove();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'remover',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Icons.delete_outline, color: AppColors.danger),
                    title: Text('Remover',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog enxuto para editar qtd/preço/desconto de um item.
class _ItemEditDialog extends StatefulWidget {
  const _ItemEditDialog({required this.item});
  final OrderItem item;

  static Future<OrderItemPatch?> show(BuildContext context, OrderItem item) {
    return showDialog<OrderItemPatch>(
      context: context,
      builder: (_) => _ItemEditDialog(item: item),
    );
  }

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _disc;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: _fmt(widget.item.quantity));
    _price = TextEditingController(text: _fmt(widget.item.unitPrice));
    _disc = TextEditingController(text: _fmt(widget.item.discount));
  }

  String _fmt(String s) {
    final v = double.tryParse(s);
    return v == null ? s : v.toString().replaceAll('.', ',');
  }

  double? _toDouble(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _disc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Preço unitário', prefixText: 'R\$ '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _disc,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Desconto', prefixText: 'R\$ '),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            OrderItemPatch(
              quantity: _toDouble(_qty.text),
              unitPrice: _toDouble(_price.text),
              discount: _toDouble(_disc.text),
            ),
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

// ===================== Totais =====================

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemsTotal = order.items.fold<double>(
      0,
      (acc, it) => acc + (double.tryParse(it.total) ?? 0),
    );
    final discount = double.tryParse(order.discount ?? '0') ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Itens', value: money(itemsTotal.toString())),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _TotalRow(
                label: 'Desconto da OS',
                value: '- ${money(discount.toString())}'),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                money(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.brandDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ===================== Linha do tempo =====================

class _TimelineSection extends ConsumerWidget {
  const _TimelineSection({required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final draft = await _NoteDialog.show(context);
    if (draft == null) return;
    try {
      await ref.read(osRepositoryProvider).createNote(
            order.id,
            message: draft.message,
            visiblePublic: draft.visiblePublic,
          );
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final events = order.events;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.timeline_outlined,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Linha do tempo',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (canWrite)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _addNote(context, ref),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('Adicionar nota'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhum evento ainda.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < events.length; i++)
                      _EventRow(
                        event: events[i],
                        isFirst: i == 0,
                        isLast: i == events.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final OrderEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = _dotColor();
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trilho vertical com o ponto/ícone.
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isFirst
                          ? Colors.transparent
                          : scheme.outlineVariant,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_kindIcon(), size: 16, color: dotColor),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color:
                          isLast ? Colors.transparent : scheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _label(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: event.visiblePublic
                              ? 'Visível ao cliente'
                              : 'Interno (não visível ao cliente)',
                          child: Icon(
                            event.visiblePublic
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 16,
                            color: event.visiblePublic
                                ? AppColors.brand
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (event.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _fmtTimestamp(event.createdAt!),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rótulo do evento: usa a `message` quando há; senão deriva de `status_change`
  /// (rótulo PT-BR do status) ou do `kind`.
  String _label() {
    final msg = event.message?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
    switch (event.kind) {
      case 'status_change':
        final snap = event.statusSnapshot;
        return snap == null
            ? 'Status alterado'
            : 'Status: ${osStatusLabel(snap)}';
      case 'created':
        return 'OS criada';
      case 'photo':
        return 'Foto adicionada';
      default:
        return 'Nota';
    }
  }

  Color _dotColor() {
    switch (event.kind) {
      case 'status_change':
        return event.statusSnapshot == null
            ? AppColors.brand
            : osStatusColor(event.statusSnapshot!);
      case 'created':
        return AppColors.success;
      case 'photo':
        return AppColors.info;
      default:
        return AppColors.graphite;
    }
  }

  IconData _kindIcon() {
    switch (event.kind) {
      case 'created':
        return Icons.flag_outlined;
      case 'status_change':
        return Icons.swap_horiz;
      case 'photo':
        return Icons.photo_outlined;
      case 'note':
      default:
        return Icons.chat_bubble_outline;
    }
  }

  /// Timestamp curto a partir de um ISO-8601. Mostra `dd/MM HH:mm`; se não
  /// parsear, devolve o original.
  String _fmtTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// Resultado do dialog de nova nota.
class _NoteDraft {
  const _NoteDraft({required this.message, required this.visiblePublic});
  final String message;
  final bool visiblePublic;
}

/// Dialog para adicionar uma nota à linha do tempo (mensagem + visibilidade).
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  static Future<_NoteDraft?> show(BuildContext context) {
    return showDialog<_NoteDraft>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
  }

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _message = TextEditingController();
  bool _visiblePublic = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      _NoteDraft(message: text, visiblePublic: _visiblePublic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar nota'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _message,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Nota',
                hintText: 'Ex.: peça pedida ao fornecedor, previsão de chegada…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _visiblePublic,
              onChanged: (v) => setState(() => _visiblePublic = v),
              title: const Text('Visível ao cliente'),
              subtitle: const Text(
                'Quando ligado, aparece no acompanhamento do cliente.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
