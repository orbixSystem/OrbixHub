import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/inventory/domain/stock_status.dart';

/// A regra é lida por três telas (estoque, caixa, OS) e erra em silêncio: um
/// produto classificado errado não estoura nada — só deixa vender o que não
/// existe, ou bloqueia o que existe.
void main() {
  StockStatus st(String atual, {String? min, String kind = 'product'}) =>
      stockStatusOf(kind: kind, currentStock: atual, minStock: min);

  test('zero e negativo são esgotado — com ou sem mínimo cadastrado', () {
    expect(st('0'), StockStatus.esgotado);
    expect(st('0.000'), StockStatus.esgotado);
    expect(st('-2'), StockStatus.esgotado);
    expect(st('0', min: '5'), StockStatus.esgotado);
  });

  test('esgotado vence baixo: saldo zero não é "quase acabando"', () {
    // Importa porque o caixa BLOQUEIA o esgotado e só AVISA no baixo.
    expect(st('0', min: '10'), StockStatus.esgotado);
    expect(podeVender(st('0', min: '10')), isFalse);
    expect(podeVender(st('1', min: '10')), isTrue);
  });

  test('no mínimo já é baixo (<=, igual ao backend)', () {
    expect(st('5', min: '5'), StockStatus.baixo);
    expect(st('4.9', min: '5'), StockStatus.baixo);
    expect(st('5.1', min: '5'), StockStatus.ok);
  });

  test('sem mínimo, item com saldo é ok — mínimo nulo não vira zero', () {
    expect(st('3'), StockStatus.ok);
  });

  test('serviço nunca controla estoque, mesmo com saldo zero no banco', () {
    // Serviço nasce com current_stock = 0 no backend; tratá-lo como esgotado
    // bloquearia a venda de toda mão de obra.
    expect(st('0', kind: 'service'), StockStatus.semControle);
    expect(podeVender(st('0', kind: 'service')), isTrue);
  });

  test('saldo ausente ou ilegível não inventa estado', () {
    expect(st(''), StockStatus.semControle);
    expect(stockStatusOf(kind: 'product'), StockStatus.semControle);
    expect(st('abc'), StockStatus.semControle);
  });
}
