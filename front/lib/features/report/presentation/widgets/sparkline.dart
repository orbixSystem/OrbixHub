import 'package:flutter/material.dart';

/// A linha do mês, desenhada do tamanho de uma assinatura.
///
/// Não substitui o gráfico grande: fica colada ao número de abertura para
/// responder, no mesmo olhar, a pergunta que um total não responde — o mês foi
/// parelho ou foi três dias bons? Dois meses com o mesmo faturamento são
/// negócios diferentes conforme a resposta.
///
/// Desenhada à mão em `CustomPainter` (e não com uma biblioteca de gráficos)
/// porque aqui não há eixo, grade, legenda nem toque: é um traço. Trazer um
/// `LineChart` inteiro para isso custaria layout, hit-test e um visual que não
/// combina com o corpo de texto ao lado.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.valores, required this.cor});

  final List<double> valores;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    if (valores.length < 2) return const SizedBox.shrink();
    final semMovimento = MediaQuery.disableAnimationsOf(context);
    if (semMovimento) {
      return CustomPaint(
        painter: _SparkPainter(valores: valores, cor: cor, progresso: 1),
        size: Size.infinite,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        painter: _SparkPainter(valores: valores, cor: cor, progresso: t),
        size: Size.infinite,
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.valores,
    required this.cor,
    required this.progresso,
  });

  final List<double> valores;
  final Color cor;

  /// Quanto da linha já foi traçado (0–1).
  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    final maior = valores.reduce((a, b) => a > b ? a : b);
    final menor = valores.reduce((a, b) => a < b ? a : b);
    final amplitude = (maior - menor).abs() < 0.0001 ? 1.0 : maior - menor;
    // Margem de 2px em cima e embaixo: sem ela o pico encosta na borda e a
    // linha parece cortada.
    const folga = 2.0;
    final alturaUtil = size.height - folga * 2;
    final passo = size.width / (valores.length - 1);

    Offset ponto(int i) => Offset(
          passo * i,
          folga + alturaUtil - ((valores[i] - menor) / amplitude) * alturaUtil,
        );

    final caminho = Path()..moveTo(ponto(0).dx, ponto(0).dy);
    for (var i = 1; i < valores.length; i++) {
      final p = ponto(i);
      final anterior = ponto(i - 1);
      // Curva suave entre pontos, com os controles no meio do caminho: a
      // série diária de uma oficina é irregular, e um polígono de bicos
      // transmite ruído em vez de tendência.
      final meio = (anterior.dx + p.dx) / 2;
      caminho.cubicTo(meio, anterior.dy, meio, p.dy, p.dx, p.dy);
    }

    // Traçado progressivo: a linha é desenhada, não revelada por uma cortina.
    final metrica = caminho.computeMetrics().first;
    final visivel = metrica.extractPath(0, metrica.length * progresso);

    // Preenchimento MUITO leve sob a linha — sugere volume sem virar área
    // colorida competindo com o número ao lado.
    if (progresso > 0.02) {
      final area = Path.from(visivel)
        ..lineTo(size.width * progresso, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()..color = cor.withValues(alpha: 0.10),
      );
    }

    canvas.drawPath(
      visivel,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Ponto no último dia, quando a linha termina: marca onde o mês parou.
    if (progresso > 0.98) {
      final fim = ponto(valores.length - 1);
      canvas.drawCircle(fim, 3, Paint()..color = cor);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progresso != progresso || old.valores != valores || old.cor != cor;
}
