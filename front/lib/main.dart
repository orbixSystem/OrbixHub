import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/devtools/dev_inbox_overlay.dart';
import 'core/router/app_router.dart';
import 'core/router/navigator_key.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/branding.dart';
import 'di.dart';

Future<void> main() async {
  await initializeDateFormatting('pt_BR', null);
  runApp(ProviderScope(overrides: diOverrides, child: const OrbixApp()));
}

class OrbixApp extends ConsumerStatefulWidget {
  const OrbixApp({super.key});

  @override
  ConsumerState<OrbixApp> createState() => _OrbixAppState();
}

class _OrbixAppState extends ConsumerState<OrbixApp> {
  OverlayEntry? _controls;
  OverlayEntry? _beetle;

  @override
  void initState() {
    super.initState();
    // Insert the global controls into the root navigator's overlay once it
    // exists. Doing this here (instead of wrapping the Navigator in a Stack via
    // MaterialApp.builder) keeps web focus traversal happy.
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertControls());
  }

  void _insertControls() {
    if (_controls != null) return;
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _insertControls());
      return;
    }
    _controls = OverlayEntry(builder: (_) => const GlobalControls());
    _beetle = OverlayEntry(builder: (_) => const DevBeetleControl());
    overlay.insertAll([_controls!, _beetle!]);
  }

  @override
  void dispose() {
    _controls?.remove();
    _beetle?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      routerConfig: router,
    );
  }
}
