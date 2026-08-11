import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/document_company.dart';
import '../../../core/pdf/pdf_theme.dart';
import '../../cashier/domain/cashier_format.dart';
import '../domain/os_models.dart';
import 'os_status.dart';

/// PDF de uma OS, no MESMO padrão visual do comprovante de venda
/// (`sale_pdf.dart`): cabeçalho da empresa, faixa de identificação, seções em
/// faixa, tabela de itens com zebra, totais alinhados à direita, paginação e
/// linha de assinatura. Antes a OS saía com um layout bem mais simples — o
/// dono pediu para "deixar parelho".
///
/// Função **pura**: não acessa rede. O logo já chega em bytes dentro de
/// [company] (ver `companyForDocumentsProvider`).
Future<Uint8List> buildOsPdf(
  ServiceOrder order,
  PdfPageFormat format, {
  DocumentCompany? company,
}) async {
  final doc = pw.Document();
  final agora = DateTime.now();
  final itens = order.items;

  final qtdTotal = itens.fold<double>(0, (a, i) => a + moneyToDouble(i.quantity));
  final somaItens = itens.fold<double>(0, (a, i) => a + moneyToDouble(i.total));
  final desconto = moneyToDouble(order.discount);
  final total = moneyToDouble(order.total);

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 34),
      // MultiPage: OS com muitas peças/serviços continua na folha seguinte em
      // vez de estourar ou cortar linhas.
      header: (ctx) => ctx.pageNumber == 1 || company == null
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                '${company.name.toUpperCase()}  ·  OS ${order.number}',
                style: const pw.TextStyle(fontSize: 8, color: PdfDocTokens.muted),
              ),
            ),
      footer: (ctx) => _rodape(ctx),
      build: (context) => [
        if (company != null) ...[
          pdfCompanyHeader(company),
          pw.SizedBox(height: 8),
          pw.Container(height: 2, color: PdfDocTokens.brand),
          pw.SizedBox(height: 10),
        ],
        _tituloDocumento(order),
        pw.SizedBox(height: 8),
        _faixaIdentificacao(order, agora),
        pw.SizedBox(height: 6),
        pdfSectionBand('Cliente e veículo'),
        pw.SizedBox(height: 4),
        _blocoClienteVeiculo(order),
        if ((order.complaint ?? '').trim().isNotEmpty ||
            (order.diagnosis ?? '').trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pdfSectionBand('Relato e diagnóstico'),
          pw.SizedBox(height: 4),
          _blocoRelatoDiagnostico(order),
        ],
        pw.SizedBox(height: 8),
        pdfSectionBand('Peças e serviços'),
        _tabelaItens(itens),
        pw.SizedBox(height: 6),
        // Totais à direita, alinhados com a coluna de dinheiro da tabela acima.
        pw.Row(
          children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 232,
              child: _blocoTotais(
                qtdTotal: qtdTotal,
                somaItens: somaItens,
                desconto: desconto,
                total: total,
                paymentStatus: order.paymentStatus,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 22),
        pw.Center(child: pdfSignatureLine('Assinatura do cliente')),
      ],
    ),
  );

  return doc.save();
}

/// Título do documento — igual ao comprovante de venda: nome do documento à
/// esquerda e, se a OS foi cancelada, o selo "CANCELADA" à direita (um
/// documento antigo circulando não pode parecer válido).
pw.Widget _tituloDocumento(ServiceOrder order) {
  final cancelada = order.status == 'cancelada';
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        'ORDEM DE SERVIÇO',
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfDocTokens.graphite,
          letterSpacing: .6,
        ),
      ),
      pw.Spacer(),
      if (cancelada)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfDocTokens.brand, width: 1),
          ),
          child: pw.Text(
            'CANCELADA',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfDocTokens.brand,
              letterSpacing: 1,
            ),
          ),
        )
      else
        // Sem seal (não é irreversível): o status simplificado, no mesmo tom
        // usado na ficha/lista da OS.
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: _pdfSimpleStatusColor(order.status),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            osSimpleStatusLabel(osSimpleStatusOf(order.status)),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
    ],
  );
}

/// Cor do status simplificado, em `PdfColor` (a paleta de `os_status.dart` é
/// `Color` do Flutter — o gerador de PDF fala com `pdf`/`PdfColor`, então o
/// valor ARGB é convertido aqui, sem duplicar a paleta).
PdfColor _pdfSimpleStatusColor(String status) {
  final c = osSimpleStatusColor(osSimpleStatusOf(status));
  return PdfColor.fromInt(c.toARGB32() & 0xFFFFFFFF);
}

/// Faixa "OS Nº / Abertura / Responsável / Emissão", em células com borda —
/// mesmo molde da faixa de identificação do comprovante de venda.
pw.Widget _faixaIdentificacao(ServiceOrder order, DateTime agora) {
  final abertura = DateTime.tryParse(order.createdAt ?? '')?.toLocal();
  final responsavel = (order.assignedToName ?? order.assignedTo ?? '').trim();
  return pw.Table(
    border: pw.TableBorder.all(color: PdfDocTokens.line, width: .5),
    children: [
      pw.TableRow(
        children: [
          _celula('OS Nº:', order.number),
          _celula('Abertura:', abertura == null ? '-' : _data(abertura)),
          if (responsavel.isNotEmpty) _celula('Responsável:', responsavel),
          _celula('Emissão:', _dataHora(agora)),
        ],
      ),
    ],
  );
}

pw.Widget _celula(String rotulo, String valor) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: rotulo,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfDocTokens.graphite,
              ),
            ),
            pw.TextSpan(
              text: valor,
              style: const pw.TextStyle(fontSize: 8, color: PdfDocTokens.graphite),
            ),
          ],
        ),
      ),
    );

pw.Widget _blocoClienteVeiculo(ServiceOrder order) {
  final cliente = (order.customerName ?? '').trim();
  final veiculo = (order.subjectLabel ?? '').trim();
  final previsaoInicio = DateTime.tryParse(order.scheduledStart ?? '')?.toLocal();
  final previsaoFim = DateTime.tryParse(order.scheduledEnd ?? '')?.toLocal();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pdfLabelValue(
        'Cliente:',
        cliente.isEmpty ? 'Não identificado' : cliente,
      ),
      pw.SizedBox(height: 2),
      pdfLabelValue('Veículo:', veiculo),
      if (previsaoInicio != null || previsaoFim != null) ...[
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: pdfLabelValue(
                'Previsão início:',
                previsaoInicio == null ? '' : _data(previsaoInicio),
              ),
            ),
            pw.Expanded(
              flex: 3,
              child: pdfLabelValue(
                'Previsão fim:',
                previsaoFim == null ? '' : _data(previsaoFim),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

pw.Widget _blocoRelatoDiagnostico(ServiceOrder order) {
  final relato = (order.complaint ?? '').trim();
  final diagnostico = (order.diagnosis ?? '').trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (relato.isNotEmpty) pdfLabelValue('Relato:', relato),
      if (relato.isNotEmpty && diagnostico.isNotEmpty) pw.SizedBox(height: 3),
      if (diagnostico.isNotEmpty) pdfLabelValue('Diagnóstico:', diagnostico),
    ],
  );
}

pw.Widget _tabelaItens(List<OrderItem> itens) {
  pw.Widget th(String t, {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfDocTokens.graphite,
          ),
        ),
      );
  pw.Widget td(String t, {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(
          t,
          style: const pw.TextStyle(fontSize: 8, color: PdfDocTokens.graphite),
        ),
      );

  return pw.Table(
    border: pw.TableBorder.all(color: PdfDocTokens.line, width: .5),
    columnWidths: const {
      0: pw.FlexColumnWidth(.55), // item (nº)
      1: pw.FlexColumnWidth(4.4), // descrição
      2: pw.FlexColumnWidth(.8), // un.
      3: pw.FlexColumnWidth(1), // qtde
      4: pw.FlexColumnWidth(1.5), // valor unitário
      5: pw.FlexColumnWidth(1.5), // valor total
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfDocTokens.band),
        children: [
          th('#', align: pw.Alignment.center),
          th('Descrição da peça/serviço'),
          th('Un.', align: pw.Alignment.center),
          th('Qtde', align: pw.Alignment.centerRight),
          th('Valor unitário', align: pw.Alignment.centerRight),
          th('Valor total', align: pw.Alignment.centerRight),
        ],
      ),
      if (itens.isEmpty)
        pw.TableRow(
          children: [
            td(''),
            td('Nenhum item lançado'),
            td(''),
            td(''),
            td(''),
            td(''),
          ],
        )
      else
        for (final (indice, i) in itens.indexed)
          pw.TableRow(
            // Zebra: em lista longa é o que impede o olho de pular de linha ao
            // atravessar a folha até a coluna de valor.
            decoration: indice.isOdd
                ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFAF9F7))
                : null,
            children: [
              td('${indice + 1}', align: pw.Alignment.center),
              td(i.name.isEmpty ? '-' : i.name),
              td(i.kind == 'service' ? 'SERV' : 'UN', align: pw.Alignment.center),
              td(fmtQuantidade(i.quantity), align: pw.Alignment.centerRight),
              td(formatMoney(moneyToDouble(i.unitPrice)),
                  align: pw.Alignment.centerRight),
              td(formatMoney(moneyToDouble(i.total)),
                  align: pw.Alignment.centerRight),
            ],
          ),
    ],
  );
}

pw.Widget _blocoTotais({
  required double qtdTotal,
  required double somaItens,
  required double desconto,
  required double total,
  required String paymentStatus,
}) {
  final linhas = <(String, String)>[
    ('Qtde total de itens', fmtQuantidade(qtdTotal.toString())),
    ('Valor das peças/serviços', formatMoney(somaItens)),
    ('Desconto', formatMoney(desconto)),
    ('Valor total', formatMoney(total)),
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Table(
        border: pw.TableBorder.all(color: PdfDocTokens.line, width: .5),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.4),
          1: pw.FlexColumnWidth(1.4),
        },
        children: [
          for (final (rotulo, valor) in linhas)
            pw.TableRow(
              children: [
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  child: pw.Text(
                    rotulo,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: rotulo == 'Valor total'
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: PdfDocTokens.graphite,
                    ),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  child: pw.Text(
                    valor,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: rotulo == 'Valor total'
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: PdfDocTokens.graphite,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        'Pagamento: ${_paymentStatusLabel(paymentStatus)}',
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfDocTokens.brand,
        ),
      ),
    ],
  );
}

String _paymentStatusLabel(String status) => switch (status) {
      'pago' => 'Pago',
      'parcial' => 'Parcial',
      _ => 'A receber',
    };

String _dois(int n) => n.toString().padLeft(2, '0');
String _data(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year}';
String _dataHora(DateTime d) =>
    '${_data(d)} ${_dois(d.hour)}:${_dois(d.minute)}:${_dois(d.second)}';

/// Rodapé de toda folha: paginação — mesmo molde do comprovante de venda.
pw.Widget _rodape(pw.Context ctx) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfDocTokens.line, width: .5)),
    ),
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Row(
      children: [
        pw.Text(
          'Gerado pelo OrbixHub',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfDocTokens.muted),
        ),
        pw.Spacer(),
        pw.Text(
          'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfDocTokens.muted),
        ),
      ],
    ),
  );
}
