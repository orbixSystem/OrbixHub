import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import 'document_company.dart';

/// Empresa + logo já baixado, pronta para qualquer gerador de PDF.
///
/// O download do logo acontece AQUI, não dentro do gerador: os builders de PDF
/// são funções puras (nada de rede), o que os deixa testáveis e reutilizáveis.
/// Quem precisa do papel faz `await ref.read(companyForDocumentsProvider.future)`
/// e passa o resultado adiante.
///
/// Falha de rede não impede o documento: o logo cai para `null` e o cabeçalho
/// sai só com o texto — que é a parte que tem valor para o cliente.
final companyForDocumentsProvider = FutureProvider<DocumentCompany>((ref) async {
  final bundle = await ref.watch(settingsControllerProvider.future);
  final company = bundle.company;
  final logoUrl = company['logoUrl'];
  final logo = logoUrl is String && logoUrl.trim().isNotEmpty
      ? await _baixaLogo(ref.read(dioProvider), logoUrl.trim())
      : null;
  return companyFromSettings(company, logo: logo);
});

/// Baixa os bytes do logo. Devolve `null` em qualquer falha — de propósito.
Future<Uint8List?> _baixaLogo(Dio dio, String url) async {
  try {
    final res = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        // O logo é servido pelo módulo `storage` do próprio backend, então o
        // interceptor de Bearer/refresh se aplica. `validateStatus` frouxo evita
        // exceção só para cair no catch abaixo.
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return null;
    final img = Uint8List.fromList(bytes);
    // Valida o FORMATO aqui, não na hora de desenhar: o `pdf` estoura ao montar
    // a página com bytes que não são imagem, e aí o documento inteiro não sai por
    // causa de um upload corrompido. Rejeitando cedo, o papel sai sem o logo.
    return bytesParecemImagem(img) ? img : null;
  } on Object {
    // Sem logo é degradação aceitável; sem documento não é.
    return null;
  }
}
