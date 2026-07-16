import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/theme/app_colors.dart';
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
    // Offline: os horários são gravados no servidor (sem outbox) — a tela
    // explica em vez de mostrar um formulário que não salva.
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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          'Horários de funcionamento',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: hoursAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro ao carregar horários: $e',
              style: const TextStyle(color: AppColors.danger)),
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
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.danger,
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
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              widget.hours.dayLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isOpen ? AppColors.ink : AppColors.inkFaint,
              ),
            ),
          ),
          Switch(
            value: _isOpen,
            onChanged: widget.saving ? null : _toggleOpen,
            activeColor: AppColors.brand,
          ),
          const SizedBox(width: 8),
          if (_isOpen) ...[
            _TimeChip(
              label: _open,
              onTap: widget.saving ? null : () => _pickTime(true),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('–',
                  style: TextStyle(color: AppColors.inkMuted)),
            ),
            _TimeChip(
              label: _close,
              onTap: widget.saving ? null : () => _pickTime(false),
            ),
          ] else
            Text('Fechado',
                style: TextStyle(color: AppColors.inkFaint, fontSize: 13)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.brandTint,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.brandDeep,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
