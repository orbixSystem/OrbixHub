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

/// Cabeçalho padrão de TODOS os documentos: logo à esquerda, identificação da
/// empresa à direita.
///
/// Montado como TABELA de uma linha com `TableCellVerticalAlignment.full`: é o
/// único mecanismo deste pacote que faz as duas células terminarem na mesma
/// altura. O logo então acompanha a altura do bloco de dados, como no
/// comprovante de referência.
///
/// Tentar isso com `Row` + `CrossAxisAlignment.stretch` NÃO funciona aqui: sem
/// altura limitada (o caso dentro de `MultiPage`) o `stretch` pede altura
/// infinita e a geração morre com "height (Infinity) exceed a page height" —
/// derrubando a exportação inteira, não só o cabeçalho.
///
/// A empresa fica alinhada à DIREITA porque é o bloco denso (5–6 linhas) e o
/// logo tem largura variável — alinhar os dois à esquerda deixaria o texto
/// dançando conforme o logo de cada oficina.
pw.Widget pdfCompanyHeader(
  DocumentCompany company, {
  /// Largura da coluna do logo — o número que manda na maioria dos casos reais,
  /// porque marca de oficina costuma ser bem mais larga que alta e bate na
  /// largura antes de chegar no teto de altura.
  ///
  /// O teto vem de MEDIR a fonte embutida (Helvetica), não de chute: a folha A4
  /// útil tem 531pt (595 menos as margens de 32) e as linhas do bloco da
  /// empresa pedem, na pior das medidas reais, ~222pt — a de contato
  /// ("Fone: … E-mail: …"), mais larga que o próprio nome. 531 − 300 = 231pt
  /// de sobra, então a direita continua cabendo em uma linha. Passar muito
  /// disto começa a quebrar o nome da empresa em duas.
  double logoMaxWidth = 300,

  /// Piso de altura: dá presença ao logo quando a empresa cadastrou poucos
  /// dados (2–3 linhas à direita).
  double minHeight = 56,

  /// TETO de altura: sem ele um logo quadrado, esticado até a largura da
  /// coluna, geraria um cabeçalho de palmo e meio e empurraria o corpo do
  /// documento para baixo.
  ///
  /// Segura o caso do logo QUADRADO (ou em pé), que sem teto ocuparia os 300pt
  /// da coluna também em altura e comeria um terço da folha.
  ///
  /// Sobe JUNTO com a largura (200×70 → 300×120) porque senão ele volta a ser o
  /// gargalo: uma marca 2.5:1 esticada a 286pt pede 114pt de altura, e um teto
  /// mais baixo cortaria justamente a largura que o dono pediu.
  double maxHeight = 120,
}) {
  final logo = company.logo;
  final dados = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    mainAxisAlignment: pw.MainAxisAlignment.center,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        company.name.toUpperCase(),
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          // 11pt: o bloco da direita era o mais pesado do cabeçalho e roubava
          // atenção do que o documento diz. Em PAPEL 11pt é nome de empresa
          // em timbrado — o piso de 12px da auditoria SysOne é sobre TELA,
          // outro meio e outra distância de leitura.
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfDocTokens.graphite,
        ),
      ),
      // Razão social só quando difere do fantasia — repetir o mesmo nome em
      // duas linhas só gasta papel.
      if ((company.legalName ?? '').isNotEmpty &&
          company.legalName!.toUpperCase() != company.name.toUpperCase())
        _linha(company.legalName!),
      _linha(company.documentosLinha),
      _linha(company.enderecoLinha),
      _linha(company.cidadeLinha),
      _linha(company.contatoLinha),
      _linha(company.website ?? ''),
    ],
  );

  if (logo == null) {
    return pw.ConstrainedBox(
      constraints: pw.BoxConstraints(minHeight: minHeight),
      child: pw.Row(children: [pw.Expanded(child: dados)]),
    );
  }

  return pw.Table(
    columnWidths: {
      0: pw.FixedColumnWidth(logoMaxWidth),
      1: const pw.FlexColumnWidth(),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
    children: [
      pw.TableRow(
        children: [
          pw.ConstrainedBox(
            // Piso E TETO vivem AQUI: a célula do logo é a que define a altura
            // da linha. Sem o teto, um logo quadrado ocuparia os 200pt da
            // coluna em altura e o cabeçalho comeria um terço da página.
            constraints: pw.BoxConstraints(
              minHeight: minHeight,
              maxHeight: maxHeight,
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(right: 14),
              child: pw.Image(
                pw.MemoryImage(logo),
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.centerLeft,
              ),
            ),
          ),
          dados,
        ],
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
      // 9pt: linha de endereço/contato de timbrado. Encolher a direita libera
      // largura para o logo e baixa a altura do cabeçalho inteiro.
      style: const pw.TextStyle(fontSize: 9, color: PdfDocTokens.muted),
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
          fontSize: 12,
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
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfDocTokens.graphite,
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          // Hífen simples, não travessão: a Helvetica embutida no PDF não
          // desenha U+2014 e o caractere sairia SUMIDO do documento.
          valor.isEmpty ? '-' : valor,
          style: const pw.TextStyle(fontSize: 12, color: PdfDocTokens.graphite),
        ),
      ),
    ],
  );
}

/// Empilha linhas de um bloco com um respiro entre elas.
///
/// Existe para que a regra "campo vazio não aparece no papel" não custe um
/// emaranhado de `if` + `SizedBox` dentro de cada bloco: quem monta devolve só
/// as linhas que tem (`if (x.isNotEmpty) …` na lista) e o espaçamento sai certo
/// sozinho — sem sobrar um vão onde a linha ausente estaria.
pw.Widget pdfStack(List<pw.Widget> linhas, {double gap = 2}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final (i, linha) in linhas.indexed) ...[
        if (i > 0) pw.SizedBox(height: gap),
        linha,
      ],
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
        style: const pw.TextStyle(fontSize: 12, color: PdfDocTokens.muted),
      ),
    ],
  );
}
