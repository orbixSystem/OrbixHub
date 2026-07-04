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

