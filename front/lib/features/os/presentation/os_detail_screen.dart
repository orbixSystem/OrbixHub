import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/cnpj.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../domain/os_models.dart';
import 'item_picker_dialog.dart';
import 'order_edit_dialog.dart';
import 'os_pdf.dart';
import 'os_providers.dart';
import 'os_status.dart';

const _maxContentWidth = 1200.0;

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

  bool _hasModule(WidgetRef ref, String key) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasModule(key);
  }

  /// Identificação da empresa (tenant ativo) p/ exibir e imprimir na OS.
  OsCompany? _company(WidgetRef ref) {
    final s = ref.read(sessionControllerProvider);
    if (s is! SessionAuthenticated) return null;
    final t = s.me.activeTenant;
    if (t == null) return null;
    return OsCompany(
      name: t.name,
      legalName: t.legalName,
      cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final canWrite = _has(ref, 'os.write');
    final canApprove = _has(ref, 'os.approve');
    final canRead = _has(ref, 'os.read');
    // "Emitir NF" só aparece com o módulo fiscal habilitado E a permissão de
    // emissão — o backend é a verdade (aqui só refletimos para UX).
    final canIssueInvoice =
        _hasModule(ref, 'invoice') && _has(ref, 'invoice.issue');
    final company = _company(ref);
    // Logo do tenant para exibir no cabeçalho da OS.
    final logoUrl = ref
        .watch(settingsControllerProvider)
        .whenOrNull(data: (b) => b.company['logoUrl'] as String?);

    return orderAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is AppException ? e.message : 'Erro ao carregar a OS.'),
      ),
      data: (order) {
        // Estado terminal (cancelada/entregue) trava a edição de conteúdo —
        // espelha o backend; cancelada volta a editar reabrindo-a.
        final terminal = osIsTerminal(order.status);
        final canEdit = canWrite && !terminal;
        final hasTracking =
            order.publicToken != null && order.publicToken!.isNotEmpty;

        // Seções da coluna PRINCIPAL e da LATERAL (desktop). No mobile tudo
        // empilha numa coluna só, em ordem sensata.
        final mainSections = <Widget>[
          _DiagnosisSection(order: order, canWrite: canEdit),
          _ItemsSection(order: order, canWrite: canEdit),
          _TotalsCard(order: order),
          _TimelineSection(order: order, canWrite: canEdit),
        ];
        final asideSections = <Widget>[
          if (hasTracking) _TrackingLinkCard(token: order.publicToken!),
          _PhotosSection(order: order, canWrite: canEdit),
        ];

        final isDesktop = context.isDesktop;
        final body = isDesktop
            // IntrinsicHeight + stretch: as duas colunas ficam da mesma altura
            // (a principal manda), e a última seção da lateral (fotos) é
            // esticada para preencher — sem "buraco" no fim da coluna.
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _stack(mainSections)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _asideStack(asideSections)),
                  ],
                ),
              )
            : _stack([...mainSections, ...asideSections]);

        return _Bounded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 28 : 16,
              12,
              isDesktop ? 28 : 16,
              28,
            ),
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
                company: company,
                logoUrl: logoUrl,
                canEdit: canEdit,
                canRead: canRead,
                onEdit: () => _edit(context, ref, order),
                onApplyTemplate: () => _applyTemplate(context, ref, order),
                onPrint: () => _printOrder(context, order, company),
                invoiceAction: canIssueInvoice
                    ? _IssueInvoiceButton(orderId: order.id)
                    : null,
              ),
              const SizedBox(height: 20),
              // Painel de workflow: mostra em qual etapa a OS está (stepper) e
              // qual o PRÓXIMO passo, com a ação principal em destaque.
              _WorkflowPanel(
                order: order,
                canWrite: canWrite,
                canApprove: canApprove,
                onChange: (target) =>
                    _changeStatus(context, ref, order, target),
              ),
              const SizedBox(height: 24),
              body,
            ],
          ),
        );
      },
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
    // Ações que travam/encerram a OS pedem confirmação (sem volta fácil).
    if (target == 'cancelada') {
      final ok = await showNeuConfirm(
        context,
        title: 'Cancelar OS?',
        message:
            'A OS ${order.number} será cancelada e a edição bloqueada. '
            'Você poderá reabri-la depois, mas os dados param aqui.',
        confirmLabel: 'Cancelar OS',
      );
      if (!ok || !context.mounted) return;
    } else if (target == 'entregue') {
      final ok = await showNeuConfirm(
        context,
        title: 'Confirmar entrega?',
        message:
            'A OS será marcada como entregue e ficará somente leitura.',
        confirmLabel: 'Confirmar entrega',
        danger: false,
        icon: Icons.local_shipping_outlined,
      );
      if (!ok || !context.mounted) return;
    }
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

  Future<void> _applyTemplate(
    BuildContext context,
    WidgetRef ref,
    ServiceOrder order,
  ) async {
    final repo = ref.read(osRepositoryProvider);
    List<OsTemplate> templates;
    try {
      templates = await repo.listTemplates();
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!context.mounted) return;
    final chosen = await _TemplatePickerDialog.show(context, templates);
    if (chosen == null) return;
    try {
      await repo.applyTemplate(order.id, chosen.id);
      ref.invalidate(orderProvider(orderId));
      ref.invalidate(orderListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Template aplicado.')));
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _printOrder(
    BuildContext context,
    ServiceOrder order,
    OsCompany? company,
  ) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => buildOsPdf(order, format, company: company),
      );
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o PDF.')),
        );
      }
    }
  }
}

/// Empilha as seções da coluna LATERAL como [_stack], mas ESTICA a última
/// (fotos) para ocupar a altura restante — evita o "buraco" no fim da coluna
/// quando a coluna principal é mais alta.
Widget _asideStack(List<Widget> sections) {
  if (sections.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < sections.length - 1; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        sections[i],
      ],
      if (sections.length > 1) const SizedBox(height: 20),
      Expanded(child: sections.last),
    ],
  );
}

/// Empilha seções com espaçamento padrão de 20px entre elas.
Widget _stack(List<Widget> sections) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        sections[i],
      ],
    ],
  );
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
    required this.company,
    required this.canEdit,
    required this.canRead,
    required this.onEdit,
    required this.onApplyTemplate,
    required this.onPrint,
    this.logoUrl,
    this.invoiceAction,
  });

  final ServiceOrder order;
  final OsCompany? company;
  final String? logoUrl;
  final bool canEdit;
  final bool canRead;
  final VoidCallback onEdit;
  final VoidCallback onApplyTemplate;
  final VoidCallback onPrint;

  /// Ação opcional "Emitir NF" (só com módulo fiscal + permissão).
  final Widget? invoiceAction;

  /// Formata uma data ISO-8601 para dd/MM/yyyy (pt-BR); se não parsear, devolve
  /// o valor original.
  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String?)>[
      ('Cliente', order.customerName),
      ('Veículo', order.subjectLabel),
      ('Responsável', order.assignedTo),
      ('Relato', order.complaint),
      (
        'Previsão início',
        order.scheduledStart == null ? null : _fmtDate(order.scheduledStart!)
      ),
      (
        'Previsão fim',
        order.scheduledEnd == null ? null : _fmtDate(order.scheduledEnd!)
      ),
    ];
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (company != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (logoUrl != null && logoUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      logoUrl!,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company!.name,
                        style: TextStyle(
                            color: neu.inkMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                      if ((company!.cnpj ?? '').isNotEmpty)
                        Text(
                          'CNPJ: ${company!.cnpj}',
                          style: TextStyle(
                              color: neu.inkFaint, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: neu.base),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: Icons.build_rounded, index: 0, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.number,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OsStatusChip(status: order.status),
                  ],
                ),
              ),
              if (canEdit)
                NeuIconButton(
                  tooltip: 'Aplicar template',
                  icon: Icons.dashboard_customize_outlined,
                  size: 42,
                  onPressed: onApplyTemplate,
                ),
              if (canRead) ...[
                const SizedBox(width: 8),
                NeuIconButton(
                  tooltip: 'Imprimir',
                  icon: Icons.print_outlined,
                  size: 42,
                  onPressed: onPrint,
                ),
              ],
              if (invoiceAction != null) ...[
                const SizedBox(width: 8),
                invoiceAction!,
              ],
              if (canEdit) ...[
                const SizedBox(width: 8),
                NeuIconButton(
                  tooltip: 'Editar',
                  icon: Icons.edit_outlined,
                  size: 42,
                  onPressed: onEdit,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
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
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: neu.inkFaint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    color: neu.ink,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Botão "Emitir NF" do cabeçalho da OS: emite a nota a partir desta OS e, em
/// sucesso, navega para o detalhe da nota. Só é montado quando o módulo fiscal
/// está habilitado e o usuário tem `invoice.issue`.
class _IssueInvoiceButton extends ConsumerStatefulWidget {
  const _IssueInvoiceButton({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_IssueInvoiceButton> createState() =>
      _IssueInvoiceButtonState();
}

class _IssueInvoiceButtonState extends ConsumerState<_IssueInvoiceButton> {
  bool _loading = false;

  Future<void> _issue() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final invoice =
          await ref.read(invoiceRepositoryProvider).issue(widget.orderId);
      if (mounted) context.go('/m/invoice/${invoice.id}');
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (_loading) {
      return NeuSurface(
        elevation: NeuElevation.raised,
        radius: 21,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: neu.navy),
            ),
          ),
        ),
      );
    }
    return NeuIconButton(
      tooltip: 'Emitir nota fiscal',
      icon: Icons.receipt_long_outlined,
      size: 42,
      color: neu.navy,
      onPressed: _issue,
    );
  }
}

// ===================== Card de seção padrão =====================

/// Card de seção do detalhe da OS: relevo neumórfico + cabeçalho com glyph
/// colorido, título e uma ação opcional à direita. Unifica o visual de todas
/// as seções (diagnóstico, itens, totais, timeline, fotos, link).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.glyphIndex = 5,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final int glyphIndex;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: icon, index: glyphIndex, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ===================== Workflow (stepper + próximo passo) =====================

/// Etapas do fluxo "feliz" da OS, em ordem. `cancelada` fica fora — é desvio.
const _happyFlow = <String>[
  'aberta',
  'aguardando_aprovacao',
  'aprovada',
  'em_execucao',
  'concluida',
  'entregue',
];

/// Painel de workflow: um STEPPER mostrando em que etapa a OS está + o PRÓXIMO
/// passo, com a ação principal em destaque (secundárias/cancelar discretas).
/// Responde "o que está acontecendo aqui?" logo de cara.
class _WorkflowPanel extends StatelessWidget {
  const _WorkflowPanel({
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
    final neu = context.neu;
    final status = order.status;
    final cancelled = status == 'cancelada';

    // Ações válidas a partir do status atual (respeitando permissões).
    final targets = osTransitions[status] ?? const <String>[];
    bool allowed(String t) {
      if (t == 'aprovada') return canApprove;
      if (cancelled && t == 'aberta') return canApprove; // reabrir é privilegiado
      return true;
    }

    final available = canWrite ? targets.where(allowed).toList() : <String>[];
    final hasCancel = available.contains('cancelada');
    final forward = available.where((t) => t != 'cancelada').toList();

    // Ação principal = o avanço "para frente" (maior índice > atual no fluxo);
    // se não houver avanço (ex.: reabrir cancelada), usa o primeiro disponível.
    final curIdx = _happyFlow.indexOf(status);
    String? primary;
    for (final t in forward) {
      final i = _happyFlow.indexOf(t);
      if (i > curIdx && (primary == null || i > _happyFlow.indexOf(primary))) {
        primary = t;
      }
    }
    primary ??= forward.isNotEmpty ? forward.first : null;
    final secondary = forward.where((t) => t != primary).toList();

    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProgressStepper(status: status),
          if (cancelled)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _WorkflowNote(
                icon: Icons.cancel_outlined,
                color: neu.danger,
                text: canWrite
                    ? 'OS cancelada — edição bloqueada. Reabra para voltar a editá-la.'
                    : 'OS cancelada.',
              ),
            )
          else if (status == 'entregue')
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _WorkflowNote(
                icon: Icons.verified_outlined,
                color: neu.success,
                text: 'OS entregue — finalizada (somente leitura).',
              ),
            ),
          if (available.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: neu.base),
            const SizedBox(height: 16),
            Text(
              'Próximo passo',
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (primary != null)
                  NeuButton(
                    label: osTransitionLabel(primary),
                    icon: _transitionIcon(primary),
                    onPressed: () => onChange(primary!),
                  ),
                for (final t in secondary)
                  NeuButton(
                    label: osTransitionLabel(t),
                    icon: _transitionIcon(t),
                    kind: NeuButtonKind.secondary,
                    onPressed: () => onChange(t),
                  ),
                if (hasCancel)
                  NeuButton(
                    label: osTransitionLabel('cancelada'),
                    icon: Icons.close_rounded,
                    kind: NeuButtonKind.danger,
                    onPressed: () => onChange('cancelada'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Faixa informativa (tint) usada para estados terminais dentro do painel.
class _WorkflowNote extends StatelessWidget {
  const _WorkflowNote({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _transitionIcon(String target) {
  switch (target) {
    case 'aguardando_aprovacao':
      return Icons.outbox_outlined;
    case 'aprovada':
      return Icons.check_circle_outline;
    case 'aberta':
      return Icons.undo_rounded;
    case 'em_execucao':
      return Icons.play_arrow_rounded;
    case 'concluida':
      return Icons.task_alt;
    case 'entregue':
      return Icons.local_shipping_outlined;
    default:
      return Icons.arrow_forward;
  }
}

/// Stepper do ciclo de vida da OS. Desktop/tablet: nós ligados horizontalmente
/// (feito ✓ / atual ● / futuro nº). Mobile: "Etapa X de N" + barra segmentada.
class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cancelled = status == 'cancelada';
    final curIdx = cancelled ? -1 : _happyFlow.indexOf(status);
    return context.isMobile
        ? _StepperMobile(curIdx: curIdx, cancelled: cancelled)
        : _StepperWide(curIdx: curIdx, cancelled: cancelled);
  }
}

class _StepperWide extends StatelessWidget {
  const _StepperWide({required this.curIdx, required this.cancelled});
  final int curIdx;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final children = <Widget>[];
    for (var i = 0; i < _happyFlow.length; i++) {
      if (i > 0) {
        final done = !cancelled && i <= curIdx;
        children.add(Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.only(top: 13),
            decoration: BoxDecoration(
              color: done ? neu.navy : neu.base,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ));
      }
      children.add(_StepNode(
        index: i,
        curIdx: curIdx,
        cancelled: cancelled,
        label: osStatusLabel(_happyFlow[i]),
      ));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.curIdx,
    required this.cancelled,
    required this.label,
  });

  final int index;
  final int curIdx;
  final bool cancelled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final done = !cancelled && index < curIdx;
    final current = !cancelled && index == curIdx;
    final Color circle;
    final Color fg;
    if (current) {
      circle = neu.navy;
      fg = neu.onNavy;
    } else if (done) {
      circle = neu.navy.withValues(alpha: 0.16);
      fg = neu.navy;
    } else {
      circle = neu.base;
      fg = neu.inkFaint;
    }
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: circle),
            child: done
                ? Icon(Icons.check_rounded, size: 18, color: fg)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: current ? neu.ink : neu.inkMuted,
              fontSize: 11.5,
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperMobile extends StatelessWidget {
  const _StepperMobile({required this.curIdx, required this.cancelled});
  final int curIdx;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final total = _happyFlow.length;
    final idx = curIdx < 0 ? 0 : curIdx;
    final label = cancelled ? 'Cancelada' : osStatusLabel(_happyFlow[idx]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              cancelled ? 'Fluxo interrompido' : 'Etapa ${idx + 1} de $total',
              style: TextStyle(
                color: neu.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                color: cancelled ? neu.danger : neu.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: !cancelled && i <= curIdx ? neu.navy : neu.base,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ===================== Diagnóstico =====================

/// Diagnóstico editável inline na ficha (não mais no dialog de edição). Mostra o
/// texto atual; ao tocar em "Editar" vira um campo de texto com "Salvar". Salvar
/// chama o PATCH da OS (`diagnosis`) e atualiza a ficha. Aparece também ao
/// cliente na página pública de acompanhamento.
class _DiagnosisSection extends ConsumerStatefulWidget {
  const _DiagnosisSection({required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  @override
  ConsumerState<_DiagnosisSection> createState() => _DiagnosisSectionState();
}

class _DiagnosisSectionState extends ConsumerState<_DiagnosisSection> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.order.diagnosis ?? '');
  }

  @override
  void didUpdateWidget(covariant _DiagnosisSection old) {
    super.didUpdateWidget(old);
    // Reflete mudanças vindas de fora (ex.: após refresh) quando não editando.
    if (!_editing && old.order.diagnosis != widget.order.diagnosis) {
      _controller.text = widget.order.diagnosis ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final text = _controller.text.trim();
    try {
      await ref.read(osRepositoryProvider).updateOrder(
            widget.order.id,
            OrderPatch(diagnosis: text.isEmpty ? '' : text),
          );
      ref.invalidate(orderProvider(widget.order.id));
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagnóstico salvo.')),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final diagnosis = widget.order.diagnosis?.trim() ?? '';
    return _SectionCard(
      icon: Icons.search_rounded,
      title: 'Diagnóstico',
      glyphIndex: 1,
      action: widget.canWrite && !_editing
          ? _HeaderAction(
              icon: Icons.edit_outlined,
              label: diagnosis.isEmpty ? 'Adicionar' : 'Editar',
              onTap: () => setState(() => _editing = true),
            )
          : null,
      child: _editing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NeuTextField(
                  controller: _controller,
                  label: 'Diagnóstico técnico (visível ao cliente)',
                  hint: 'Descreva o que foi identificado no veículo.',
                  minLines: 3,
                  maxLines: 8,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeuButton(
                      label: 'Cancelar',
                      kind: NeuButtonKind.secondary,
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _editing = false;
                                _controller.text =
                                    widget.order.diagnosis ?? '';
                              }),
                    ),
                    const SizedBox(width: 10),
                    NeuButton(
                      label: 'Salvar',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ],
            )
          : Text(
              diagnosis.isEmpty ? 'Sem diagnóstico ainda.' : diagnosis,
              style: TextStyle(
                color: diagnosis.isEmpty ? neu.inkFaint : neu.ink,
                fontSize: 15,
                height: 1.4,
              ),
            ),
    );
  }
}

/// Ação compacta no cabeçalho de uma seção (adicionar/editar). Menor que um
/// [NeuButton] cheio, sem quebrar o alinhamento do título.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rChip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: neu.navy),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: neu.navy,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
    final ok = await showNeuConfirm(
      context,
      title: 'Remover item?',
      message: 'Remover "${item.name}" desta OS? O total será recalculado.',
      confirmLabel: 'Remover',
    );
    if (!ok || !context.mounted) return;
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
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Peças e serviços',
      glyphIndex: 0,
      action: canWrite
          ? _HeaderAction(
              icon: Icons.add_rounded,
              label: 'Adicionar',
              onTap: () => _add(context, ref),
            )
          : null,
      child: order.items.isEmpty
          ? _InlineEmpty(
              icon: Icons.add_shopping_cart_outlined,
              text: 'Nenhum item ainda.',
              hint: 'Adicione peças do estoque ou serviços de mão de obra.',
            )
          : NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < order.items.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: neu.base, indent: 14, endIndent: 14),
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
    );
  }
}

/// Estado vazio compacto dentro de uma seção (mais enxuto que [NeuEmptyState],
/// que é para tela inteira). Ícone, frase curta e uma dica em cinza.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.text, this.hint});
  final IconData icon;
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: neu.base,
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: neu.inkFaint),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: neu.inkFaint, fontSize: 12.5, height: 1.3),
            ),
          ],
        ],
      ),
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
    final neu = context.neu;
    final isService = item.kind == 'service';
    final disc = double.tryParse(item.discount) ?? 0;
    final detail = [
      '${item.quantity} × ${money(item.unitPrice)}',
      if (disc > 0) '- ${money(item.discount)}',
    ].join('  ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(
            isService
                ? Icons.design_services_outlined
                : Icons.inventory_2_outlined,
            size: 20,
            color: neu.inkMuted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: TextStyle(
                        color: neu.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(color: neu.inkMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(money(item.total),
              style: TextStyle(color: neu.ink, fontWeight: FontWeight.w800)),
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
    final neu = context.neu;
    final itemsTotal = order.items.fold<double>(
      0,
      (acc, it) => acc + (double.tryParse(it.total) ?? 0),
    );
    final discount = double.tryParse(order.discount ?? '0') ?? 0;
    return _SectionCard(
      icon: Icons.payments_rounded,
      title: 'Resumo financeiro',
      glyphIndex: 2,
      child: Column(
        children: [
          _TotalRow(label: 'Itens', value: money(itemsTotal.toString())),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _TotalRow(
                label: 'Desconto da OS',
                value: '- ${money(discount.toString())}'),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: neu.navy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(NeuTokens.rField),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: TextStyle(
                        color: neu.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                Text(
                  money(order.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: neu.navy,
                    letterSpacing: -0.5,
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

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: neu.inkMuted, fontSize: 14)),
        Text(value,
            style: TextStyle(color: neu.ink, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ===================== Link de acompanhamento =====================

/// Card com o link público de acompanhamento da OS. Copiar funciona; WhatsApp
/// e e-mail aparecem desabilitados ("Em breve"). A origem do link vem de
/// `Uri.base.origin` na WEB; em desktop/mobile `Uri.base` é `file://` (sem
/// origin http → `.origin` lança StateError), então usamos `AppConfig.publicWebUrl`.
/// O app usa hash URL strategy, então o link precisa do `/#/` (sem ele, a rota
/// pública não casa e o cliente cai no login).
class _TrackingLinkCard extends StatelessWidget {
  const _TrackingLinkCard({required this.token});

  final String token;

  String get _url {
    final origin = kIsWeb
        ? Uri.base.origin
        : AppConfig.publicWebUrl.replaceFirst(RegExp(r'/+$'), '');
    return '$origin/#/t/$token';
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.link_rounded,
      title: 'Link de acompanhamento',
      glyphIndex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compartilhe com o cliente para ele acompanhar a OS em tempo real.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SelectableText(
              _url,
              style: TextStyle(fontSize: 13, color: neu.inkMuted),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              NeuButton(
                label: 'Copiar link',
                icon: Icons.copy_rounded,
                onPressed: () => _copy(context),
              ),
              NeuButton(
                label: 'WhatsApp',
                icon: Icons.chat_outlined,
                kind: NeuButtonKind.secondary,
                onPressed: null,
              ),
              NeuButton(
                label: 'E-mail',
                icon: Icons.email_outlined,
                kind: NeuButtonKind.secondary,
                onPressed: null,
              ),
            ],
          ),
        ],
      ),
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
    final events = order.events;
    return _SectionCard(
      icon: Icons.timeline_rounded,
      title: 'Linha do tempo',
      glyphIndex: 4,
      action: canWrite
          ? _HeaderAction(
              icon: Icons.add_comment_outlined,
              label: 'Nota',
              onTap: () => _addNote(context, ref),
            )
          : null,
      child: events.isEmpty
          ? _InlineEmpty(
              icon: Icons.history_rounded,
              text: 'Nenhum evento ainda.',
              hint: 'As mudanças de status e notas aparecem aqui.',
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
    final neu = context.neu;
    final dotColor = _dotColor(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trilho vertical com o ponto/ícone.
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : neu.base,
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_kindIcon(), size: 16, color: dotColor),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : neu.base,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _label(),
                          style: TextStyle(
                              color: neu.ink, fontWeight: FontWeight.w700),
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
                          color: event.visiblePublic ? neu.navy : neu.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  if (event.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtTimestamp(event.createdAt!),
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

  Color _dotColor(BuildContext context) {
    final neu = context.neu;
    switch (event.kind) {
      case 'status_change':
        return event.statusSnapshot == null
            ? neu.navy
            : osStatusColor(event.statusSnapshot!);
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

// ===================== Fotos =====================

/// Galeria de fotos da OS: miniaturas em rolagem horizontal (com remover, sob
/// permissão) e upload via picker. Lê `order.photos`; ao mutar, invalida a OS.
class _PhotosSection extends ConsumerStatefulWidget {
  const _PhotosSection({required this.order, required this.canWrite});

  final ServiceOrder order;
  final bool canWrite;

  @override
  ConsumerState<_PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends ConsumerState<_PhotosSection> {
  bool _busy = false;

  ServiceOrder get order => widget.order;

  Future<void> _add() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.bytes == null) return;

    final ext = (file.extension ?? 'jpeg').toLowerCase();
    setState(() => _busy = true);
    try {
      await ref.read(osRepositoryProvider).addPhoto(
            order.id,
            bytes: file.bytes!,
            filename: file.name,
            contentType: 'image/$ext',
            caption: null,
          );
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(OrderPhoto photo) async {
    final confirmed = await showNeuConfirm(
      context,
      title: 'Remover foto?',
      message: 'Esta foto será removida da OS. Não é possível desfazer.',
      confirmLabel: 'Remover',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(osRepositoryProvider).deletePhoto(order.id, photo.id);
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Abre a thread de comentários da foto (staff lê e adiciona).
  void _openComments(OrderPhoto photo) {
    showNeuDialog<void>(
      context,
      dialog: NeuDialog(
        title: 'Comentários da foto',
        maxWidth: 520,
        child: _PhotoCommentsPanel(orderId: order.id, photo: photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = order.photos;
    return _SectionCard(
      icon: Icons.photo_library_rounded,
      title: 'Fotos',
      glyphIndex: 5,
      action: widget.canWrite
          ? _HeaderAction(
              icon: _busy ? Icons.hourglass_top_rounded : Icons.add_a_photo_outlined,
              label: _busy ? 'Enviando…' : 'Adicionar',
              onTap: _busy ? () {} : _add,
            )
          : null,
      child: photos.isEmpty
          ? _InlineEmpty(
              icon: Icons.image_outlined,
              text: 'Sem fotos.',
              hint: 'Registre o estado do veículo antes e depois do serviço.',
            )
          : SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _PhotoThumb(
                  photo: photos[i],
                  canWrite: widget.canWrite,
                  onRemove: () => _remove(photos[i]),
                  onTap: () => _openComments(photos[i]),
                ),
              ),
            ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    required this.photo,
    required this.canWrite,
    required this.onRemove,
    required this.onTap,
  });

  final OrderPhoto photo;
  final bool canWrite;
  final VoidCallback onRemove;

  /// Toque na miniatura abre a thread de comentários da foto.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: NeuNetworkImage(
            url: photo.url,
            width: 96,
            height: 96,
            radius: 12,
          ),
        ),
        // Selo de comentários: abre a thread ao tocar.
        Positioned(
          bottom: 2,
          left: 2,
          child: Material(
            color: Colors.black54,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(Icons.mode_comment_outlined,
                    size: 13, color: Colors.white),
              ),
            ),
          ),
        ),
        if (canWrite)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Formata um ISO-8601 para "dd/MM HH:mm" (pt-BR); vazio se não parsear.
String _fmtCommentDate(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
}

/// Painel da thread de comentários de uma foto da OS (lado staff): preview da
/// foto, lista de comentários (equipe/cliente + data) e campo para adicionar.
/// Carrega via [OsRepository.listPhotoComments]; adiciona via
/// [OsRepository.addPhotoComment].
class _PhotoCommentsPanel extends ConsumerStatefulWidget {
  const _PhotoCommentsPanel({required this.orderId, required this.photo});

  final String orderId;
  final OrderPhoto photo;

  @override
  ConsumerState<_PhotoCommentsPanel> createState() =>
      _PhotoCommentsPanelState();
}

class _PhotoCommentsPanelState extends ConsumerState<_PhotoCommentsPanel> {
  final _input = TextEditingController();
  late Future<List<PhotoComment>> _future;
  List<PhotoComment> _comments = const [];
  bool _loaded = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PhotoComment>> _load() async {
    final list = await ref
        .read(osRepositoryProvider)
        .listPhotoComments(widget.orderId, widget.photo.id);
    _comments = list;
    _loaded = true;
    return list;
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final created = await ref
          .read(osRepositoryProvider)
          .addPhotoComment(widget.orderId, widget.photo.id, body);
      _input.clear();
      setState(() => _comments = [..._comments, created]);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: NeuNetworkImage(
            url: widget.photo.url,
            width: 220,
            height: 160,
            radius: 12,
          ),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<PhotoComment>>(
          future: _future,
          builder: (context, snap) {
            if (!_loaded &&
                snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!_loaded && snap.hasError) {
              final e = snap.error;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  e is AppException
                      ? e.message
                      : 'Erro ao carregar comentários.',
                  style: TextStyle(color: neu.inkMuted),
                ),
              );
            }
            if (_comments.isEmpty) {
              return _InlineEmpty(
                icon: Icons.mode_comment_outlined,
                text: 'Nenhum comentário ainda.',
                hint: 'Escreva o primeiro comentário sobre esta foto.',
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _CommentTile(comment: _comments[i]),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: NeuSurface(
                elevation: NeuElevation.inset,
                radius: NeuTokens.rField,
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(color: neu.ink, fontSize: 14.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Adicionar comentário…',
                    hintStyle: TextStyle(color: neu.inkFaint),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            NeuIconButton(
              icon: Icons.send_rounded,
              tooltip: 'Enviar comentário',
              color: neu.navy,
              onPressed: _sending ? null : _add,
            ),
          ],
        ),
      ],
    );
  }
}

/// Cartão de um comentário: autor (Equipe/cliente) + data + texto.
class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final PhotoComment comment;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isStaff = comment.authorKind == 'staff';
    final who = (comment.authorName?.trim().isNotEmpty ?? false)
        ? comment.authorName!.trim()
        : (isStaff ? 'Equipe' : 'Cliente');
    final date = _fmtCommentDate(comment.createdAt);
    final accent = isStaff ? neu.navy : neu.inkMuted;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isStaff ? Icons.engineering_outlined : Icons.person_outline,
                size: 15,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                who,
                style: TextStyle(
                  color: accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: TextStyle(color: neu.inkFaint, fontSize: 11.5),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            comment.body,
            style: TextStyle(color: neu.ink, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// ===================== Seletor de template =====================

/// Dialog para escolher um template de OS a aplicar. Lista cada template como
/// um ListTile clicável; devolve o escolhido (ou null em Cancelar). Vazio →
/// mensagem orientando a criar templates.
class _TemplatePickerDialog extends StatelessWidget {
  const _TemplatePickerDialog({required this.templates});

  final List<OsTemplate> templates;

  static Future<OsTemplate?> show(
    BuildContext context,
    List<OsTemplate> templates,
  ) {
    return showDialog<OsTemplate>(
      context: context,
      builder: (_) => _TemplatePickerDialog(templates: templates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Aplicar template'),
      content: SizedBox(
        width: 420,
        child: templates.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum template — crie em Templates.'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in templates)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dashboard_customize_outlined),
                      title: Text(t.name),
                      subtitle: (t.description != null &&
                              t.description!.isNotEmpty)
                          ? Text(
                              t.description!,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(t),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
