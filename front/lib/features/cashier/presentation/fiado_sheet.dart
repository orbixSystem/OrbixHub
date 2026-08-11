import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../os/domain/os_models.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';
import 'cashier_sheet_widgets.dart';

/// Bottom sheet de FIADO / A PRAZO.
/// Lança um plano de parcelas para uma OS sem registrar nenhuma entrada de caixa
/// agora — o cliente pagará futuramente, parcela a parcela.
Future<void> showFiadoSheet(
  BuildContext context,
  WidgetRef ref,
  CashierConfig config,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FiadoSheet(externalRef: ref, config: config),
  );
}

class _FiadoSheet extends ConsumerStatefulWidget {
  const _FiadoSheet({required this.externalRef, required this.config});
  final WidgetRef externalRef;
  final CashierConfig config;

  @override
  ConsumerState<_FiadoSheet> createState() => _FiadoSheetState();
}

class _FiadoSheetState extends ConsumerState<_FiadoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();

  ServiceOrder? _selectedOs;
  PaymentDetail? _osPayment;
  bool _loadingBalance = false;
  bool _saving = false;

  // Parcelamento
  int _numParcelas = 1;
  int _diaVencimento = 10;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  double get _totalAPrazo => _osPayment?.balance.toDouble() ?? 0;

  Future<void> _onOsSelected(ServiceOrder? os) async {
    setState(() {
      _selectedOs = os;
      _osPayment = null;
    });
    if (os == null) return;
    setState(() => _loadingBalance = true);
    try {
      final detail = await widget.externalRef
          .read(cashierRepositoryProvider)
          .paymentSummary(
            saleKind: 'os',
            saleId: os.id,
            total: moneyToDouble(os.total),
          );
      if (!mounted) return;
      setState(() => _osPayment = detail);
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione a OS'),
          backgroundColor: context.neu.danger,
        ),
      );
      return;
    }
    if (_totalAPrazo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Esta OS não tem saldo em aberto.'),
          backgroundColor: context.neu.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final note = _descCtrl.text.trim();
      await widget.externalRef
          .read(cashierRepositoryProvider)
          .createInstallmentPlan(
            InstallmentPlanDraft(
              saleKind: 'os',
              saleId: _selectedOs!.id,
              installmentCount: _numParcelas,
              dueDayOfMonth: _diaVencimento,
              totalAmount: _totalAPrazo,
              notes: note.isEmpty ? null : note,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: context.neu.danger,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: NeuSurface(
          elevation: NeuElevation.raised,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: neu.inkFaint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Título
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFFF59E0B),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fiado / A prazo',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              'Nenhum pagamento agora — o cliente paga depois.',
                              style:
                                  TextStyle(color: neu.inkMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Picker de OS
                  CashierOsPickerField(
                    selected: _selectedOs,
                    onChanged: _onOsSelected,
                    ref: widget.externalRef,
                  ),
                  if (_loadingBalance)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else if (_osPayment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: CashierBalanceLine(payment: _osPayment!),
                    ),
                  const SizedBox(height: 20),
                  // Configuração de parcelas
                  NeuSurface(
                    elevation: NeuElevation.inset,
                    radius: NeuTokens.rField,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                size: 18, color: neu.navy),
                            const SizedBox(width: 8),
                            Text(
                              'Condições de pagamento',
                              style: TextStyle(
                                color: neu.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // Nº de parcelas
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nº de parcelas',
                                    style: TextStyle(
                                      color: neu.inkMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  NeuSurface(
                                    elevation: NeuElevation.inset,
                                    radius: NeuTokens.rChip,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove,
                                              size: 16),
                                          onPressed: _numParcelas > 1
                                              ? () => setState(
                                                  () => _numParcelas--)
                                              : null,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            _numParcelas == 1
                                                ? '1x (único)'
                                                : '$_numParcelas x',
                                            style: TextStyle(
                                              color: neu.ink,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.add, size: 16),
                                          onPressed: _numParcelas < 60
                                              ? () => setState(
                                                  () => _numParcelas++)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Dia de vencimento
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dia de vencimento',
                                    style: TextStyle(
                                      color: neu.inkMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  NeuSurface(
                                    elevation: NeuElevation.inset,
                                    radius: NeuTokens.rChip,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove,
                                              size: 16),
                                          onPressed: _diaVencimento > 1
                                              ? () => setState(
                                                  () => _diaVencimento--)
                                              : null,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            'dia $_diaVencimento',
                                            style: TextStyle(
                                              color: neu.ink,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.add, size: 16),
                                          onPressed: _diaVencimento < 28
                                              ? () => setState(
                                                  () => _diaVencimento++)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Resumo do parcelamento
                        if (_totalAPrazo > 0)
                          Builder(builder: (ctx) {
                            final perParcela =
                                _totalAPrazo / _numParcelas;
                            if (_numParcelas == 1) {
                              return Text(
                                'Pagamento único de ${formatMoney(_totalAPrazo)} '
                                'todo dia $_diaVencimento',
                                style: TextStyle(
                                  color: neu.navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }
                            return Text(
                              '${_numParcelas}x de ${formatMoney(perParcela)} '
                              '· vencimento todo dia $_diaVencimento',
                              style: TextStyle(
                                color: neu.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  NeuTextField(
                    label: 'Observação (opcional)',
                    controller: _descCtrl,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 20),
                  NeuButton(
                    label: _numParcelas == 1
                        ? 'Lançar como fiado'
                        : 'Parcelar em $_numParcelas x',
                    expanded: true,
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
