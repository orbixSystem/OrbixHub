import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/external_lookups_repository.dart';

/// Impl com Dio próprio (sem o interceptor de auth da app — estas APIs são
/// públicas e externas ao backend OrbixHub). As subclasses CNAE são cacheadas
/// em memória (carrega uma vez por sessão); falhas degradam graciosamente.
class ExternalLookupsRepositoryImpl implements ExternalLookupsRepository {
  ExternalLookupsRepositoryImpl();

  static const _cnaeUrl =
      'https://servicodados.ibge.gov.br/api/v2/cnae/subclasses';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  /// Cache em memória das subclasses CNAE. `null` = ainda não carregado.
  List<CnaeOption>? _cnaeCache;
  Future<List<CnaeOption>>? _cnaeInFlight;

  @override
  Future<List<CnaeOption>> cnaeSubclasses() {
    final cached = _cnaeCache;
    if (cached != null) return Future.value(cached);
    // Coalesce concurrent callers onto a single in-flight request.
    return _cnaeInFlight ??= _fetchCnaes().then((list) {
      _cnaeCache = list;
      _cnaeInFlight = null;
      return list;
    });
  }

  Future<List<CnaeOption>> _fetchCnaes() async {
    try {
      final resp = await _dio.get<String>(_cnaeUrl);
      if (resp.statusCode == 200 && resp.data != null) {
        final raw = jsonDecode(resp.data!) as List<dynamic>;
        return raw
            .map((e) => CnaeOption(
                  id: (e['id'] as dynamic)?.toString() ?? '',
                  descricao: (e['descricao'] as String?) ?? '',
                ))
            .where((e) => e.id.isNotEmpty)
            .toList();
      }
      return const [];
    } catch (_) {
      // Falha → lista vazia (a UI usa fallback de texto livre).
      return const [];
    }
  }

  @override
  Future<AddressLookup?> addressByCep(String cep) async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return null;
    try {
      final resp =
          await _dio.get<String>('https://viacep.com.br/ws/$digits/json/');
      if (resp.statusCode != 200 || resp.data == null) return null;
      final data = jsonDecode(resp.data!) as Map<String, dynamic>;
      if (data['erro'] == true || data['erro'] == 'true') return null;
      return AddressLookup(
        logradouro: data['logradouro'] as String?,
        bairro: data['bairro'] as String?,
        municipio: data['localidade'] as String?,
        uf: data['uf'] as String?,
        complemento: data['complemento'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
