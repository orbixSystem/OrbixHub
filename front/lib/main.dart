import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/branding.dart';
import 'di.dart';

void main() {
  runApp(const ProviderScope(child: OrbixApp()));
}

class OrbixApp extends ConsumerWidget {
  const OrbixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final seed = ref
        .watch(brandingSeedProvider)
        .maybeWhen(data: (c) => c, orElse: () => AppColors.brand);
    final mode = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'OrbixHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed: seed),
      darkTheme: AppTheme.dark(seed: seed),
      themeMode: mode,
      routerConfig: router,
    );
  }
}
