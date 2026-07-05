import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../os/domain/os_models.dart';
import '../domain/schedule_models.dart';
import 'schedule_providers.dart';

/// Dialog para atribuir técnico e agendar um item de OS.
/// Chame com [showItemAssignDialog].
Future<bool?> showItemAssignDialog(
  BuildContext context, {
  required String orderId,
  required OrderItem item,
  required List<MemberOption> members,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => ItemAssignDialog(
        orderId: orderId,
        item: item,
        members: members,
      ),
    );

class ItemAssignDialog extends ConsumerStatefulWidget {
  const ItemAssignDialog({
    super.key,
    required this.orderId,
    required this.item,
    required this.members,
  });

  final String orderId;
  final OrderItem item;
  final List<MemberOption> members;

  @override
  ConsumerState<ItemAssignDialog> createState() => _ItemAssignDialogState();
}

class _ItemAssignDialogState extends ConsumerState<ItemAssignDialog> {
  String? _assignedTo;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  int? _duration; // minutes
  bool _saving = false;
  String? _error;

  static const _durations = [30, 60, 90, 120, 180, 240];
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _assignedTo = widget.item.assignedTo;
    if (widget.item.scheduledStart != null) {
      final dt = DateTime.tryParse(widget.item.scheduledStart!);
      if (dt != null) {
        final local = dt.toLocal();
        _startDate = DateTime(local.year, local.month, local.day);
        _startTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
    }
    _duration = widget.item.estimatedDuration;
  }

  String get _scheduledStartIso {
    if (_startDate == null || _startTime == null) return '';
    final dt = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    return dt.toUtc().toIso8601String();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final iso = _scheduledStartIso.isNotEmpty ? _scheduledStartIso : null;
      await ref.read(scheduleRepositoryProvider).scheduleItem(
            widget.orderId,
            widget.item.id,
            ScheduleItemDraft(
              assignedTo: _assignedTo,
              scheduledStart: iso,
              estimatedDuration: _duration,
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _unschedule() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .unscheduleItem(widget.orderId, widget.item.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSchedule = widget.item.assignedTo != null ||
        widget.item.scheduledStart != null;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Agendar item',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                  fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Técnico
            const Text('Técnico',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String?>(
              initialValue: _assignedTo,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Sem atribuição'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Sem atribuição —')),
                ...widget.members.map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name),
                    )),
              ],
              onChanged:
                  _saving ? null : (v) => setState(() => _assignedTo = v),
            ),

            const SizedBox(height: 16),

            // Data e hora
            const Text('Data e hora de início',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 14),
                    label: Text(_startDate != null
                        ? _dateFmt.format(_startDate!)
                        : 'Data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickTime,
                    icon: const Icon(Icons.access_time_outlined, size: 14),
                    label: Text(_startTime != null
                        ? _startTime!.format(context)
                        : 'Hora'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Duração
            const Text('Duração estimada',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted)),
            const SizedBox(height: 4),
            DropdownButtonFormField<int?>(
              initialValue: _duration,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Não definida'),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('— Não definida —')),
                ..._durations.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(
                          d < 60 ? '$d min' : '${d ~/ 60}h${d % 60 != 0 ? ' ${d % 60}min' : ''}'),
                    )),
              ],
              onChanged:
                  _saving ? null : (v) => setState(() => _duration = v),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (hasSchedule)
          TextButton(
            onPressed: _saving ? null : _unschedule,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remover'),
          )
        else
          const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Salvar'),
            ),
          ],
        ),
      ],
    );
  }
}
