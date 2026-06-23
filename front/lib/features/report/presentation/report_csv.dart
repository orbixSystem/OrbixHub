import 'package:csv/csv.dart';

/// Tabela de um relatório pronta para export: cabeçalhos + linhas (strings) +
/// um título legível (vira o nome do arquivo). Construída na tela a partir do
/// modelo de cada relatório, para que CSV e PDF compartilhem a mesma fonte.
class ReportTable {
  const ReportTable({
    required this.title,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;
}

/// Constrói o conteúdo CSV (cabeçalho + linhas) a partir de uma [ReportTable].
/// Usa `;` como separador (padrão BR p/ Excel) e `\r\n` entre linhas. Função
/// pura e testável — não dispara download.
String buildCsv(ReportTable table) {
  const converter = ListToCsvConverter(
    fieldDelimiter: ';',
    eol: '\r\n',
  );
  return converter.convert(<List<String>>[
    table.headers,
    ...table.rows,
  ]);
}

/// Nome de arquivo seguro derivado do título do relatório (slug + .csv).
String csvFileName(String title) => '${_slug(title)}.csv';

String _slug(String input) {
  final lower = input.toLowerCase();
  final ascii = lower
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll(RegExp('[í]'), 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll(RegExp('[ú]'), 'u')
      .replaceAll('ç', 'c');
  return ascii.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(
        RegExp(r'^-+|-+$'),
        '',
      );
}
