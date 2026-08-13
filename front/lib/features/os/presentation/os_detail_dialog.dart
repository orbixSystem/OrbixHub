import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';

import '../../../core/export/file_download.dart';
import '../../../core/pdf/company_document_provider.dart';
import '../../../core/ui/ui.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../domain/os_models.dart';
import 'os_pdf.dart';
import 'os_providers.dart';
import 'os_status.dart';
import 'payment_status.dart';

/// Detalhe RESUMIDO de uma OS, em modal — o equivalente do
/// `showSaleDetailDialog` para o outro tipo de título.
///
/// Existe para responder "o que é essa dívida?" sem tirar o operador de onde
/// ele está (a carteira de fiado, o histórico do caixa). Antes, só a venda
/// tinha esse caminho: a OS obrigava a navegar para a tela cheia e voltar,
/// perdendo a lista de cobrança.
///
/// É leitura + exportar. Editar itens, mudar status, fotos e timeline seguem na
/// TELA da OS — "Abrir OS completa" leva até lá quando é isso que se quer.
Future<void> showOsDetailDialog(
  BuildContext context, {
  required String orderId,
}) {
  return showNeuDialog<void>(
    context,
    dialog: NeuDialog(
      title: 'Ordem de serviço',
      maxWidth: 560,
      child: _OsDetail(orderId: orderId),
    ),
  );
}

/// OS + resumo de pagamento, buscados juntos.
final _osDetailProvider = FutureProvider.autoDispose
    .family<({ServiceOrder order, PaymentDetail? payment}), String>(
        (ref, orderId) async {
  final order = await ref.read(osRepositoryProvider).getOrder(orderId);
  PaymentDetail? payment;
  try {
    // O caixa não conhece o total da OS — quem sabe é a OS (regra "aponta,
    // não invade"), então passamos o total daqui.
    payment = await ref.read(cashierRepositoryProvider).paymentSummary(
          saleKind: 'os',
          saleId: orderId,
          total: moneyToDouble(order.total ?? '0'),
        );
  } catch (_) {
    // Sem o resumo (caixa indisponível) o detalhe ainda vale: mostra os itens.
  }
  return (order: order, payment: payment);
});

class _OsDetail extends ConsumerWidget {
  const _OsDetail({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final async = ref.watch(_osDetailProvider(orderId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: neu.danger, size: 28),
            const SizedBox(height: 10),
            Text(
              '$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            NeuButton(
              label: 'Tentar de novo',
              kind: NeuButtonKind.secondary,
              onPressed: () => ref.invalidate(_osDetailProvider(orderId)),
            ),
          ],
        ),
      ),
      data: (d) => _Corpo(order: d.order, payment: d.payment),
    );
  }
}

class _Corpo extends ConsumerWidget {
  const _Corpo({required this.order, required this.payment});

  final ServiceOrder order;
  final PaymentDetail? payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neu = context.neu;
    final simples = osSimpleStatusOf(order.status);
    // Gráfico para o tint, legível para o rótulo — ver osStatusInk.
    final corStatus = osSimpleStatusInk(simples, Theme.of(context).brightness);
    final tintStatus = osSimpleStatusColor(simples);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identidade: número + status + pagamento.
        Row(
          children: [
            Expanded(
              child: Text(
                order.number,
                style: TextStyle(
                  color: neu.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            NeuStatusChip(
              label: osSimpleStatusLabel(simples),
              color: corStatus,
              tint: tintStatus.withValues(alpha: .14),
              icon: osSimpleStatusIcon(simples),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if ((payment?.total ?? 0) > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: PaymentTag(status: order.paymentStatus, dense: true),
          ),
        const SizedBox(height: 14),
        // Quem e o quê — as duas perguntas que identificam a OS.
        _Linha(rotulo: 'Cliente', valor: order.customerName ?? '—'),
        if ((order.subjectLabel ?? '').isNotEmpty)
          _Linha(rotulo: 'Veículo', valor: order.subjectLabel!),
        if ((order.assignedToName ?? '').isNotEmpty)
          _Linha(rotulo: 'Responsável', valor: order.assignedToName!),
        if ((order.complaint ?? '').isNotEmpty)
          _Linha(rotulo: 'Relato', valor: order.complaint!),
        if ((order.diagnosis ?? '').isNotEmpty)
          _Linha(rotulo: 'Diagnóstico', valor: order.diagnosis!),
        const SizedBox(height: 16),
        // O que foi feito/vendido.
        Text(
          'Itens',
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (order.items.isEmpty)
          Text(
            'Sem itens lançados.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
          )
        else
          NeuSurface(
            elevation: NeuElevation.inset,
            radius: NeuTokens.rField,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                for (final i in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          i.kind == 'service'
                              ? Icons.handyman_outlined
                              : Icons.inventory_2_outlined,
                          size: 14,
                          color: neu.inkFaint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _qtdPrefixo(i.quantity) + i.name,
                            maxLines: 2,
                            style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          money(i.total),
                          style: TextStyle(
                            color: neu.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _TotalDestaque(total: order.total ?? '0'),
        if (payment != null && payment!.total > 0) ...[
          const SizedBox(height: 10),
          _Linha(rotulo: 'Pago', valor: formatMoney(payment!.paid)),
          if (payment!.balance > 0)
            _Linha(
              rotulo: 'Saldo a receber',
              valor: formatMoney(payment!.balance),
              destaque: true,
            ),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            _BotaoExportar(order: order),
            NeuButton(
              label: 'Abrir OS completa',
              icon: Icons.open_in_new_rounded,
              onPressed: () {
                // Fecha o modal antes de navegar: senão a OS abre por baixo
                // dele e o usuário volta para um diálogo órfão.
                Navigator.of(context).pop();
                context.push('/m/os/${order.id}');
              },
            ),
          ],
        ),
      ],
    );
  }

  /// "4× " quando a quantidade passa de 1 (e sem casas inúteis); vazio senão.
  String _qtdPrefixo(String quantity) {
    final q = double.tryParse(quantity) ?? 1;
    if (q <= 1) return '';
    final txt = q == q.roundToDouble() ? q.toInt().toString() : q.toString();
    return '$txt× ';
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              rotulo,
              style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                color: destaque ? neu.warning : neu.ink,
                fontSize: 14,
                fontWeight: destaque ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalDestaque extends StatelessWidget {
  const _TotalDestaque({required this.total});
  final String total;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: neu.navy.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(NeuTokens.rField),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total',
            style: TextStyle(
              color: neu.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              money(total),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: neu.navy,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoExportar extends ConsumerStatefulWidget {
  const _BotaoExportar({required this.order});

  final ServiceOrder order;

  @override
  ConsumerState<_BotaoExportar> createState() => _BotaoExportarState();
}

class _BotaoExportarState extends ConsumerState<_BotaoExportar> {
  bool _gerando = false;

  Future<void> _exportar() async {
    setState(() => _gerando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final company = await ref.read(companyForDocumentsProvider.future);
      final bytes = await buildOsPdf(
        widget.order,
        PdfPageFormat.a4,
        company: company,
      );
      final numero =
          widget.order.number.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
      final nome = 'OS-$numero.pdf';
      await downloadBytes(bytes, nome, 'application/pdf');
      showNeuSuccessOn(messenger, 'PDF exportado: $nome');
    } on Object {
      showNeuErrorOn(messenger, 'Não foi possível gerar o PDF.');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuButton(
      label: 'Exportar PDF',
      icon: Icons.picture_as_pdf_outlined,
      kind: NeuButtonKind.secondary,
      loading: _gerando,
      onPressed: _gerando ? null : _exportar,
    );
  }
}
