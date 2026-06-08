import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';
import 'package:orbixhub_front/features/shell/presentation/sidebar.dart';

/// Regression guard: the previous shell (NavigationRail with an Expanded in a
/// scrollable trailing) threw a layout assertion that broke hit-testing and
/// made the whole app unclickable. This pumps the replacement sidebar and
/// asserts it lays out cleanly while still rendering the gated nav.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const me = Me(
    user: User(id: 'u1', email: 'a@b.c', fullName: 'Dono Teste'),
    activeTenant: Tenant(id: 't1', slug: 's1', name: 'Oficina Teste'),
    role: 'owner',
    permissions: ['billing.manage'],
    modules: ['os', 'customers'],
  );

  testWidgets('sidebar lays out with no exception and shows gated nav',
      (tester) async {
    final items = gatedNavItems(me);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  height: 720,
                  child: SidebarContent(
                    me: me,
                    items: items,
                    selectedIndex: 0,
                    onNavigate: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ordens de Serviço'), findsOneWidget);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Planos'), findsOneWidget);
    expect(find.text('Dono Teste'), findsOneWidget); // user footer
  });

  testWidgets('tapping a nav item reports its route', (tester) async {
    final items = gatedNavItems(me);
    String? tapped;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  height: 720,
                  child: SidebarContent(
                    me: me,
                    items: items,
                    selectedIndex: 0,
                    onNavigate: (r) => tapped = r,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Planos'));
    expect(tapped, '/billing');
  });
}
