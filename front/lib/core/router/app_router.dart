import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../di.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/invoice/presentation/invoice_screen.dart';
import '../../features/invoice/presentation/invoice_detail_screen.dart';
import '../../features/invoice/presentation/invoice_config_screen.dart';
import '../../features/messages/presentation/messages_inbox_screen.dart';
import '../../features/messages/presentation/message_thread_screen.dart';
import '../../features/os/presentation/os_list_screen.dart';
import '../../features/os/presentation/os_detail_screen.dart';
import '../../features/os/presentation/templates_screen.dart';
import '../../features/report/presentation/report_screen.dart';
import '../../features/sales/presentation/sales_history_screen.dart';
import '../../features/sales/presentation/sale_counter_screen.dart';
import '../../features/sales/presentation/sale_detail_screen.dart';
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
import '../../features/schedule/presentation/agenda_screen.dart';
import '../../features/schedule/presentation/business_hours_screen.dart';
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
          // pageBuilder + neuPage → o Navigator do shell faz o cross-fade da
          // troca de tela (sem duplicar a GlobalKey da página, como acontecia
          // ao envolver o child num AnimatedSwitcher).
          GoRoute(
            path: '/',
            pageBuilder: (_, s) => neuPage(s, const DashboardScreen()),
          ),
          GoRoute(
            path: '/billing',
            pageBuilder: (_, s) => neuPage(s, const PlansScreen()),
          ),
          GoRoute(
            path: '/equipe',
            pageBuilder: (_, s) => neuPage(s, const TeamScreen()),
          ),
          GoRoute(
            path: '/configuracoes',
            pageBuilder: (_, s) => neuPage(s, const SettingsScreen()),
          ),
          // Mensagens — genérico (não é módulo de tenant), fora de /m/. Gated
          // só por autenticação (já está dentro da shell autenticada).
          // Agenda — gated por os.read (verificação na nav_items + backend).
          GoRoute(
            path: '/agenda',
            builder: (_, _) => const AgendaScreen(),
          ),
          GoRoute(
            path: '/agenda/horarios',
            builder: (_, _) => const BusinessHoursScreen(),
          ),
          GoRoute(
            path: '/mensagens',
            pageBuilder: (_, s) => neuPage(s, const MessagesInboxScreen()),
          ),
          GoRoute(
            path: '/mensagens/:id',
            pageBuilder: (_, s) => neuPage(
              s,
              MessageThreadScreen(
                conversationId: s.pathParameters['id'] ?? '',
              ),
            ),
          ),
          // Customers module — literal routes declared before the generic
          // /m/:moduleKey placeholder so they take precedence.
          GoRoute(
            path: '/m/customers',
            pageBuilder: (_, s) => neuPage(s, const CustomersScreen()),
          ),
          GoRoute(
            path: '/m/customers/:id',
            pageBuilder: (_, s) => neuPage(
              s,
              CustomerDetailScreen(customerId: s.pathParameters['id'] ?? ''),
            ),
          ),
          // Inventory module — literal route before the generic placeholder.
          GoRoute(
            path: '/m/inventory',
            pageBuilder: (_, s) => neuPage(s, const InventoryScreen()),
          ),
          // OS module — literal routes before the generic placeholder so they
          // take precedence; both stay gated under /m/os.
          GoRoute(
            path: '/m/os',
            pageBuilder: (_, s) => neuPage(s, const OsListScreen()),
          ),
          // Templates de OS — antes de /m/os/:id para não ser capturado como id.
          GoRoute(
            path: '/m/os/templates',
            pageBuilder: (_, s) => neuPage(s, const TemplatesScreen()),
          ),
          GoRoute(
            path: '/m/os/:id',
            pageBuilder: (_, s) => neuPage(
              s,
              OsDetailScreen(orderId: s.pathParameters['id'] ?? ''),
            ),
          ),
          // Notas Fiscais — literais antes do placeholder genérico; gated sob
          // /m/invoice (módulo `invoice`).
          GoRoute(
            path: '/m/invoice',
            pageBuilder: (_, s) => neuPage(s, const InvoiceScreen()),
          ),
          // Configuração fiscal — literal antes de /m/invoice/:id (senão
          // "config" seria capturado como id).
          GoRoute(
            path: '/m/invoice/config',
            pageBuilder: (_, s) => neuPage(s, const InvoiceConfigScreen()),
          ),
          GoRoute(
            path: '/m/invoice/:id',
            pageBuilder: (_, s) => neuPage(
              s,
              InvoiceDetailScreen(invoiceId: s.pathParameters['id'] ?? ''),
            ),
          ),
          // Vendas/Caixa — literais antes do placeholder genérico; gated sob
          // /m/sales (módulo `sales`). /nova (balcão) antes de /:id.
          GoRoute(
            path: '/m/sales',
            pageBuilder: (_, s) => neuPage(s, const SalesHistoryScreen()),
          ),
          GoRoute(
            path: '/m/sales/nova',
            pageBuilder: (_, s) => neuPage(s, const SaleCounterScreen()),
          ),
          GoRoute(
            path: '/m/sales/:id',
            pageBuilder: (_, s) => neuPage(
              s,
              SaleDetailScreen(saleId: s.pathParameters['id'] ?? ''),
            ),
          ),
          // Relatórios — literal antes do placeholder genérico; gated sob /m/
          // (módulo `report`); o backend exige report.read nos endpoints.
          GoRoute(
            path: '/m/report',
            pageBuilder: (_, s) => neuPage(s, const ReportScreen()),
          ),
          GoRoute(
            path: '/m/:moduleKey',
            pageBuilder: (_, s) => neuPage(
              s,
              ModulePlaceholderScreen(
                moduleKey: s.pathParameters['moduleKey'] ?? '',
              ),
            ),
          ),
        ],
      ),
    ],
  );
});
