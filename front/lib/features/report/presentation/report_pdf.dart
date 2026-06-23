import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_csv.dart';

/// Identificação da empresa (tenant) impressa no topo do relatório.
class ReportCompany {
  const ReportCompany({required this.name, this.legalName, this.cnpj});
  final String name;
  final String? legalName;
  final String? cnpj;
}

/// Gera um PDF de relatório: cabeçalho da empresa (nome + CNPJ), título do
/// relatório, período e uma tabela simples (mesma fonte do CSV — [ReportTable]).
/// Não acessa rede. Usado por `Printing.layoutPdf`. Reusa o estilo on-brand da OS.
Future<Uint8List> buildReportPdf(
  ReportTable table,
  PdfPageFormat format, {
  ReportCompany? company,
  String? periodLabel,
}) async {
  const brand = PdfColor.fromInt(0xFFEC5E12);
  const graphite = PdfColor.fromInt(0xFF15171C);
  const muted = PdfColor.fromInt(0xFF6B7079);
  const line = PdfColor.fromInt(0xFFE7E4DD);

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        if (company != null) ...[
          pw.Text(
            company.name,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: graphite,
            ),
          ),
          if ((company.legalName ?? '').isNotEmpty &&
              company.legalName != company.name)
            pw.Text(company.legalName!,
                style: pw.TextStyle(fontSize: 10, color: muted)),
          if ((company.cnpj ?? '').isNotEmpty)
            pw.Text('CNPJ: ${company.cnpj}',
                style: pw.TextStyle(fontSize: 10, color: muted)),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          table.title,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: graphite,
          ),
        ),
        if (periodLabel != null && periodLabel.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text('Período: $periodLabel',
              style: pw.TextStyle(fontSize: 10, color: muted)),
        ],
        pw.SizedBox(height: 6),
        pw.Divider(color: line, thickness: 1),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          border: null,
          headerDecoration: const pw.BoxDecoration(color: line),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: graphite,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellHeight: 22,
          headers: table.headers,
          data: table.rows.isEmpty
              ? [
                  [
                    'Sem dados no período',
                    ...List.filled(table.headers.length - 1, ''),
                  ],
                ]
              : table.rows,
        ),
        pw.SizedBox(height: 14),
        pw.Divider(color: line, thickness: 1),
        pw.SizedBox(height: 4),
        pw.Text(
          'Gerado pelo OrbixHub',
          style: pw.TextStyle(fontSize: 9, color: brand),
        ),
      ],
    ),
  );

  return doc.save();
}
