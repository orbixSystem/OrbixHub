import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transição de rota de nível superior (login ↔ app, tracking público): fade
/// puro (sem slide — slide dentro do shell "bugava" elementos). Usar como
/// `pageBuilder`:
///
/// ```dart
/// GoRoute(path: '/x', pageBuilder: (c, s) => neuPage(s, const XScreen()))
/// ```
CustomTransitionPage<T> neuPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Cross-fade profissional para trocar o CONTEÚDO dentro do shell (o sidebar
/// fica parado — sliding a página inteira brigava com ele). Fade + micro-escala
/// (0.985→1) dá sensação premium sem pulos de layout. Chaveie por `location`.
///
/// ```dart
/// NeuContentSwitcher(routeKey: location, child: routedChild)
/// ```
class NeuContentSwitcher extends StatelessWidget {
  const NeuContentSwitcher({
    super.key,
    required this.routeKey,
    required this.child,
  });

  final String routeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Full-bleed: cada tela preenche o espaço; a anterior some por baixo.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.topLeft,
        children: [
          ...previousChildren,
          ?currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(routeKey), child: child),
    );
  }
}
