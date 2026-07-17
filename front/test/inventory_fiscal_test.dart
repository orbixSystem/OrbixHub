import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/inventory/domain/inventory_models.dart';

void main() {
  test('ItemDraft de produto serializa campos fiscais de produto', () {
    final json = ItemDraft(name: 'Óleo', kind: 'product', ncm: '27101259', cfop: '5102', origem: '0', gtin: '7891234567895').toJson();
    expect(json['ncm'], '27101259');
    expect(json['cfop'], '5102');
    expect(json['origem'], '0');
    expect(json['gtin'], '7891234567895');
  });

  test('ItemDraft de serviço serializa código do serviço e ISS', () {
    final json = ItemDraft(name: 'Troca', kind: 'service', codigoServico: '14.01', aliquotaIss: 5).toJson();
    expect(json['codigoServico'], '14.01');
    expect(json['aliquotaIss'], 5);
  });

  test('InventoryItem lê classificação fiscal do JSON (snake_case)', () {
    final item = InventoryItem.fromJson({
      'id': '1', 'name': 'Óleo', 'kind': 'product',
      'ncm': '27101259', 'cfop': '5102', 'origem': '0', 'gtin': '789',
      'codigo_servico': null, 'aliquota_iss': null,
    });
    expect(item.ncm, '27101259');
    expect(item.cfop, '5102');
  });
}
