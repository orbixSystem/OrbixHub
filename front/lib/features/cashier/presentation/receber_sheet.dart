import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../os/domain/os_models.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import 'cashier_providers.dart';
import 'cashier_sheet_widgets.dart';

typedef _FieldShell = CashierFieldShell;
typedef _BalanceLine = CashierBalanceLine;
typedef _OsPickerField = CashierOsPickerField;

double? _parseAmount(String raw) {
  final v = double.tryParse(raw.trim().replaceAll(',', '.'));
  return (v == null || v <= 0) ? null : v;
}

/// Bottom sheet de RECEBIMENTO (OS ou Venda) com suporte a parcelamento do saldo.
Future<void> showReceberSheet(
  BuildContext context,
  WidgetRef ref,
  CashierConfig config,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReceberSheet(externalRef: ref, config: config),
  );
}

class _ReceberSheet extends ConsumerStatefulWidget {
  const _ReceberSheet({required this.externalRef, required this.config});
  final WidgetRef externalRef;
  final CashierConfig config;

  @override
  ConsumerState<_ReceberSheet> createState() => _ReceberSheetState();
}

class _ReceberSheetState extends ConsumerState<_ReceberSheet> {
  // 'os' ou 'sale'
  String _origin = 'os';

  // OS selecionada
  ServiceOrder? _selectedOs;
  PaymentDetail? _osPayment;
  bool _loadingBalance = false;

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  late String _method = widget.config.paymentMethods.isNotEmpty
      ? widget.config.paymentMethods.first
      : 'pix';
  final _descCtrl = TextEditingController();
  bool _saving = false;

  // Parcelamento
  bool _parcelar = false;
  int _numParcelas = 3;
  int _diaVencimento = 10;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  double get _saldo => _osPayment?.balance.toDouble() ?? 0;
  double get _valorDigitado => _parseAmount(_amountCtrl.text) ?? 0;
  bool get _temSaldoRestante =>
      _valorDigitado > 0 && _valorDigitado < _saldo - 0.005;

  Future<void> _onOsSelected(ServiceOrder? os) async {
    setState(() {
      _selectedOs = os;
      _osPayment = null;
      _parcelar = false;
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
      setState(() {
        _osPayment = detail;
        _amountCtrl.text = formatAmountForInput(detail.balance.toDouble());
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _amountCtrl.text = formatAmountForInput(moneyToDouble(os.total));
      });
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null) return;
    if (_origin == 'os' && _selectedOs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione a OS'),
          backgroundColor: context.neu.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saleId = _selectedOs?.id;
      final note = _descCtrl.text.trim();
      final description = _origin == 'os' && _selectedOs != null
          ? [
              _selectedOs!.number,
              if ((_selectedOs!.customerName?.trim().isNotEmpty) ?? false)
                _selectedOs!.customerName!.trim(),
              if (note.isNotEmpty) note,
            ].join(' · ')
          : note.isEmpty
              ? null
              : note;

      await widget.externalRef
          .read(cashierControllerProvider.notifier)
          .addEntry(
            EntryDraft(
              amount: amount,
              method: _method,
              category: _origin == 'os' ? 'os_payment' : 'venda_avulsa',
              saleKind: _origin,
              saleId: saleId,
              description: description,
            ),
          );

      // Se escolheu parcelar o restante
      if (_parcelar && _temSaldoRestante && saleId != null) {
        await widget.externalRef
            .read(cashierRepositoryProvider)
            .createInstallmentPlan(
              InstallmentPlanDraft(
                saleKind: _origin,
                saleId: saleId,
                installmentCount: _numParcelas,
                dueDayOfMonth: _diaVencimento,
                totalAmount: _saldo - _valorDigitado,
              ),
            );
      }

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
                        color: neu.success.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.payments_outlined,
                          color: neu.success, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text('Receber',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 20),
                // Seletor de origem
                _FieldShell(
                  label: 'Origem',
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      for (final opt in [
                        ('os', 'Ordem de Serviço'),
                        ('sale', 'Venda avulsa'),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: _origin == opt.$1
                                    ? neu.navy
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(NeuTokens.rChip),
                              ),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(NeuTokens.rChip),
                                onTap: () => setState(() {
                                  _origin = opt.$1;
                                  _selectedOs = null;
                                  _osPayment = null;
                                  _amountCtrl.clear();
                                  _parcelar = false;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  child: Text(
                                    opt.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _origin == opt.$1
                                          ? neu.onNavy
                                          : neu.inkMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Picker de OS / aviso de venda
                if (_origin == 'os') ...[
                  _OsPickerField(
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
                      child: _BalanceLine(payment: _osPayment!),
                    ),
                ] else
                  NeuSurface(
                    elevation: NeuElevation.inset,
                    radius: NeuTokens.rField,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Busca de venda avulsa em breve. '
                      'Use "Venda avulsa" para criar e receber.',
                      style: TextStyle(color: neu.inkMuted, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 14),
                // Valor
                NeuTextField(
                  label: 'Valor *',
                  controller: _amountCtrl,
                  hint: '0,00',
                  prefixIcon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [DecimalInputFormatter()],
                  validator: Validators.positiveNumber(field: 'Valor'),
                  helper: _osPayment != null
                      ? 'Pode receber parcial — edite o valor.'
                      : null,
                  suffix: (_osPayment == null ||
                          (_osPayment!.balance.toDouble()) <= 0)
                      ? null
                      : NeuExactAmountButton(
                          label: 'Tudo',
                          tooltip: 'Preencher com o saldo',
                          onTap: () => setState(() {
                            _amountCtrl.text = formatAmountForInput(
                                _osPayment!.balance.toDouble());
                          }),
                        ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                // Forma de pagamento
                _FieldShell(
                  label: 'Forma',
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _method,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(NeuTokens.rField),
                    dropdownColor: neu.surface,
                    icon: Icon(Icons.expand_more_rounded, color: neu.inkMuted),
                    style: TextStyle(color: neu.ink, fontSize: 15),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12),
                    ),
                    items: [
                      for (final m in widget.config.paymentMethods)
                        DropdownMenuItem(
                          value: m,
                          child: Text(methodLabel(m)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _method = v ?? _method),
                  ),
                ),
                const SizedBox(height: 14),
                // Observação
                NeuTextField(
                  label: 'Observação (opcional)',
                  controller: _descCtrl,
                  maxLength: 500,
                ),
                // Parcelamento — aparece quando há saldo restante
                if (_temSaldoRestante) ...[
                  const SizedBox(height: 16),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Parcelar restante '
                                    '(${formatMoney(_saldo - _valorDigitado)})',
                                    style: TextStyle(
                                      color: neu.ink,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Cria um plano de parcelas para o saldo em aberto',
                                    style: TextStyle(
                                        color: neu.inkMuted, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _parcelar,
                              onChanged: (v) => setState(() => _parcelar = v),
                              activeThumbColor: neu.navy,
                            ),
                          ],
                        ),
                        if (_parcelar) ...[
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
                                            icon:
                                                const Icon(Icons.remove, size: 16),
                                            onPressed: _numParcelas > 2
                                                ? () => setState(
                                                    () => _numParcelas--)
                                                : null,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Text(
                                              '$_numParcelas x',
                                              style: TextStyle(
                                                color: neu.ink,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16),
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
                                            icon:
                                                const Icon(Icons.remove, size: 16),
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
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16),
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
                          const SizedBox(height: 8),
                          Builder(builder: (ctx) {
                            final restante = _saldo - _valorDigitado;
                            if (restante <= 0) return const SizedBox.shrink();
                            final perParcela = restante / _numParcelas;
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
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                NeuButton(
                  label: _parcelar ? 'Receber e parcelar' : 'Receber',
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

