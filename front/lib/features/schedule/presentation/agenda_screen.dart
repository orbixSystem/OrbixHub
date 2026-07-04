import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_ext.dart';
import '../domain/schedule_models.dart';
import 'schedule_providers.dart';

// ─── Formatters (locale já inicializado em main.dart) ────────────────────────
final _monthFmt = DateFormat('MMMM', 'pt_BR');
final _dayLongFmt = DateFormat("EEE', 'dd/MM/yyyy", 'pt_BR');
final _dtFmt = DateFormat('dd/MM HH:mm');

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ─── Screen ──────────────────────────────────────────────────────────────────

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  late int _viewYear;
  late int _viewMonth;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _viewYear = n.year;
    _viewMonth = n.month;
  }

  void _prevMonth() => setState(() {
        if (_viewMonth == 1) {
          _viewMonth = 12;
          _viewYear--;
        } else {
          _viewMonth--;
        }
      });

  void _nextMonth() => setState(() {
        if (_viewMonth == 12) {
          _viewMonth = 1;
          _viewYear++;
        } else {
          _viewMonth++;
        }
      });

  void _goToday() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    ref.read(agendaQueryProvider.notifier).setDate(today);
    setState(() {
      _viewYear = today.year;
      _viewMonth = today.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(agendaQueryProvider);
    final agendaAsync = ref.watch(agendaProvider);
    final monthDots = ref.watch(
      monthScheduledDaysProvider(MonthKey(year: _viewYear, month: _viewMonth)),
    );

    return Scaffold(
      backgroundColor: context.canvas,
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recarregar',
            onPressed: () {
              ref.invalidate(agendaProvider);
              ref.invalidate(monthScheduledDaysProvider);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Calendário (70%) ───────────────────────────────────────
            Expanded(
              flex: 7,
              child: _CalendarPanel(
                viewYear: _viewYear,
                viewMonth: _viewMonth,
                selectedDate: query.date,
                markedDays: monthDots.asData?.value ?? {},
                onPrev: _prevMonth,
                onNext: _nextMonth,
                onToday: _goToday,
                onSelectDay: (d) =>
                    ref.read(agendaQueryProvider.notifier).setDate(d),
              ),
            ),

            const SizedBox(width: 12),

            // ── Painel de agendamentos (30%) ───────────────────────────
            Expanded(
              flex: 3,
              child: _EventsPanel(
                selectedDate: query.date,
                agendaAsync: agendaAsync,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painel do calendário ─────────────────────────────────────────────────────

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.viewYear,
    required this.viewMonth,
    required this.selectedDate,
    required this.markedDays,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onSelectDay,
  });

  final int viewYear;
  final int viewMonth;
  final DateTime selectedDate;
  final Set<int> markedDays;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          _CalendarHeader(
            viewYear: viewYear,
            viewMonth: viewMonth,
            onPrev: onPrev,
            onNext: onNext,
            onToday: onToday,
          ),
          Divider(height: 1, color: context.borderColor),
          Expanded(
            child: _CalendarGrid(
              viewYear: viewYear,
              viewMonth: viewMonth,
              selectedDate: selectedDate,
              markedDays: markedDays,
              onSelectDay: onSelectDay,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cabeçalho do calendário ──────────────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.viewYear,
    required this.viewMonth,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final int viewYear;
  final int viewMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(
            _cap(_monthFmt.format(DateTime(viewYear, viewMonth))),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$viewYear',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: context.textSecondary,
            ),
          ),
          const Spacer(),
          // Botão Hoje
          OutlinedButton(
            onPressed: onToday,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textPrimary,
              side: BorderSide(color: context.borderColor),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: const Text('Hoje'),
          ),
          const SizedBox(width: 10),
          // Navegação
          _NavButton(icon: Icons.chevron_left, onPressed: onPrev, tooltip: 'Mês anterior'),
          const SizedBox(width: 4),
          _NavButton(icon: Icons.chevron_right, onPressed: onNext, tooltip: 'Próximo mês'),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.borderColor),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: context.textSecondary),
        ),
      ),
    );
  }
}

// ─── Grid do calendário ───────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.viewYear,
    required this.viewMonth,
    required this.selectedDate,
    required this.markedDays,
    required this.onSelectDay,
  });

  final int viewYear;
  final int viewMonth;
  final DateTime selectedDate;
  final Set<int> markedDays;
  final ValueChanged<DateTime> onSelectDay;

  static const _headers = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayDay =
        now.year == viewYear && now.month == viewMonth ? now.day : -1;
    final selDay =
        selectedDate.year == viewYear && selectedDate.month == viewMonth
            ? selectedDate.day
            : -1;

    // Dia 1 do mês e total de dias
    final first = DateTime(viewYear, viewMonth, 1);
    final daysInMonth = DateUtils.getDaysInMonth(viewYear, viewMonth);
    // offset domingo-primeiro: Dom=0, Seg=1, …, Sáb=6
    final startOffset = first.weekday % 7;
    // dias do mês anterior para preencher
    final prevMonthDays = DateUtils.getDaysInMonth(
      viewMonth == 1 ? viewYear - 1 : viewYear,
      viewMonth == 1 ? 12 : viewMonth - 1,
    );

    return Column(
      children: [
        // ── Cabeçalho dias da semana ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: _headers
                .map((h) => Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Divider(height: 1, color: context.borderColor),
        // ── Células dos dias (6 linhas fixas) ────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: List.generate(6, (week) {
                return Expanded(
                  child: Row(
                    children: List.generate(7, (dow) {
                      final cellIndex = week * 7 + dow;
                      final dayNum = cellIndex - startOffset + 1;

                      // Dia do mês anterior
                      if (dayNum < 1) {
                        final prevDay = prevMonthDays + dayNum;
                        return _DayCell(
                          label: '$prevDay',
                          isOtherMonth: true,
                          isToday: false,
                          isSelected: false,
                          hasDot: false,
                          onTap: () {
                            final pm = viewMonth == 1 ? 12 : viewMonth - 1;
                            final py = viewMonth == 1 ? viewYear - 1 : viewYear;
                            onSelectDay(DateTime(py, pm, prevDay));
                          },
                        );
                      }

                      // Dia do próximo mês
                      if (dayNum > daysInMonth) {
                        final nextDay = dayNum - daysInMonth;
                        return _DayCell(
                          label: '$nextDay',
                          isOtherMonth: true,
                          isToday: false,
                          isSelected: false,
                          hasDot: false,
                          onTap: () {
                            final nm = viewMonth == 12 ? 1 : viewMonth + 1;
                            final ny = viewMonth == 12 ? viewYear + 1 : viewYear;
                            onSelectDay(DateTime(ny, nm, nextDay));
                          },
                        );
                      }

                      return _DayCell(
                        label: '$dayNum',
                        isOtherMonth: false,
                        isToday: dayNum == todayDay,
                        isSelected: dayNum == selDay,
                        hasDot: markedDays.contains(dayNum),
                        onTap: () =>
                            onSelectDay(DateTime(viewYear, viewMonth, dayNum)),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Célula de dia ────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.isOtherMonth,
    required this.isToday,
    required this.isSelected,
    required this.hasDot,
    required this.onTap,
  });

  final String label;
  final bool isOtherMonth;
  final bool isToday;
  final bool isSelected;
  final bool hasDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final onAccent = context.onAccent;

    // Hierarquia visual: hoje > selecionado > padrão
    final Color bgColor;
    final Color textColor;
    final Border? border;

    if (isToday) {
      bgColor = accent;
      textColor = onAccent;
      border = null;
    } else if (isSelected) {
      bgColor = context.accentSubtle;
      textColor = context.onAccentSubtle;
      border = Border.all(color: accent, width: 1.5);
    } else {
      bgColor = Colors.transparent;
      textColor = isOtherMonth
          ? context.textDisabled
          : context.textPrimary;
      border = null;
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      (isToday || isSelected) && !isOtherMonth
                          ? FontWeight.w700
                          : FontWeight.w400,
                  color: textColor,
                ),
              ),
              const Spacer(),
              // Pontinhos de agendamento
              SizedBox(
                height: 10,
                child: hasDot && !isOtherMonth
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isToday ? onAccent.withValues(alpha: 0.85) : accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Painel de agendamentos (direita) ─────────────────────────────────────────

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({
    required this.selectedDate,
    required this.agendaAsync,
  });

  final DateTime selectedDate;
  final AsyncValue<AgendaResult> agendaAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agendamentos',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _cap(_dayLongFmt.format(selectedDate)),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.borderColor),
          Expanded(
            child: agendaAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro: $e',
                    style: TextStyle(color: context.textError, fontSize: 13),
                  ),
                ),
              ),
              data: (result) => result.items.isEmpty
                  ? _EmptyEvents(selectedDate: selectedDate)
                  : _EventsList(items: result.items),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista de eventos ─────────────────────────────────────────────────────────

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 40, color: context.textDisabled),
            const SizedBox(height: 10),
            Text(
              isToday
                  ? 'Nenhum serviço\nagendado para hoje.'
                  : 'Nenhum serviço\nagendado para este dia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({required this.items});

  final List<AgendaItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _EventCard(item: items[i]),
    );
  }
}

// ─── Card de evento ───────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item});

  final AgendaItem item;

  Color _statusColor(String status) => switch (status) {
        'em_execucao' => const Color(0xFFE8A302),
        'concluida' || 'entregue' => const Color(0xFF0E9F6E),
        'cancelada' => const Color(0xFFE5484D),
        _ => const Color(0xFF2E90FA),
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
        ? DateTime.tryParse(item.scheduledStart!)?.toLocal()
        : null;
    final end = item.scheduledEnd != null
        ? DateTime.tryParse(item.scheduledEnd!)?.toLocal()
        : null;
    final statusColor = _statusColor(item.order.status);

    return InkWell(
      onTap: () => context.go('/os/orders/${item.order.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderColor),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de status colorida
              Container(width: 4, color: statusColor),
              // Conteúdo
              Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // OS + status badge + seta
                    Row(
                      children: [
                        Text(
                          item.order.number,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: context.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _statusLabel(item.order.status),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: context.textDisabled),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Relato
                    if (item.name.isNotEmpty)
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: context.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Cliente
                    if (item.order.customerName != null) ...[
                      const SizedBox(height: 2),
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        value: item.order.customerName!,
                      ),
                    ],
                    // Veículo
                    if (item.order.subjectLabel != null) ...[
                      const SizedBox(height: 2),
                      _InfoRow(
                        icon: Icons.directions_car_outlined,
                        value: item.order.subjectLabel!,
                      ),
                    ],
                    const SizedBox(height: 4),
                    // Datas estimadas
                    if (start != null)
                      _InfoRow(
                        icon: Icons.play_circle_outline_rounded,
                        value: 'Início: ${_dtFmt.format(start)}',
                      ),
                    if (end != null) ...[
                      const SizedBox(height: 2),
                      _InfoRow(
                        icon: Icons.stop_circle_outlined,
                        value: 'Fim: ${_dtFmt.format(end)}',
                      ),
                    ],
                    // Responsável
                    if (item.assignedToName != null) ...[
                      const SizedBox(height: 2),
                      _InfoRow(
                        icon: Icons.engineering_outlined,
                        value: item.assignedToName!,
                      ),
                    ],
                    // Duração estimada
                    if (item.estimatedDuration != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.surfaceHigher,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fmtDuration(item.estimatedDuration!),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.textSecondary,
                          ),
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
      ),
    );
  }

  String _fmtDuration(int min) {
    if (min < 60) return '${min}min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h${m}min';
  }
}

// ─── Linha de info (ícone + label + valor) ────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: context.textSecondary),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
