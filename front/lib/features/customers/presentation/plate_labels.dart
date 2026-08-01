/// Rótulos PT-BR das chaves cruas do bloco técnico da consulta de placa.
///
/// A API entrega o bloco `extra` com nomes de base de dados
/// (`cap_maxima_tracao`, `tipo_doc_prop`, …) e o conjunto varia por consulta.
/// Em vez de fixar uma lista de campos e perder o resto, exibimos TUDO e só
/// traduzimos o rótulo — chave desconhecida cai no humanizador.
library;

const Map<String, String> _plateFieldLabels = {
  'ano_fabricacao': 'Ano de fabricação',
  'ano_modelo': 'Ano do modelo',
  'caixa_cambio': 'Caixa de câmbio',
  'cap_maxima_tracao': 'Cap. máxima de tração',
  'carroceria': 'Carroceria',
  'chassi': 'Chassi',
  'cilindradas': 'Cilindradas',
  'combustivel': 'Combustível',
  'di': 'DI (declaração de importação)',
  'eixo_traseiro_dif': 'Eixo traseiro / diferencial',
  'eixos': 'Eixos',
  'especie': 'Espécie',
  'faturado': 'Documento do faturado',
  'grupo': 'Grupo',
  'linha': 'Linha',
  'modelo': 'Modelo (registro)',
  'municipio': 'Município',
  'nacionalidade': 'Nacionalidade',
  'peso_bruto_total': 'Peso bruto total',
  'placa': 'Placa',
  'placa_modelo_antigo': 'Placa (modelo antigo)',
  'placa_modelo_novo': 'Placa (Mercosul)',
  'quantidade_passageiro': 'Passageiros',
  'restricao_1': 'Restrição 1',
  'restricao_2': 'Restrição 2',
  'restricao_3': 'Restrição 3',
  'restricao_4': 'Restrição 4',
  's.especie': 'Subespécie',
  'segmento': 'Segmento',
  'situacao_chassi': 'Situação do chassi',
  'situacao_veiculo': 'Situação do veículo',
  'sub_segmento': 'Subsegmento',
  'terceiro_eixo': 'Terceiro eixo',
  'tipo_carroceria': 'Tipo de carroceria',
  'tipo_doc_faturado': 'Tipo do doc. do faturado',
  'tipo_doc_importadora': 'Tipo do doc. da importadora',
  'tipo_doc_prop': 'Tipo do doc. do proprietário',
  'tipo_montagem': 'Tipo de montagem',
  'tipo_veiculo': 'Tipo de veículo',
  'uf': 'UF',
  'uf_faturado': 'UF do faturado',
  'uf_placa': 'UF da placa',
  'unidade_local_srf': 'Unidade local (SRF)',
};

/// Rótulo amigável de uma chave do bloco técnico. Desconhecida →
/// `tipo_doc_prop` vira "Tipo doc prop" (nunca some da ficha).
String plateFieldLabel(String key) {
  final known = _plateFieldLabels[key];
  if (known != null) return known;
  final words = key.replaceAll(RegExp(r'[._]+'), ' ').trim();
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}

/// Chaves do bloco técnico que já aparecem nas seções principais da ficha —
/// omitidas do bloco "dados técnicos" para não repetir a mesma informação.
const Set<String> plateFieldsShownElsewhere = {
  'ano_fabricacao',
  'ano_modelo',
  'chassi',
  'cilindradas',
  'combustivel',
  'especie',
  'municipio',
  'nacionalidade',
  'placa',
  'placa_modelo_antigo',
  'placa_modelo_novo',
  'quantidade_passageiro',
  'sub_segmento',
  'tipo_veiculo',
  'uf',
};

/// Pares (rótulo, valor) do bloco técnico ordenados por rótulo, já sem os
/// campos repetidos nas seções principais.
List<(String, String)> plateTechnicalRows(Map<String, String> extra) {
  final rows = <(String, String)>[
    for (final e in extra.entries)
      if (!plateFieldsShownElsewhere.contains(e.key) && e.value.trim().isNotEmpty)
        (plateFieldLabel(e.key), e.value.trim()),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return rows;
}
