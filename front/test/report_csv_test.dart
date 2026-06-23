import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/report/presentation/report_csv.dart';

/// `buildCsv` gera CSV `;`-separado, `\r\n` entre linhas, com cabeçalho + linhas
/// exatamente na ordem dada. `csvFileName` deriva um slug ASCII seguro.
void main() {
  test('buildCsv produz a string esperada (cabeçalho + linhas)', () {
    const table = ReportTable(
      title: 'Faturamento por dia',
      headers: ['Dia', 'OS', 'Receita'],
      rows: [
        ['01/06/2026', '1', 'R\$ 100,00'],
        ['02/06/2026', '2', 'R\$ 200,00'],
        ['TOTAL', '', 'R\$ 300,00'],
      ],
    );

    final csv = buildCsv(table);

    expect(
      csv,
      'Dia;OS;Receita\r\n'
      '01/06/2026;1;R\$ 100,00\r\n'
      '02/06/2026;2;R\$ 200,00\r\n'
      'TOTAL;;R\$ 300,00',
    );
  });

  test('campo com ; é citado conforme RFC', () {
    const table = ReportTable(
      title: 'X',
      headers: ['A', 'B'],
      rows: [
        ['tem;ponto', 'ok'],
      ],
    );
    final csv = buildCsv(table);
    expect(csv, 'A;B\r\n"tem;ponto";ok');
  });

  test('csvFileName gera slug ASCII com .csv', () {
    expect(csvFileName('Rendimento da equipe'), 'rendimento-da-equipe.csv');
    expect(csvFileName('Posição de estoque'), 'posicao-de-estoque.csv');
    expect(csvFileName('OS — Operacional'), 'os-operacional.csv');
  });
}
