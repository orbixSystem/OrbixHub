import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../cashier/presentation/prazo_fiado_section.dart';
import '../domain/receivables_models.dart';
import 'receivables_providers.dart';

/// Combina (ou corrige) o prazo de um título que JÁ está fiado.
///
/// Existia um buraco aqui: dava para combinar prazo na hora de fiar, mas não
/// depois. Quem fiou sem data só conseguia dar uma abrindo "Receber", apagando
/// o valor que vem preenchido e clicando em "Deixar fiado" — ninguém descobre
/// isso. E quem combinou errado não tinha conserto nenhum, porque o servidor
/// recusava um segundo plano.
///
/// Devolve `true` quando gravou, para o chamador recarregar a carteira.
Future<bool> showCombinarPrazoDialog(
  BuildContext context, {
  required ReceivableTitle titulo,
  required List<Installment> parcelasAtuais,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _CombinarPrazoDialog(
      titulo: titulo,
      parcelasAtuais: parcelasAtuais,
    ),
  );
  return ok ?? false;
}

class _CombinarPrazoDialog extends ConsumerStatefulWidget {
  const _CombinarPrazoDialog({
    required this.titulo,
    required this.parcelasAtuais,
  });

  final ReceivableTitle titulo;
  final List<Installment> parcelasAtuais;

  @override
  ConsumerState<_CombinarPrazoDialog> createState() =>
      _CombinarPrazoDialogState();
}

class _CombinarPrazoDialogState extends ConsumerState<_CombinarPrazoDialog> {
  PrazoFiado _prazo = const PrazoFiado();
  bool _salvando = false;
  String? _erro;

  /// Já há prazo combinado? Então isto é uma CORREÇÃO, e o texto muda.
  bool get _corrigindo =>
      widget.parcelasAtuais.any((p) => p.paidAt == null);

  /// Parcelas já pagas não são tocadas — o que se recombina é o que falta.
  double get _aCombinar => widget.titulo.balance.toDouble();

  Future<void> _salvar() async {
    final plano = _prazo.planoPara(
      saleKind: widget.titulo.origin,
      saleId: widget.titulo.id,
      valor: _aCombinar,
      substituirPendentes: true,
    );
    if (plano == null) {
      // "Sem prazo" aqui significaria apagar o combinado sem colocar outro —
      // uma operação diferente, que o servidor não expõe. Melhor dizer isso do
      // que fingir que gravou.
      setState(() => _erro =
          'Escolha uma data única ou um parcelamento para combinar o prazo.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref.read(cashierRepositoryProvider).createInstallmentPlan(plano);
      ref.invalidate(debtorsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final rotulo = widget.titulo.origin == 'os'
        ? widget.titulo.number
        : 'Venda ${widget.titulo.number}';
    return NeuDialog(
      title: _corrigindo ? 'Alterar prazo' : 'Combinar prazo',
      maxWidth: 460,
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(_salvando ? 'Salvando…' : 'Salvar prazo'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rotulo · ${formatMoney(_aCombinar)} em aberto',
            style: TextStyle(
              color: neu.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_corrigindo) ...[
            const SizedBox(height: 6),
            Text(
              'O prazo atual será substituído. Parcelas já pagas não mudam — '
              'só o que ainda falta receber é recombinado.',
              style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 14),
          PrazoFiadoSection(
            valor: _prazo,
            total: _aCombinar,
            titulo: 'Novo prazo',
            onChanged: (p) => setState(() => _prazo = p),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(
              _erro!,
              style: TextStyle(color: neu.danger, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
