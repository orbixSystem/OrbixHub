import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../features/auth/presentation/session_state.dart';
import '../ui/neu_tokens.dart';
import 'theme_presets.dart';

/// Resolves the seed color for the neumorphic palette from the workshop's
/// configured `company.themePreset` (preferred) or `company.primaryColor`.
/// Falls back to the default Lavanda seed when unauthenticated, on any error,
/// or when the color is missing/invalid.
final brandingSeedProvider = FutureProvider<Color>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  // Só com sessão ONLINE: no modo offline (B6) esta busca em `/settings` seria
  // uma chamada de rede fadada ao erro — cai no seed padrão sem tocar no dio.
  if (session is! SessionAuthenticated) return NeuTokens.lavanderSeed;
  try {
    final res = await ref.read(dioProvider).get<Object?>('/settings');
    final data = (res.data as Map)['company'];
    final preset = (data is Map ? data['themePreset'] : null) as String?;
    if (preset != null) return seedForPreset(preset);
    final hex = (data is Map ? data['primaryColor'] : null) as String?;
    if (hex != null && RegExp(r'^#([0-9a-fA-F]{6})$').hasMatch(hex)) {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
  } catch (_) {
    /* fall through */
  }
  return NeuTokens.lavanderSeed;
});
