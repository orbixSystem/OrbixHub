import 'package:flutter/material.dart';

import '../util/masks.dart';
import 'neu_tokens.dart';

/// Campo numérico com **−** e **+** clicáveis DENTRO do campo.
///
/// Existe pelo dedo: no balcão, e sobretudo no celular, ajustar "2 → 3" tocando
/// um botão é mais rápido e erra menos que apagar e redigitar. O campo segue
/// editável — quem quer `0,5` hora de mão de obra digita.
///
/// Os botões ficam **dentro** da moldura (`prefixIcon`/`suffixIcon`), não ao
/// lado: por fora eles roubavam ~80px da linha e o número aparecia cortado
/// ("4.000" virava "4."). Por dentro, a largura toda pertence ao campo.
///
/// O valor é travado em zero — não existe quantidade nem preço negativo, então o
/// **−** para em 0 em vez de deixar o usuário criar um valor que a validação vai
/// recusar depois.
class NeuStepperField extends StatefulWidget {
  const NeuStepperField({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.decimals = 0,
    this.min = 0,
    this.max,
    this.trimTrailingZeros = false,
    this.textAlign = TextAlign.center,
    this.validator,
    this.semanticLabel,
  });

  /// Valor atual (a fonte da verdade é o pai — o campo é controlado).
  final double value;

  /// Chamado a cada toque nos botões e a cada digitação.
  final ValueChanged<double> onChanged;

  /// Quanto cada toque soma/subtrai.
  final double step;

  /// Casas decimais aceitas na DIGITAÇÃO (0 = inteiro; 2 = dinheiro).
  final int decimals;

  /// Piso — zero por padrão (nem quantidade nem preço são negativos).
  final double min;

  /// Teto opcional (sem teto por padrão).
  final double? max;

  /// Mostra `4` em vez de `4,000` quando o valor é inteiro. Para QUANTIDADE:
  /// ninguém escreve "4,000 palhetas". Dinheiro fica sempre com as 2 casas.
  final bool trimTrailingZeros;

  final TextAlign textAlign;
  final String? Function(String?)? validator;

  /// Rótulo para leitor de tela ("Quantidade", "Preço") — sem isto os botões
  /// seriam anunciados como "mais"/"menos" sem contexto.
  final String? semanticLabel;

  @override
  State<NeuStepperField> createState() => _NeuStepperFieldState();
}

class _NeuStepperFieldState extends State<NeuStepperField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: _fmt(widget.value));

  @override
  void didUpdateWidget(NeuStepperField old) {
    super.didUpdateWidget(old);
    // Reflete mudanças vindas de fora (botão do pai, "valor exato", reset) sem
    // atropelar quem está digitando: só reescreve se o número mudou de fato.
    if (widget.value != old.value && _parse(_ctrl.text) != widget.value) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Formata no padrão pt-BR (vírgula), como o resto dos campos de valor do app.
  String _fmt(double v) {
    if (widget.trimTrailingZeros && v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(widget.decimals).replaceAll('.', ',');
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  /// Aplica um passo, respeitando piso e teto.
  void _bump(double delta) {
    final atual = _parse(_ctrl.text) ?? widget.value;
    var novo = atual + delta;
    if (novo < widget.min) novo = widget.min;
    final teto = widget.max;
    if (teto != null && novo > teto) novo = teto;
    // Arredonda ao passo para o toque não propagar sujeira de ponto flutuante
    // (0.1 + 0.2 = 0.30000000000000004).
    novo = double.parse(
        novo.toStringAsFixed(widget.decimals == 0 ? 3 : widget.decimals));
    _ctrl.text = _fmt(novo);
    widget.onChanged(novo);
  }

  @override
  Widget build(BuildContext context) {
    final atual = _parse(_ctrl.text) ?? widget.value;
    final teto = widget.max;
    return Semantics(
      label: widget.semanticLabel,
      child: TextFormField(
        controller: _ctrl,
        textAlign: widget.textAlign,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [DecimalInputFormatter(widget.decimals)],
        validator: widget.validator,
        onChanged: (v) => widget.onChanged(_parse(v) ?? 0),
        decoration: InputDecoration(
          isDense: true,
          // Sem padding lateral: os botões já ocupam as pontas.
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: _StepButton(
            icon: Icons.remove_rounded,
            tooltip: 'Diminuir',
            onTap: atual > widget.min ? () => _bump(-widget.step) : null,
          ),
          suffixIcon: _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'Aumentar',
            onTap: (teto == null || atual < teto)
                ? () => _bump(widget.step)
                : null,
          ),
          // Sem estes limites o Material reserva 48px de largura MÍNIMA para
          // cada ícone, que era parte do aperto que cortava o número.
          prefixIconConstraints: const BoxConstraints(
            minWidth: _StepButton.lado,
            minHeight: _StepButton.lado,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: _StepButton.lado,
            minHeight: _StepButton.lado,
          ),
        ),
      ),
    );
  }
}

/// Um dos dois botões do stepper. `onTap: null` desabilita (no piso/teto).
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, this.onTap});

  /// Lado do botão. Compacto porque vive DENTRO do campo — a área de toque
  /// efetiva é maior, já que a altura do campo o envolve.
  static const lado = 34.0;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ativo = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(NeuTokens.rChip),
        onTap: onTap,
        child: SizedBox(
          width: lado,
          height: lado,
          child: Center(
            child: Icon(
              icon,
              size: 17,
              color: ativo ? neu.ink : neu.inkMuted.withValues(alpha: .35),
            ),
          ),
        ),
      ),
    );
  }
}
