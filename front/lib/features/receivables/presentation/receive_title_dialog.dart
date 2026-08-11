import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/domain/local_payment.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../cashier/presentation/cashier_sheet_widgets.dart';
import '../domain/receivables_models.dart';

/// Recebimento de um título em fiado — a ÚNICA porta de entrada de dinheiro
/// para uma OS/venda já registrada.
///
/// A regra é uma só e é simples: **digite quanto o cliente está pagando**. Se
/// for o saldo todo, quita; se for menos, o resto continua pendente e aparece
/// na carteira. Parcelar não é uma operação concorrente (não é outro botão) —
/// é uma OPÇÃO do que sobrou: recebeu metade, pode programar o restante em N
/// vezes ali mesmo, sem sair do fluxo.
///
/// Quando o título já tem plano de parcelas, o diálogo abre focado na PRÓXIMA
/// parcela (valor fixo, quitação registrada via `payInstallment`) — quem
/// parcelou já decidiu os valores; reabrir essa conta aqui só confundiria.
///
/// O recebimento em si é um lançamento no caixa apontando para a venda/OS — a
/// mesma e única porta por onde dinheiro entra.
Future<bool> showReceiveTitleDialog(
  BuildContext context,
  WidgetRef ref, {
  required CashierConfig config,
  required ReceivableTitle title,
  Installment? parcela,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _ReceiveTitleDialog(config: config, title: title, parcela: parcela),
  );
  return ok ?? false;
}

class _ReceiveTitleDialog extends ConsumerStatefulWidget {
  const _ReceiveTitleDialog({
    required this.config,
    required this.title,
    this.parcela,
  });

  final CashierConfig config;
  final ReceivableTitle title;

  /// Parcela alvo, quando o título já está parcelado.
  final Installment? parcela;

  @override
  ConsumerState<_ReceiveTitleDialog> createState() =>
      _ReceiveTitleDialogState();
}

class _ReceiveTitleDialogState extends ConsumerState<_ReceiveTitleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amountCtrl = TextEditingController(
    // Pré-preenche com o que se espera receber: o valor da parcela, quando há
    // plano, ou o SALDO (não o total) quando não há.
    text: formatAmountForInput(_esperado),
  );
  final _descCtrl = TextEditingController();
  late String _method = widget.config.paymentMethods.isNotEmpty
      ? widget.config.paymentMethods.first
      : 'pix';
  bool _saving = false;

  // Parcelamento do que sobrar (só quando NÃO há plano ainda).
  bool _parcelar = false;
  int _numParcelas = 2;
  int _diaVencimento = 10;

  double get _saldo => widget.title.balance.toDouble();
  double get _esperado => widget.parcela?.valor ?? _saldo;

  double get _digitado =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

  /// Quanto continua pendente depois deste recebimento.
  double get _restante => round2Money(_saldo - _digitado);

  /// Só oferece parcelar quando de fato sobra dinheiro E o título ainda não
  /// tem plano — parcelar duas vezes o mesmo saldo não faria sentido.
  bool get _podeParcelarRestante =>
      widget.parcela == null && _restante > paymentEps && _digitado > 0;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String get _rotulo => widget.title.origin == 'os'
      ? widget.title.number
      : 'Venda ${widget.title.number}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final parcela = widget.parcela;
    final valor = _digitado;
    // Quitação de PARCELA não usa o valor digitado (o backend cobra o valor
    // programado), então as travas de valor abaixo só valem no caminho livre.
    if (parcela == null) {
      if (valor <= 0) {
        // Nunca sair calado: "o botão não faz nada" é o pior modo de falha, e
        // já custou caro neste app.
        _snack('Informe um valor maior que zero.');
        return;
      }
      // Receber mais do que se deve seria erro de digitação virando dinheiro
      // fantasma no caixa — barra antes de gravar.
      if (valor > _saldo + paymentEps) {
        _snack('O valor é maior que o saldo de ${formatMoney(_saldo)}.');
        return;
      }
    }
    setState(() => _saving = true);
    final nota = _descCtrl.text.trim();
    try {
      if (parcela != null) {
        // Quitação de parcela: o backend lança no caixa E marca a parcela.
        await ref.read(cashierRepositoryProvider).payInstallment(
              installmentId: parcela.id,
              method: _method,
              description: nota.isEmpty ? _rotulo : '$_rotulo · $nota',
            );
      } else {
        await ref.read(cashierControllerProvider.notifier).addEntry(
              EntryDraft(
                amount: valor,
                method: _method,
                // A direção (entrada) é derivada da categoria no backend.
                category:
                    widget.title.origin == 'os' ? 'os_payment' : 'venda_avulsa',
                saleKind: widget.title.origin,
                saleId: widget.title.id,
                // O extrato mostra de qual título veio o dinheiro.
                description: nota.isEmpty ? _rotulo : '$_rotulo · $nota',
              ),
            );
        // Programar o que sobrou, quando pedido — na mesma ação, para o
        // operador não ter de voltar depois só para parcelar.
        if (_parcelar && _restante > paymentEps) {
          await ref.read(cashierRepositoryProvider).createInstallmentPlan(
                InstallmentPlanDraft(
                  saleKind: widget.title.origin,
                  saleId: widget.title.id,
                  installmentCount: _numParcelas,
                  dueDayOfMonth: _diaVencimento,
                  totalAmount: _restante,
                ),
              );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('$e');
    }
  }

  void _snack(String msg) {
    final neu = context.neu;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: neu.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final t = widget.title;
    final parcela = widget.parcela;
    final parcial = t.status == 'parcial';
    return NeuDialog(
      title: parcela != null ? 'Receber parcela' : 'Receber $_rotulo',
      maxWidth: 440,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Cancelar',
            kind: NeuButtonKind.secondary,
            onPressed: _saving ? null : () => Navigator.pop(ctx, false),
          ),
        ),
        NeuButton(
          label: 'Registrar',
          icon: Icons.payments_outlined,
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NeuSurface(
              elevation: NeuElevation.inset,
              radius: NeuTokens.rField,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      parcela != null
                          ? 'Parcela de $_rotulo'
                          : (parcial ? 'Saldo a receber' : 'Valor em aberto'),
                      style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                    ),
                  ),
                  Text(
                    formatMoney(_esperado),
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (parcela == null && parcial)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Total ${formatMoney(t.total)} · já pagou '
                  '${formatMoney(t.paid)}',
                  style: TextStyle(color: neu.inkFaint, fontSize: 11.5),
                ),
              ),
            const SizedBox(height: 14),
            // Parcela tem valor definido pelo plano: mostrar um campo editável
            // convidaria a divergir do cronograma sem que nada explicasse a
            // diferença depois.
            if (parcela != null)
              _ValorFixo(valor: _esperado, vencimento: parcela.dueDate)
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NeuTextField(
                      label: 'Valor recebido *',
                      controller: _amountCtrl,
                      hint: '0,00',
                      prefixIcon: Icons.attach_money_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [DecimalInputFormatter()],
                      validator: Validators.positiveNumber(field: 'Valor'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quitar de uma vez, sem digitar o saldo.
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: NeuExactAmountButton(
                      label: 'Tudo',
                      tooltip: 'Preencher com o saldo total',
                      onTap: () => setState(() {
                        _amountCtrl.text = formatAmountForInput(_saldo);
                      }),
                    ),
                  ),
                ],
              ),
              // A consequência do que foi digitado, dita em uma linha: é o que
              // torna "receber parcial" óbvio em vez de um efeito colateral.
              const SizedBox(height: 8),
              _Consequencia(restante: _restante, digitado: _digitado),
              if (_podeParcelarRestante) ...[
                const SizedBox(height: 12),
                _ParcelarRestante(
                  restante: _restante,
                  ligado: _parcelar,
                  numParcelas: _numParcelas,
                  diaVencimento: _diaVencimento,
                  onToggle: (v) => setState(() => _parcelar = v),
                  onParcelas: (v) => setState(() => _numParcelas = v),
                  onDia: (v) => setState(() => _diaVencimento = v),
                ),
              ],
            ],
            const SizedBox(height: 14),
            _FormaPagamento(
              formas: widget.config.paymentMethods,
              selecionada: _method,
              onChanged: (m) => setState(() => _method = m),
            ),
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Observação (opcional)',
              controller: _descCtrl,
              maxLength: 200,
            ),
          ],
        ),
      ),
    );
  }
}

/// Valor da parcela (não editável) + vencimento.
class _ValorFixo extends StatelessWidget {
  const _ValorFixo({required this.valor, required this.vencimento});

  final double valor;
  final String vencimento;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final d = DateTime.tryParse(vencimento);
    final venc = d == null
        ? null
        : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, size: 16, color: neu.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              venc == null
                  ? 'Valor da parcela: ${formatMoney(valor)}'
                  : 'Vence em $venc · ${formatMoney(valor)}',
              style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diz, em uma linha, o que acontece com o que foi digitado: quita ou deixa
/// saldo. Sem isso "receber parcial" é um efeito invisível — o operador só
/// descobre depois, vendo a dívida ainda na carteira.
class _Consequencia extends StatelessWidget {
  const _Consequencia({required this.restante, required this.digitado});

  final double restante;
  final double digitado;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    if (digitado <= 0) return const SizedBox.shrink();
    final quita = restante <= paymentEps;
    return Row(
      children: [
        Icon(
          quita ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
          size: 15,
          color: quita ? neu.success : neu.warning,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            quita
                ? 'Quita o título.'
                : 'Ficam ${formatMoney(restante)} pendentes.',
            style: TextStyle(
              color: quita ? neu.success : neu.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Opção (não obrigação) de programar o que sobrou em parcelas mensais.
class _ParcelarRestante extends StatelessWidget {
  const _ParcelarRestante({
    required this.restante,
    required this.ligado,
    required this.numParcelas,
    required this.diaVencimento,
    required this.onToggle,
    required this.onParcelas,
    required this.onDia,
  });

  final double restante;
  final bool ligado;
  final int numParcelas;
  final int diaVencimento;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onParcelas;
  final ValueChanged<int> onDia;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Parcelar o restante',
                  style: TextStyle(
                    color: neu.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: ligado,
                onChanged: onToggle,
                activeThumbColor: neu.navy,
              ),
            ],
          ),
          if (ligado) ...[
            const SizedBox(height: 10),
            // Wrap: os dois steppers empilham sozinhos em tela estreita.
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                CashierStepperField(
                  label: 'Parcelas',
                  valueLabel: '$numParcelas x',
                  onDecrement:
                      numParcelas > 2 ? () => onParcelas(numParcelas - 1) : null,
                  onIncrement: numParcelas < 60
                      ? () => onParcelas(numParcelas + 1)
                      : null,
                ),
                CashierStepperField(
                  label: 'Vence dia',
                  valueLabel: '$diaVencimento',
                  onDecrement:
                      diaVencimento > 1 ? () => onDia(diaVencimento - 1) : null,
                  onIncrement:
                      diaVencimento < 28 ? () => onDia(diaVencimento + 1) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${numParcelas}x de '
              '${formatMoney(round2Money(restante / numParcelas))} '
              '· todo dia $diaVencimento',
              style: TextStyle(
                color: neu.navy,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Formas de pagamento vindas da CONFIG do tenant (nunca hardcoded).
class _FormaPagamento extends StatelessWidget {
  const _FormaPagamento({
    required this.formas,
    required this.selecionada,
    required this.onChanged,
  });

  final List<String> formas;
  final String selecionada;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Forma de pagamento',
          style: TextStyle(
            color: neu.inkMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in formas)
              InkWell(
                borderRadius: BorderRadius.circular(NeuTokens.rChip),
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: m == selecionada ? neu.navy : Colors.transparent,
                    border: Border.all(
                      color: m == selecionada ? neu.navy : neu.line,
                    ),
                    borderRadius: BorderRadius.circular(NeuTokens.rChip),
                  ),
                  child: Text(
                    methodLabel(m),
                    style: TextStyle(
                      color: m == selecionada ? neu.onNavy : neu.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
