import '../../features/auth/domain/auth_models.dart';

/// Rotas **100% online-only**: offline elas não têm nada a mostrar, então o app
/// leva o usuário embora (redirect) com um aviso em modal. As telas
/// PARCIALMENTE offline (Configurações — Aparência funciona; detalhe da OS —
/// edição funciona) NÃO entram aqui: elas bloqueiam por seção, no lugar. O CRUD
/// básico (clientes / OS / estoque / caixa) funciona offline e nunca bloqueia.
///
/// Função pura (testada) — o `AppShell` a consulta a cada mudança de rota/rede.
bool isOnlineOnlyRoute(String location) {
  return location == '/billing' || // planos
      location.startsWith('/m/invoice') || // notas fiscais
      location == '/m/report' || // relatórios (BI do servidor)
      location.startsWith('/agenda') || // agenda + horários (servidor)
      location == '/equipe'; // gestão de equipe (servidor)
}

/// Para onde mandar o usuário quando ele está offline numa rota online-only:
/// a primeira rota de CRUD que o plano dele habilita (funciona offline). Cai no
/// Início só se nenhuma existir — o dashboard é online-only, mas é o último recurso.
String offlineSafeRoute(Me me) {
  for (final key in const ['os', 'customers', 'inventory']) {
    if (me.hasModule(key)) return '/m/$key';
  }
  return '/';
}
