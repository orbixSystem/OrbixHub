import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/ui.dart';
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
  static final _timeFmt = DateFormat('HH:mm');

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
    final ok = await showNeuConfirm(
      context,
      title: 'Remover agendamento?',
      message:
          'O técnico e o horário deste item serão removidos. Você pode '
          'agendar novamente depois.',
      confirmLabel: 'Remover',
    );
    if (!ok || !mounted) return;
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
    final neu = context.neu;
    final hasSchedule = widget.item.assignedTo != null ||
        widget.item.scheduledStart != null;

    return NeuDialog(
      title: 'Agendar item',
      maxWidth: 420,
      actions: [
        if (hasSchedule)
          NeuButton(
            label: 'Remover',
            kind: NeuButtonKind.danger,
            onPressed: _saving ? null : _unschedule,
          ),
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        NeuButton(
          label: 'Salvar',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: neu.inkMuted,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 18),

          // Técnico
          _label(neu, 'Técnico'),
          _dropdownShell(
            neu,
            DropdownButton<String?>(
              value: _assignedTo,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text('Sem atribuição',
                  style: TextStyle(color: neu.inkFaint)),
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
          ),
          const SizedBox(height: 16),

          // Data e hora
          _label(neu, 'Data e hora de início'),
          Row(
            children: [
              Expanded(
                child: NeuButton(
                  label: _startDate != null
                      ? _dateFmt.format(_startDate!)
                      : 'Data',
                  icon: Icons.calendar_today_outlined,
                  kind: NeuButtonKind.secondary,
                  expanded: true,
                  onPressed: _saving ? null : _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeuButton(
                  label: _startTime != null
                      ? _startTime!.format(context)
                      : 'Hora',
                  icon: Icons.access_time_outlined,
                  kind: NeuButtonKind.secondary,
                  expanded: true,
                  onPressed: _saving ? null : _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Duração
          _label(neu, 'Duração estimada'),
          _dropdownShell(
            neu,
            DropdownButton<int?>(
              value: _duration,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text('Não definida', style: TextStyle(color: neu.inkFaint)),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('— Não definida —')),
                ..._durations.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d < 60
                          ? '$d min'
                          : '${d ~/ 60}h${d % 60 != 0 ? ' ${d % 60}min' : ''}'),
                    )),
              ],
              onChanged: _saving ? null : (v) => setState(() => _duration = v),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: neu.danger, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _label(NeuTokens neu, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: neu.inkMuted,
          ),
        ),
      );

  Widget _dropdownShell(NeuTokens neu, Widget child) => NeuSurface(
        elevation: NeuElevation.inset,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: DropdownButtonHideUnderline(child: child),
      );
}
