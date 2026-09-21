import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/domain/local_payment.dart';
import '../../cashier/presentation/cashier_providers.dart';

/// Corrige o VALOR de uma parcela em aberto.
///
/// O plano divide o total igualmente; a combinação real raramente é ("essa eu
/// pago 500 e as outras menores"), e valor digitado errado acontece. Antes a
/// única saída era refazer o plano inteiro — o que reescreve as datas e faz
/// perder o prazo combinado.
///
/// Só parcela EM ABERTO: o valor de uma parcela paga já virou lançamento no
/// caixa, e mexer nele deixaria os dois discordando para sempre (o servidor
/// recusa também — aqui a UI só não oferece).
///
/// Devolve `true` quando gravou.
Future<bool> showEditarParcelaDialog(
  BuildContext context, {
  required Installment parcela,
  required int ordem,
  required int total,
  /// Quanto o título ainda deve — serve para dizer, na hora, que a soma das
  /// parcelas deixou de fechar com a dívida.
  required double saldoDoTitulo,
  /// Soma das OUTRAS parcelas em aberto (sem esta).
  required double outrasEmAberto,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _EditarParcelaDialog(
      parcela: parcela,
      ordem: ordem,
      total: total,
      saldoDoTitulo: saldoDoTitulo,
      outrasEmAberto: outrasEmAberto,
    ),
  );
  return ok ?? false;
}

class _EditarParcelaDialog extends ConsumerStatefulWidget {
  const _EditarParcelaDialog({
    required this.parcela,
    required this.ordem,
    required this.total,
    required this.saldoDoTitulo,
    required this.outrasEmAberto,
  });

  final Installment parcela;
  final int ordem;
  final int total;
  final double saldoDoTitulo;
  final double outrasEmAberto;

  @override
  ConsumerState<_EditarParcelaDialog> createState() =>
      _EditarParcelaDialogState();
}

class _EditarParcelaDialogState extends ConsumerState<_EditarParcelaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _valorCtrl = TextEditingController(
    text: formatAmountForInput(widget.parcela.valor),
  );
  final _motivoCtrl = TextEditingController();
  bool _saving = false;

  double get _novoValor =>
      double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0;

  /// O que as parcelas em aberto passarão a somar com o valor digitado.
  double get _somaEmAberto => round2Money(widget.outrasEmAberto + _novoValor);

  /// Diferença entre o que as parcelas somam e o que o cliente deve. Zero é o
  /// normal; qualquer outra coisa o operador precisa ver ANTES de gravar.
  double get _diferenca => round2Money(_somaEmAberto - widget.saldoDoTitulo);

  @override
  void dispose() {
    _valorCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_novoValor <= 0) {
      showNeuErrorSnackBar(context, 'O valor da parcela precisa ser maior que zero.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(cashierRepositoryProvider).updateInstallmentAmount(
            installmentId: widget.parcela.id,
            amount: _novoValor,
            reason: _motivoCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showNeuErrorSnackBar(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuDialog(
      title: 'Valor da ${widget.ordem}ª parcela',
      maxWidth: 420,
      actions: [
        Builder(
          builder: (ctx) => NeuButton(
            label: 'Cancelar',
            kind: NeuButtonKind.secondary,
            onPressed: _saving ? null : () => Navigator.pop(ctx, false),
          ),
        ),
        NeuButton(
          label: 'Salvar valor',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving ? null : _salvar,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Parcela ${widget.ordem} de ${widget.total} · vence em '
              '${_dataBr(widget.parcela.dueDate)}',
              style: TextStyle(color: neu.inkMuted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Valor da parcela *',
              controller: _valorCtrl,
              hint: '0,00',
              prefixText: 'R\$ ',
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter()],
              validator: Validators.positiveNumber(field: 'Valor'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // A consequência ANTES de gravar: mudar uma parcela mexe no que o
            // cronograma soma, e essa soma tem de fechar com a dívida. Descobrir
            // depois, conferindo à mão, é o que fazia esta conta ser evitada.
            _Conferencia(soma: _somaEmAberto, diferenca: _diferenca),
            const SizedBox(height: 12),
            NeuTextField(
              label: 'Motivo (opcional)',
              controller: _motivoCtrl,
              hint: 'Ex.: cliente pediu para concentrar na primeira',
              maxLength: 200,
            ),
          ],
        ),
      ),
    );
  }
}

String _dataBr(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Diz se as parcelas em aberto continuam somando a dívida. Sobrar ou faltar não
/// é proibido (o operador pode estar combinando outra coisa), mas nunca deve ser
/// uma descoberta posterior.
class _Conferencia extends StatelessWidget {
  const _Conferencia({required this.soma, required this.diferenca});

  final double soma;
  final double diferenca;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final fecha = diferenca.abs() <= paymentEps;
    final sobra = diferenca > 0;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            fecha ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: fecha ? neu.success : neu.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fecha
                  ? 'As parcelas em aberto somam ${formatMoney(soma)} — fecha '
                      'com o que o cliente deve.'
                  : sobra
                      ? 'As parcelas passam a somar ${formatMoney(soma)}: '
                          '${formatMoney(diferenca)} MAIS do que o cliente deve.'
                      : 'As parcelas passam a somar ${formatMoney(soma)}: '
                          '${formatMoney(diferenca.abs())} a MENOS do que o '
                          'cliente deve.',
              style: TextStyle(
                color: fecha ? neu.inkMuted : neu.warning,
                fontSize: 13,
                fontWeight: fecha ? FontWeight.w400 : FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
