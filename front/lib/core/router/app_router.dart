import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../di.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/messages/presentation/messages_inbox_screen.dart';
import '../../features/messages/presentation/message_thread_screen.dart';
import '../../features/os/presentation/os_list_screen.dart';
import '../../features/os/presentation/os_detail_screen.dart';
import '../../features/auth/presentation/accept_invite_screen.dart';
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
import 'navigator_key.dart';

/// Routes that never require authentication.
const _authRoutes = {'/login', '/register', '/verify', '/forgot', '/reset'};

bool _isPublic(String location) =>
    _authRoutes.contains(location) ||
    location.startsWith('/t/') ||
    location.startsWith('/convite/');

/// go_router wired to the session. `refreshListenable` re-runs `redirect` on
/// every session change. Guards run server-truth-first: the client only reflects
/// role/module gating for UX; a backend 403 is still handled gracefully in-screen.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
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

      // Module gating: any /m/<key>/... route requires that module enabled in
      // /me. Parse the key from the path (not pathParameters) so deep routes
      // like /m/customers/:id stay gated too.
      if (location.startsWith('/m/')) {
        final segments = location.split('/');
        final moduleKey = segments.length > 2 ? segments[2] : null;
        final me = session.me;
        if (moduleKey != null &&
            moduleKey.isNotEmpty &&
            !me.hasModule(moduleKey)) {
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
      GoRoute(
        path: '/convite/:token',
        builder: (_, state) =>
            AcceptInviteScreen(token: state.pathParameters['token'] ?? ''),
      ),
      // Authenticated shell.
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/billing', builder: (_, _) => const PlansScreen()),
          GoRoute(path: '/equipe', builder: (_, _) => const TeamScreen()),
          // Mensagens — genérico (não é módulo de tenant), fora de /m/. Gated
          // só por autenticação (já está dentro da shell autenticada).
          GoRoute(
            path: '/mensagens',
            builder: (_, _) => const MessagesInboxScreen(),
          ),
          GoRoute(
            path: '/mensagens/:id',
            builder: (_, state) => MessageThreadScreen(
              conversationId: state.pathParameters['id'] ?? '',
            ),
          ),
          // Customers module — literal routes declared before the generic
          // /m/:moduleKey placeholder so they take precedence.
          GoRoute(
            path: '/m/customers',
            builder: (_, _) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/m/customers/:id',
            builder: (_, state) => CustomerDetailScreen(
              customerId: state.pathParameters['id'] ?? '',
            ),
          ),
          // Inventory module — literal route before the generic placeholder.
          GoRoute(
            path: '/m/inventory',
            builder: (_, _) => const InventoryScreen(),
          ),
          // OS module — literal routes before the generic placeholder so they
          // take precedence; both stay gated under /m/os.
          GoRoute(
            path: '/m/os',
            builder: (_, _) => const OsListScreen(),
          ),
          GoRoute(
            path: '/m/os/:id',
            builder: (_, state) => OsDetailScreen(
              orderId: state.pathParameters['id'] ?? '',
            ),
          ),
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
