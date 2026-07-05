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

// --- Paleta do design system (roxo/navy) ---------------------------------
const _brand = PdfColor.fromInt(0xFF6C72C4); // roxo/navy primária
const _panel = PdfColor.fromInt(0xFF2B2F44); // painel escuro (selo/rodapé)
const _ink = PdfColor.fromInt(0xFF23263B); // tinta / texto forte
const _muted = PdfColor.fromInt(0xFF6B7079); // texto secundário
const _line = PdfColor.fromInt(0xFFE6E7EE); // linhas/bordas
const _zebra = PdfColor.fromInt(0xFFF3F4F8); // faixa zebra
const _headerBg = PdfColor.fromInt(0xFFEDEEF7); // navy bem claro (cabeçalho tab.)

/// Gera um PDF de relatório profissional na identidade visual do OrbixHub:
/// cabeçalho de marca (selo + empresa + título/período), tabela com zebra,
/// alinhamento à direita para colunas de valor, destaque de linha de total e
/// rodapé com paginação e data de geração em todas as páginas.
///
/// Função pura — não acessa rede. Usada por `Printing.layoutPdf`. Mantém a
/// assinatura pública e a fonte [ReportTable] (mesma do CSV).
Future<Uint8List> buildReportPdf(
  ReportTable table,
  PdfPageFormat format, {
  ReportCompany? company,
  String? periodLabel,
}) async {
  final doc = pw.Document();

  final generatedAt = _formatDateTime(DateTime.now());
  final footerCompany = company?.name ?? 'OrbixHub';

  // Descobre quais colunas são numéricas/monetárias para alinhar à direita.
  final numericCols = _detectNumericColumns(table);
  // Detecta linha de total (primeira célula com "Total"/"Totais").
  final totalRowIndex = _detectTotalRow(table);

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
      header: (context) =>
          context.pageNumber == 1 ? _buildBrandHeader(table, company, periodLabel) : _buildRunningHeader(table),
      footer: (context) => _buildFooter(context, footerCompany, generatedAt),
      build: (context) => [
        _buildTable(table, numericCols, totalRowIndex),
      ],
    ),
  );

  return doc.save();
}

// --- Cabeçalho de marca (primeira página) --------------------------------
pw.Widget _buildBrandHeader(
  ReportTable table,
  ReportCompany? company,
  String? periodLabel,
) {
  final name = company?.name ?? 'OrbixHub';
  final legalName = company?.legalName ?? '';
  final cnpj = company?.cnpj ?? '';
  final showLegal = legalName.isNotEmpty && legalName != name;

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Selo com as iniciais da empresa.
            _buildSeal(name),
            pw.SizedBox(width: 12),
            // Bloco da empresa (esquerda).
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    name,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  if (showLegal)
                    pw.Text(
                      legalName,
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  if (cnpj.isNotEmpty)
                    pw.Text(
                      'CNPJ: $cnpj',
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            // Bloco do relatório (direita).
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'RELATÓRIO',
                  style: pw.TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _brand,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  table.title,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                if (periodLabel != null && periodLabel.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Período: $periodLabel',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        // Linha divisória sutil com um realce da marca à esquerda.
        pw.Row(
          children: [
            pw.Container(width: 48, height: 2.5, color: _brand),
            pw.Expanded(child: pw.Container(height: 1, color: _line)),
          ],
        ),
      ],
    ),
  );
}

// --- Cabeçalho reduzido (páginas seguintes) ------------------------------
pw.Widget _buildRunningHeader(ReportTable table) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _line, width: 1)),
    ),
    child: pw.Text(
      table.title,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: _muted,
      ),
    ),
  );
}

// --- Selo quadrado com as iniciais da empresa ----------------------------
pw.Widget _buildSeal(String name) {
  return pw.Container(
    width: 44,
    height: 44,
    decoration: pw.BoxDecoration(
      color: _panel,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    alignment: pw.Alignment.center,
    child: pw.Text(
      _initials(name),
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );
}

// --- Tabela profissional (zebra + total + alinhamento) -------------------
pw.Widget _buildTable(
  ReportTable table,
  Set<int> numericCols,
  int totalRowIndex,
) {
  final colCount = table.headers.length;

  final rows = <pw.TableRow>[];

  // Cabeçalho (repete em cada página).
  rows.add(
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: _headerBg),
      children: [
        for (var c = 0; c < colCount; c++)
          _cell(
            table.headers[c],
            bold: true,
            color: _ink,
            alignRight: numericCols.contains(c),
          ),
      ],
    ),
  );

  if (table.rows.isEmpty) {
    rows.add(
      pw.TableRow(
        children: [
          _cell('Sem dados no período', color: _muted, italic: true),
          for (var c = 1; c < colCount; c++) _cell(''),
        ],
      ),
    );
  } else {
    for (var r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      final isTotal = r == totalRowIndex;
      final zebra = r.isOdd;

      final decoration = isTotal
          ? const pw.BoxDecoration(
              color: _headerBg,
              border: pw.Border(top: pw.BorderSide(color: _brand, width: 1.2)),
            )
          : (zebra
              ? const pw.BoxDecoration(color: _zebra)
              : const pw.BoxDecoration(color: PdfColors.white));

      rows.add(
        pw.TableRow(
          decoration: decoration,
          children: [
            for (var c = 0; c < colCount; c++)
              _cell(
                c < row.length ? row[c] : '',
                bold: isTotal,
                alignRight: numericCols.contains(c),
              ),
          ],
        ),
      );
    }
  }

  return pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
    ),
    children: rows,
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  bool italic = false,
  bool alignRight = false,
  PdfColor color = _ink,
}) {
  return pw.Container(
    alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      ),
    ),
  );
}

// --- Rodapé (todas as páginas) -------------------------------------------
pw.Widget _buildFooter(
  pw.Context context,
  String company,
  String generatedAt,
) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _line, width: 1)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Text(
            'OrbixHub · $company',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        pw.Text(
          'Gerado em $generatedAt',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
        pw.SizedBox(width: 16),
        pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: pw.TextStyle(
            fontSize: 8,
            color: _muted,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

// --- Helpers --------------------------------------------------------------

/// Iniciais da empresa para o selo (até 2 letras).
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'OH';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Data/hora no formato dd/MM/yyyy HH:mm (sem depender de intl).
String _formatDateTime(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// Palavras que sugerem coluna de valor/quantidade no cabeçalho.
const _numericHeaderHints = <String>[
  'r\$',
  'valor',
  'total',
  'qtd',
  'faturamento',
  'ticket',
  '%',
];

/// Decide, por coluna, se deve alinhar à direita: ou o cabeçalho sugere valor,
/// ou a maioria das células é um número/moeda no formato BR.
Set<int> _detectNumericColumns(ReportTable table) {
  final result = <int>{};
  final colCount = table.headers.length;

  for (var c = 0; c < colCount; c++) {
    final header = table.headers[c].toLowerCase();
    final headerHints =
        _numericHeaderHints.any((hint) => header.contains(hint));
    if (headerHints) {
      result.add(c);
      continue;
    }

    var numeric = 0;
    var considered = 0;
    for (final row in table.rows) {
      if (c >= row.length) continue;
      final cell = row[c].trim();
      if (cell.isEmpty) continue;
      considered++;
      if (_looksNumericBr(cell)) numeric++;
    }
    if (considered > 0 && numeric / considered >= 0.6) {
      result.add(c);
    }
  }
  return result;
}

/// Reconhece número/moeda no padrão brasileiro: "1.234,56", "R$ 1.234,56",
/// "45%", "10", "12,5".
bool _looksNumericBr(String value) {
  var s = value.trim();
  if (s.isEmpty) return false;
  s = s
      .replaceAll('R\$', '')
      .replaceAll('%', '')
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  if (s.startsWith('-')) s = s.substring(1);
  if (s.isEmpty) return false;
  return double.tryParse(s) != null;
}

/// Índice da última linha se ela parecer um total (primeira célula com
/// "Total"/"Totais"); caso contrário -1.
int _detectTotalRow(ReportTable table) {
  if (table.rows.isEmpty) return -1;
  final last = table.rows.length - 1;
  final row = table.rows[last];
  if (row.isEmpty) return -1;
  final first = row.first.trim().toLowerCase();
  if (first == 'total' || first == 'totais' || first.startsWith('total')) {
    return last;
  }
  return -1;
}
