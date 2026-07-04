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
import '../../features/os/presentation/templates_screen.dart';
import '../../features/report/presentation/report_screen.dart';
import '../../features/auth/presentation/accept_invite_screen.dart';
import '../../features/auth/presentation/forgot_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_screen.dart';
import '../../features/auth/presentation/session_state.dart';
import '../../features/auth/presentation/tenant_picker_screen.dart';
import '../../features/auth/presentation/verify_screen.dart';
import '../../features/billing/presentation/plans_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shell/presentation/dashboard_screen.dart';
import '../../features/shell/presentation/module_placeholder_screen.dart';
import '../../features/team/presentation/team_screen.dart';
import '../../features/tracking/presentation/public_tracking_screen.dart';
import '../devtools/dev_flag.dart';
import '../devtools/ui_showcase_screen.dart';
import '../ui/neu_transitions.dart';
import '../widgets/splash_screen.dart';
import 'navigator_key.dart';

/// Routes that never require authentication.
const _authRoutes = {'/login', '/register', '/verify', '/forgot', '/reset'};

bool _isPublic(String location) =>
    _authRoutes.contains(location) ||
    location.startsWith('/t/') ||
    location.startsWith('/convite/') ||
    // Vitrine do design system — só existe em dev (kDevTools).
    (kDevTools && location == '/dev/ui');

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
        // Relatórios também exige `report.read` (gerencial). Sem ela, manda pra
        // home — o backend já 403a; isto evita a tela quebrada. Esconder ≠
        // proteger, mas escondemos o que não é do papel.
        if (moduleKey == 'report' && !me.hasPermission('report.read')) {
          return '/';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, s) => neuPage(s, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => neuPage(s, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, s) => neuPage(s, const RegisterScreen()),
      ),
      GoRoute(
        path: '/verify',
        pageBuilder: (_, s) => neuPage(s, const VerifyScreen()),
      ),
      GoRoute(
        path: '/forgot',
        pageBuilder: (_, s) => neuPage(s, const ForgotScreen()),
      ),
      GoRoute(
        path: '/reset',
        pageBuilder: (_, s) => neuPage(s, const ResetScreen()),
      ),
      GoRoute(
        path: '/picker',
        pageBuilder: (_, s) => neuPage(s, const TenantPickerScreen()),
      ),
      GoRoute(
        path: '/t/:token',
        pageBuilder: (_, s) => neuPage(
          s,
          PublicTrackingScreen(token: s.pathParameters['token'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/convite/:token',
        pageBuilder: (_, s) => neuPage(
          s,
          AcceptInviteScreen(token: s.pathParameters['token'] ?? ''),
        ),
      ),
      // Vitrine dev do design system neumórfico (fora do shell; some em release).
      if (kDevTools)
        GoRoute(path: '/dev/ui', builder: (_, _) => const UiShowcaseScreen()),
      // Authenticated shell.
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/billing', builder: (_, _) => const PlansScreen()),
          GoRoute(path: '/equipe', builder: (_, _) => const TeamScreen()),
          GoRoute(
            path: '/configuracoes',
            builder: (_, _) => const SettingsScreen(),
          ),
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
          // Templates de OS — antes de /m/os/:id para não ser capturado como id.
          GoRoute(
            path: '/m/os/templates',
            builder: (_, _) => const TemplatesScreen(),
          ),
          GoRoute(
            path: '/m/os/:id',
            builder: (_, state) => OsDetailScreen(
              orderId: state.pathParameters['id'] ?? '',
            ),
          ),
          // Relatórios — literal antes do placeholder genérico; gated sob /m/
          // (módulo `report`); o backend exige report.read nos endpoints.
          GoRoute(
            path: '/m/report',
            builder: (_, _) => const ReportScreen(),
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
