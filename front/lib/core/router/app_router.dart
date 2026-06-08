import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../di.dart';
import '../../features/auth/presentation/forgot_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_screen.dart';
import '../../features/auth/presentation/session_state.dart';
import '../../features/auth/presentation/tenant_picker_screen.dart';
import '../../features/auth/presentation/verify_screen.dart';
import '../../features/billing/presentation/plans_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/dashboard_screen.dart';
import '../../features/shell/presentation/module_placeholder_screen.dart';
import '../../features/team/presentation/team_screen.dart';
import '../../features/tracking/presentation/public_tracking_screen.dart';
import '../widgets/splash_screen.dart';

/// Routes that never require authentication.
const _authRoutes = {'/login', '/register', '/verify', '/forgot', '/reset'};

bool _isPublic(String location) =>
    _authRoutes.contains(location) || location.startsWith('/t/');

/// go_router wired to the session. `refreshListenable` re-runs `redirect` on
/// every session change. Guards run server-truth-first: the client only reflects
/// role/module gating for UX; a backend 403 is still handled gracefully in-screen.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;

      // While bootstrapping, park on the splash.
      if (session is SessionLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final authed = session is SessionAuthenticated;

      // Public routes are always reachable (deep-link tracking, auth forms).
      if (_isPublic(location)) {
        // Signed-in users hitting an auth form get bounced home.
        if (authed && _authRoutes.contains(location)) return '/';
        return null;
      }

      if (!authed) return '/login';

      // Authenticated. Leave the splash.
      if (location == '/splash') return '/';

      // Module gating: /m/:moduleKey requires the module to be enabled in /me.
      if (location.startsWith('/m/')) {
        final moduleKey = state.pathParameters['moduleKey'];
        final me = session.me;
        if (moduleKey != null && !me.hasModule(moduleKey)) {
          return '/';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotScreen()),
      GoRoute(path: '/reset', builder: (_, _) => const ResetScreen()),
      GoRoute(path: '/picker', builder: (_, _) => const TenantPickerScreen()),
      GoRoute(
        path: '/t/:token',
        builder: (_, state) =>
            PublicTrackingScreen(token: state.pathParameters['token'] ?? ''),
      ),
      // Authenticated shell.
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/billing', builder: (_, _) => const PlansScreen()),
          GoRoute(path: '/equipe', builder: (_, _) => const TeamScreen()),
          GoRoute(
            path: '/m/:moduleKey',
            builder: (_, state) => ModulePlaceholderScreen(
              moduleKey: state.pathParameters['moduleKey'] ?? '',
            ),
          ),
        ],
      ),
    ],
  );
});
