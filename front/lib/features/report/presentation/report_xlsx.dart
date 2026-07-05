import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'report_csv.dart';

/// Gera uma planilha .xlsx (OOXML) a partir de uma [ReportTable] — SEM depender
/// de pacote de Excel (evita conflito de versão do `xml` com o `pdf`). Escreve
/// os XML mínimos do pacote OOXML e empacota num ZIP com `archive`.
///
/// Layout "pré-feito": título em destaque, empresa/período, cabeçalho em negrito
/// com fundo, larguras de coluna automáticas e a linha de cabeçalho congelada
/// (scroll do conteúdo mantém os títulos à vista). Função pura e testável.
Uint8List buildXlsx(ReportTable table, {String? company, String? period}) {
  final cols = table.headers.isEmpty ? 1 : table.headers.length;

  // Linhas de metadados acima do cabeçalho (título + empresa + período).
  final metaLines = <String>[table.title];
  if (company != null && company.trim().isNotEmpty) metaLines.add(company.trim());
  if (period != null && period.trim().isNotEmpty) {
    metaLines.add('Período: ${period.trim()}');
  }

  final rowsXml = StringBuffer();
  var r = 1;

  // Título (negrito 14) + metadados (cinza).
  for (var i = 0; i < metaLines.length; i++) {
    final style = i == 0 ? 1 : 2; // 1 = título, 2 = meta
    rowsXml.write('<row r="$r">');
    rowsXml.write(_cell('A$r', metaLines[i], style));
    rowsXml.write('</row>');
    r++;
  }
  // Linha em branco separando meta do cabeçalho.
  rowsXml.write('<row r="$r"/>');
  r++;

  final headerRow = r; // linha do cabeçalho (para congelar abaixo dela)
  rowsXml.write('<row r="$r">');
  for (var c = 0; c < cols; c++) {
    final h = c < table.headers.length ? table.headers[c] : '';
    rowsXml.write(_cell('${_colRef(c)}$r', h, 3)); // 3 = cabeçalho
  }
  rowsXml.write('</row>');
  r++;

  for (final row in table.rows) {
    rowsXml.write('<row r="$r">');
    for (var c = 0; c < cols; c++) {
      final v = c < row.length ? row[c] : '';
      rowsXml.write(_cell('${_colRef(c)}$r', v, 0));
    }
    rowsXml.write('</row>');
    r++;
  }

  // Larguras: baseadas no maior conteúdo de cada coluna.
  final widthsXml = StringBuffer('<cols>');
  for (var c = 0; c < cols; c++) {
    var maxLen = c < table.headers.length ? table.headers[c].length : 8;
    for (final row in table.rows) {
      if (c < row.length && row[c].length > maxLen) maxLen = row[c].length;
    }
    final width = (maxLen + 2).clamp(10, 60);
    widthsXml.write('<col min="${c + 1}" max="${c + 1}" width="$width" '
        'customWidth="1"/>');
  }
  widthsXml.write('</cols>');

  // Congela o cabeçalho: tudo acima e incluindo a linha [headerRow] fica fixo.
  final freeze = '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="$headerRow" topLeftCell="A${headerRow + 1}" '
      'activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>';

  final sheetXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '$freeze$widthsXml<sheetData>$rowsXml</sheetData></worksheet>';

  final archive = Archive();
  void add(String path, String content) {
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(path, data.length, data));
  }

  add('[Content_Types].xml', _contentTypes);
  add('_rels/.rels', _rootRels);
  add('xl/workbook.xml', _workbook(_sheetName(table.title)));
  add('xl/_rels/workbook.xml.rels', _workbookRels);
  add('xl/styles.xml', _styles);
  add('xl/worksheets/sheet1.xml', sheetXml);

  final zip = ZipEncoder().encode(archive);
  return Uint8List.fromList(zip);
}

/// Nome de arquivo seguro para a planilha (reusa o slug do relatório).
String xlsxFileName(String title) => '${csvFileName(title).replaceAll(
      RegExp(r'\.csv$'),
      '',
    )}.xlsx';

// ---- células / refs ----

String _cell(String ref, String value, int style) =>
    '<c r="$ref" t="inlineStr" s="$style"><is><t xml:space="preserve">'
    '${_esc(value)}</t></is></c>';

/// Referência de coluna (0 → A, 25 → Z, 26 → AA…).
String _colRef(int index) {
  var i = index;
  final sb = StringBuffer();
  do {
    sb.write(String.fromCharCode(65 + (i % 26)));
    i = (i ~/ 26) - 1;
  } while (i >= 0);
  return String.fromCharCodes(sb.toString().codeUnits.reversed);
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Nome da aba: ≤31 chars, sem caracteres proibidos pelo Excel.
String _sheetName(String title) {
  final clean = title.replaceAll(RegExp(r'[\[\]\*\/\\\?:]'), ' ').trim();
  final safe = clean.isEmpty ? 'Relatório' : clean;
  return safe.length <= 31 ? safe : safe.substring(0, 31);
}

// ---- partes fixas do pacote OOXML ----

const _contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbook(String sheetName) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="${_esc(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
    '</workbook>';

const _workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

/// Estilos: fontes (padrão, negrito, título 14 negrito) + fills (obrigatório o
/// none/gray125 + o cinza do cabeçalho) + cellXfs (0 padrão, 1 título, 2 meta,
/// 3 cabeçalho negrito com fundo).
const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="3">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="14"/><color rgb="FF2B2F44"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="3">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFE6E7EE"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="4">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';
