import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../../../core/util/validators.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../domain/receivables_models.dart';

/// Recebimento de um título em fiado.
///
/// Não reusa o `EntryDialog` porque aquele é acoplado à OS (tem seletor de OS,
/// categorias de gestão e `saleKind: 'os'` fixo) e não sabe receber uma venda de
/// balcão. Aqui o título já está escolhido, então o diálogo é só: quanto, como e
/// uma observação — com o saldo pré-preenchido e editável, que é o que permite
/// receber parcial ("hoje ele me paga metade").
///
/// O recebimento em si é um lançamento no caixa apontando para a venda/OS — a
/// mesma e única porta por onde dinheiro entra.
Future<bool> showReceiveTitleDialog(
  BuildContext context,
  WidgetRef ref, {
  required CashierConfig config,
  required ReceivableTitle title,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ReceiveTitleDialog(config: config, title: title),
  );
  return ok ?? false;
}

class _ReceiveTitleDialog extends ConsumerStatefulWidget {
  const _ReceiveTitleDialog({required this.config, required this.title});

  final CashierConfig config;
  final ReceivableTitle title;

  @override
  ConsumerState<_ReceiveTitleDialog> createState() =>
      _ReceiveTitleDialogState();
}

class _ReceiveTitleDialogState extends ConsumerState<_ReceiveTitleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amountCtrl = TextEditingController(
    // Pré-preenche com o SALDO (não com o total): é o que falta receber.
    text: formatAmountForInput(widget.title.balance.toDouble()),
  );
  final _descCtrl = TextEditingController();
  late String _method = widget.config.paymentMethods.first;
  bool _saving = false;

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
    final valor = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) return;
    // Receber mais do que se deve seria erro de digitação virando dinheiro
    // fantasma no caixa — barra antes de gravar.
    if (valor > widget.title.balance + 0.005) {
      _snack('O valor é maior que o saldo de '
          '${formatMoney(widget.title.balance)}.');
      return;
    }
    setState(() => _saving = true);
    final nota = _descCtrl.text.trim();
    try {
      await ref.read(cashierControllerProvider.notifier).addEntry(
            EntryDraft(
              amount: valor,
              method: _method,
              // A direção (entrada) é derivada da categoria no backend.
              category: widget.title.origin == 'os'
                  ? 'os_payment'
                  : 'venda_avulsa',
              saleKind: widget.title.origin,
              saleId: widget.title.id,
              // O extrato mostra de qual título veio o dinheiro.
              description: nota.isEmpty ? _rotulo : '$_rotulo · $nota',
            ),
          );
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
    final parcial = t.status == 'parcial';
    return NeuDialog(
      title: 'Receber $_rotulo',
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
                      parcial ? 'Saldo a receber' : 'Valor em aberto',
                      style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                    ),
                  ),
                  Text(
                    formatMoney(t.balance),
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (parcial)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Total ${formatMoney(t.total)} · já pagou '
                  '${formatMoney(t.paid)}',
                  style: TextStyle(color: neu.inkFaint, fontSize: 11.5),
                ),
              ),
            const SizedBox(height: 14),
            NeuTextField(
              label: 'Valor recebido *',
              controller: _amountCtrl,
              hint: '0,00',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter()],
              validator: Validators.positiveNumber(field: 'Valor'),
              helper: 'Pode receber parcial — edite o valor à vontade.',
            ),
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
