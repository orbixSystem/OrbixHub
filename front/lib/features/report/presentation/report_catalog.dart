import '../../auth/domain/auth_models.dart';

/// Identifica cada relatório do MVP. O builder/tabela fica na tela.
enum ReportKind {
  /// Visão geral (painel BI): KPIs + gráficos sobre os dados do período.
  /// Não tem tabela/export — é um dashboard. Exige o módulo `os` (fonte
  /// obrigatória); clientes/estoque entram só se os módulos existirem.
  overview,

  /// OS operacional (linhas + status/técnico). Filtros: período, técnico, status.
  osOperational,

  /// Faturamento (total, ticket, série/dia, por status). Filtro: período.
  revenue,

  /// Rendimento da equipe (por responsável). Filtro: período.
  team,

  /// Top produtos/serviços. Filtros: período, kind, limit.
  topItems,

  /// Estoque (posição). Point-in-time.
  inventoryPosition,

  /// Clientes (novos + ativos). Filtro: período.
  customers,
}

/// Especificação de um relatório: o módulo-fonte que o habilita + rótulo + grupo.
/// O relatório só aparece se `me.modules` contém [moduleKey] (o módulo dono dos
/// dados) E o tenant tem o módulo `report` + `report.read` (gate da feature toda).
class ReportSpec {
  const ReportSpec({
    required this.kind,
    required this.moduleKey,
    required this.group,
    required this.label,
  });

  final ReportKind kind;

  /// Módulo dono dos dados (os / inventory / customers).
  final String moduleKey;

  /// Grupo no seletor (nome do módulo-fonte), para agrupar os relatórios.
  final String group;

  /// Rótulo PT-BR do relatório.
  final String label;
}

/// Catálogo completo (ordem de exibição). Os de OS são "lentes" sobre os dados de
/// OS — todos exigem o módulo `os`.
const List<ReportSpec> _allReports = [
  // PRIMEIRO do catálogo → é a tela inicial de Relatórios (painel BI).
  ReportSpec(
    kind: ReportKind.overview,
    moduleKey: 'os',
    group: 'Visão geral',
    label: 'Visão geral',
  ),
  ReportSpec(
    kind: ReportKind.osOperational,
    moduleKey: 'os',
    group: 'Ordens de Serviço',
    label: 'Operacional',
  ),
  ReportSpec(
    kind: ReportKind.revenue,
    moduleKey: 'os',
    group: 'Ordens de Serviço',
    label: 'Faturamento',
  ),
  ReportSpec(
    kind: ReportKind.team,
    moduleKey: 'os',
    group: 'Ordens de Serviço',
    label: 'Rendimento da equipe',
  ),
  ReportSpec(
    kind: ReportKind.topItems,
    moduleKey: 'os',
    group: 'Ordens de Serviço',
    label: 'Top produtos/serviços',
  ),
  ReportSpec(
    kind: ReportKind.inventoryPosition,
    moduleKey: 'inventory',
    group: 'Estoque',
    label: 'Posição de estoque',
  ),
  ReportSpec(
    kind: ReportKind.customers,
    moduleKey: 'customers',
    group: 'Clientes',
    label: 'Clientes',
  ),
];

/// Função pura (testada): os relatórios que este usuário deve ver, derivados
/// SOMENTE do `/me`. A feature inteira exige o módulo `report` + `report.read`
/// (gate do menu/rota); cada relatório exige adicionalmente o módulo dono dos
/// dados. Esconder ≠ proteger — o backend é a verdade (endpoints gated).
List<ReportSpec> availableReports(Me me) {
  if (!me.hasModule('report') || !me.hasPermission('report.read')) {
    return const [];
  }
  return _allReports.where((r) => me.hasModule(r.moduleKey)).toList();
}
