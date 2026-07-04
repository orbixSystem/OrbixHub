import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/schedule_models.dart';
import 'schedule_providers.dart';

/// Agenda diária: lista de itens de OS agendados para um dia,
/// com navegação dia a dia e filtro por técnico (TODO: dropdown de membros).
class AgendaScreen extends ConsumerWidget {
  const AgendaScreen({super.key});

  static final _dateFmt = DateFormat('E, dd/MM', 'pt_BR');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(agendaQueryProvider);
    final agendaAsync = ref.watch(agendaProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  ref.read(agendaQueryProvider.notifier).prevDay(),
              tooltip: 'Dia anterior',
            ),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: query.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null && context.mounted) {
                  ref.read(agendaQueryProvider.notifier).setDate(picked);
                }
              },
              child: Text(
                _dateFmt.format(query.date),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () =>
                  ref.read(agendaQueryProvider.notifier).nextDay(),
              tooltip: 'Próximo dia',
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Hoje',
            onPressed: () {
              final n = DateTime.now();
              ref
                  .read(agendaQueryProvider.notifier)
                  .setDate(DateTime(n.year, n.month, n.day));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: () =>
                ref.invalidate(agendaProvider),
          ),
        ],
      ),
      body: agendaAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro: $e',
                style: const TextStyle(color: AppColors.danger)),
          ),
        ),
        data: (result) => result.items.isEmpty
            ? _EmptyDay(date: query.date)
            : _AgendaList(items: result.items, timeFmt: _timeFmt),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined,
              size: 48, color: AppColors.inkFaint),
          const SizedBox(height: 12),
          Text(
            isToday
                ? 'Nenhum serviço agendado para hoje.'
                : 'Nenhum serviço agendado para este dia.',
            style:
                TextStyle(color: AppColors.inkMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({required this.items, required this.timeFmt});

  final List<AgendaItem> items;
  final DateFormat timeFmt;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) =>
          _AgendaCard(item: items[i], timeFmt: timeFmt),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.item, required this.timeFmt});

  final AgendaItem item;
  final DateFormat timeFmt;

  Color _statusColor(String status) => switch (status) {
        'em_execucao' => AppColors.warning,
        'concluida' => AppColors.success,
        'entregue' => AppColors.success,
        'cancelada' => AppColors.danger,
        _ => AppColors.info,
      };

  String _statusLabel(String status) => switch (status) {
        'aberta' => 'Aberta',
        'aguardando_aprovacao' => 'Aguard. aprovação',
        'aprovada' => 'Aprovada',
        'em_execucao' => 'Em execução',
        'concluida' => 'Concluída',
        'entregue' => 'Entregue',
        'cancelada' => 'Cancelada',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final start = item.scheduledStart != null
        ? DateTime.tryParse(item.scheduledStart!)
        : null;
    final end = item.scheduledEnd != null
        ? DateTime.tryParse(item.scheduledEnd!)
        : null;
    final status = item.order.status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (start != null) ...[
                  Text(
                    timeFmt.format(start.toLocal()),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink),
                  ),
                  if (end != null)
                    Text(
                      timeFmt.format(end.toLocal()),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.inkMuted),
                    ),
                ] else
                  Text('–',
                      style: TextStyle(color: AppColors.inkFaint)),
              ],
            ),
          ),
          // Divider
          Container(
            width: 3,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _statusColor(status),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.order.number,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.brand),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                        label: _statusLabel(status),
                        color: _statusColor(status)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.order.customerName != null)
                  Text(
                    item.order.customerName!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.order.subjectLabel != null)
                  Text(
                    item.order.subjectLabel!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.estimatedDuration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${item.estimatedDuration} min',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.inkFaint),
                    ),
                  ),
              ],
            ),
          ),
          // Navigate to OS
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            color: AppColors.inkFaint,
            tooltip: 'Abrir OS',
            onPressed: () =>
                context.go('/os/orders/${item.order.id}'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }
}
