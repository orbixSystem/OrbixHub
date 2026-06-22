import 'package:flutter/material.dart';

import '../../auth/domain/auth_models.dart';

/// A navigable destination, already gated in/out for the current user.
class NavItem {
  const NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

/// Friendly label + icon per known module key; unknown keys fall back gracefully.
const Map<String, (String, IconData)> moduleMeta = {
  'os': ('Ordens de Serviço', Icons.build_outlined),
  'customers': ('Clientes', Icons.people_alt_outlined),
  'inventory': ('Estoque', Icons.inventory_2_outlined),
};

/// Pure gating: the navigation items a user may see, derived ONLY from their
/// `/me` (role/permissions + enabled modules). Hiding is for UX; the router and
/// backend enforce the real boundary.
List<NavItem> gatedNavItems(Me me) {
  final items = <NavItem>[
    const NavItem('Início', Icons.home_outlined, '/'),
  ];
  for (final key in me.modules) {
    final meta = moduleMeta[key] ?? (key, Icons.extension_outlined);
    items.add(NavItem(meta.$1, meta.$2, '/m/$key'));
  }
  // Mensagens é genérico (não é módulo de tenant). v1 reusa as permissões de OS:
  // mostra para quem pode ler OS; owners também têm essa permissão.
  if (me.hasPermission('os.read')) {
    items.add(
      const NavItem('Mensagens', Icons.forum_outlined, '/mensagens'),
    );
  }
  // Team management is gated by users.manage; placed before Planos.
  if (me.hasPermission('users.manage')) {
    items.add(const NavItem('Equipe', Icons.groups_outlined, '/equipe'));
  }
  // Billing/plans is owner-only (billing.manage); mechanics never see it.
  if (me.hasPermission('billing.manage')) {
    items.add(const NavItem('Planos', Icons.credit_card_outlined, '/billing'));
  }
  // Configurações — visível para qualquer membro autenticado.
  // A tela em si gatea empresa/módulos por settings.manage internamente.
  items.add(
    const NavItem('Configurações', Icons.settings_outlined, '/configuracoes'),
  );
  return items;
}

/// Index of the item best matching [location] (longest matching route prefix).
int selectedNavIndex(List<NavItem> items, String location) {
  var best = 0;
  var bestLen = -1;
  for (var i = 0; i < items.length; i++) {
    final route = items[i].route;
    final matches = route == '/' ? location == '/' : location.startsWith(route);
    if (matches && route.length > bestLen) {
      best = i;
      bestLen = route.length;
    }
  }
  return best;
}
