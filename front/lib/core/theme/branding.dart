import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../features/auth/presentation/session_state.dart';
import 'app_colors.dart';

/// Resolves the seed color for the app's [ColorScheme] from the workshop's
/// configured `company.primaryColor`. Falls back to [AppColors.brand] when
/// unauthenticated, on any error, or when the color is missing/invalid.
final brandingSeedProvider = FutureProvider<Color>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  if (session is! SessionAuthenticated) return AppColors.brand;
  try {
    final res = await ref.read(dioProvider).get<Object?>('/settings');
    final data = (res.data as Map)['company'];
    final hex = (data is Map ? data['primaryColor'] : null) as String?;
    if (hex != null && RegExp(r'^#([0-9a-fA-F]{6})$').hasMatch(hex)) {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
  } catch (_) {
    /* fall through */
  }
  return AppColors.brand;
});
