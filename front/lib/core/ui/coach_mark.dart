import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_targets.dart';
import 'neu_button.dart';
import 'neu_surface.dart';
import 'neu_tokens.dart';

/// Um passo do tutorial: destaca o widget de [targetKey] e mostra [title]/[text].
class CoachStep {
  const CoachStep({
    required this.title,
    required this.text,
    this.targetKey,
    this.targetName,
    this.radius = 16,
    this.padding = 8,
  });

  /// Nome do alvo registrado com `CoachTarget` (ver `coach_targets.dart`).
  ///
  /// Preferido sobre [targetKey] no conteúdo central: o texto do tutorial não
  /// pode importar a tela para pegar uma `GlobalKey`. Alvo ausente (elemento que
  /// não existe naquele tamanho de tela) degrada para cartão centralizado — o
  /// passo continua aparecendo.
  final String? targetName;

  /// GlobalKey do widget a destacar. **Opcional**: sem ela o passo é um cartão
  /// centralizado, sem holofote.
  ///
  /// Isso existe porque tutorial tem de funcionar em desktop E mobile, e muitos
  /// elementos só existem num dos dois (sidebar fixa × drawer, colunas de tabela
  /// que somem no celular). Amarrar todo passo a um alvo faria o tutorial sumir
  /// pela metade no celular — pior que não ter holofote.
  final GlobalKey? targetKey;
  final String title;
  final String text;

  /// Raio do recorte de destaque.
  final double radius;

  /// Folga ao redor do alvo (aumenta o buraco).
  final double padding;
}

/// Tutorial por spotlight: escurece a tela e recorta um buraco no elemento-alvo,
/// com um cartão explicativo (Anterior/Próximo/Pular). Funciona em desktop e
/// mobile. Persiste "já visto" por [id] em SharedPreferences.
///
/// Uso típico (na tela, após o 1º frame):
/// ```dart
/// WidgetsBinding.instance.addPostFrameCallback((_) {
///   CoachMark.maybeStart(context, id: 'dashboard', steps: [...]);
/// });
/// ```
abstract final class CoachMark {
  /// `true` enquanto um tutorial está na tela.
  ///
  /// O chrome global (sino, tema) vive no TOPO do overlay do root navigator e só
  /// se esconde durante modais (`modalRouteObserver`). O tutorial é um
  /// `OverlayEntry`, não uma rota — então aqueles botões continuavam pintando
  /// SOBRE o cartão. Este sinal é o equivalente do modal para eles.
  static final ativo = ValueNotifier<bool>(false);

  static String _key(String id) => 'coach_seen_$id';

  /// Mostra o tutorial [id] só se ainda não foi visto (e houver alvo montado).
  static Future<void> maybeStart(
    BuildContext context, {
    required String id,
    required List<CoachStep> steps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key(id)) == true) return;
    if (!context.mounted) return;
    await start(context, id: id, steps: steps);
  }

  /// Mostra o tutorial [id] agora (ignora "já visto") — para um botão "rever".
  static Future<void> start(
    BuildContext context, {
    required String id,
    required List<CoachStep> steps,
  }) async {
    // Todo passo entra: alvo por NOME é resolvido a cada frame (a tela pode nem
    // ter montado ainda) e, se não existir, o passo vira cartão centralizado em
    // vez de desaparecer. Só descartamos passo com `targetKey` explícita e morta,
    // porque aí o autor pediu um holofote que não existe.
    final live = steps.where((s) {
      final key = s.targetKey;
      if (key == null) return true;
      final box = key.currentContext?.findRenderObject();
      return box is RenderBox && box.hasSize;
    }).toList();
    if (live.isEmpty) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    ativo.value = true;
    entry = OverlayEntry(
      builder: (_) => _CoachView(
        steps: live,
        onDone: () async {
          entry.remove();
          ativo.value = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_key(id), true);
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _CoachView extends StatefulWidget {
  const _CoachView({required this.steps, required this.onDone});

  final List<CoachStep> steps;
  final Future<void> Function() onDone;

  @override
  State<_CoachView> createState() => _CoachViewState();
}

class _CoachViewState extends State<_CoachView> {
  int _i = 0;

  CoachStep get _step => widget.steps[_i];

  /// Retângulo global do alvo do passo atual (ou null se sumiu).
  Rect? _targetRect() {
    final nome = _step.targetName;
    final key = _step.targetKey ?? (nome == null ? null : CoachTargets.live(nome));
    if (key == null) return null; // sem alvo vivo: cartão centralizado
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  void _next() {
    if (_i < widget.steps.length - 1) {
      setState(() => _i++);
    } else {
      widget.onDone();
    }
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
  }

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final target = _targetRect();
    final hole = target == null
        ? null
        : Rect.fromLTRB(
            target.left - _step.padding,
            target.top - _step.padding,
            target.right + _step.padding,
            target.bottom + _step.padding,
          );

    // Posição do cartão: abaixo do alvo se couber, senão acima; centralizado.
    const cardW = 320.0;
    const estCardH = 168.0;
    final belowSpace =
        hole == null ? 0.0 : size.height - hole.bottom - safe.bottom - 24;
    final placeBelow = hole == null || belowSpace >= estCardH;
    final cardLeft = hole == null
        ? (size.width - cardW) / 2
        : (hole.center.dx - cardW / 2).clamp(16.0, size.width - cardW - 16);
    final cardTop = hole == null
        ? (size.height - estCardH) / 2
        : (placeBelow ? hole.bottom + 16 : hole.top - estCardH - 16)
            .clamp(safe.top + 16, size.height - estCardH - 16);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Scrim com recorte (buraco) no alvo. Toca fora não fecha (evita
          // fechar sem querer); usa os botões.
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(
                hole: hole,
                radius: _step.radius,
                color: Colors.black.withValues(alpha: 0.62),
              ),
            ),
          ),
          // Anel de destaque na borda do buraco.
          if (hole != null)
            Positioned.fromRect(
              rect: hole,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_step.radius),
                    border: Border.all(color: neu.accent, width: 2),
                  ),
                ),
              ),
            ),
          // Cartão explicativo.
          Positioned(
            left: cardLeft,
            top: cardTop.toDouble(),
            width: cardW,
            child: NeuSurface(
              elevation: NeuElevation.raisedHigh,
              radius: NeuTokens.rCard,
              color: neu.surface,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_i + 1} de ${widget.steps.length}',
                    style: TextStyle(
                      color: neu.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _step.title,
                    style: TextStyle(
                      color: neu.ink,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _step.text,
                    style:
                        TextStyle(color: neu.inkMuted, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: widget.onDone,
                        child: const Text('Pular'),
                      ),
                      const Spacer(),
                      if (_i > 0) ...[
                        NeuButton(
                          label: 'Anterior',
                          kind: NeuButtonKind.secondary,
                          onPressed: _prev,
                        ),
                        const SizedBox(width: 8),
                      ],
                      NeuButton(
                        label: _i == widget.steps.length - 1
                            ? 'Concluir'
                            : 'Próximo',
                        onPressed: _next,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta o scrim escuro com um buraco arredondado no [hole].
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.color,
  });

  final Rect? hole;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final paint = Paint()..color = color;
    if (hole == null) {
      canvas.drawRect(full, paint);
      return;
    }
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole!, Radius.circular(radius)));
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      holePath,
    );
    canvas.drawPath(scrim, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.color != color || old.radius != radius;
}
