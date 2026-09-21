import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/util/masks.dart';
import '../domain/cashier_format.dart';
import '../domain/cashier_models.dart';
import '../domain/local_payment.dart';
import 'cashier_providers.dart';

/// O valor de um título PARCELADO mudou — e o cronograma não muda sozinho.
///
/// Editar os itens de uma venda (ou de uma OS) altera o que o cliente deve, mas
/// as parcelas já combinadas continuam com os valores antigos. O silêncio aqui
/// é o pior desfecho: a dívida passa a ser uma coisa e a cobrança, outra, e
/// ninguém descobre até a última parcela não fechar a conta.
///
/// Três saídas, porque as três são legítimas:
/// - **recalcular**: divide o novo saldo igualmente entre as parcelas em aberto,
///   mantendo as DATAS combinadas (por isso corrige valor por valor em vez de
///   refazer o plano, que reescreveria os vencimentos);
/// - **editar à mão**: quando a combinação não é igual ("essa eu pago 500");
/// - **deixar como está**: o operador pode ter mudado o valor de propósito e já
///   ter acertado outra coisa com o cliente. Fica a divergência, visível no
///   cronograma.
///
/// Parcela PAGA nunca entra: o valor dela já virou lançamento no caixa.
///
/// Devolve `true` se mexeu em alguma parcela.
Future<bool> showAjustarParcelasDialog(
  BuildContext context, {
  required String rotuloTitulo,
  required double totalAntes,
  required double totalDepois,
  /// Quanto o cliente ainda deve DEPOIS da edição — é o que as parcelas em
  /// aberto deveriam somar.
  required double saldo,
  required List<Installment> parcelasEmAberto,
}) async {
  if (parcelasEmAberto.isEmpty) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AjustarParcelasDialog(
      rotuloTitulo: rotuloTitulo,
      totalAntes: totalAntes,
      totalDepois: totalDepois,
      saldo: saldo,
      parcelasEmAberto: parcelasEmAberto,
    ),
  );
  return ok ?? false;
}

class _AjustarParcelasDialog extends ConsumerStatefulWidget {
  const _AjustarParcelasDialog({
    required this.rotuloTitulo,
    required this.totalAntes,
    required this.totalDepois,
    required this.saldo,
    required this.parcelasEmAberto,
  });

  final String rotuloTitulo;
  final double totalAntes;
  final double totalDepois;
  final double saldo;
  final List<Installment> parcelasEmAberto;

  @override
  ConsumerState<_AjustarParcelasDialog> createState() =>
      _AjustarParcelasDialogState();
}

class _AjustarParcelasDialogState
    extends ConsumerState<_AjustarParcelasDialog> {
  /// Modo da tela: escolher o que fazer, ou digitar os valores.
  bool _manual = false;
  bool _saving = false;

  /// Um controlador por parcela em aberto (modo manual).
  late final List<TextEditingController> _ctrls = [
    for (final p in widget.parcelasEmAberto)
      TextEditingController(text: formatAmountForInput(p.valor)),
  ];

  List<Installment> get _parcelas => widget.parcelasEmAberto;

  /// O que as parcelas somam hoje, com os valores antigos.
  double get _somaAtual =>
      round2Money(_parcelas.fold<double>(0, (a, p) => a + p.valor));

  /// Divisão igual do novo saldo, com o ajuste de centavos na ÚLTIMA parcela —
  /// a mesma regra do servidor ao criar um plano, para os dois não divergirem.
  List<double> get _recalculo {
    final n = _parcelas.length;
    final base = round2Money(widget.saldo / n);
    return [
      for (var i = 0; i < n; i++)
        i == n - 1 ? round2Money(widget.saldo - base * (n - 1)) : base,
    ];
  }

  double get _somaManual => round2Money(
        _ctrls.fold<double>(
          0,
          (a, c) => a + (double.tryParse(c.text.replaceAll(',', '.')) ?? 0),
        ),
      );

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  /// Aplica valor por valor: mantém as datas combinadas, ao contrário de
  /// refazer o plano.
  Future<void> _aplicar(List<double> valores, String motivo) async {
    setState(() => _saving = true);
    final repo = ref.read(cashierRepositoryProvider);
    try {
      for (var i = 0; i < _parcelas.length; i++) {
        final novo = valores[i];
        // Só chama para o que realmente mudou — parcela intocada não precisa
        // aparecer no log de auditoria como "alterada".
        if ((novo - _parcelas[i].valor).abs() <= paymentEps) continue;
        if (novo <= 0) {
          throw Exception('Parcela ${i + 1}: o valor precisa ser maior que zero.');
        }
        await repo.updateInstallmentAmount(
          installmentId: _parcelas[i].id,
          amount: novo,
          reason: motivo,
        );
      }
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
    final subiu = widget.totalDepois > widget.totalAntes;
    return NeuDialog(
      title: 'As parcelas acompanham a mudança?',
      maxWidth: 520,
      actions: _manual
          ? [
              NeuButton(
                label: 'Voltar',
                kind: NeuButtonKind.secondary,
                onPressed: _saving ? null : () => setState(() => _manual = false),
              ),
              NeuButton(
                label: 'Salvar parcelas',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving
                    ? null
                    : () => _aplicar(
                          [
                            for (final c in _ctrls)
                              double.tryParse(
                                    c.text.replaceAll(',', '.'),
                                  ) ??
                                  0,
                          ],
                          'ajuste manual após mudança no valor do título',
                        ),
              ),
            ]
          : [
              Builder(
                builder: (ctx) => NeuButton(
                  label: 'Deixar como está',
                  kind: NeuButtonKind.secondary,
                  onPressed: _saving ? null : () => Navigator.pop(ctx, false),
                ),
              ),
              NeuButton(
                label: 'Editar à mão',
                icon: Icons.edit_outlined,
                kind: NeuButtonKind.secondary,
                onPressed: _saving ? null : () => setState(() => _manual = true),
              ),
              NeuButton(
                label: 'Recalcular',
                icon: Icons.calculate_outlined,
                loading: _saving,
                onPressed: _saving
                    ? null
                    : () => _aplicar(
                          _recalculo,
                          'recálculo após mudança no valor do título',
                        ),
              ),
            ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.rotuloTitulo} ${subiu ? 'subiu' : 'caiu'} de '
            '${formatMoney(widget.totalAntes)} para '
            '${formatMoney(widget.totalDepois)}, mas as '
            '${_parcelas.length} parcelas em aberto continuam somando '
            '${formatMoney(_somaAtual)} — e o cliente deve '
            '${formatMoney(widget.saldo)}.',
            style: TextStyle(color: neu.inkMuted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 16),
          if (_manual)
            _CamposManuais(
              parcelas: _parcelas,
              ctrls: _ctrls,
              soma: _somaManual,
              saldo: widget.saldo,
              onChanged: () => setState(() {}),
            )
          else
            _PreviaRecalculo(
              parcelas: _parcelas,
              valores: _recalculo,
            ),
          const SizedBox(height: 12),
          Text(
            _manual
                ? 'As datas combinadas não mudam — só os valores.'
                : 'Recalcular divide o que o cliente deve igualmente entre as '
                    'parcelas em aberto, mantendo as datas combinadas. As '
                    'parcelas já pagas não entram.',
            style: TextStyle(color: neu.inkFaint, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// O que o recálculo faria, parcela por parcela — de → para. Aplicar às cegas
/// um número que ninguém viu é o que faz o operador desconfiar do botão.
class _PreviaRecalculo extends StatefulWidget {
  const _PreviaRecalculo({required this.parcelas, required this.valores});

  final List<Installment> parcelas;
  final List<double> valores;

  @override
  State<_PreviaRecalculo> createState() => _PreviaRecalculoState();
}

class _PreviaRecalculoState extends State<_PreviaRecalculo> {
  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final parcelas = widget.parcelas;
    final valores = widget.valores;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: NeuTokens.rField,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // Sem rolagem própria, pelo mesmo motivo dos campos: quem rola é o
      // diálogo. Uma prévia cortada por uma borda invisível é pior que uma
      // prévia longa — o ponto dela é justamente ver TODAS as linhas antes de
      // aplicar.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < parcelas.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(
                    '${i + 1}ª · ${_dataBr(parcelas[i].dueDate)}',
                    style: TextStyle(color: neu.inkMuted, fontSize: 12.5),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(parcelas[i].valor),
                    style: TextStyle(
                      color: neu.inkFaint,
                      fontSize: 12.5,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: neu.inkFaint,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatMoney(valores[i]),
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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

/// Um campo por parcela em aberto, com a soma conferida na hora contra a dívida.
class _CamposManuais extends StatefulWidget {
  const _CamposManuais({
    required this.parcelas,
    required this.ctrls,
    required this.soma,
    required this.saldo,
    required this.onChanged,
  });

  final List<Installment> parcelas;
  final List<TextEditingController> ctrls;
  final double soma;
  final double saldo;
  final VoidCallback onChanged;

  @override
  State<_CamposManuais> createState() => _CamposManuaisState();
}

class _CamposManuaisState extends State<_CamposManuais> {
  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final parcelas = widget.parcelas;
    final ctrls = widget.ctrls;
    final soma = widget.soma;
    final saldo = widget.saldo;
    final onChanged = widget.onChanged;
    final diferenca = round2Money(soma - saldo);
    final fecha = diferenca.abs() <= paymentEps;
    // TODOS os campos, sem caixa de rolagem própria.
    //
    // Antes esta lista vivia num box de 280px — altura de exatamente três
    // campos — e rolava por dentro. Ela ROLAVA, mas parecia completa: a barra
    // do desktop só aparece depois que você já está rolando, então a 4ª parcela
    // em diante simplesmente não existia para quem olhava. Scroll dentro de
    // scroll num modal é assim: some conteúdo sem avisar.
    //
    // Quem rola agora é o próprio diálogo (o `NeuDialog` já tem altura limitada
    // pela tela e rola o conteúdo inteiro): uma superfície, uma rolagem, nada
    // escondido atrás de uma borda invisível.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parcelas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: NeuTextField(
              label: '${i + 1}ª parcela · vence em '
                  '${_dataBr(parcelas[i].dueDate)}',
              controller: ctrls[i],
              hint: '0,00',
              prefixText: 'R\$ ',
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [DecimalInputFormatter()],
              onChanged: (_) => onChanged(),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              fecha
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              size: 16,
              color: fecha ? neu.success : neu.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fecha
                    ? 'Somam ${formatMoney(soma)} — fecha com a dívida.'
                    : 'Somam ${formatMoney(soma)} · '
                        '${formatMoney(diferenca.abs())} '
                        '${diferenca > 0 ? 'mais' : 'menos'} que a dívida de '
                        '${formatMoney(saldo)}.',
                style: TextStyle(
                  color: fecha ? neu.inkMuted : neu.warning,
                  fontSize: 13,
                  fontWeight: fecha ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _dataBr(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
