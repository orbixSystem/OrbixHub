import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'neu_tokens.dart';

/// Transição de rota padrão: **fade-through** do Material (a tela antiga some
/// sobre o fundo ANTES de a nova aparecer — sem sobreposição/"fantasma", que era
/// o problema do cross-fade simples). Usar como `pageBuilder`:
///
/// ```dart
/// GoRoute(path: '/x', pageBuilder: (c, s) => neuPage(s, const XScreen()))
/// ```
CustomTransitionPage<T> neuPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        // Fundo preenchido durante a transição = canvas do tema (não deixa a
        // tela anterior transparecer por baixo da nova).
        fillColor: context.neu.base,
        child: child,
      );
    },
  );
}

