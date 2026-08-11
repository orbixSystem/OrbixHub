import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'document_company.dart';

/// Tokens e peças compartilhadas por todos os documentos gerados.
///
/// Um único lugar para a cor, a régua e o cabeçalho: antes cada gerador de PDF
/// repetia as constantes, e mudar a identidade exigia lembrar de quatro arquivos.
class PdfDocTokens {
  const PdfDocTokens._();

  static const brand = PdfColor.fromInt(0xFFEC5E12);
  static const graphite = PdfColor.fromInt(0xFF15171C);
  static const muted = PdfColor.fromInt(0xFF6B7079);
  static const line = PdfColor.fromInt(0xFFE7E4DD);
  /// Fundo das faixas de seção ("Dados do cliente", "Garantia"…).
  static const band = PdfColor.fromInt(0xFFF3F1EC);
}

/// Cabeçalho padrão: logo à esquerda, identificação da empresa à direita.
///
/// Espelha o comprovante de referência. A empresa fica alinhada à DIREITA porque
/// é o bloco denso (5–6 linhas) e o logo tem largura variável — alinhar os dois
/// à esquerda deixaria o texto dançando conforme o logo de cada oficina.
pw.Widget pdfCompanyHeader(
  DocumentCompany company, {
  double logoHeight = 78,
  double logoMaxWidth = 230,
}) {
  final logo = company.logo;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (logo != null)
        pw.ConstrainedBox(
          // Teto nas DUAS dimensões: um logo muito largo (faixa horizontal)
          // empurraria o bloco da empresa para fora da página.
          constraints: pw.BoxConstraints(
            maxHeight: logoHeight,
            maxWidth: logoMaxWidth,
          ),
          child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
        ),
      if (logo != null) pw.SizedBox(width: 14),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              company.name.toUpperCase(),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfDocTokens.graphite,
              ),
            ),
            // Razão social só quando difere do fantasia — repetir o mesmo nome
            // em duas linhas só gasta papel.
            if ((company.legalName ?? '').isNotEmpty &&
                company.legalName!.toUpperCase() != company.name.toUpperCase())
              _linha(company.legalName!),
            _linha(company.documentosLinha),
            _linha(company.enderecoLinha),
            _linha(company.cidadeLinha),
            _linha(company.contatoLinha),
            _linha(company.website ?? ''),
          ],
        ),
      ),
    ],
  );
}

/// Linha do cabeçalho; string vazia não vira espaço em branco.
pw.Widget _linha(String texto) {
  if (texto.trim().isEmpty) return pw.SizedBox();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 1.5),
    child: pw.Text(
      texto,
      textAlign: pw.TextAlign.right,
      style: const pw.TextStyle(fontSize: 8.5, color: PdfDocTokens.muted),
    ),
  );
}

/// Faixa de título de seção ("Dados do cliente", "Discriminação dos produtos"),
/// como no comprovante de referência: centralizada, fundo suave, borda fina.
pw.Widget pdfSectionBand(String titulo) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    decoration: pw.BoxDecoration(
      color: PdfDocTokens.band,
      border: pw.Border.all(color: PdfDocTokens.line, width: .5),
    ),
    child: pw.Center(
      child: pw.Text(
        titulo,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfDocTokens.graphite,
        ),
      ),
    ),
  );
}

/// Par rótulo+valor em linha, do bloco de dados. `flex` distribui a largura
/// quando vários pares dividem a mesma linha.
pw.Widget pdfLabelValue(String rotulo, String valor) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '$rotulo ',
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfDocTokens.graphite,
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          // Hífen simples, não travessão: a Helvetica embutida no PDF não
          // desenha U+2014 e o caractere sairia SUMIDO do documento.
          valor.isEmpty ? '-' : valor,
          style: const pw.TextStyle(fontSize: 8.5, color: PdfDocTokens.graphite),
        ),
      ),
    ],
  );
}

/// Linha de assinatura ("Rubrica") do pé do comprovante.
pw.Widget pdfSignatureLine(String rotulo, {double width = 220}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: width,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfDocTokens.muted, width: .7),
          ),
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        rotulo,
        style: const pw.TextStyle(fontSize: 8, color: PdfDocTokens.muted),
      ),
    ],
  );
}
