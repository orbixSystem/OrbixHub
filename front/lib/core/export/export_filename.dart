/// Nome do arquivo de um documento exportado (PDF/CSV).
///
/// Existe por causa de um bug que só aparecia na pasta de Downloads do cliente:
/// os PDFs saíam como `OS-OS-0004.pdf`. O número que o backend gera JÁ vem com
/// o prefixo do documento (`OS-0004`, ver `OsService`), e quatro telas
/// diferentes concatenavam `'OS-'` na frente por conta própria.
///
/// A regra fica num lugar só, e é pura — dá para testar sem UI, que é
/// justamente o que faltava para o bug ter sido pego antes.
library;

/// Monta `<prefixo>-<numero>.<extensão>`, sem repetir o prefixo quando o número
/// já o traz.
///
/// - [number] é higienizado (só letras, dígitos e hífen) porque vira nome de
///   arquivo — barra ou dois-pontos quebrariam o download no Windows.
/// - [fallback] cobre o documento sem número (venda recém-criada, por
///   exemplo); costuma ser um pedaço do id.
/// - A comparação do prefixo ignora caixa: `os-0004` e `OS-0004` contam como
///   já prefixados.
String exportFileName({
  required String prefix,
  required String number,
  String fallback = '',
  String extension = 'pdf',
}) {
  final limpo = _higieniza(number);
  final base = limpo.isNotEmpty ? limpo : _higieniza(fallback);
  if (base.isEmpty) return '$prefix.$extension';

  final jaTemPrefixo =
      base.toLowerCase().startsWith('${prefix.toLowerCase()}-');
  return jaTemPrefixo ? '$base.$extension' : '$prefix-$base.$extension';
}

String _higieniza(String v) =>
    v.trim().replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
