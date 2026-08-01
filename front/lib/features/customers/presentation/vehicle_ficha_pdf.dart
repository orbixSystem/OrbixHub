import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/customers_models.dart';
import 'plate_labels.dart';

/// Identificação da empresa (tenant) impressa no topo da ficha.
class FichaCompany {
  const FichaCompany({required this.name, this.legalName, this.cnpj});
  final String name;
  final String? legalName;
  final String? cnpj;
}

/// Gera a "Ficha do Veículo" em PDF a partir da consulta por placa
/// ([PlateInfo]) + dados do cadastro (apelido/cliente/km). Mesma direção
/// visual do PDF de OS (grafite + tangerina Orbix, base-14 fonts). Não acessa
/// rede — usado por `Printing.layoutPdf` (multiplataforma: desktop, mobile e web).
Future<Uint8List> buildVehicleFichaPdf(
  PlateInfo info,
  PdfPageFormat format, {
  FichaCompany? company,
  String? apelido,
  String? customerName,
  String? km,
}) async {
  const brand = PdfColor.fromInt(0xFFEC5E12);
  const graphite = PdfColor.fromInt(0xFF15171C);
  const muted = PdfColor.fromInt(0xFF6B7079);
  const line = PdfColor.fromInt(0xFFE7E4DD);

  final doc = pw.Document();

  // Título "MARCA MODELO" (o que der pra montar).
  final titleParts = [info.marca, info.modelo]
      .where((p) => (p ?? '').isNotEmpty)
      .cast<String>()
      .toList();
  final title = titleParts.isEmpty ? 'Veículo' : titleParts.join(' ');

  // Seções: pares rótulo→valor; só entra o que a consulta trouxe (a API avisa
  // que extra/fipe podem faltar).
  List<List<String>> section(List<(String, String?)> pairs) => [
        for (final (label, value) in pairs)
          if ((value ?? '').trim().isNotEmpty) [label, value!.trim()],
      ];

  final identificacao = section([
    ('Placa', info.placa),
    ('Placa anterior', info.placaAlternativa),
    ('Apelido', apelido),
    ('Cliente', customerName),
    ('Marca', info.marca),
    ('Modelo', info.modelo),
    ('Versão', info.versao == info.modelo ? null : info.versao),
    ('Ano fabricação', info.ano),
    ('Ano modelo', info.anoModelo),
    ('Cor', info.cor),
    ('Chassi', info.chassi),
    ('KM atual', km),
  ]);

  final caracteristicas = section([
    ('Combustível', info.combustivel),
    ('Cilindradas', info.cilindradas),
    ('Tipo', info.tipoVeiculo),
    ('Espécie', info.especie),
    ('Passageiros', info.passageiros),
    ('Segmento', info.segmento),
  ]);

  final registro = section([
    ('Município', info.municipio),
    ('UF', info.uf),
    ('Situação', info.situacao),
    ('Origem', info.origem),
    ('Nacionalidade', info.nacionalidade),
  ]);

  pw.Widget factGrid(List<List<String>> facts) => pw.Wrap(
        spacing: 28,
        runSpacing: 10,
        children: [
          for (final f in facts)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(f[0], style: pw.TextStyle(fontSize: 9, color: muted)),
                pw.SizedBox(height: 2),
                pw.Text(f[1], style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
        ],
      );

  pw.Widget sectionTitle(String label) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: graphite,
          ),
        ),
      );

  final now = DateTime.now();
  final generatedAt =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

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
            // Título + placa em destaque
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Ficha do Veículo',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: graphite,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: pw.BoxDecoration(
                    color: brand,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    info.placa,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: line, thickness: 1),
            pw.SizedBox(height: 12),

            if (identificacao.isNotEmpty) ...[
              sectionTitle('Identificação'),
              factGrid(identificacao),
              pw.SizedBox(height: 16),
            ],
            if (caracteristicas.isNotEmpty) ...[
              sectionTitle('Características'),
              factGrid(caracteristicas),
              pw.SizedBox(height: 16),
            ],
            if (registro.isNotEmpty) ...[
              sectionTitle('Registro'),
              factGrid(registro),
              pw.SizedBox(height: 16),
            ],

            // Valor de referência FIPE (melhor correspondência por score)
            if (info.fipe != null &&
                ((info.fipe!.valor ?? '').isNotEmpty ||
                    (info.fipe!.modelo ?? '').isNotEmpty)) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF6F3EC),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Referência FIPE',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: graphite,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    if ((info.fipe!.modelo ?? '').isNotEmpty)
                      pw.Text(
                        info.fipe!.modelo!,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          [
                            if ((info.fipe!.codigoFipe ?? '').isNotEmpty)
                              'Código ${info.fipe!.codigoFipe}',
                            if ((info.fipe!.mesReferencia ?? '').isNotEmpty)
                              'ref. ${info.fipe!.mesReferencia}',
                          ].join(' · '),
                          style: pw.TextStyle(fontSize: 9, color: muted),
                        ),
                        if ((info.fipe!.valor ?? '').isNotEmpty)
                          pw.Text(
                            info.fipe!.valor!,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: brand,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            pw.Spacer(),
            pw.Divider(color: line, thickness: 1),
            pw.SizedBox(height: 4),
            pw.Text(
              'Gerado pelo OrbixHub em $generatedAt — dados da consulta por placa '
              '(sujeitos à disponibilidade da base no momento da busca).',
              style: pw.TextStyle(fontSize: 9, color: muted),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

/// Gera a **ficha completa** do veículo: tudo o que a consulta por placa
/// entregou — identificação, características, registro, o bloco técnico
/// inteiro (rotulado) e TODAS as correspondências FIPE com seus valores.
///
/// Usa `MultiPage` porque o conteúdo passa de uma página com frequência (o
/// bloco técnico sozinho costuma trazer ~40 campos). Não acessa rede.
Future<Uint8List> buildVehicleFichaCompletaPdf(
  PlateInfo info,
  PdfPageFormat format, {
  FichaCompany? company,
  String? apelido,
  String? customerName,
  String? km,
}) async {
  const brand = PdfColor.fromInt(0xFFEC5E12);
  const graphite = PdfColor.fromInt(0xFF15171C);
  const muted = PdfColor.fromInt(0xFF6B7079);
  const line = PdfColor.fromInt(0xFFE7E4DD);
  const tint = PdfColor.fromInt(0xFFF6F3EC);

  final doc = pw.Document();

  final titleParts = [info.marca, info.modelo]
      .where((p) => (p ?? '').isNotEmpty)
      .cast<String>()
      .toList();
  final title = titleParts.isEmpty ? 'Veículo' : titleParts.join(' ');

  List<List<String>> rows(List<(String, String?)> pairs) => [
        for (final (label, value) in pairs)
          if ((value ?? '').trim().isNotEmpty) [label, value!.trim()],
      ];

  pw.Widget sectionTitle(String label) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: graphite,
          ),
        ),
      );

  /// Tabela rótulo→valor em 2 colunas; quebra entre páginas sem cortar linha.
  pw.Widget kvTable(List<List<String>> data) => pw.TableHelper.fromTextArray(
        border: null,
        headerCount: 0,
        cellHeight: 18,
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        cellAlignments: const {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
        columnWidths: const {
          0: pw.FixedColumnWidth(150),
          1: pw.FlexColumnWidth(),
        },
        cellDecoration: (row, _, _) => pw.BoxDecoration(
          color: row.isEven ? tint : PdfColors.white,
        ),
        data: data,
      );

  final identificacao = rows([
    ('Placa', info.placa),
    ('Placa anterior', info.placaAlternativa),
    ('Apelido', apelido),
    ('Cliente', customerName),
    ('Marca', info.marca),
    ('Modelo', info.modelo),
    ('Marca/modelo (registro)', info.marcaModelo),
    ('Versão', info.versao == info.modelo ? null : info.versao),
    ('Ano de fabricação', info.ano),
    ('Ano do modelo', info.anoModelo),
    ('Cor', info.cor),
    ('Chassi', info.chassi),
    ('KM atual', km),
  ]);

  final caracteristicas = rows([
    ('Combustível', info.combustivel),
    ('Cilindradas', info.cilindradas),
    ('Tipo de veículo', info.tipoVeiculo),
    ('Espécie', info.especie),
    ('Passageiros', info.passageiros),
    ('Segmento', info.segmento),
  ]);

  final registro = rows([
    ('Município', info.municipio),
    ('UF', info.uf),
    ('Situação', info.situacao),
    ('Origem', info.origem),
    ('Nacionalidade', info.nacionalidade),
    ('Equivalente FIPE (marca)', info.fipeMatch?.marca?.value),
    ('Equivalente FIPE (modelo)', info.fipeMatch?.modelo?.value),
    ('Dados do registro em', info.consultadoEm),
  ]);

  final tecnicos = [
    for (final (label, value) in plateTechnicalRows(info.extra)) [label, value],
  ];

  final now = DateTime.now();
  final generatedAt =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Ficha completa · ${info.placa} · gerada pelo OrbixHub em $generatedAt',
              style: pw.TextStyle(fontSize: 8, color: muted),
            ),
            pw.Text(
              '${context.pageNumber}/${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: muted),
            ),
          ],
        ),
      ),
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
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Ficha completa do veículo',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: graphite,
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: pw.BoxDecoration(
                color: brand,
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(
                info.placa,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: line, thickness: 1),

        if (identificacao.isNotEmpty) ...[
          sectionTitle('Identificação'),
          kvTable(identificacao),
        ],
        if (caracteristicas.isNotEmpty) ...[
          sectionTitle('Características'),
          kvTable(caracteristicas),
        ],
        if (registro.isNotEmpty) ...[
          sectionTitle('Registro'),
          kvTable(registro),
        ],
        if (tecnicos.isNotEmpty) ...[
          sectionTitle('Dados técnicos e restrições'),
          kvTable(tecnicos),
        ],

        // Todas as correspondências FIPE, da melhor para a pior.
        if (info.fipeTodos.isNotEmpty) ...[
          sectionTitle('Valores de referência FIPE'),
          pw.TableHelper.fromTextArray(
            border: null,
            headerDecoration: const pw.BoxDecoration(color: line),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: graphite,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellHeight: 20,
            headerAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            headers: const ['Modelo (FIPE)', 'Código', 'Referência', 'Valor'],
            data: [
              for (final f in info.fipeTodos)
                [
                  f.modelo ?? '—',
                  f.codigoFipe ?? '—',
                  [
                    if ((f.anoModelo ?? '').isNotEmpty) f.anoModelo!,
                    if ((f.combustivel ?? '').isNotEmpty) f.combustivel!,
                    if ((f.mesReferencia ?? '').isNotEmpty) f.mesReferencia!,
                  ].join(' · '),
                  f.valor ?? '—',
                ],
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'A consulta pode retornar mais de uma correspondência FIPE; a de '
            'maior precisão aparece primeiro. Os valores podem não estar '
            'disponíveis em todas as consultas.',
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],

        pw.SizedBox(height: 14),
        pw.Divider(color: line, thickness: 1),
        pw.SizedBox(height: 4),
        pw.Text(
          'Dados obtidos por consulta à base de veículos emplacados a partir da '
          'placa. Podem estar incompletos ou desatualizados — confira antes de '
          'usar para fins contratuais.',
          style: pw.TextStyle(fontSize: 8, color: muted),
        ),
      ],
    ),
  );

  return doc.save();
}
