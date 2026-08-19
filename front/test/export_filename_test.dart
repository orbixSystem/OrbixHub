import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/export/export_filename.dart';

/// O bug que originou isto: os PDFs de OS chegavam na pasta de Downloads como
/// `OS-OS-0004.pdf`. O backend gera `number` já prefixado (`OS-0004`) e quatro
/// telas colavam `'OS-'` na frente de novo.
void main() {
  group('exportFileName', () {
    test('não repete o prefixo que o número já traz', () {
      expect(
        exportFileName(prefix: 'OS', number: 'OS-0004'),
        'OS-0004.pdf',
      );
    });

    test('adiciona o prefixo quando o número vem só com o sufixo', () {
      // Formato antigo (e o de outros documentos): número puro.
      expect(exportFileName(prefix: 'OS', number: '0004'), 'OS-0004.pdf');
    });

    test('o prefixo já presente é reconhecido sem depender de caixa', () {
      expect(exportFileName(prefix: 'OS', number: 'os-0004'), 'os-0004.pdf');
    });

    test('prefixo diferente do documento não é confundido', () {
      // "venda-15" não começa com "OS-", então ganha o prefixo pedido.
      expect(
        exportFileName(prefix: 'OS', number: 'venda-15'),
        'OS-venda-15.pdf',
      );
    });

    test('higieniza o que não pode virar nome de arquivo', () {
      // Barra e dois-pontos quebram o download no Windows.
      expect(
        exportFileName(prefix: 'venda', number: '15/2026'),
        'venda-152026.pdf',
      );
    });

    test('sem número, cai no fallback', () {
      expect(
        exportFileName(prefix: 'venda', number: '', fallback: 'a1b2c3d4'),
        'venda-a1b2c3d4.pdf',
      );
    });

    test('sem número e sem fallback, ainda devolve algo utilizável', () {
      expect(exportFileName(prefix: 'venda', number: ''), 'venda.pdf');
    });

    test('respeita a extensão pedida', () {
      expect(
        exportFileName(prefix: 'clientes', number: '', extension: 'csv'),
        'clientes.csv',
      );
    });

    test('espaço em volta do número não vira nome torto', () {
      expect(exportFileName(prefix: 'OS', number: '  OS-0007 '), 'OS-0007.pdf');
    });
  });
}
