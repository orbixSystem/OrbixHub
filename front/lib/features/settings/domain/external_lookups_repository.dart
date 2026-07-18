// Consultas a APIs públicas EXTERNAS (não o backend OrbixHub): catálogo CNAE do
// IBGE e busca de endereço por CEP (ViaCEP). Fica atrás de um repository para que
// a UI nunca fale dio direto (regra: UI só fala com repository).

/// Uma subclasse CNAE do IBGE.
class CnaeOption {
  const CnaeOption({required this.id, required this.descricao});
  final String id;
  final String descricao;

  String get label => '$id - $descricao';
}

/// Endereço resolvido a partir de um CEP. Campos podem vir vazios.
class AddressLookup {
  const AddressLookup({
    this.logradouro,
    this.bairro,
    this.municipio,
    this.uf,
    this.complemento,
  });

  final String? logradouro;
  final String? bairro;
  final String? municipio;
  final String? uf;
  final String? complemento;
}

abstract class ExternalLookupsRepository {
  /// Lista completa de subclasses CNAE. Retorna `[]` em caso de falha
  /// (a UI cai no fallback de campo-texto). Resultado é cacheado em memória.
  Future<List<CnaeOption>> cnaeSubclasses();

  /// Resolve um endereço pelo CEP (8 dígitos). Retorna `null` quando o CEP é
  /// inválido, não foi encontrado, ou a consulta falhou.
  Future<AddressLookup?> addressByCep(String cep);
}
