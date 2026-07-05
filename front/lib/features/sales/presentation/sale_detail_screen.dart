import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/ui/ui.dart';
import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../invoice/domain/invoice_models.dart';
import '../../invoice/presentation/invoice_providers.dart';
import '../../invoice/presentation/invoice_status.dart';
import '../../os/presentation/os_status.dart' show money;
import '../domain/sale_models.dart';
import 'sale_providers.dart';
import 'sale_status.dart';

const _maxContentWidth = 900.0;

/// Ficha da venda: cabeçalho (nº/data/status/pagamento), cliente, itens, totais
/// e ação de cancelar (só concluída + `cashier.write`). Corpo apenas — a moldura
/// é do shell.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  bool _has(WidgetRef ref, String perm) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasPermission(perm);
  }

  bool _hasModule(WidgetRef ref, String key) {
    final s = ref.read(sessionControllerProvider);
    return s is SessionAuthenticated && s.me.hasModule(key);
  }

  /// Emite a NF a partir desta venda e abre a nota criada.
  Future<void> _issueNf(BuildContext context, WidgetRef ref, Sale sale) async {
    try {
      final invoice =
          await ref.read(invoiceRepositoryProvider).issue(saleId: sale.id);
      // Reflete na venda que agora há nota (ao voltar, mostra "ver nota").
      ref.invalidate(saleInvoicesProvider(sale.id));
      if (context.mounted) context.go('/m/invoice/${invoice.id}');
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Sale sale) async {
    final reason = await _CancelDialog.show(context);
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(saleRepositoryProvider).cancel(sale.id, reason);
      ref.invalidate(saleProvider(saleId));
      ref.invalidate(saleListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venda cancelada. Estoque estornado.')),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleProvider(saleId));
    final canSell = _has(ref, 'cashier.write');
    final isDesktop = context.isDesktop;

    return saleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(e is AppException ? e.message : 'Erro ao carregar a venda.'),
      ),
      data: (sale) {
        final canCancel = sale.status == 'concluida' && canSell;
        // Seção fiscal: só p/ venda concluída com o módulo invoice habilitado.
        // Se já há nota ATIVA, mostra "ver nota"; senão, "emitir" (com permissão).
        Widget? nfSection;
        if (sale.status == 'concluida' && _hasModule(ref, 'invoice')) {
          final invPage = ref.watch(saleInvoicesProvider(sale.id)).asData?.value;
          final active = (invPage?.items ?? const <Invoice>[]).where((i) =>
              i.status == 'draft' ||
              i.status == 'processing' ||
              i.status == 'authorized');
          if (active.isNotEmpty) {
            nfSection = _NfExistingSection(invoice: active.first);
          } else if (_has(ref, 'invoice.issue')) {
            nfSection = _IssueNfSection(onIssue: () => _issueNf(context, ref, sale));
          }
        }
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
                    onPressed: () => context.go('/m/sales'),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Voltar'),
                  ),
                ),
                const SizedBox(height: 8),
                _Header(sale: sale),
                const SizedBox(height: 20),
                _CustomerSection(sale: sale),
                const SizedBox(height: 20),
                _ItemsSection(items: sale.items),
                const SizedBox(height: 20),
                _TotalsSection(sale: sale),
                if (nfSection != null) ...[
                  const SizedBox(height: 20),
                  nfSection,
                ],
                if (canCancel) ...[
                  const SizedBox(height: 20),
                  _CancelSection(onCancel: () => _cancel(context, ref, sale)),
                ],
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
  const _Header({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final n = sale.number;
    final title = (n == null || n.isEmpty) ? 'Venda' : 'Venda nº $n';
    final date = saleFmtDateTime(sale.createdAt);
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconChip.glyph(context,
                  icon: Icons.point_of_sale_rounded, index: 0, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
                        SaleStatusChip(status: sale.status),
                        const SizedBox(width: 8),
                        NeuStatusChip(
                          label: paymentMethodLabel(sale.paymentMethod),
                          icon: paymentMethodIcon(sale.paymentMethod),
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
          if (date.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 16, color: neu.inkFaint),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: TextStyle(color: neu.inkMuted, fontSize: 13.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== Cliente =====================

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final hasCustomer = (sale.customerName ?? '').isNotEmpty;
    return _SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Cliente',
      glyphIndex: 1,
      child: Row(
        children: [
          Icon(
            hasCustomer ? Icons.person_rounded : Icons.storefront_outlined,
            color: neu.inkMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasCustomer ? sale.customerName! : 'Consumidor final',
              style: TextStyle(
                color: neu.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Itens =====================

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.items});

  final List<SaleItem> items;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.list_alt_rounded,
      title: 'Itens da venda',
      glyphIndex: 0,
      child: items.isEmpty
          ? Text('Sem itens.',
              style: TextStyle(color: neu.inkFaint, fontSize: 14))
          : NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          color: neu.base,
                          indent: 14,
                          endIndent: 14),
                    _ItemRow(item: items[i]),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final isService = item.kind == 'service';
    final detail = '${_fmtQty(item.quantity)} × ${money(item.unitPrice)}';
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
                    style:
                        TextStyle(color: neu.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(color: neu.inkMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(money(item.total),
              style: TextStyle(color: neu.ink, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// Mostra a quantidade sem casas quando inteira (2 em vez de 2,00).
  String _fmtQty(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return raw;
    return v == v.truncate()
        ? v.toInt().toString()
        : v.toString().replaceAll('.', ',');
  }
}

// ===================== Totais =====================

class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final hasDiscount = (double.tryParse(sale.discount) ?? 0) > 0;
    return _SectionCard(
      icon: Icons.payments_rounded,
      title: 'Totais',
      glyphIndex: 2,
      child: Column(
        children: [
          _TotalRow(label: 'Subtotal', value: money(sale.subtotal)),
          if (hasDiscount) ...[
            const SizedBox(height: 8),
            _TotalRow(label: 'Desconto', value: '- ${money(sale.discount)}'),
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
                  money(sale.total),
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

// ===================== Emitir NF =====================

class _IssueNfSection extends StatelessWidget {
  const _IssueNfSection({required this.onIssue});

  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.receipt_long_rounded,
      title: 'Nota fiscal',
      glyphIndex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emita a nota fiscal desta venda. A nota abre em seguida para você '
            'acompanhar a autorização.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: NeuButton(
              label: 'Emitir NF',
              icon: Icons.receipt_long_rounded,
              onPressed: onIssue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nota já emitida para esta venda: mostra o status e link para ver a nota.
class _NfExistingSection extends StatelessWidget {
  const _NfExistingSection({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return _SectionCard(
      icon: Icons.receipt_long_rounded,
      title: 'Nota fiscal',
      glyphIndex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InvoiceStatusChip(status: invoice.status),
              if ((invoice.number ?? '').isNotEmpty) ...[
                const SizedBox(width: 10),
                Text('Nº ${invoice.number}',
                    style: TextStyle(color: neu.inkMuted, fontSize: 13.5)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: NeuButton(
              label: 'Ver nota',
              icon: Icons.open_in_new_rounded,
              kind: NeuButtonKind.secondary,
              onPressed: () => context.go('/m/invoice/${invoice.id}'),
            ),
          ),
        ],
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
      title: 'Cancelar venda',
      glyphIndex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O cancelamento é definitivo e registra o motivo. O estoque dos '
            'produtos é estornado, mas o histórico é preservado.',
            style: TextStyle(color: neu.inkMuted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: NeuButton(
              label: 'Cancelar venda',
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
        title: 'Cancelar venda',
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
          hint: 'Ex.: cliente desistiu da compra.',
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
              label: 'Cancelar venda',
              kind: NeuButtonKind.danger,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
