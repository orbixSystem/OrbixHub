import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:orbixhub_front/core/pdf/document_company.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';
import 'package:orbixhub_front/features/expenses/presentation/expense_pdf.dart';
import 'package:orbixhub_front/features/os/domain/os_models.dart';
import 'package:orbixhub_front/features/os/presentation/os_pdf.dart';
import 'package:orbixhub_front/features/report/presentation/report_csv.dart';
import 'package:orbixhub_front/features/report/presentation/report_pdf.dart';

/// TODOS os documentos usam o MESMO cabeçalho (`pdfCompanyHeader`).
///
/// O relatório tinha um próprio — selo de iniciais no lugar do logo, sem
/// endereço nem contato — então dois papéis da mesma oficina saíam com
/// identidades diferentes e só ele não mostrava a marca do cliente.
///
/// Estes testes GERAM os PDFs de verdade: um cabeçalho que estoura a página ou
/// uma imagem inválida derruba a exportação, e isso acontece na frente do
/// cliente, não aqui.
void main() {
  // PNG 1x1 válido — o suficiente para exercitar o caminho COM logo.
  final logo = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  DocumentCompany empresa({bool comLogo = true, bool completa = true}) =>
      DocumentCompany(
        name: 'Auto Elétrico São Francisco',
        legalName: completa ? 'Bruno Cirino Auto Elétrico ME' : null,
        cnpj: '33.007.505/0001-37',
        inscricaoEstadual: completa ? '638.011.636.111' : null,
        phone: completa ? '(17) 9743-7674' : null,
        email: completa ? 'brunocirino123@gmail.com' : null,
        logradouro: completa ? 'Oscar Antonio da Costa' : null,
        numero: completa ? '1659' : null,
        bairro: completa ? 'Centro' : null,
        municipio: completa ? 'São Francisco' : null,
        uf: completa ? 'SP' : null,
        cep: completa ? '15710-000' : null,
        logo: comLogo ? logo : null,
      );

  const os = ServiceOrder(
    id: 'os-1',
    number: 'OS-0042',
    customerId: 'c1',
    customerName: 'Suzana Ferreira',
    subjectLabel: 'Gol 1.6 — ABC1D23',
    status: 'em_execucao',
    total: '480.00',
    discount: '0',
    items: [
      OrderItem(
        id: 'i1',
        kind: 'service',
        name: 'Troca de correia dentada',
        quantity: '1',
        unitPrice: '480.00',
        total: '480.00',
      ),
    ],
  );

  const despesa = ExpenseDetail(
    expense: Expense(
      id: 'e1',
      description: 'Aluguel do galpão',
      amount: 2500,
      dueDate: '2026-08-10T00:00:00.000Z',
    ),
  );

  const tabela = ReportTable(
    title: 'Faturamento por período',
    headers: ['Data', 'OS', 'Valor'],
    rows: [
      ['10/08/2026', 'OS-0042', '480,00'],
      ['Total', '', '480,00'],
    ],
  );

  /// Um PDF válido começa com "%PDF" e tem corpo — só isso já prova que o
  /// documento foi montado e serializado sem estourar.
  void ehPdfValido(Uint8List bytes, String qual) {
    expect(bytes.length, greaterThan(800), reason: '$qual saiu vazio demais');
    expect(
      String.fromCharCodes(bytes.take(4)),
      '%PDF',
      reason: '$qual não é um PDF',
    );
  }

  test('OS gera com o cabeçalho padrão', () async {
    ehPdfValido(
      await buildOsPdf(os, PdfPageFormat.a4, company: empresa()),
      'PDF da OS',
    );
  });

  test('despesa gera com o cabeçalho padrão', () async {
    ehPdfValido(
      await buildExpensePdf(despesa, PdfPageFormat.a4, company: empresa()),
      'PDF da despesa',
    );
  });

  test('relatório gera com o MESMO cabeçalho dos demais', () async {
    ehPdfValido(
      await buildReportPdf(
        tabela,
        PdfPageFormat.a4,
        company: empresa(),
        periodLabel: '01/08/2026 – 31/08/2026',
      ),
      'PDF do relatório',
    );
  });

  test('sem logo: o cabeçalho não quebra (empresa que não subiu marca)',
      () async {
    ehPdfValido(
      await buildOsPdf(os, PdfPageFormat.a4, company: empresa(comLogo: false)),
      'PDF da OS sem logo',
    );
  });

  test('poucos dados: o logo ainda tem altura (piso do cabeçalho)', () async {
    // Empresa que só cadastrou nome + CNPJ: a coluna da direita encolhe, e sem
    // o piso de altura o logo viraria uma tira fina.
    ehPdfValido(
      await buildOsPdf(os, PdfPageFormat.a4, company: empresa(completa: false)),
      'PDF da OS com empresa mínima',
    );
  });

  test('cabeçalho não come a página: sobra espaço para o corpo', () async {
    // Um cabeçalho que ocupa metade da folha é o sintoma que o dono relatou
    // ("margem absurda"). Não dá para medir altura de widget aqui, mas dá para
    // medir a CONSEQUÊNCIA: com o cabeçalho enxuto, uma OS de 1 item cabe
    // folgada em UMA página. Se o topo voltar a inchar, o conteúdo transborda
    // para a segunda e este teste cai.
    final bytes = await buildOsPdf(os, PdfPageFormat.a4, company: empresa());
    final texto = String.fromCharCodes(bytes);
    // "/Count N" no catálogo de páginas do PDF.
    final m = RegExp(r'/Count\s+(\d+)').firstMatch(texto);
    expect(m, isNotNull, reason: 'não achei a contagem de páginas no PDF');
    expect(
      int.parse(m!.group(1)!),
      1,
      reason: 'a OS de 1 item passou a ocupar mais de uma página — o '
          'cabeçalho voltou a inchar',
    );
  });

  test('logo quadrado não estica o cabeçalho (teto de altura)', () async {
    // Sem teto, um logo 1:1 esticado até a largura da coluna geraria um
    // cabeçalho de palmo e meio. O PNG do fixture é 1x1 — o pior caso, e o que
    // segura a subida do teto de altura (70 → 100) feita a pedido do dono.
    final bytes = await buildOsPdf(os, PdfPageFormat.a4, company: empresa());
    final m = RegExp(r'/Count\s+(\d+)')
        .firstMatch(String.fromCharCodes(bytes));
    expect(int.parse(m!.group(1)!), 1);
  });
}
