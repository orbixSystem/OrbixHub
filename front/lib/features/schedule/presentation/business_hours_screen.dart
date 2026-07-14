import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../domain/schedule_models.dart';
import 'schedule_providers.dart';

/// Tela de edição dos horários de funcionamento (7 dias/semana).
/// Acessível via Settings → seção Agenda, ou rota /schedule/business-hours.
class BusinessHoursScreen extends ConsumerWidget {
  const BusinessHoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    if (ref.watch(isOfflineProvider)) {
      return Scaffold(
        backgroundColor: neu.base,
        body: const RequiresConnectionView(
          message: 'Os horários de funcionamento são salvos no servidor. '
              'Conecte-se à internet para vê-los e alterá-los.',
        ),
      );
    }
    final hoursAsync = ref.watch(businessHoursProvider);
    return Scaffold(
      backgroundColor: neu.base,
      appBar: AppBar(
        backgroundColor: neu.surface,
        foregroundColor: neu.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Horários de funcionamento',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: hoursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro ao carregar horários: $e',
                textAlign: TextAlign.center,
                style: TextStyle(color: neu.danger)),
          ),
        ),
        data: (hours) => _HoursList(hours: hours),
      ),
    );
  }
}

class _HoursList extends ConsumerStatefulWidget {
  const _HoursList({required this.hours});

  final List<BusinessHours> hours;

  @override
  ConsumerState<_HoursList> createState() => _HoursListState();
}

class _HoursListState extends ConsumerState<_HoursList> {
  late List<BusinessHours> _hours;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hours = List.from(widget.hours);
  }

  Future<void> _save(int day, BusinessHoursPatch patch) async {
    setState(() => _saving = true);
    try {
      final updated =
          await ref.read(scheduleRepositoryProvider).updateBusinessHours(day, patch);
      setState(() {
        _hours[day] = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${updated.dayLabel} atualizado.'),
            backgroundColor: context.neu.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: context.neu.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _hours.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _DayCard(
        hours: _hours[i],
        saving: _saving,
        onSave: (patch) => _save(i, patch),
      ),
    );
  }
}

class _DayCard extends StatefulWidget {
  const _DayCard({
    required this.hours,
    required this.saving,
    required this.onSave,
  });

  final BusinessHours hours;
  final bool saving;
  final ValueChanged<BusinessHoursPatch> onSave;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  late bool _isOpen;
  late String _open;
  late String _close;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.hours.isOpen;
    _open = widget.hours.openTime;
    _close = widget.hours.closeTime;
  }

  @override
  void didUpdateWidget(_DayCard old) {
    super.didUpdateWidget(old);
    if (old.hours != widget.hours) {
      _isOpen = widget.hours.isOpen;
      _open = widget.hours.openTime;
      _close = widget.hours.closeTime;
    }
  }

  Future<void> _pickTime(bool isOpen) async {
    final parts = (isOpen ? _open : _close).split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final str =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isOpen) {
        _open = str;
      } else {
        _close = str;
      }
    });
    widget.onSave(BusinessHoursPatch(
      isOpen: _isOpen,
      openTime: isOpen ? str : _open,
      closeTime: isOpen ? _close : str,
    ));
  }

  void _toggleOpen(bool v) {
    setState(() => _isOpen = v);
    widget.onSave(BusinessHoursPatch(
      isOpen: v,
      openTime: _open,
      closeTime: _close,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              widget.hours.dayLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _isOpen ? neu.ink : neu.inkFaint,
              ),
            ),
          ),
          Switch(
            value: _isOpen,
            onChanged: widget.saving ? null : _toggleOpen,
            activeThumbColor: neu.navy,
          ),
          const SizedBox(width: 8),
          if (_isOpen) ...[
            _TimeChip(
              label: _open,
              onTap: widget.saving ? null : () => _pickTime(true),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('–', style: TextStyle(color: neu.inkMuted)),
            ),
            _TimeChip(
              label: _close,
              onTap: widget.saving ? null : () => _pickTime(false),
            ),
          ] else
            Text('Fechado',
                style: TextStyle(color: neu.inkFaint, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: neu.accentTint,
          borderRadius: BorderRadius.circular(NeuTokens.rChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: neu.navy),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: neu.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
