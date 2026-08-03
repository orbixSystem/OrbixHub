import '../../sale/domain/sale_models.dart';
import 'cashier_format.dart';

/// "O que foi vendido" em uma linha: os primeiros itens + "e mais N".
///
/// Preferido a mostrar a contagem: "4× Óleo, Filtro" ajuda a reconhecer a venda
/// no histórico, "3 itens" não ajuda em nada.
String resumoItens(List<SaleItem> items, {int mostrar = 2}) {
  if (items.isEmpty) return '';
  final partes = <String>[];
  for (final i in items.take(mostrar)) {
    final q = fmtQuantidade(i.quantity);
    partes.add(q == '1' ? i.name : '$q× ${i.name}');
  }
  final resto = items.length - partes.length;
  if (resto > 0) partes.add('e mais $resto');
  return partes.join(', ');
}
