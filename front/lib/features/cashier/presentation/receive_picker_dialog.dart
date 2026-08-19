import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../os/domain/os_models.dart';
import '../../receivables/domain/receivables_models.dart';
import '../../receivables/presentation/receive_title_dialog.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';
import 'cashier_sheet_widgets.dart';

/// "Receber OS": busca a ordem de serviço e monta o MESMO [ReceivableTitle]
/// que `offerOsPayment` já usa — daqui em diante é o [showReceiveTitleDialog]
/// de sempre, sem nenhuma lógica de pagamento nova.
///
/// Só OS, de propósito: venda avulsa já tem seu próprio botão ("Venda
/// avulsa", que CRIA a venda e já recebe/deixa fiado no mesmo fluxo — ver
/// `sale_create_dialog.dart`), e o saldo de uma venda já registrada se cobra
/// pela aba Fiado (é o que aquele fluxo já diz ao usuário: "Caixa › Fiado").
/// Duas entradas com o rótulo "Venda avulsa" fazendo coisas diferentes era
/// exatamente a confusão a evitar.
Future<void> showReceivePickerDialog(
  BuildContext context,
  WidgetRef ref,
  CashierConfig config,
) async {
  final title = await showNeuDialog<ReceivableTitle>(
    context,
    dialog: NeuDialog(
      title: 'Receber OS',
      maxWidth: 460,
      child: _ReceiveOsPicker(),
    ),
  );
  if (title == null || !context.mounted) return;
  await showReceiveTitleDialog(context, ref, config: config, title: title);
}

class _ReceiveOsPicker extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ReceiveOsPicker> createState() => _ReceiveOsPickerState();
}

class _ReceiveOsPickerState extends ConsumerState<_ReceiveOsPicker> {
  ServiceOrder? _os;
  PaymentDetail? _payment;
  bool _loading = false;

  Future<void> _onOsSelected(ServiceOrder? os) async {
    setState(() {
      _os = os;
      _payment = null;
    });
    if (os == null) return;
    setState(() => _loading = true);
    try {
      final detail = await ref.read(cashierRepositoryProvider).paymentSummary(
            saleKind: 'os',
            saleId: os.id,
            total: moneyToDouble(os.total),
          );
      if (!mounted) return;
      setState(() => _payment = detail);
      // Saldo em aberto: segue direto pro recebimento, sem clique extra —
      // já sabemos o que o usuário veio fazer aqui.
      if (detail.balance > 0) {
        Navigator.of(context).pop(ReceivableTitle(
          id: os.id,
          origin: 'os',
          number: os.number,
          createdAt: os.createdAt,
          total: detail.total,
          paid: detail.paid,
          balance: detail.balance,
          status: detail.status,
        ));
      }
    } catch (_) {
      // Sem saldo carregado: fica na tela, o picker segue disponível.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CashierOsPickerField(
          selected: _os,
          ref: ref,
          onChanged: _onOsSelected,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_payment != null && _payment!.balance <= 0) ...[
          const SizedBox(height: 12),
          CashierBalanceLine(payment: _payment!),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: neu.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Esta OS já está quitada — não há saldo para receber.',
                  style: TextStyle(color: neu.inkMuted, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
