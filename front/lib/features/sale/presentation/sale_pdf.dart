import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/document_company.dart';
import '../../../core/pdf/pdf_theme.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../customers/domain/customers_models.dart';
import '../domain/sale_models.dart';

/// Dados do comprovante que NÃO vivem na venda.
///
/// A venda guarda só `customer_id` + o nome (snapshot). Documento/telefone/
/// endereço são do cliente e podem ter mudado — quem exporta busca a ficha
/// atual e passa aqui, em vez de o gerador sair pedindo dados por conta própria.
class SaleReceiptExtras {
  const SaleReceiptExtras({this.customer, this.vendedor, this.pagamentos});

  /// Ficha do cliente (para CNPJ/telefone/endereço). Nula em venda sem cliente.
  final Customer? customer;

  /// Quem vendeu. Nulo quando o nome não pôde ser resolvido — melhor omitir a
  /// linha do que estampar um uuid ou, pior, quem está exportando agora.
  final String? vendedor;

  /// Formas de pagamento recebidas: rótulo → valor. Vazio = venda em aberto.
  final List<({String label, double valor})>? pagamentos;
}

/// Comprovante de venda em PDF, no formato que o balcão brasileiro reconhece:
/// cabeçalho da empresa, faixa de identificação, dados do cliente, discriminação
/// dos produtos, totais, garantia, forma de pagamento e rubrica.
///
/// Função **pura**: não acessa rede. O logo já chega em bytes dentro de
/// [company] (ver `companyForDocumentsProvider`).
Future<Uint8List> buildSalePdf(
  Sale sale,
  PdfPageFormat format, {
  required DocumentCompany company,
  SaleReceiptExtras extras = const SaleReceiptExtras(),
  DateTime? emitidoEm,
}) async {
  final doc = pw.Document();
  final agora = emitidoEm ?? DateTime.now();
  final cliente = extras.customer;

  final itens = sale.items;
  final qtdTotal = itens.fold<double>(
    0,
    (a, i) => a + moneyToDouble(i.quantity),
  );
  final somaItens = itens.fold<double>(
    0,
    (a, i) => a + moneyToDouble(i.subtotal),
  );
  final desconto = moneyToDouble(sale.discount);
  final total = moneyToDouble(sale.total);
  final pagos = extras.pagamentos ?? const [];
  final recebido = pagos.fold<double>(0, (a, p) => a + p.valor);

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
      // MultiPage (e não Page): venda com muitos itens tem de continuar na folha
      // seguinte em vez de estourar ou cortar linhas.
      build: (context) => [
        pdfCompanyHeader(company),
        pw.SizedBox(height: 10),
        _faixaIdentificacao(sale, agora, extras.vendedor),
        pw.SizedBox(height: 6),
        pdfSectionBand('Dados do cliente'),
        pw.SizedBox(height: 4),
        _blocoCliente(sale, cliente),
        pw.SizedBox(height: 8),
        pdfSectionBand('Discriminação dos produtos'),
        _tabelaItens(itens),
        pw.SizedBox(height: 6),
        // Totais à direita, como no comprovante: a coluna de valores fica
        // alinhada com a da tabela acima.
        pw.Row(
          children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 250,
              child: _blocoTotais(
                qtdTotal: qtdTotal,
                somaItens: somaItens,
                desconto: desconto,
                total: total,
                recebido: recebido,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pdfSectionBand('Garantia'),
        pw.SizedBox(height: 3),
        pw.Text(
          'Produto: [ ] 1 Mês   [ ] 3 Meses   [ ] 6 Meses   [ ] 9 Meses   [ ] 12 Meses',
          style: const pw.TextStyle(fontSize: 8.5, color: PdfDocTokens.graphite),
        ),
        pw.SizedBox(height: 8),
        pdfSectionBand('Forma de pagamento'),
        pw.SizedBox(height: 3),
        _blocoPagamento(pagos, total: total, recebido: recebido),
        pw.SizedBox(height: 22),
        pw.Center(child: pdfSignatureLine('Rubrica')),
      ],
    ),
  );
  return doc.save();
}

/// Faixa "Venda Nº / Data / Vendedor / Emissão" em células com borda.
pw.Widget _faixaIdentificacao(Sale sale, DateTime agora, String? vendedor) {
  final criada = DateTime.tryParse(sale.createdAt ?? '')?.toLocal();
  return pw.Table(
    border: pw.TableBorder.all(color: PdfDocTokens.line, width: .5),
    children: [
      pw.TableRow(
        children: [
          _celula('Venda Nº:', sale.number.isEmpty ? '-' : sale.number),
          _celula('Data da emissão:', _data(criada ?? agora)),
          // Vendedor omitido quando não resolvido: um campo em branco é honesto,
          // um nome errado num comprovante não.
          if (vendedor != null && vendedor.trim().isNotEmpty)
            _celula('Vendedor:', vendedor.trim()),
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
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfDocTokens.graphite,
              ),
            ),
          ],
        ),
      ),
    );

pw.Widget _blocoCliente(Sale sale, Customer? c) {
  final nome = (c?.name ?? sale.customerName ?? '').trim();
  final endereco = (c?.address ?? '').trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pdfLabelValue(
        'Cliente:',
        nome.isEmpty ? 'Consumidor não identificado' : nome,
      ),
      pw.SizedBox(height: 2),
      pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pdfLabelValue(
              c?.type == 'PJ' ? 'CNPJ:' : 'CPF/CNPJ:',
              (c?.document ?? '').trim().isEmpty
                  ? ''
                  : formataCnpj(c!.document!),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pdfLabelValue('Telefone:', (c?.phone ?? '').trim()),
          ),
        ],
      ),
      if (endereco.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pdfLabelValue('Endereço:', endereco),
      ],
      if ((c?.email ?? '').trim().isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pdfLabelValue('E-mail:', c!.email!.trim()),
      ],
    ],
  );
}

pw.Widget _tabelaItens(List<SaleItem> itens) {
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
      0: pw.FlexColumnWidth(4.4), // descrição
      1: pw.FlexColumnWidth(.8), // un.
      2: pw.FlexColumnWidth(1), // qtde
      3: pw.FlexColumnWidth(1.5), // valor unitário
      4: pw.FlexColumnWidth(1.5), // valor total
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfDocTokens.band),
        children: [
          th('Descrição do produto/serviço'),
          th('Un.', align: pw.Alignment.center),
          th('Qtde', align: pw.Alignment.centerRight),
          th('Valor unitário', align: pw.Alignment.centerRight),
          th('Valor total', align: pw.Alignment.centerRight),
        ],
      ),
      for (final i in itens)
        pw.TableRow(
          children: [
            td(i.name.isEmpty ? '-' : i.name),
            // Serviço não tem unidade de estoque; produto sai como "UN".
            td(i.kind == 'service' ? 'SERV' : 'UN', align: pw.Alignment.center),
            td(fmtQuantidade(i.quantity), align: pw.Alignment.centerRight),
            td(formatMoney(moneyToDouble(i.unitPrice)),
                align: pw.Alignment.centerRight),
            td(formatMoney(moneyToDouble(i.subtotal)),
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
  required double recebido,
}) {
  // Troco só quando recebeu MAIS que o total (dinheiro). Pagamento parcial é
  // fiado, não troco negativo — mostrar "-50" aqui confundiria o balcão.
  final troco = recebido > total ? recebido - total : 0.0;
  final linhas = <(String, String)>[
    ('Qtde total de itens', fmtQuantidade(qtdTotal.toString())),
    ('Valor dos produtos', formatMoney(somaItens)),
    ('Valor total desconto', formatMoney(desconto)),
    ('Valor total', formatMoney(total)),
    ('Valor troco', formatMoney(troco)),
  ];
  return pw.Table(
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
              child: pw.Text(
                rotulo,
                style: pw.TextStyle(
                  fontSize: 8,
                  // "Valor total" é o que o cliente confere primeiro.
                  fontWeight: rotulo == 'Valor total'
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: PdfDocTokens.graphite,
                ),
              ),
            ),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
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
  );
}

pw.Widget _blocoPagamento(
  List<({String label, double valor})> pagos, {
  required double total,
  required double recebido,
}) {
  if (pagos.isEmpty) {
    return pw.Text(
      'Em aberto - nenhum recebimento lancado no caixa.',
      style: const pw.TextStyle(fontSize: 8.5, color: PdfDocTokens.muted),
    );
  }
  // Falta = fiado. Sai explícito no comprovante para o cliente levar por escrito
  // quanto ainda deve — é a informação que gera discussão depois.
  final falta = total - recebido;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Table(
        border: pw.TableBorder.all(color: PdfDocTokens.line, width: .5),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1.4),
        },
        children: [
          for (final p in pagos)
            pw.TableRow(
              children: [
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  child: pw.Text(
                    p.label,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfDocTokens.graphite,
                    ),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
                  child: pw.Text(
                    formatMoney(p.valor),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfDocTokens.graphite,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      if (falta > 0.005) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          'Saldo a receber (fiado): ${formatMoney(falta)}',
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfDocTokens.brand,
          ),
        ),
      ],
    ],
  );
}

String _dois(int n) => n.toString().padLeft(2, '0');
String _data(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year}';
String _dataHora(DateTime d) =>
    '${_data(d)} ${_dois(d.hour)}:${_dois(d.minute)}:${_dois(d.second)}';
