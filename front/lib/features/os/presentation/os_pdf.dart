import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/os_models.dart';
import 'os_status.dart';

/// Identificação da empresa (tenant) impressa no topo da OS.
class OsCompany {
  const OsCompany({required this.name, this.legalName, this.cnpj});
  final String name;
  final String? legalName;
  final String? cnpj;
}

/// Gera o PDF de impressão de uma OS: cabeçalho da empresa (nome + CNPJ),
/// nº + status, cliente/veículo, datas relevantes, tabela de itens e total.
/// Mantido simples e on-brand-ish (cinza grafite + tangerina Orbix). Não acessa
/// rede — usa o que já está em `order`/`company`. Usado por `Printing.layoutPdf`.
Future<Uint8List> buildOsPdf(
  ServiceOrder order,
  PdfPageFormat format, {
  OsCompany? company,
}) async {
  const brand = PdfColor.fromInt(0xFFEC5E12);
  const graphite = PdfColor.fromInt(0xFF15171C);
  const muted = PdfColor.fromInt(0xFF6B7079);
  const line = PdfColor.fromInt(0xFFE7E4DD);

  final doc = pw.Document();

  final facts = <List<String>>[
    if ((order.customerName ?? '').isNotEmpty)
      ['Cliente', order.customerName!],
    if ((order.subjectLabel ?? '').isNotEmpty)
      ['Veículo', order.subjectLabel!],
    if ((order.assignedTo ?? '').isNotEmpty)
      ['Responsável', order.assignedTo!],
    if ((order.scheduledStart ?? '').isNotEmpty)
      ['Previsão início', order.scheduledStart!],
    if ((order.scheduledEnd ?? '').isNotEmpty)
      ['Previsão fim', order.scheduledEnd!],
    if ((order.createdAt ?? '').isNotEmpty)
      ['Abertura', order.createdAt!],
  ];

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Cabeçalho da empresa (tenant)
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
                pw.Text(
                  company.legalName!,
                  style: pw.TextStyle(fontSize: 10, color: muted),
                ),
              if ((company.cnpj ?? '').isNotEmpty)
                pw.Text(
                  'CNPJ: ${company.cnpj}',
                  style: pw.TextStyle(fontSize: 10, color: muted),
                ),
              pw.SizedBox(height: 12),
            ],
            // Cabeçalho
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Ordem de Serviço',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      order.number,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: graphite,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: brand,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    osStatusLabel(order.status),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: line, thickness: 1),
            pw.SizedBox(height: 12),

            // Dados (cliente/veículo/datas)
            if (facts.isNotEmpty) ...[
              pw.Wrap(
                spacing: 28,
                runSpacing: 10,
                children: [
                  for (final f in facts)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          f[0],
                          style: pw.TextStyle(fontSize: 9, color: muted),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          f[1],
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
            if ((order.complaint ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Relato',
                  style: pw.TextStyle(fontSize: 9, color: muted)),
              pw.SizedBox(height: 2),
              pw.Text(order.complaint!, style: const pw.TextStyle(fontSize: 12)),
            ],
            if ((order.diagnosis ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Diagnóstico',
                  style: pw.TextStyle(fontSize: 9, color: muted)),
              pw.SizedBox(height: 2),
              pw.Text(order.diagnosis!, style: const pw.TextStyle(fontSize: 12)),
            ],
            pw.SizedBox(height: 18),

            // Tabela de itens
            pw.Text(
              'Itens',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: graphite,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: null,
              headerDecoration: const pw.BoxDecoration(color: line),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: graphite,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellHeight: 24,
              headerAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headers: const ['Item', 'Qtd', 'Preço unit.', 'Total'],
              data: [
                if (order.items.isEmpty)
                  ['Nenhum item', '', '', '']
                else
                  for (final it in order.items)
                    [
                      it.name,
                      it.quantity,
                      money(it.unitPrice),
                      money(it.total),
                    ],
              ],
            ),
            pw.SizedBox(height: 14),

            // Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total: ',
                  style: pw.TextStyle(fontSize: 13, color: muted),
                ),
                pw.Text(
                  money(order.total),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: brand,
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.Divider(color: line, thickness: 1),
            pw.SizedBox(height: 4),
            pw.Text(
              'Gerado pelo OrbixHub',
              style: pw.TextStyle(fontSize: 9, color: muted),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}
