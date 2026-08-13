import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../os/domain/os_models.dart';
import '../../os/presentation/os_providers.dart';
import '../../os/presentation/os_status.dart';

/// Abre um modal read-only com o relatório detalhado de uma OS. `orderId` é o
/// id da OS (vem de `SubjectHistoryEntry.id` quando `kind == 'os'`). Busca o
/// detalhe completo via [orderProvider] e desenha um relatório bonito no
/// design system (cabeçalho + blocos + itens + linha do tempo).
Future<void> showOsReportDialog(BuildContext context, String orderId) {
  return showNeuDialog<void>(
    context,
    dialog: NeuDialog(
      title: 'Relatório da OS',
      maxWidth: 640,
      child: _OsReportBody(orderId: orderId),
    ),
  );
}

class _OsReportBody extends ConsumerWidget {
  const _OsReportBody({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    return orderAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: NeuEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Não foi possível carregar a OS',
          message: 'Tente novamente em instantes. Se persistir, verifique sua '
              'conexão ou fale com o suporte.',
        ),
      ),
      data: (order) => _OsReport(order: order),
    );
  }
}

class _OsReport extends StatelessWidget {
  const _OsReport({required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final diagnosis = order.diagnosis?.trim();
    final scheduled = _scheduledLabel(order);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho: número grande + status.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'OS ${order.number}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OsStatusChip(status: order.status),
          ],
        ),
        if (scheduled != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 14, color: neu.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  scheduled,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Blocos: cliente / veículo / responsável.
        _FactsWrap(
          facts: [
            (Icons.person_outline, 'Cliente', order.customerName),
            (Icons.directions_car_outlined, 'Veículo', order.subjectLabel),
            (Icons.engineering_outlined, 'Responsável', order.assignedTo),
          ],
        ),

        // Relato do cliente.
        if ((order.complaint?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          _TextBlock(
            icon: Icons.report_gmailerrorred_outlined,
            label: 'Relato',
            value: order.complaint!.trim(),
          ),
        ],

        // Diagnóstico.
        if (diagnosis != null && diagnosis.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TextBlock(
            icon: Icons.build_circle_outlined,
            label: 'Diagnóstico',
            value: diagnosis,
          ),
        ],

        // Itens + total.
        const SizedBox(height: 20),
        _SectionTitle(icon: Icons.receipt_long_outlined, label: 'Itens'),
        const SizedBox(height: 10),
        _ItemsBlock(items: order.items, total: order.total),

        // Linha do tempo.
        if (order.events.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(icon: Icons.history, label: 'Linha do tempo'),
          const SizedBox(height: 10),
          _Timeline(events: order.events),
        ],
      ],
    );
  }

  /// Rótulo curto da previsão (início → fim) quando houver datas.
  static String? _scheduledLabel(ServiceOrder order) {
    final start = _fmtTimestamp(order.scheduledStart);
    final end = _fmtTimestamp(order.scheduledEnd);
    if (start == null && end == null) return null;
    if (start != null && end != null) return 'Previsão: $start → $end';
    return 'Previsão: ${start ?? end}';
  }
}

/// Grade de fatos rotulados (label em inkMuted, valor em ink com ellipsis).
class _FactsWrap extends StatelessWidget {
  const _FactsWrap({required this.facts});

  final List<(IconData, String, String?)> facts;

  @override
  Widget build(BuildContext context) {
    // Mobile: um por linha; maior: dois por linha.
    final columns = context.isMobile ? 1 : 2;
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final width = columns == 1
            ? c.maxWidth
            : (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (icon, label, value) in facts)
              SizedBox(
                width: width,
                child: _Fact(icon: icon, label: label, value: value),
              ),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final filled = value != null && value!.trim().isNotEmpty;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: neu.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  filled ? value!.trim() : '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filled ? neu.ink : neu.inkFaint,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloco de texto longo (relato / diagnóstico) — cavado, com rótulo e valor.
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: neu.inkFaint),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: neu.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: neu.ink, fontSize: 14.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        Icon(icon, size: 18, color: neu.navy),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: neu.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Lista de itens + total destacado.
class _ItemsBlock extends StatelessWidget {
  const _ItemsBlock({required this.items, required this.total});

  final List<OrderItem> items;
  final String? total;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Nenhum item lançado nesta OS.',
                style: TextStyle(color: neu.inkMuted, fontSize: 14),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: neu.line),
              _ItemRow(item: items[i]),
            ],
          Divider(height: 1, color: neu.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  money(total),
                  style: TextStyle(
                    color: neu.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isService = item.kind == 'service';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isService ? Icons.handyman_outlined : Icons.inventory_2_outlined,
            size: 18,
            color: neu.inkFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtQty(item.quantity)} × ${money(item.unitPrice)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(item.total),
            style: TextStyle(
              color: neu.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha do tempo compacta: ponto colorido por tipo + rótulo + data.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<OrderEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final OrderEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final color = _dotColor(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : neu.line,
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_kindIcon(), size: 14, color: color),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : neu.line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (event.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtTimestamp(event.createdAt) ?? '',
                      style: TextStyle(color: neu.inkMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rótulo: usa `message` quando há; senão deriva de `status_change`/`kind`.
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

  Color _dotColor(BuildContext context) {
    final neu = context.neu;
    switch (event.kind) {
      case 'status_change':
        return event.statusSnapshot == null
            ? neu.navy
            : osStatusInk(
                event.statusSnapshot!, Theme.of(context).brightness);
      case 'created':
        return neu.success;
      case 'photo':
        return neu.glyphs[1];
      default:
        return neu.inkMuted;
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
      default:
        return Icons.chat_bubble_outline;
    }
  }
}

/// Formata uma quantidade decimal serializada ("1", "2.50") em algo enxuto
/// ("1", "2,5"). Null/inválido → o texto original ou "1".
String _fmtQty(String raw) {
  final v = double.tryParse(raw);
  if (v == null) return raw;
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}

/// Timestamp curto a partir de um ISO-8601 → `dd/MM/yyyy HH:mm` (local). Null
/// ou inválido → null (para o chamador esconder a linha).
String? _fmtTimestamp(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
