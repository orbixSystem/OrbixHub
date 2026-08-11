import 'dart:async';
import '../../../core/realtime/realtime_chat.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui.dart';
import '../../../core/util/cnpj.dart';
import '../../auth/presentation/session_state.dart';
import '../../invoice/presentation/invoice_providers.dart';
import '../../invoice/presentation/invoice_status.dart';
import '../../messages/domain/messages_models.dart';
import '../../../di.dart';
import '../domain/os_models.dart';
import 'item_picker_dialog.dart';
import 'order_edit_dialog.dart';
import '../../../core/export/file_download.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../../core/pdf/document_company.dart';
import 'os_pdf.dart';
import 'os_providers.dart';
import 'os_quick_actions.dart';
import 'os_status.dart';
import 'payment_status.dart';

const _maxContentWidth = 1200.0;

/// Ficha da OS: cabeçalho (nº/cliente/veículo/status) editável, lista de itens
/// (adicionar via picker do estoque ou avulso, editar, remover) com totais ao
/// vivo, e botões de status com as transições válidas. Corpo apenas — moldura
/// é do shell.
class OsDetailScreen extends ConsumerStatefulWidget {
  const OsDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OsDetailScreen> createState() => _OsDetailScreenState();
}

class _OsDetailScreenState extends ConsumerState<OsDetailScreen> {
  /// Push em tempo real: a OS muda pelas mãos de outra pessoa (outro mecânico
  /// mudando status, o cliente mandando mensagem) e esta tela precisa refletir
  /// sem depender de o usuário recarregar.
  final RealtimeChat _rt = RealtimeChat();

  String get orderId => widget.orderId;

  @override
  void initState() {
    super.initState();
    final accessToken = ref.read(accessTokenStoreProvider).token;
    if (accessToken == null) return;
    _rt.connectStaff(
      accessToken: accessToken,
      // Mensagem nova numa conversa desta OS: a linha do tempo/contador muda.
      onMessage: (_) => _recarregar(),
      onOsChanged: (evt) {
        // A sala é do TENANT: chega mudança de QUALQUER OS. Só recarrega se for
        // esta — senão a tela recarregaria a cada movimento da oficina.
        if (evt['orderId'] == orderId) _recarregar();
      },
    );
  }

  /// Recarrega pela API. O socket avisa QUE mudou; o dado continua vindo de uma
  /// fonte só — o payload do evento é mínimo de propósito.
  void _recarregar() {
    if (!mounted) return;
    ref.invalidate(orderProvider(orderId));
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  bool _has(WidgetRef ref, String perm) {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission(perm) ?? false;
  }

  bool _hasModule(WidgetRef ref, String key) {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasModule(key) ?? false;
  }

  /// Empresa para exibir NA TELA — síncrona, do tenant ativo, que o `/me` já
  /// trouxe. A tela não pode esperar rede para mostrar um cabeçalho.
  DocumentCompany? _companyParaTela(WidgetRef ref) {
    final t = ref.read(sessionControllerProvider).meOrNull?.activeTenant;
    if (t == null) return null;
    return DocumentCompany(
      name: t.name,
      legalName: t.legalName,
      cnpj: (t.cnpj != null && t.cnpj!.isNotEmpty) ? formatCnpj(t.cnpj) : null,
    );
  }

  /// Empresa para o PDF — Configurações › Empresa, com logo, IE, endereço e
  /// contato. Falha de leitura cai para a versão da tela: o documento sai com
  /// menos dados no topo em vez de não sair.
  Future<DocumentCompany?> _companyParaPdf(WidgetRef ref) async {
    try {
      return await ref.read(companyForDocumentsProvider.future);
    } on Object {
      return _companyParaTela(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final canWrite = _has(ref, 'os.write');
    final canApprove = _has(ref, 'os.approve');
    final canRead = _has(ref, 'os.read');
    // "Emitir NF" só aparece com o módulo fiscal habilitado E a permissão de
    // emissão — o backend é a verdade (aqui só refletimos para UX).
    // NF desligada no front (kInvoiceEnabled=false): sem botão de emitir nota na
    // OS, mesmo com módulo/permissão. O backend segue capaz — é só retirada de UI.
    final canIssueInvoice =
        kInvoiceEnabled &&
        _hasModule(ref, 'invoice') &&
        _has(ref, 'invoice.issue');
    final company = _companyParaTela(ref);
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
          // Caixinha com as mensagens DESTA OS (prévia + atalho pra thread).
          if (order.conversationId != null && order.conversationId!.isNotEmpty)
            _MessagesSection(conversationId: order.conversationId!),
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
                onPrint: () => _exportOrder(context, ref, order),
                // Emitir/ver NF fala com o servidor fiscal — offline a ação
                // fica inerte com tooltip "Requer conexão".
                invoiceAction: canIssueInvoice
                    ? RequiresConnection(
                        reason: 'a nota é emitida pelo servidor fiscal',
                        child: _IssueInvoiceButton(orderId: order.id),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              // Seletor de 3 botões (Em andamento/Finalizada/Cancelada): mostra
              // em qual dos 3 estados a OS está e avança automaticamente por
              // todos os passos reais da FSM ao tocar num destino alcançável.
              _WorkflowPanel(
                order: order,
                canWrite: canWrite,
                canApprove: canApprove,
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

  /// Exporta a OS em PDF DIRETO para arquivo — sem passar pelo diálogo de
  /// impressão. Quem quer papel imprime o arquivo; quem quer mandar no WhatsApp
  /// (o caso comum) não deveria ter de cancelar uma janela de impressora antes.
  Future<void> _exportOrder(
    BuildContext context,
    WidgetRef ref,
    ServiceOrder order,
  ) async {
    try {
      final company = await _companyParaPdf(ref);
      final bytes = await buildOsPdf(
        order,
        PdfPageFormat.a4,
        company: company,
      );
      final nome = 'OS-${order.number.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')}'
          '.pdf';
      await downloadBytes(bytes, nome, 'application/pdf');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF exportado: $nome')),
        );
      }
    } on Object {
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
    required this.onPrint,
    this.logoUrl,
    this.invoiceAction,
  });

  final ServiceOrder order;
  final DocumentCompany? company;
  final String? logoUrl;
  final bool canEdit;
  final bool canRead;
  final VoidCallback onEdit;
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
      ('Responsável', order.assignedToName ?? order.assignedTo),
      ('Relato', order.complaint),
      (
        'Previsão início',
        order.scheduledStart == null ? null : _fmtDate(order.scheduledStart!),
      ),
      (
        'Previsão fim',
        order.scheduledEnd == null ? null : _fmtDate(order.scheduledEnd!),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((company!.cnpj ?? '').isNotEmpty)
                        Text(
                          'CNPJ: ${company!.cnpj}',
                          style: TextStyle(color: neu.inkFaint, fontSize: 12),
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
          Builder(
            builder: (context) {
              final isMobile = context.isMobile;
              final leading = NeuIconChip.glyph(
                context,
                icon: Icons.build_rounded,
                index: 0,
                size: 52,
              );
              // Número: fica em 24px quando cabe e, só num extremo, encolhe suave
              // (nunca quebra em 2 linhas nem corta com "…" — ilegível num número).
              // No mobile o bloco do número recebe a LARGURA TODA; os botões de
              // ação vão para uma linha própria abaixo, então o número não disputa
              // espaço com eles por mais longo que seja.
              final titleColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      order.number,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // OS criada offline (número provisório OS-P…): o registro
                  // ainda não existe no servidor. Status SIMPLIFICADO (não os
                  // 7 reais) — é a mesma leitura de Em andamento/Finalizada/
                  // Cancelada que a lista e o seletor de ações usam.
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _SimpleStatusTag(status: order.status),
                      if (order.payment != null && order.payment!.total > 0)
                        PaymentTag(status: order.paymentStatus, dense: true),
                      if (isPendingOsNumber(order.number))
                        SyncRowBadge(entity: 'service_order', id: order.id),
                    ],
                  ),
                ],
              );
              final actions = <Widget>[
                // Atalho direto para a conversa desta OS (inbox de mensagens) —
                // a conversa é criada pelo backend junto com a OS.
                if (order.conversationId != null &&
                    order.conversationId!.isNotEmpty)
                  NeuIconButton(
                    tooltip: 'Mensagens da OS',
                    icon: Icons.forum_outlined,
                    size: 42,
                    onPressed: () =>
                        context.push('/mensagens/${order.conversationId}'),
                  ),
                if (canRead)
                  NeuIconButton(
                    tooltip: 'Exportar PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    size: 42,
                    onPressed: onPrint,
                  ),
                if (canEdit)
                  NeuIconButton(
                    tooltip: 'Editar',
                    icon: Icons.edit_outlined,
                    size: 42,
                    onPressed: onEdit,
                  ),
              ];
              // Espaçamento de 8px entre os botões (lista dinâmica).
              final actionRow = <Widget>[
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  actions[i],
                ],
              ];

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        leading,
                        const SizedBox(width: 16),
                        Expanded(child: titleColumn),
                      ],
                    ),
                    if (actionRow.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actionRow,
                      ),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  leading,
                  const SizedBox(width: 16),
                  Expanded(child: titleColumn),
                  ...actionRow,
                ],
              );
            },
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
          // Ação fiscal em destaque (botão rotulado, largura total) — só com
          // módulo `invoice` + permissão. Emitir nota ou ver a nota existente.
          if (invoiceAction != null) ...[
            const SizedBox(height: 18),
            invoiceAction!,
          ],
        ],
      ),
    );
  }
}

/// Tag de status SIMPLIFICADO no cabeçalho (tint suave, mesmo estilo do
/// [OsStatusChip] granular que substitui) — Em andamento/Finalizada/
/// Cancelada, não os 7 status reais.
class _SimpleStatusTag extends StatelessWidget {
  const _SimpleStatusTag({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final simples = osSimpleStatusOf(status);
    final color = osSimpleStatusColor(simples);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .22 : .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(osSimpleStatusIcon(simples), size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            osSimpleStatusLabel(simples),
            style: TextStyle(
              color: dark ? Color.lerp(color, Colors.white, .35) : color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
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
            Text(
              label,
              style: TextStyle(
                color: neu.inkFaint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: neu.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
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
      final invoice = await ref
          .read(invoiceRepositoryProvider)
          .issue(orderId: widget.orderId);
      // Reflete na OS que agora há uma nota (ao voltar, mostra "ver nota").
      ref.invalidate(orderInvoicesProvider(widget.orderId));
      if (mounted) context.go('/m/invoice/${invoice.id}');
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Já existe nota ATIVA (rascunho/processando/autorizada) para esta OS?
    // Se sim, o botão vira "ver nota" (a OS reflete o estado fiscal em vez de
    // só oferecer emitir e bater no 409).
    final page = ref.watch(orderInvoicesProvider(widget.orderId)).asData?.value;
    final active = (page?.items ?? const []).where(
      (i) =>
          i.status == 'draft' ||
          i.status == 'processing' ||
          i.status == 'authorized',
    );
    if (active.isNotEmpty) {
      final inv = active.first;
      return NeuButton(
        label: 'Ver nota fiscal · ${invoiceStatusLabel(inv.status)}',
        icon: Icons.receipt_long,
        kind: NeuButtonKind.secondary,
        expanded: true,
        onPressed: () => context.go('/m/invoice/${inv.id}'),
      );
    }
    return NeuButton(
      label: 'Emitir nota fiscal',
      icon: Icons.receipt_long_outlined,
      expanded: true,
      loading: _loading,
      onPressed: _loading ? null : _issue,
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
    this.notice,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final int glyphIndex;
  final Widget? action;

  /// Aviso no rodapé da seção (ex.: [OfflinePendingNotice] — some quando online).
  final Widget? notice;

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
              NeuIconChip.glyph(
                context,
                icon: icon,
                index: glyphIndex,
                size: 34,
              ),
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
          ?notice,
        ],
      ),
    );
  }
}

// ===================== Workflow (seletor de 3 estados) =====================

/// Painel de workflow: 3 botões (Em andamento/Finalizada/Cancelada) — o botão
/// do estado atual aparece preenchido; tocar num outro alcançável avança
/// AUTOMATICAMENTE por todos os passos reais da FSM entre eles (aprovação e
/// baixa de estoque acontecem no caminho, sem gate manual — "quanto mais
/// simples for isso melhor").
class _WorkflowPanel extends ConsumerStatefulWidget {
  const _WorkflowPanel({
    required this.order,
    required this.canWrite,
    required this.canApprove,
  });

  final ServiceOrder order;
  final bool canWrite;
  final bool canApprove;

  @override
  ConsumerState<_WorkflowPanel> createState() => _WorkflowPanelState();
}

class _WorkflowPanelState extends ConsumerState<_WorkflowPanel> {
  bool _busy = false;

  /// Se um toque em [destino] resultaria numa ação de verdade (caminho não
  /// vazio) E o usuário tem permissão para ela.
  bool _habilitado(OsSimpleStatus destino) {
    if (_busy) return false;
    return osSimpleTransitionEnabled(
      widget.order,
      destino,
      canWrite: widget.canWrite,
      canApprove: widget.canApprove,
    );
  }

  Future<void> _tap(OsSimpleStatus destino) async {
    if (!_habilitado(destino)) return;
    await runOsSimpleTransition(
      context,
      ref,
      widget.order,
      destino,
      onWillApply: () => setState(() => _busy = true),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _receberPagamento() async {
    if (_busy || !canReceiveOsPayment(ref, widget.order)) return;
    setState(() => _busy = true);
    await offerOsPayment(context, ref, widget.order);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final order = widget.order;
    final isMobile = context.isMobile;
    final podeReceber = canReceiveOsPayment(ref, order);

    // Botões de AÇÃO (verbos) — o status já foi dito no cabeçalho (badge
    // simplificado + tag de pagamento); esta linha existe só para agir, não
    // pra repetir "onde a OS está". Sem NeuCard: não precisa ocupar a tela
    // toda, principalmente no mobile.
    final acoes = <({IconData icon, String label, NeuButtonKind kind, VoidCallback onPressed})>[];
    if (order.status == 'cancelada') {
      if (_habilitado(OsSimpleStatus.emAndamento)) {
        acoes.add((
          icon: Icons.undo_rounded,
          label: 'Reabrir',
          kind: NeuButtonKind.primary,
          onPressed: () => _tap(OsSimpleStatus.emAndamento),
        ));
      }
    } else if (order.status != 'entregue') {
      // Um botão só, "Finalizar" — sem distinguir concluida/entregue por
      // dentro: essa nuance do FSM não interessa a quem está fechando o
      // serviço. O que importa (receber ou não) vem a seguir, no diálogo.
      if (_habilitado(OsSimpleStatus.finalizada)) {
        acoes.add((
          icon: Icons.check_circle_rounded,
          label: 'Finalizar',
          kind: NeuButtonKind.primary,
          onPressed: () => _tap(OsSimpleStatus.finalizada),
        ));
      }
      if (_habilitado(OsSimpleStatus.cancelada)) {
        acoes.add((
          icon: Icons.close_rounded,
          label: 'Cancelar OS',
          kind: NeuButtonKind.danger,
          onPressed: () => _tap(OsSimpleStatus.cancelada),
        ));
      }
    }
    // "Receber pagamento" fica disponível a qualquer momento em que houver
    // saldo — não só no instante de finalizar. Se o dono recusou o diálogo
    // ali (ou a OS já estava concluída sem pagar), o botão continua aqui.
    if (podeReceber) {
      acoes.add((
        icon: Icons.payments_outlined,
        label: 'Receber pagamento',
        kind: NeuButtonKind.secondary,
        onPressed: _receberPagamento,
      ));
    }

    if (_busy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: neu.inkMuted),
          ),
          const SizedBox(width: 10),
          Text('Atualizando…', style: TextStyle(color: neu.inkMuted, fontSize: 13)),
        ],
      );
    }
    if (acoes.isEmpty) {
      if (order.status == 'cancelada') {
        return _WorkflowNote(
          icon: Icons.cancel_outlined,
          color: neu.danger,
          text: 'OS cancelada.',
        );
      }
      if (order.status == 'entregue') {
        return _WorkflowNote(
          icon: Icons.verified_outlined,
          color: neu.success,
          text: 'OS entregue — finalizada (somente leitura).',
        );
      }
      return const SizedBox.shrink();
    }
    // Desktop: texto + ícone (espaço não falta). Mobile: só ícone — a linha
    // fica compacta, sem competir por largura numa tela estreita.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in acoes)
          isMobile
              ? NeuIconButton(
                  icon: a.icon,
                  tooltip: a.label,
                  color: a.kind == NeuButtonKind.danger ? neu.danger : null,
                  onPressed: a.onPressed,
                )
              : NeuButton(
                  label: a.label,
                  icon: a.icon,
                  kind: a.kind,
                  onPressed: a.onPressed,
                ),
      ],
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
      await ref
          .read(osRepositoryProvider)
          .updateOrder(
            widget.order.id,
            OrderPatch(diagnosis: text.isEmpty ? '' : text),
          );
      ref.invalidate(orderProvider(widget.order.id));
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Diagnóstico salvo.')));
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      // Offline o diagnóstico é salvo no aparelho e sobe no replay do outbox.
      notice: const OfflinePendingNotice(),
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
                  maxLength: 500,
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
                              _controller.text = widget.order.diagnosis ?? '';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
                      Divider(
                        height: 1,
                        color: neu.base,
                        indent: 14,
                        endIndent: 14,
                      ),
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
              style: TextStyle(
                color: neu.inkFaint,
                fontSize: 12.5,
                height: 1.3,
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
                Text(
                  item.name,
                  style: TextStyle(color: neu.ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(color: neu.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(item.total),
            style: TextStyle(color: neu.ink, fontWeight: FontWeight.w800),
          ),
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
                    leading: Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    title: Text(
                      'Remover',
                      style: TextStyle(color: AppColors.danger),
                    ),
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
    return NeuDialog(
      title: widget.item.name,
      maxWidth: context.isMobile ? 560 : 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Salvar',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(
            OrderItemPatch(
              quantity: _toDouble(_qty.text),
              unitPrice: _toDouble(_price.text),
              discount: _toDouble(_disc.text),
            ),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              labelText: 'Preço unitário',
              prefixText: 'R\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _disc,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Desconto',
              prefixText: 'R\$ ',
            ),
          ),
        ],
      ),
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
              value: '- ${money(discount.toString())}',
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: neu.navy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(NeuTokens.rField),
            ),
            // O valor em fonte 22 não caberia ao lado do rótulo em celular.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    color: neu.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    money(order.total),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: neu.navy,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Pago/saldo — a mesma informação que antes só aparecia no painel
          // de status (removido de lá pra não fazer o indicador de andamento
          // da OS parecer também um indicador de pagamento).
          if (order.payment != null && order.payment!.total > 0) ...[
            const SizedBox(height: 8),
            _TotalRow(
              label: 'Pago',
              value: money(order.payment!.paid.toString()),
            ),
            if (order.payment!.balance > 0) ...[
              const SizedBox(height: 8),
              _TotalRow(
                label: 'Saldo a receber',
                value: money(order.payment!.balance.toString()),
              ),
            ],
          ],
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
        Text(
          value,
          style: TextStyle(color: neu.ink, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ===================== Link de acompanhamento =====================

/// Card com o link público de acompanhamento da OS: copiar, compartilhar por
/// WhatsApp (wa.me) e por e-mail (mailto) via url_launcher. A origem do link vem de
/// `Uri.base.origin` na WEB; em desktop/mobile `Uri.base` é `file://` (sem
/// origin http → `.origin` lança StateError), então usamos `AppConfig.publicWebUrl`.
/// O app usa hash URL strategy, então o link precisa do `/#/` (sem ele, a rota
/// pública não casa e o cliente cai no login).
// ===================== Mensagens da OS (prévia) =====================

/// Caixinha compacta com as últimas mensagens DESTA OS (cliente ↔ equipe).
/// Prévia somente-leitura: usa `before` no futuro para NÃO zerar o contador de
/// não-lidas do inbox; a conversa completa abre em /mensagens/:id.
class _MessagesSection extends ConsumerWidget {
  const _MessagesSection({required this.conversationId});

  final String conversationId;

  void _open(BuildContext context) => context.go('/mensagens/$conversationId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(osConversationPreviewProvider(conversationId));
    return _SectionCard(
      icon: Icons.forum_rounded,
      title: 'Mensagens',
      glyphIndex: 1,
      action: _HeaderAction(
        icon: Icons.open_in_new_rounded,
        label: 'Abrir',
        onTap: () => _open(context),
      ),
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
        error: (e, _) => Text(
          e is AppException ? e.message : 'Erro ao carregar as mensagens.',
          style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
        ),
        data: (thread) {
          final unread = thread.conversation.staffUnread;
          final messages = thread.messages;
          if (messages.isEmpty) {
            return Text(
              'Nenhuma mensagem ainda. O cliente pode escrever pelo link de '
              'acompanhamento — a conversa aparece aqui.',
              style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.35),
            );
          }
          // As 3 mais recentes (a página vem em ordem cronológica).
          final recent = messages.length > 3
              ? messages.sublist(messages.length - 3)
              : messages;
          final older = thread.hasMore
              ? '${messages.length}+'
              : '${messages.length}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (unread > 0) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: NeuStatusChip(
                    label: unread == 1
                        ? '1 mensagem não lida'
                        : '$unread mensagens não lidas',
                    color: neu.accent,
                    tint: neu.accentTint,
                    icon: Icons.mark_chat_unread_outlined,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _MessagePreviewTile(
                  message: recent[i],
                  onTap: () => _open(context),
                ),
              ],
              if (messages.length > recent.length || thread.hasMore) ...[
                const SizedBox(height: 8),
                Text(
                  'Mostrando as ${recent.length} mais recentes de $older — '
                  'toque em "Abrir" para ver tudo.',
                  style: TextStyle(color: neu.inkFaint, fontSize: 11.5),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Uma mensagem na prévia: remetente + hora numa linha, corpo em até 2 linhas.
class _MessagePreviewTile extends StatelessWidget {
  const _MessagePreviewTile({required this.message, required this.onTap});

  final Message message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final fromCustomer = message.sender == 'customer';
    final who = (message.authorName?.trim().isNotEmpty ?? false)
        ? message.authorName!.trim()
        : (fromCustomer ? 'Cliente' : 'Equipe');
    final hasPhoto = message.photoUrl != null && message.photoUrl!.isNotEmpty;
    final body = message.body.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NeuTokens.rField),
      child: NeuSurface(
        elevation: NeuElevation.inset,
        radius: NeuTokens.rField,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  fromCustomer
                      ? Icons.person_rounded
                      : Icons.support_agent_rounded,
                  size: 14,
                  color: fromCustomer ? neu.accent : neu.inkFaint,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fromCustomer ? neu.accent : neu.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _fmtCommentDate(message.createdAt),
                  style: TextStyle(color: neu.inkFaint, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhoto) ...[
                  Icon(Icons.photo_outlined, size: 14, color: neu.inkFaint),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    body.isNotEmpty ? body : (hasPhoto ? 'Foto' : ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: neu.ink, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copiado')));
  }

  /// Mensagem padrão compartilhada por WhatsApp/e-mail (link de acompanhamento).
  String get _shareText =>
      'Acompanhe sua ordem de serviço em tempo real: $_url';

  Future<void> _openExternal(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o aplicativo.')),
      );
    }
  }

  Future<void> _whatsApp(BuildContext context) => _openExternal(
    context,
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_shareText)}'),
  );

  Future<void> _email(BuildContext context) => _openExternal(
    context,
    Uri(
      scheme: 'mailto',
      query:
          'subject=${Uri.encodeComponent('Acompanhamento da sua OS')}'
          '&body=${Uri.encodeComponent(_shareText)}',
    ),
  );

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
          // Enviar o link ao cliente é a ÚNICA coisa da OS que não funciona
          // offline (o cliente precisa alcançar o servidor pelo link).
          RequiresConnection(
            reason: 'o envio do link ao cliente exige internet',
            child: Wrap(
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
                  onPressed: () => _whatsApp(context),
                ),
                NeuButton(
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                  kind: NeuButtonKind.secondary,
                  onPressed: () => _email(context),
                ),
              ],
            ),
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
      await ref
          .read(osRepositoryProvider)
          .createNote(
            order.id,
            message: draft.message,
            visiblePublic: draft.visiblePublic,
          );
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      // Notas criadas offline ficam no aparelho até a conexão voltar.
      notice: const OfflinePendingNotice(
        message:
            'Notas criadas agora só serão enviadas ao sistema quando a '
            'conexão voltar',
      ),
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
                            color: neu.ink,
                            fontWeight: FontWeight.w700,
                          ),
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
    Navigator.of(
      context,
    ).pop(_NoteDraft(message: text, visiblePublic: _visiblePublic));
  }

  @override
  Widget build(BuildContext context) {
    return NeuDialog(
      title: 'Adicionar nota',
      maxWidth: context.isMobile ? 560 : 420,
      actions: [
        NeuButton(
          label: 'Cancelar',
          kind: NeuButtonKind.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: 'Adicionar',
          icon: Icons.check_rounded,
          onPressed: _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _message,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Nota',
              hintText: 'Ex.: peça pedida ao fornecedor, previsão de chegada…',
              alignLabelWithHint: true,
              counterText: '',
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
      await ref
          .read(osRepositoryProvider)
          .addPhoto(
            order.id,
            bytes: file.bytes!,
            filename: file.name,
            contentType: 'image/$ext',
            caption: null,
          );
      ref.invalidate(orderProvider(order.id));
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Abre a thread de comentários da foto (staff lê e adiciona).
  Future<void> _openComments(OrderPhoto photo) async {
    await showNeuDialog<void>(
      context,
      dialog: NeuDialog(
        title: 'Comentários da foto',
        maxWidth: 520,
        child: _PhotoCommentsPanel(orderId: order.id, photo: photo),
      ),
    );
    // Recarrega o detalhe ao fechar: o badge de comentários da miniatura
    // reflete o que a thread mostrou (inclui comentários novos do cliente).
    if (mounted) ref.invalidate(orderProvider(order.id));
  }

  @override
  Widget build(BuildContext context) {
    final photos = order.photos;
    // Offline: a foto fica guardada no aparelho (blob) e sobe no replay; abrir
    // comentários e remover foto exigem a foto existir no servidor.
    final offline = ref.watch(isOfflineProvider);
    return _SectionCard(
      icon: Icons.photo_library_rounded,
      title: 'Fotos',
      glyphIndex: 5,
      notice: const OfflinePendingNotice(
        message:
            'As fotos adicionadas agora só serão enviadas ao sistema '
            'quando a conexão voltar',
      ),
      action: widget.canWrite
          ? _HeaderAction(
              icon: _busy
                  ? Icons.hourglass_top_rounded
                  : Icons.add_a_photo_outlined,
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
                  offline: offline,
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
    this.offline = false,
  });

  final OrderPhoto photo;
  final bool canWrite;

  /// Offline: comentários e remoção da foto exigem servidor (B8) — o toque é
  /// bloqueado e a miniatura ganha tooltip "Requer conexão".
  final bool offline;
  final VoidCallback onRemove;

  /// Toque na miniatura abre a thread de comentários da foto.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget image = NeuNetworkImage(
      url: photo.url,
      width: 96,
      height: 96,
      radius: 12,
    );
    return Stack(
      children: [
        if (offline)
          Tooltip(
            message: '$kRequiresConnectionTooltip — comentários da foto',
            child: Opacity(opacity: 0.75, child: image),
          )
        else
          GestureDetector(onTap: onTap, child: image),
        // Selo de comentários: só aparece quando a foto TEM comentários, com a
        // contagem — assim a equipe sabe sem precisar abrir a foto.
        if (photo.commentCount > 0)
          Positioned(
            bottom: 2,
            left: 2,
            child: Material(
              color: Colors.black54,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: offline ? null : onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mode_comment_outlined,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${photo.commentCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Remover foto exige a foto NO SERVIDOR (não há op de sync p/ remoção):
        // offline o botão continua VISÍVEL, mas inerte e explicado — some ≠
        // explicar.
        if (canWrite)
          Positioned(
            top: 2,
            right: 2,
            child: RequiresConnection(
              reason: 'remover foto',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
            if (!_loaded && snap.connectionState == ConnectionState.waiting) {
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
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  style: TextStyle(color: neu.ink, fontSize: 14.5),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
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

