import 'dart:typed_data';

/// Identificação da empresa impressa no topo de cada documento gerado (OS,
/// venda, ficha de veículo, relatório).
///
/// Existe em `core/` de propósito: o cabeçalho é o mesmo em todos os documentos,
/// e cada módulo montar o seu levaria a papéis divergentes — nome num, CNPJ
/// noutro. Os dados vêm de Configurações › Empresa em runtime (nunca hardcoded).
class DocumentCompany {
  const DocumentCompany({
    required this.name,
    this.legalName,
    this.cnpj,
    this.inscricaoEstadual,
    this.inscricaoMunicipal,
    this.phone,
    this.email,
    this.website,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.municipio,
    this.uf,
    this.cep,
    this.logo,
  });

  final String name;
  final String? legalName;
  final String? cnpj;
  final String? inscricaoEstadual;
  final String? inscricaoMunicipal;
  final String? phone;
  final String? email;
  final String? website;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? municipio;
  final String? uf;
  final String? cep;

  /// Bytes do logo já baixados. **Nulo é normal**: empresa sem logo, ou falha de
  /// rede. O documento nunca deixa de sair por causa da imagem — sai só com o
  /// texto, que é o que tem valor legal.
  final Uint8List? logo;

  /// "OSCAR ANTONIO DA COSTA, 1659 - CENTRO" — logradouro, número e bairro na
  /// linha que o comprovante usa. Vazio quando não há endereço cadastrado.
  String get enderecoLinha {
    final rua = [
      if (_tem(logradouro)) logradouro!.trim(),
      if (_tem(numero)) numero!.trim(),
    ].join(', ');
    return [
      if (rua.isNotEmpty) rua,
      if (_tem(complemento)) complemento!.trim(),
      if (_tem(bairro)) bairro!.trim(),
    ].join(' - ');
  }

  /// "SAO FRANCISCO - SP   CEP: 15710-000" — município/UF e CEP.
  String get cidadeLinha {
    final cidade = [
      if (_tem(municipio)) municipio!.trim(),
      if (_tem(uf)) uf!.trim(),
    ].join(' - ');
    final cepFmt = _formataCep(cep);
    return [
      if (cidade.isNotEmpty) cidade,
      if (cepFmt.isNotEmpty) 'CEP: $cepFmt',
    ].join('   ');
  }

  /// Linha de documentos: "CNPJ: 33.007.505/0001-37   IE: 638.011.636.111".
  String get documentosLinha => [
        if (_tem(cnpj)) 'CNPJ: ${formataCnpj(cnpj!)}',
        if (_tem(inscricaoEstadual)) 'IE: ${inscricaoEstadual!.trim()}',
      ].join('   ');

  /// "Fone: (17) 9743-7674   E-mail: contato@..." — só o que existe.
  String get contatoLinha => [
        if (_tem(phone)) 'Fone: ${phone!.trim()}',
        if (_tem(email)) 'E-mail: ${email!.trim()}',
      ].join('   ');

  /// Empresa sem NENHUM dado cadastrado além do nome — o cabeçalho fica só com
  /// o nome, e quem gera o documento pode avisar que falta preencher.
  bool get semDadosFiscais =>
      !_tem(cnpj) && !_tem(phone) && !_tem(email) && enderecoLinha.isEmpty;
}

bool _tem(String? s) => s != null && s.trim().isNotEmpty;

/// Monta a partir do bundle de Configurações › Empresa (`/settings`).
///
/// Função pura e tolerante: chave ausente, valor não-string ou vazio caem para
/// `null`. O bundle vem de jsonb livre no servidor — assumir formato aqui faria
/// o documento estourar por causa de um campo mal preenchido.
DocumentCompany companyFromSettings(
  Map<String, dynamic>? bundle, {
  String fallbackName = 'Minha empresa',
  Uint8List? logo,
}) {
  String? s(String key) {
    final v = bundle?[key];
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  // Nome fantasia é o que o cliente reconhece; razão social é o reserva.
  final nome = s('companyName') ?? s('legalName') ?? fallbackName;
  return DocumentCompany(
    name: nome,
    legalName: s('legalName'),
    cnpj: s('taxId'),
    inscricaoEstadual: s('inscricaoEstadual'),
    inscricaoMunicipal: s('inscricaoMunicipal'),
    phone: s('phone'),
    email: s('email'),
    website: s('website'),
    logradouro: s('logradouro'),
    numero: s('numero'),
    complemento: s('complemento'),
    bairro: s('bairro'),
    municipio: s('municipio'),
    uf: s('uf'),
    cep: s('cep'),
    logo: logo,
  );
}

/// Formata CNPJ/CPF por CONTAGEM DE DÍGITOS, devolvendo o original quando não
/// bate com nenhum dos dois. Documento estrangeiro ou meio digitado sai como
/// está, em vez de virar uma máscara errada num papel que o cliente leva.
String formataCnpj(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 14) {
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}'
        '/${d.substring(8, 12)}-${d.substring(12)}';
  }
  if (d.length == 11) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}'
        '-${d.substring(9)}';
  }
  return raw.trim();
}

String _formataCep(String? raw) {
  if (!_tem(raw)) return '';
  final d = raw!.replaceAll(RegExp(r'\D'), '');
  if (d.length != 8) return raw.trim();
  return '${d.substring(0, 5)}-${d.substring(5)}';
}

/// Confere a assinatura (magic bytes) de PNG e JPEG — os formatos que o upload de
/// logo aceita.
///
/// Serve para rejeitar um logo corrompido ANTES de montar a página: o `pdf`
/// estoura ao desenhar bytes que não são imagem, e aí o documento inteiro deixa
/// de sair por causa da figura. Barato de propósito — não valida a imagem toda,
/// só descarta o que claramente não é uma.
bool bytesParecemImagem(Uint8List b) {
  if (b.length < 4) return false;
  final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
  final jpeg = b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
  return png || jpeg;
}
