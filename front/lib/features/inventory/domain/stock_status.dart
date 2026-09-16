/// Estado de estoque de um item — regra pura, sem Flutter e sem repositório.
///
/// Existe separada porque **três telas decidem a mesma coisa**: a lista de
/// estoque (chip), o caixa (bloqueia a venda) e o vínculo de item na OS (avisa,
/// mas deixa seguir). Antes, cada uma refazia a conta com um critério ligeiramente
/// diferente; a lista de estoque, por exemplo, não tinha nem o conceito de
/// "esgotado" — item zerado aparecia igualzinho a um item farto.
library;

enum StockStatus {
  /// Item não controla estoque: serviço, ou produto cujo saldo não veio.
  semControle,

  /// Saldo zerado ou negativo. Vender consome estoque na hora e o backend
  /// recusa (`Estoque insuficiente.`) — por isso esgotado é bloqueio no caixa.
  esgotado,

  /// Saldo no mínimo ou abaixo dele (e ainda > 0). Alerta, nunca bloqueio.
  baixo,

  ok,
}

/// Classifica um item a partir dos decimais serializados que a API devolve.
///
/// Mínimo nulo = "nunca considerar baixo" (mesma convenção do backend em
/// `low-stock.ts`); mas mínimo nulo **não** impede o esgotado — saldo zero é
/// zero com ou sem mínimo cadastrado.
StockStatus stockStatusOf({
  required String kind,
  String? currentStock,
  String? minStock,
}) {
  if (kind == 'service') return StockStatus.semControle;
  final qty = double.tryParse((currentStock ?? '').trim());
  if (qty == null) return StockStatus.semControle;
  if (qty <= 0) return StockStatus.esgotado;
  final min = double.tryParse((minStock ?? '').trim());
  if (min != null && qty <= min) return StockStatus.baixo;
  return StockStatus.ok;
}

/// Este item pode sair numa VENDA agora? Só o esgotado não pode — e não é
/// escolha de UI: o backend dá baixa na hora e recusa saldo negativo.
bool podeVender(StockStatus s) => s != StockStatus.esgotado;
