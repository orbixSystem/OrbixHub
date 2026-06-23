import 'dart:typed_data';

import 'report_models.dart';

/// Identificação da empresa (tenant) para o cabeçalho do PDF de export.
class ReportExportCompany {
  const ReportExportCompany({required this.name, this.legalName, this.cnpj});
  final String name;
  final String? legalName;
  final String? cnpj;
}

/// Contrato de dados dos relatórios. A UI só fala com esta interface (regra 8).
/// Um método por endpoint de `GET /report/*`. Todos gated no backend por
/// `@RequiresModule('report')` + `@Permissions('report.read')`.
abstract class ReportRepository {
  /// `GET /report/os` — operacional PAGINADO (scroll infinito): linhas da página
  /// + total. Aceita busca (`q`) e ordenação (`sort`); default `sort: 'recent'`.
  Future<OsOperationalReport> osReport({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort,
    int page,
    int pageSize,
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

  /// `GET /report/inventory` — posição de estoque (point-in-time), PAGINADA.
  Future<InventoryReport> inventory({int page, int pageSize, String? q});

  /// `GET /report/inventory.csv` — CSV do relatório COMPLETO (gerado no
  /// servidor). Retorna os bytes prontos para o browser baixar.
  Future<Uint8List> inventoryCsv({String? q});

  /// `GET /report/inventory.pdf` — PDF do relatório COMPLETO (gerado no
  /// servidor). `company` vai no cabeçalho. Retorna os bytes.
  Future<Uint8List> inventoryPdf({ReportExportCompany? company, String? q});

  /// `GET /report/customers` — novos no range + total ativo.
  Future<CustomersReport> customers({required ReportRange range});

  /// Membros da equipe (`GET /employees`) para o filtro "técnico" dos
  /// relatórios de OS. Reusa a mesma rota/forma do dropdown da OS.
  Future<List<ReportMemberOption>> members();
}
