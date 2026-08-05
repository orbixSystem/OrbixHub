import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/offline/widgets/offline_notices.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_state.dart';
import '../../../di.dart';
import '../../os/presentation/os_status.dart' show money;
import '../domain/invoice_models.dart';
import 'invoice_providers.dart';
import 'invoice_status.dart';

const _maxContentWidth = 900.0;

/// Ficha da nota fiscal: cabeçalho (nº/série, tipo, status), dados do cliente,
/// linhas, totais, motivo de rejeição (se houver), timeline e ações (baixar
/// PDF/XML, cancelar). Corpo apenas — a moldura é do shell.
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  bool _has(WidgetRef ref, String perm) {
    final s = ref.read(sessionControllerProvider);
    return s.meOrNull?.hasPermission(perm) ?? false;
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
  ) async {
    final reason = await _CancelDialog.show(context);
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(invoiceRepositoryProvider).cancel(invoice.id, reason);
      ref.invalidate(invoiceProvider(invoiceId));
      ref.invalidate(invoiceListProvider);
      if (context.mounted) {
        showNeuSuccessSnackBar(context, 'Nota cancelada.');
      }
    } on AppException catch (e) {
      if (context.mounted) {
        showNeuErrorSnackBar(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOfflineProvider)) {
      return const RequiresConnectionView(
        message: 'A nota fiscal é consultada no servidor fiscal. Conecte-se à '
            'internet para ver os detalhes, baixar o PDF/XML ou cancelá-la.',
      );
    }
    final invoiceAsync = ref.watch(invoiceProvider(invoiceId));
    final canIssue = _has(ref, 'invoice.issue');
    final isDesktop = context.isDesktop;

    return invoiceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is AppException ? e.message : 'Erro ao carregar a nota.'),
      ),
      data: (invoice) {
        final canCancel = invoice.status == 'authorized' && canIssue;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
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
                    onPressed: () => context.go('/m/invoice'),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Voltar'),
                  ),
                ),
                const SizedBox(height: 8),
                _Header(invoice: invoice),
                const SizedBox(height: 20),
                if (invoice.status == 'rejected' &&
                    (invoice.rejectionReason ?? '').isNotEmpty) ...[
                  _RejectionNotice(reason: invoice.rejectionReason!),
                  const SizedBox(height: 20),
                ],
                _CustomerSection(invoice: invoice),
                const SizedBox(height: 20),
                _LinesSection(lines: invoice.lines),
                const SizedBox(height: 20),
                _TotalsSection(invoice: invoice),
                const SizedBox(height: 20),
                _DocumentsSection(invoice: invoice),
                if (canCancel) ...[
                  const SizedBox(height: 20),
                  _CancelSection(onCancel: () => _cancel(context, ref, invoice)),
                ],
                const SizedBox(height: 20),
                _TimelineSection(events: invoice.events),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===================== Card de seção padrão =====================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.glyphIndex = 5,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final int glyphIndex;

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
              NeuIconChip.glyph(context, icon: icon, index: glyphIndex, size: 34),
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
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ===================== Cabeçalho =====================

class _Header extends StatelessWidget {
  const _Header({required this.invoice});

  final Invoice invoice;

  String get _title {
    final n = invoice.number;
    if (n == null || n.isEmpty) {
      return invoice.status == 'draft' ? 'Rascunho' : 'Nota fiscal';
    }
    final series = invoice.series;
    return series == null || series.isEmpty
        ? 'Nº $n'
        : 'Nº $n · Série $series';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: Icons.receipt_long_rounded, index: 0, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: TextStyle(
                        color: neu.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        InvoiceStatusChip(status: invoice.status),
                        const SizedBox(width: 8),
                        NeuStatusChip(
                          label: invoiceDocumentTypeLabel(invoice.documentType),
                          color: neu.inkMuted,
                          tint: neu.inkMuted.withValues(alpha: .14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((invoice.accessKey ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Chave de acesso',
              style: TextStyle(
                color: neu.inkFaint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              invoice.accessKey!,
              style: TextStyle(color: neu.inkMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== Aviso de rejeição =====================

class _RejectionNotice extends StatelessWidget {
  const _RejectionNotice({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neu.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(NeuTokens.rCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: neu.danger, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nota rejeitada',
                  style: TextStyle(
                    color: neu.danger,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: TextStyle(
                    color: neu.danger,
                    fontSize: 13.5,
                    height: 1.4,
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

// ===================== Cliente =====================

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String?)>[
      ('Cliente', invoice.customerName),
      ('Documento', invoice.customerDocument),
      ('OS de origem', invoice.orderNumber),
      ('Ambiente', _environmentLabel(invoice.environment)),
    ];
    return _SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Destinatário',
      glyphIndex: 1,
      child: Wrap(
        spacing: 28,
        runSpacing: 4,
        children: [
          for (final (label, value) in facts)
            if (value != null && value.isNotEmpty)
              _InlineFact(label: label, value: value),
        ],
      ),
    );
  }

  String? _environmentLabel(String? env) {
    switch (env) {
      case 'producao':
        return 'Produção';
      case 'homologacao':
        return 'Homologação';
      default:
        return env;
    }
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

// ===================== Linhas =====================

class _LinesSection extends StatelessWidget {
  const _LinesSection({required this.lines});

  final List<InvoiceLine> lines;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Itens da nota',
      glyphIndex: 0,
      child: lines.isEmpty
          ? Text(
              'Sem itens.',
              style: TextStyle(color: neu.inkFaint, fontSize: 14),
            )
          : NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: neu.base,
                          indent: 14,
                          endIndent: 14),
                    _LineRow(line: lines[i]),
                  ],
                ],
              ),
            ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isService = line.kind == 'service';
    final detail = '${line.quantity} × ${money(line.unitPrice)}';
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
                Text(line.name,
                    style: TextStyle(
                        color: neu.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(color: neu.inkMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(money(line.total),
              style: TextStyle(color: neu.ink, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ===================== Totais =====================

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.payments_rounded,
      title: 'Totais',
      glyphIndex: 2,
      child: Column(
        children: [
          if ((invoice.serviceAmount ?? '').isNotEmpty)
            _TotalRow(label: 'Serviços', value: money(invoice.serviceAmount)),
          if ((invoice.productAmount ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _TotalRow(label: 'Produtos', value: money(invoice.productAmount)),
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
                  money(invoice.totalAmount),
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

// ===================== Documentos (PDF/XML) =====================

/// Abre o PDF/XML da nota no navegador/app externo (url_launcher). Se falhar
/// (URL inválida/sem app), avisa e copia o link como fallback.
class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.invoice});

  final Invoice invoice;

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    var ok = false;
    if (uri != null) {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (ok || !context.mounted) return;
    // Fallback: copia o link se não deu para abrir.
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir. Link copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final pdf = invoice.pdfUrl;
    final xml = invoice.xmlUrl;
    final hasAny = (pdf ?? '').isNotEmpty || (xml ?? '').isNotEmpty;
    return _SectionCard(
      icon: Icons.download_rounded,
      title: 'Documentos',
      glyphIndex: 3,
      child: hasAny
          ? Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if ((pdf ?? '').isNotEmpty)
                  NeuButton(
                    label: 'Abrir PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: () => _open(context, pdf!),
                  ),
                if ((xml ?? '').isNotEmpty)
                  NeuButton(
                    label: 'Abrir XML',
                    icon: Icons.code_rounded,
                    kind: NeuButtonKind.secondary,
                    onPressed: () => _open(context, xml!),
                  ),
              ],
            )
          : Text(
              'Os arquivos ficam disponíveis quando a nota é autorizada.',
              style: TextStyle(color: neu.inkFaint, fontSize: 13.5, height: 1.4),
            ),
    );
  }
}

// ===================== Cancelar =====================

class _CancelSection extends StatelessWidget {
  const _CancelSection({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.block_rounded,
      title: 'Cancelar nota',
      glyphIndex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O cancelamento é definitivo e registra o motivo. A nota deixa de '
            'ser válida, mas o histórico é preservado.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: NeuButton(
              label: 'Cancelar nota',
              icon: Icons.block_rounded,
              kind: NeuButtonKind.danger,
              onPressed: onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog que pede o motivo do cancelamento (mín. 3 chars). Retorna o motivo ou
/// null se o usuário fechar/cancelar.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  static Future<String?> show(BuildContext context) {
    return showNeuDialog<String>(
      context,
      dialog: const NeuDialog(
        title: 'Cancelar nota fiscal',
        maxWidth: 460,
        child: _CancelDialog(),
      ),
    );
  }

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _reason.text.trim();
    if (text.length < 3) {
      setState(() => _error = 'Descreva o motivo (mínimo 3 caracteres).');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuTextField(
          controller: _reason,
          label: 'Motivo do cancelamento',
          hint: 'Ex.: nota emitida em duplicidade.',
          minLines: 2,
          maxLines: 4,
          errorText: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            NeuButton(
              label: 'Voltar',
              kind: NeuButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            NeuButton(
              label: 'Cancelar nota',
              kind: NeuButtonKind.danger,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}

// ===================== Linha do tempo =====================

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.events});

  final List<InvoiceEvent> events;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.timeline_rounded,
      title: 'Histórico',
      glyphIndex: 5,
      child: events.isEmpty
          ? Text(
              'Nenhum evento ainda.',
              style: TextStyle(color: neu.inkFaint, fontSize: 14),
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

  final InvoiceEvent event;
  final bool isFirst;
  final bool isLast;

  Color _dotColor(BuildContext context) {
    final snap = event.statusSnapshot;
    if (snap != null && snap.isNotEmpty) {
      return invoiceStatusColor(context, snap);
    }
    return context.neu.navy;
  }

  String _label() {
    final msg = event.message?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
    final snap = event.statusSnapshot;
    if (snap != null && snap.isNotEmpty) {
      return 'Status: ${invoiceStatusLabel(snap)}';
    }
    return event.kind;
  }

  String _fmtTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final dotColor = _dotColor(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  child: Icon(Icons.circle, size: 12, color: dotColor),
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
                  Text(
                    _label(),
                    style: TextStyle(
                        color: neu.ink, fontWeight: FontWeight.w700),
                  ),
                  if ((event.createdAt ?? '').isNotEmpty) ...[
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
}
