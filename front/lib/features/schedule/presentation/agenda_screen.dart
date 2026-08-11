import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../../os/domain/os_models.dart';
import '../../os/presentation/os_providers.dart';
import '../../os/presentation/os_schedule_dialog.dart';
import '../domain/schedule_models.dart';
import 'schedule_providers.dart';

// ─── Formatters (locale já inicializado em main.dart) ────────────────────────
final _monthFmt = DateFormat('MMMM', 'pt_BR');
final _monthAbbrFmt = DateFormat('MMM', 'pt_BR');
final _dayLongFmt = DateFormat("EEE', 'dd/MM/yyyy", 'pt_BR');

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Abreviação capitalizada do mês (1..12), sem ponto final. Ex.: "Jan", "Fev".
String _monthAbbr(int month) =>
    _cap(_monthAbbrFmt.format(DateTime(2020, month)).replaceAll('.', ''));

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

  bool _canWrite() =>
      ref.read(sessionControllerProvider).meOrNull?.hasPermission('os.write') ??
      false;

  /// Recarrega as duas lentes: a lista do dia e a contagem do mês.
  void _recarregarAgenda() {
    ref.invalidate(agendaProvider);
    ref.invalidate(monthScheduledDaysProvider);
  }

  /// Reagenda uma OS já na agenda — o diálogo é do módulo OS (dono das datas).
  Future<void> _reagendar(AgendaItem item) async {
    final ServiceOrder order;
    try {
      order = await ref.read(osRepositoryProvider).getOrder(item.order.id);
    } on Object catch (e) {
      if (mounted) {
        showNeuErrorSnackBar(
            context, e is AppException ? e.message : 'Não foi possível abrir a OS.');
      }
      return;
    }
    if (!mounted) return;
    final ok = await showOsScheduleDialog(context, ref, order: order);
    if (ok) _recarregarAgenda();
  }

  /// Agenda uma OS que ainda não tem data: escolhe entre as abertas e define
  /// a janela. Sem isso a agenda era só de leitura.
  Future<void> _agendar() async {
    final order = await showOsPickerParaAgendar(context, ref);
    if (order == null || !mounted) return;
    final ok = await showOsScheduleDialog(context, ref, order: order);
    if (ok) _recarregarAgenda();
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

  /// Aplica o mês/ano escolhidos no seletor. O resto da tela reage sozinho
  /// (providers dependem de `_viewYear`/`_viewMonth`).
  void _pickMonthYear(int year, int month) => setState(() {
        _viewYear = year;
        _viewMonth = month;
      });

  void _refresh() {
    ref.invalidate(agendaProvider);
    ref.invalidate(monthScheduledDaysProvider);
  }

  /// Abre o seletor de mês/ano (grade 12 meses + navegação de ano).
  void _openMonthYearPicker() {
    showNeuDialog<void>(
      context,
      dialog: NeuDialog(
        title: 'Selecionar mês',
        maxWidth: 380,
        child: _MonthYearPicker(
          initialYear: _viewYear,
          selectedYear: _viewYear,
          selectedMonth: _viewMonth,
          onPick: (year, month) {
            Navigator.of(context).maybePop();
            _pickMonthYear(year, month);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agenda (módulo schedule) não tem camada offline — consulta o servidor.
    if (ref.watch(isOfflineProvider)) {
      return const RequiresConnectionView(
        message: 'A agenda é montada no servidor. Conecte-se à internet para '
            'ver e alterar os agendamentos.',
      );
    }
    final query = ref.watch(agendaQueryProvider);
    final agendaAsync = ref.watch(agendaProvider);
    final monthDots = ref.watch(
      monthScheduledDaysProvider(MonthKey(year: _viewYear, month: _viewMonth)),
    );

    final calendar = _CalendarPanel(
      viewYear: _viewYear,
      viewMonth: _viewMonth,
      selectedDate: query.date,
      countByDay: monthDots.asData?.value ?? const {},
      onPrev: _prevMonth,
      onNext: _nextMonth,
      onToday: _goToday,
      onRefresh: _refresh,
      onOpenPicker: _openMonthYearPicker,
      onSelectDay: (d) => ref.read(agendaQueryProvider.notifier).setDate(d),
    );

    final events = _EventsPanel(
      selectedDate: query.date,
      agendaAsync: agendaAsync,
      canWrite: _canWrite(),
      onAgendar: _agendar,
      onReagendar: _reagendar,
    );

    // Alvos de tutorial embrulhando as variáveis: `calendario` e `eventos` são
    // usados no layout de desktop (duas colunas) E no de celular (empilhado), então
    // um alvo aqui vale nos dois sem duplicar conteúdo.
    final calendarioAlvo =
        CoachTarget('agenda.calendario', child: calendar);
    final eventosAlvo = CoachTarget('agenda.eventos', child: events);

    final body = context.isMobile
        // Mobile: calendário em cima (altura fixa) + agenda do dia embaixo.
        ? Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 372, child: calendarioAlvo),
                const SizedBox(height: 12),
                Expanded(child: eventosAlvo),
              ],
            ),
          )
        // Desktop/tablet: duas colunas — calendário à esquerda, agenda à direita.
        // Em telas altas, limita a altura (senão as células do mês ficam
        // gigantes); em notebooks usa a altura disponível. Alinha ao topo.
        : LayoutBuilder(
            builder: (context, c) {
              const maxH = 680.0;
              final avail = c.maxHeight - 32; // desconta o padding vertical
              final h = (avail > maxH ? maxH : avail).clamp(280.0, maxH);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1500),
                    child: SizedBox(
                      height: h,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: calendarioAlvo),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: eventosAlvo),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );

    return ColoredBox(color: context.neu.base, child: body);
  }
}

// ─── Painel do calendário ─────────────────────────────────────────────────────

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.viewYear,
    required this.viewMonth,
    required this.selectedDate,
    required this.countByDay,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onRefresh,
    required this.onOpenPicker,
    required this.onSelectDay,
  });

  final int viewYear;
  final int viewMonth;
  final DateTime selectedDate;
  final Map<int, int> countByDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onRefresh;
  final VoidCallback onOpenPicker;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: EdgeInsets.zero,
      radius: NeuTokens.rPanel,
      child: Column(
        children: [
          _CalendarHeader(
            viewYear: viewYear,
            viewMonth: viewMonth,
            onPrev: onPrev,
            onNext: onNext,
            onToday: onToday,
            onRefresh: onRefresh,
            onOpenPicker: onOpenPicker,
          ),
          Divider(height: 1, color: neu.line),
          Expanded(
            child: _CalendarGrid(
              viewYear: viewYear,
              viewMonth: viewMonth,
              selectedDate: selectedDate,
              countByDay: countByDay,
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
    required this.onRefresh,
    required this.onOpenPicker,
  });

  final int viewYear;
  final int viewMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onRefresh;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isMobile = context.isMobile;

    // Título tocável (mês + ano) → abre o seletor de mês/ano.
    final title = InkWell(
      onTap: onOpenPicker,
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _cap(_monthFmt.format(DateTime(viewYear, viewMonth))),
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 19,
                        fontWeight: FontWeight.w800,
                        color: neu.ink,
                      ),
                    ),
                    TextSpan(
                      text: '  $viewYear',
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 19,
                        fontWeight: FontWeight.w400,
                        color: neu.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 20, color: neu.inkMuted),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 10 : 16, 12, isMobile ? 8 : 12, 12),
      child: Row(
        children: [
          // Expanded (não Flexible+Spacer) → o título fica com todo o espaço
          // restante e não corta ("Julho 2026" inteiro no mobile).
          Expanded(child: title),
          const SizedBox(width: 8),
          // "Hoje": botão rotulado no desktop, ícone compacto no mobile.
          if (isMobile)
            NeuIconButton(
              icon: Icons.today_rounded,
              tooltip: 'Hoje',
              size: 40,
              onPressed: onToday,
            )
          else ...[
            NeuButton(
              label: 'Hoje',
              icon: Icons.today_rounded,
              kind: NeuButtonKind.secondary,
              onPressed: onToday,
            ),
            const SizedBox(width: 8),
            NeuIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Recarregar',
              size: 44,
              onPressed: onRefresh,
            ),
          ],
          const SizedBox(width: 8),
          NeuIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Mês anterior',
            size: isMobile ? 40 : 44,
            onPressed: onPrev,
          ),
          const SizedBox(width: 6),
          NeuIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Próximo mês',
            size: isMobile ? 40 : 44,
            onPressed: onNext,
          ),
        ],
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
    required this.countByDay,
    required this.onSelectDay,
  });

  final int viewYear;
  final int viewMonth;
  final DateTime selectedDate;
  final Map<int, int> countByDay;
  final ValueChanged<DateTime> onSelectDay;

  static const _headers = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
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
                            color: neu.inkMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Divider(height: 1, color: neu.line),
        // ── Células dos dias (6 linhas fixas) ────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
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
                          count: 0,
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
                          count: 0,
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
                        count: countByDay[dayNum] ?? 0,
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
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool isOtherMonth;
  final bool isToday;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    // Hierarquia visual: selecionado (preenchido navy) > hoje (anel navy) > padrão.
    final Color bgColor;
    final Color textColor;
    final Border? border;

    if (isSelected) {
      bgColor = neu.navy;
      textColor = neu.onNavy;
      border = null;
    } else if (isToday) {
      bgColor = Colors.transparent;
      textColor = neu.navy;
      border = Border.all(color: neu.navy, width: 1.5);
    } else {
      bgColor = Colors.transparent;
      textColor = isOtherMonth ? neu.inkFaint : neu.ink;
      border = null;
    }

    final Color dotColor;
    if (isSelected) {
      dotColor = neu.onNavy.withValues(alpha: 0.9);
    } else if (isToday) {
      dotColor = neu.navy;
    } else {
      dotColor = neu.accent;
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(3),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(NeuTokens.rChip),
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: (isToday || isSelected) && !isOtherMonth
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
              const Spacer(),
              // QUANTAS OS ocupam o dia. Um pontinho dizia só "tem alguma
              // coisa" — o mesmo desenho para um dia tranquilo e para um dia
              // lotado, que é exatamente a diferença que interessa na hora de
              // decidir onde encaixar o próximo serviço.
              SizedBox(
                height: 12,
                child: count > 0 && !isOtherMonth
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: dotColor.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: dotColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 2),
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
    required this.canWrite,
    required this.onAgendar,
    required this.onReagendar,
  });

  final DateTime selectedDate;
  final AsyncValue<AgendaResult> agendaAsync;

  /// `os.write` — a agenda só LÊ a OS; quem agenda é o módulo dono dela.
  final bool canWrite;
  final VoidCallback onAgendar;
  final void Function(AgendaItem) onReagendar;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: EdgeInsets.zero,
      radius: NeuTokens.rPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agendamentos',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: neu.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _cap(_dayLongFmt.format(selectedDate)),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: neu.inkMuted,
                  ),
                ),
                // Filtro por responsável: existia no estado (`setAssignedTo`)
                // e nunca era acionado por nada — "quais carros são do Carlos
                // hoje?" não tinha resposta na tela.
                const SizedBox(height: 12),
                const _FiltroResponsavel(),
                // A agenda era só de leitura: para marcar uma data era preciso
                // achar a OS, abrir e entrar em Editar. Agendar a partir do dia
                // que se está olhando é o caminho natural.
                if (canWrite) ...[
                  const SizedBox(height: 10),
                  NeuButton(
                    label: 'Agendar OS',
                    icon: Icons.event_available_outlined,
                    expanded: true,
                    onPressed: onAgendar,
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: neu.line),
          Expanded(
            child: agendaAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro: $e',
                    style: TextStyle(color: neu.danger, fontSize: 13),
                  ),
                ),
              ),
              data: (result) => result.items.isEmpty
                  ? NeuEmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Nenhum agendamento',
                      message: canWrite
                          ? 'Nenhum carro previsto para este dia. Use '
                              '"Agendar OS" para marcar a entrada de um.'
                          : 'Não há serviços agendados para este dia.',
                    )
                  : _EventsList(items: result.items, onReagendar: onReagendar),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista de eventos ─────────────────────────────────────────────────────────

class _EventsList extends StatelessWidget {
  const _EventsList({required this.items, this.onReagendar});

  final List<AgendaItem> items;
  final void Function(AgendaItem)? onReagendar;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _EventCard(
        item: items[i],
        index: i,
        onReagendar:
            onReagendar == null ? null : () => onReagendar!(items[i]),
      ),
    );
  }
}

// ─── Card de evento ───────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.item,
    required this.index,
    this.onReagendar,
  });

  final AgendaItem item;
  final int index;

  /// `null` sem `os.write` — quem só lê a agenda não reagenda.
  final VoidCallback? onReagendar;

  static String _dia(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}';
  }

  /// Cor + tint semânticos do status (design system).
  (Color, Color) _statusColors(NeuTokens neu, String status) =>
      switch (status) {
        'em_execucao' => (neu.warning, neu.warningTint),
        'concluida' || 'entregue' => (neu.success, neu.successTint),
        'cancelada' => (neu.danger, neu.dangerTint),
        _ => (neu.info, neu.infoTint),
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
    final neu = context.neu;
    final start = item.scheduledStart != null
        ? DateTime.tryParse(item.scheduledStart!)?.toLocal()
        : null;
    final end = item.scheduledEnd != null
        ? DateTime.tryParse(item.scheduledEnd!)?.toLocal()
        : null;
    final (statusColor, statusTint) = _statusColors(neu, item.order.status);
    final identidade = [
      ?item.order.customerName,
      if ((item.order.subjectLabel ?? '').isNotEmpty) item.order.subjectLabel!,
    ].join(' · ');
    // Mesma leitura da lista de OS: janela "10/08 → 15/08"; sem fim, um dia só.
    final janela = start == null
        ? 'Sem data'
        : (end == null || _dia(end) == _dia(start)
            ? _dia(start)
            : '${_dia(start)} → ${_dia(end)}');
    // Atraso só existe em OS viva — entregue/cancelada não estoura prazo.
    final viva = item.order.status != 'entregue' &&
        item.order.status != 'cancelada' &&
        item.order.status != 'concluida';
    final atrasada = viva && end != null && end.isBefore(DateTime.now());

    return NeuCard(
      padding: const EdgeInsets.all(12),
      radius: NeuTokens.rCard,
      // Rota do detalhe da OS é /m/os/:id (gated pelo módulo). O caminho
      // antigo '/os/orders/:id' não existe no router — clicar dava erro.
      onTap: () => context.go('/m/os/${item.order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: glyph + número da OS + status + seta.
          Row(
            children: [
              NeuIconChip.glyph(
                context,
                icon: item.kind == 'part'
                    ? Icons.inventory_2_outlined
                    : Icons.build_rounded,
                index: index,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.order.number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: neu.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    NeuStatusChip(
                      label: _statusLabel(item.order.status),
                      color: statusColor,
                      tint: statusTint,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: neu.inkFaint),
            ],
          ),
          // Relato / nome do serviço.
          if (item.name.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: neu.ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Cliente e veículo numa linha só: juntos IDENTIFICAM o carro, e
          // separados em duas linhas com ícone cada só alongavam o card.
          if (identidade.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.directions_car_outlined,
              value: identidade,
            ),
          ],
          // A JANELA (entra → sai), não duas linhas de data. A "duração
          // estimada" saiu: numa OS de vários dias virava "120h", que não diz
          // nada sobre o serviço — a janela é a informação real.
          const SizedBox(height: 4),
          _InfoRow(
            icon: atrasada ? Icons.event_busy_outlined : Icons.event_outlined,
            value: atrasada ? '$janela · atrasada' : janela,
            color: atrasada ? neu.danger : null,
            forte: atrasada,
          ),
          if (item.assignedToName != null) ...[
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.engineering_outlined,
              value: item.assignedToName!,
            ),
          ],
          if (onReagendar != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: NeuButton(
                label: 'Reagendar',
                icon: Icons.edit_calendar_outlined,
                kind: NeuButtonKind.secondary,
                onPressed: onReagendar,
              ),
            ),
          ],
        ],
      ),
    );
  }

}

// ─── Linha de info (ícone + valor) ────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.value,
    this.color,
    this.forte = false,
  });

  final IconData icon;
  final String value;
  final Color? color;
  final bool forte;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      children: [
        Icon(icon, size: 13, color: color ?? neu.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color ?? neu.inkMuted,
              fontWeight: forte ? FontWeight.w700 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Seletor de mês/ano ───────────────────────────────────────────────────────

/// Conteúdo do diálogo de seleção de mês/ano: navegação de ano por setas ‹ ›
/// e grade 3×4 dos 12 meses. Toca num mês → aplica (ano + mês) via [onPick].
class _MonthYearPicker extends StatefulWidget {
  const _MonthYearPicker({
    required this.initialYear,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onPick,
  });

  final int initialYear;
  final int selectedYear;
  final int selectedMonth;
  final void Function(int year, int month) onPick;

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Navegação de ano.
        Row(
          children: [
            NeuIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Ano anterior',
              size: 44,
              onPressed: () => setState(() => _year--),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_year',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: neu.ink,
                  ),
                ),
              ),
            ),
            NeuIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Próximo ano',
              size: 44,
              onPressed: () => setState(() => _year++),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Grade 3×4 de meses.
        Column(
          children: List.generate(4, (row) {
            return Padding(
              padding: EdgeInsets.only(bottom: row < 3 ? 10 : 0),
              child: Row(
                children: List.generate(3, (col) {
                  final month = row * 3 + col + 1;
                  final isSelected =
                      month == widget.selectedMonth && _year == widget.selectedYear;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: col < 2 ? 10 : 0),
                      child: _MonthChip(
                        label: _monthAbbr(month),
                        isSelected: isSelected,
                        onTap: () => widget.onPick(_year, month),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: NeuSurface(
          elevation: isSelected ? NeuElevation.flat : NeuElevation.raised,
          radius: NeuTokens.rChip,
          color: isSelected ? neu.navy : neu.surface,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? neu.onNavy : neu.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtro "quem é o responsável" da agenda. Some quando a oficina não tem
/// equipe cadastrada — um seletor com uma opção só é ruído.
class _FiltroResponsavel extends ConsumerWidget {
  const _FiltroResponsavel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final membros = ref.watch(agendaMembersProvider).value ?? const [];
    if (membros.isEmpty) return const SizedBox.shrink();
    final selecionado = ref.watch(agendaQueryProvider).assignedTo;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String?>(
        initialValue: selecionado,
        isExpanded: true,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
        dropdownColor: neu.surface,
        icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
        style: TextStyle(color: neu.ink, fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          prefixIcon: Icon(Icons.engineering_outlined, size: 18),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Toda a equipe')),
          for (final m in membros)
            DropdownMenuItem(value: m.id, child: Text(m.name)),
        ],
        onChanged: (v) =>
            ref.read(agendaQueryProvider.notifier).setAssignedTo(v),
      ),
    );
  }
}
