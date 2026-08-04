import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/document_company.dart';
import '../../../core/pdf/pdf_theme.dart';
import '../../cashier/domain/cashier_format.dart' show methodLabel;
import '../domain/expense_models.dart';

/// Ficha de uma conta a pagar em PDF.
///
/// Serve duas situações reais da oficina: levar a conta em aberto para negociar
/// com o fornecedor, e comprovar ao contador que a despesa foi paga — por isso o
/// título muda conforme o estado, em vez de um "relatório" genérico que não serve
/// bem a nenhuma das duas.
///
/// Função **pura**: não acessa rede. O logo chega em bytes dentro de [company]
/// (ver `companyForDocumentsProvider`).
///
/// Cuidado herdado do comprovante de venda: a Helvetica embutida **não desenha
/// travessão** (U+2014) — o caractere sai sumido. Só hífen neste arquivo.
Future<Uint8List> buildExpensePdf(
  ExpenseDetail detalhe,
  PdfPageFormat format, {
  required DocumentCompany company,

  /// Nome da categoria. A conta guarda só o `category_id`, então quem exporta
  /// resolve o nome e passa — o gerador não sai buscando dado por conta própria.
  String? categoria,
  DateTime? emitidoEm,
}) async {
  final doc = pw.Document();
  final e = detalhe.expense;
  final agora = emitidoEm ?? DateTime.now();

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 22),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pdfCompanyHeader(company),
            )
          : pw.SizedBox(),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Documento nao fiscal - controle interno',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfDocTokens.muted,
              ),
            ),
            pw.Text(
              'Pagina ${ctx.pageNumber} de ${ctx.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfDocTokens.muted,
              ),
            ),
          ],
        ),
      ),
      build: (ctx) => [
        pdfSectionBand(
          e.pago ? 'COMPROVANTE DE PAGAMENTO' : 'CONTA A PAGAR',
        ),
        pw.SizedBox(height: 10),
        _bloco('A CONTA', [
          pdfLabelValue('Descricao:', e.description),
          if (categoria != null && categoria.isNotEmpty)
            pdfLabelValue('Categoria:', categoria),
          pdfLabelValue('Vencimento:', _data(e.vencimento)),
          pdfLabelValue(
            'Valor previsto:',
            // "a confirmar" e não "R$ 0,00": zero leria como "nao devo nada".
            e.temValor ? _dinheiro(e.amount) : 'a confirmar',
          ),
          pdfLabelValue('Tipo:', _tipo(detalhe)),
        ]),
        if ((e.supplierName ?? '').isNotEmpty || (e.supplierDoc ?? '').isNotEmpty)
          _bloco('FORNECEDOR', [
            if ((e.supplierName ?? '').isNotEmpty)
              pdfLabelValue('Nome:', e.supplierName!),
            if ((e.supplierDoc ?? '').isNotEmpty)
              pdfLabelValue('CNPJ/CPF:', formataCnpj(e.supplierDoc!)),
          ]),
        if (e.pago)
          _bloco('PAGAMENTO', [
            pdfLabelValue('Pago em:', _data(e.pagoEm!)),
            if ((e.paidMethod ?? '').isNotEmpty)
              pdfLabelValue('Forma:', methodLabel(e.paidMethod!)),
            pdfLabelValue('Valor pago:', _dinheiro(e.valorEfetivo)),
            // Divergência explicada, não escondida: juros e desconto sao a razao
            // mais comum de o pago diferir do previsto, e quem confere precisa
            // ver a diferenca em numero.
            if (e.paidAmount != null && e.paidAmount != e.amount && e.temValor)
              pdfLabelValue(
                'Diferenca:',
                _dinheiro(e.valorEfetivo - e.amount),
              ),
          ]),
        if (detalhe.parcelas.isNotEmpty)
          _bloco('PARCELAMENTO', [
            pdfLabelValue('Parcela:', e.rotuloParcela),
            pdfLabelValue('Total da compra:', _dinheiro(detalhe.totalParcelado)),
            pdfLabelValue(
              'Pagas:',
              '${detalhe.parcelasPagas} de ${detalhe.parcelas.length}',
            ),
          ]),
        if (detalhe.recurrence != null)
          _bloco('DESPESA FIXA', [
            pdfLabelValue(
              'Repeticao:',
              detalhe.recurrence!.frequency == 'yearly'
                  ? 'Todo ano, dia ${detalhe.recurrence!.dayOfMonth}'
                  : 'Todo mes, dia ${detalhe.recurrence!.dayOfMonth}',
            ),
            if (detalhe.recurrence!.endsOn != null)
              pdfLabelValue(
                'Ate:',
                _data(DateTime.parse(detalhe.recurrence!.endsOn!)),
              ),
          ]),
        if ((e.notes ?? '').isNotEmpty)
          _bloco('OBSERVACAO', [pdfLabelValue('', e.notes!)]),
        pw.SizedBox(height: 26),
        pw.Center(child: pdfSignatureLine('Responsavel')),
        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Text(
            'Emitido em ${_data(agora)} as ${_hora(agora)}',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfDocTokens.muted,
            ),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Faixa + linhas de um bloco. Agrupar é o que torna a folha conferível: uma
/// lista corrida de 12 rotulos obriga a ler tudo para achar o valor pago.
pw.Widget _bloco(String titulo, List<pw.Widget> linhas) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pdfSectionBand(titulo),
        pw.SizedBox(height: 6),
        for (final l in linhas)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: l,
          ),
      ],
    ),
  );
}

String _tipo(ExpenseDetail d) {
  if (d.expense.parcelada) {
    return 'Compra parcelada (${d.expense.rotuloParcela})';
  }
  if (d.expense.fixa) return 'Despesa fixa (repete)';
  return 'Despesa unica';
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "R$ 1.234,56" sem depender de intl: o gerador é puro e roda em teste.
String _dinheiro(num v) {
  final negativo = v < 0;
  final texto = v.abs().toStringAsFixed(2);
  final partes = texto.split('.');
  final inteiros = partes[0];
  final buf = StringBuffer();
  for (var i = 0; i < inteiros.length; i++) {
    if (i > 0 && (inteiros.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiros[i]);
  }
  return '${negativo ? '-' : ''}R\$ $buf,${partes[1]}';
}
