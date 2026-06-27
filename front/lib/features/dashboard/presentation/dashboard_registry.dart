import '../../auth/domain/auth_models.dart';

/// Identifica qual widget de métrica renderizar. O builder concreto fica na tela
/// (mapeado a partir desta chave), mantendo `dashboardWidgets` puro e testável.
enum DashboardWidgetKind {
  /// OS — visão gerencial (faturamento, OS por status, ticket, ciclo).
  osManagement,

  /// OS — visão operacional ("minhas OS" do mecânico).
  osOperational,

  /// Estoque — abaixo do mínimo, valor, produtos/serviços.
  inventory,

  /// Clientes — ativos + novos no período.
  customers,
}

/// Especificação de um widget do dashboard: o módulo e a permissão que o
/// habilitam, mais qual widget renderizar. Espelha `gatedNavItems`.
class DashboardWidgetSpec {
  const DashboardWidgetSpec({
    required this.kind,
    required this.moduleKey,
    required this.permission,
    this.showValue = true,
  });

  final DashboardWidgetKind kind;
  final String moduleKey;
  final String permission;

  /// Só relevante p/ o widget de estoque: exibe a métrica monetária ("Valor em
  /// estoque") apenas para quem tem visibilidade gerencial (`report.read`).
  final bool showValue;
}

/// Função pura (testada): a lista ordenada de widgets que este usuário deve ver,
/// derivada SOMENTE do `/me` (módulos habilitados + permissões). Um widget só
/// entra se `me.modules` contém [moduleKey] E `me.hasPermission(permission)`.
/// Esconder ≠ proteger — o backend é a verdade; estes endpoints são gated.
List<DashboardWidgetSpec> dashboardWidgets(Me me) {
  final specs = <DashboardWidgetSpec>[];

  // OS — role-aware. Ambas exigem o módulo `os` + `os.read`. Quem tem
  // `report.read` (owner/gerente) vê o gerencial; senão (mecânico) o operacional.
  if (me.hasModule('os') && me.hasPermission('os.read')) {
    if (me.hasPermission('report.read')) {
      specs.add(const DashboardWidgetSpec(
        kind: DashboardWidgetKind.osManagement,
        moduleKey: 'os',
        permission: 'os.read',
      ));
    } else {
      specs.add(const DashboardWidgetSpec(
        kind: DashboardWidgetKind.osOperational,
        moduleKey: 'os',
        permission: 'os.read',
      ));
    }
  }

  // Estoque — gated por `inventory.read` (mecânico mantém). A métrica monetária
  // ("Valor em estoque") só aparece para quem tem `report.read` (gerencial);
  // sem ela, o widget renderiza sem o valor (o que repor, não o quanto vale).
  if (me.hasModule('inventory') && me.hasPermission('inventory.read')) {
    specs.add(DashboardWidgetSpec(
      kind: DashboardWidgetKind.inventory,
      moduleKey: 'inventory',
      permission: 'inventory.read',
      showValue: me.hasPermission('report.read'),
    ));
  }

  // Clientes — métrica gerencial: gated por `report.read` (owner/gerente).
  // Mecânico/caixa não veem a contagem de clientes.
  if (me.hasModule('customers') && me.hasPermission('report.read')) {
    specs.add(const DashboardWidgetSpec(
      kind: DashboardWidgetKind.customers,
      moduleKey: 'customers',
      permission: 'report.read',
    ));
  }

  return specs;
}
