import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Cadeado desenhado em vetor: nítido em qualquer densidade (do celular ao
/// monitor 4K) e sem asset para carregar.
///
/// [t] é o estado: `0` = totalmente fechado, `1` = totalmente aberto. A haste
/// gira em torno do pino DIREITO (como um cadeado de verdade) e sobe um pouco
/// ao abrir; o corpo fica parado.
class LockPainter extends CustomPainter {
  const LockPainter({
    required this.t,
    required this.bodyColor,
    required this.shackleColor,
    required this.keyholeColor,
  });

  /// 0 = fechado · 1 = aberto.
  final double t;
  final Color bodyColor;
  final Color shackleColor;
  final Color keyholeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;

    // ---- métricas (proporcionais ao tamanho) ----
    // O cadeado é desenhado na parte de BAIXO do quadro: a faixa superior fica
    // reservada para a haste subir ao abrir sem encostar na borda.
    final bodyW = s * 0.58;
    final bodyH = s * 0.40;
    final bodyBottom = s * 0.96;
    final bodyTop = bodyBottom - bodyH;
    final bodyRect = Rect.fromLTRB(
      cx - bodyW / 2,
      bodyTop,
      cx + bodyW / 2,
      bodyBottom,
    );

    final shackleR = bodyW * 0.33; // raio do arco da haste
    final shackleW = s * 0.082; // espessura da haste
    final shackleCy = bodyTop - shackleR * 0.50; // centro do arco (fechado)
    final legBottom = bodyTop + bodyH * 0.16; // pernas entram no corpo

    // ---- haste (desenhada ANTES do corpo, para "entrar" atrás dele) ----
    // O pivô é o PÉ da perna direita, que fica dentro do corpo — é ali que a
    // haste está presa. Girando no sentido horário, a perna esquerda sobe e
    // sai do corpo; a direita continua ancorada. (Pivotar no topo faria a haste
    // varrer para fora, como se tivesse se soltado do cadeado.)
    final pivot = Offset(cx + shackleR, legBottom);
    // Sobe bem (a perna esquerda sai do furo por CIMA, como num cadeado real)
    // e inclina só o suficiente para o olho ler "destravou".
    final angle = math.pi / 180 * 15 * t;
    final lift = -s * 0.05 * t;

    final shacklePath = Path()
      ..moveTo(cx - shackleR, legBottom)
      ..lineTo(cx - shackleR, shackleCy)
      ..arcToPoint(
        Offset(cx + shackleR, shackleCy),
        radius: Radius.circular(shackleR),
        clockwise: true,
      )
      ..lineTo(cx + shackleR, legBottom);

    canvas.save();
    canvas.translate(0, lift);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(
      shacklePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shackleW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = shackleColor,
    );
    canvas.restore();

    // ---- corpo ----
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(bodyH * 0.28),
    );
    // Sombra sutil por baixo — dá volume sem destoar do neumorfismo.
    canvas.drawRRect(
      bodyRRect.shift(Offset(0, s * 0.012)),
      Paint()
        ..color = bodyColor.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
    );
    canvas.drawRRect(bodyRRect, Paint()..color = bodyColor);

    // ---- fechadura: círculo + fenda, centralizados no corpo ----
    final kR = bodyH * 0.16;
    final kCenter = Offset(cx, bodyTop + bodyH * 0.44);
    final keyPaint = Paint()..color = keyholeColor;
    canvas.drawCircle(kCenter, kR, keyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          kCenter.dx - kR * 0.42,
          kCenter.dy,
          kCenter.dx + kR * 0.42,
          kCenter.dy + bodyH * 0.26,
        ),
        Radius.circular(kR * 0.42),
      ),
      keyPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LockPainter old) =>
      old.t != t ||
      old.bodyColor != bodyColor ||
      old.shackleColor != shackleColor ||
      old.keyholeColor != keyholeColor;
}

/// Cadeado animado. Anima de fechado→aberto quando [open] vira `true` e o
/// contrário quando vira `false`; nasce já no estado final (sem animar) para
/// não "piscar" ao entrar na tela.
class AnimatedLock extends StatefulWidget {
  const AnimatedLock({
    super.key,
    required this.open,
    this.size = 96,
    this.duration = const Duration(milliseconds: 900),
    this.color,
  });

  final bool open;
  final double size;
  final Duration duration;

  /// Cor base (haste + corpo). Default: verde quando aberto, grafite quando
  /// fechado — a mesma leitura de status usada no resto do app.
  final Color? color;

  @override
  State<AnimatedLock> createState() => _AnimatedLockState();
}

class _AnimatedLockState extends State<AnimatedLock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.open ? 1 : 0,
  );

  /// Abrir tem um leve "salto" no fim (a haste solta); fechar termina firme,
  /// como um encaixe.
  Animation<double> get _t => CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInOutCubic.flipped,
  );

  @override
  void didUpdateWidget(covariant AnimatedLock old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      widget.open ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        // Interpola a cor junto com o movimento: fechado (grafite) → aberto
        // (verde), então o status é legível mesmo sem ler o texto.
        final base =
            widget.color ??
            Color.lerp(neu.navy, neu.success, _t.value.clamp(0, 1))!;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: LockPainter(
            t: _t.value.clamp(0, 1),
            bodyColor: base,
            shackleColor: base.withValues(alpha: 0.92),
            keyholeColor: neu.surface,
          ),
        );
      },
    );
  }
}

/// Transição de estado do caixa: um cadeado grande que abre (ou fecha) e some
/// sozinho. Serve de confirmação visual da ação — o usuário vê o que aconteceu
/// em vez de só ler um aviso que passa rápido.
///
/// [opening] `true` = caixa foi aberto (cadeado destrava) · `false` = caixa foi
/// fechado (cadeado tranca). Funciona igual no desktop e no mobile: é um
/// diálogo centrado, sem toque necessário — fecha ao terminar a animação.
Future<void> showCashierLockTransition(
  BuildContext context, {
  required bool opening,

  /// Texto sob o título. No fechamento vem o resultado da conferência
  /// (sobra/falta), que é a informação que o operador precisa ver.
  String? message,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) =>
        _LockTransitionCard(opening: opening, message: message),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class _LockTransitionCard extends StatefulWidget {
  const _LockTransitionCard({required this.opening, this.message});

  final bool opening;
  final String? message;

  @override
  State<_LockTransitionCard> createState() => _LockTransitionCardState();
}

class _LockTransitionCardState extends State<_LockTransitionCard> {
  /// Começa no estado ANTERIOR e vira no primeiro frame — é o que faz o
  /// cadeado animar em vez de já aparecer no estado final.
  late bool _open = !widget.opening;
  Timer? _flip;
  Timer? _close;

  @override
  void initState() {
    super.initState();
    // Um respiro antes de animar: o usuário vê o estado de origem primeiro.
    _flip = Timer(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _open = widget.opening);
    });
    _close = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _flip?.cancel();
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final label = widget.opening ? 'Caixa aberto' : 'Caixa fechado';
    final hint =
        widget.message ??
        (widget.opening
            ? 'Já dá para registrar entradas e saídas.'
            : 'Movimentos do dia encerrados.');
    final accent = widget.opening ? neu.success : neu.navy;

    // Material é obrigatório aqui: showGeneralDialog entrega o conteúdo direto
    // ao Overlay, e Text sem Material ancestral sai com o sublinhado amarelo
    // duplo de debug do Flutter. (Os outros diálogos não sofrem disso porque
    // passam por Dialog, que já é Material.) Transparente para não interferir
    // no neumorfismo.
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: NeuSurface(
            elevation: NeuElevation.raisedHigh,
            radius: NeuTokens.rPanel,
            color: neu.surface,
            glow: false,
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedLock(open: _open, size: 116),
                const SizedBox(height: 18),
                // O rótulo entra depois do cadeado começar a se mexer.
                AnimatedOpacity(
                  opacity: _open == widget.opening ? 1 : 0,
                  duration: const Duration(milliseconds: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: neu.inkMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
