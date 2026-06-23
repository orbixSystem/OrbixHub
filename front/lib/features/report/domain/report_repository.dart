import 'report_models.dart';

/// Contrato de dados dos relatórios. A UI só fala com esta interface (regra 8).
/// Um método por endpoint de `GET /report/*`. Todos gated no backend por
/// `@RequiresModule('report')` + `@Permissions('report.read')`.
abstract class ReportRepository {
  /// `GET /report/os` — operacional: linhas + agregados por status/técnico.
  Future<OsOperationalReport> osReport({
    required ReportRange range,
    String? assignedTo,
    String? status,
  });

  /// `GET /report/revenue` — faturamento: total, ticket, série/dia, por status.
  Future<RevenueReport> revenue({required ReportRange range});

  /// `GET /report/team` — rendimento agregado por responsável.
  Future<TeamReport> team({required ReportRange range});

  /// `GET /report/top-items` — top produtos/serviços por receita.
  Future<TopItemsReport> topItems({
    required ReportRange range,
    String? kind,
    int? limit,
  });

  /// `GET /report/inventory` — posição de estoque (point-in-time).
  Future<InventoryReport> inventory();

  /// `GET /report/customers` — novos no range + total ativo.
  Future<CustomersReport> customers({required ReportRange range});

  /// Membros da equipe (`GET /employees`) para o filtro "técnico" dos
  /// relatórios de OS. Reusa a mesma rota/forma do dropdown da OS.
  Future<List<ReportMemberOption>> members();
}
