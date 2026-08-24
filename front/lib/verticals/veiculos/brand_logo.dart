/// URL best-effort do logo de uma marca de carro, no mesmo dataset/slug que o
/// backend usa nas opções de autocomplete (`brandLogoUrl` em fipe.client.ts).
/// Casca de carro, camada de apresentação — o que não casar cai num ícone no
/// widget que renderiza. Retorna null para nome vazio.
library;

const Map<String, String> _accentFolds = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'š': 's', 'ž': 'z', 'ý': 'y',
};

String? brandLogoUrl(String? name) {
  final raw = name?.trim();
  if (raw == null || raw.isEmpty) return null;
  // FIPE manda nomes tipo "VW - VolksWagen" / "GM - Chevrolet": pega o que vem
  // depois do " - ".
  final base = raw.contains(' - ') ? raw.split(' - ').last : raw;
  final folded = base
      .toLowerCase()
      .split('')
      .map((c) => _accentFolds[c] ?? c)
      .join();
  final slug = folded
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return null;
  return 'https://raw.githubusercontent.com/filippofilip95/car-logos-dataset/master/logos/thumb/$slug.png';
}
