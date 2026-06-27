import 'package:flutter/material.dart';

/// Lightweight entrance animation: a child fades in while sliding up a few
/// pixels, once, on first build. Cheap (a single short controller) and safe to
/// scatter across screens.
///
/// Use [index] to stagger a list/grid — each item starts a little later than
/// the previous one, capped so long lists don't feel sluggish.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 360),
    this.offset = 14,
  });

  final Widget child;

  /// Position in a sequence; multiplies the start delay (capped at 10 steps).
  final int index;
  final Duration duration;

  /// Vertical travel in logical pixels.
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset),
      end: Offset.zero,
    ).animate(curve);

    // Stagger: ~55ms per step, capped at 10 steps (~550ms) so long lists
    // don't drag. Steps beyond the cap all start together.
    final step = widget.index.clamp(0, 10);
    final delay = Duration(milliseconds: 55 * step);
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(offset: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}
