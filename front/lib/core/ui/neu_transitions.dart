import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Transição de rota padrão do app: fade-through suave (200ms), consistente
/// em todas as plataformas. Usar como `pageBuilder` nas rotas do go_router:
///
/// ```dart
/// GoRoute(path: '/x', pageBuilder: (c, s) => neuPage(s, const XScreen()))
/// ```
CustomTransitionPage<T> neuPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0, .015),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
