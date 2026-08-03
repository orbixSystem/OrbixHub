import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/inventory/domain/inventory_models.dart';

/// Contrato do payload de EDIÇÃO de produto.
///
/// O backend valida com `whitelist + forbidNonWhitelisted`, então qualquer chave
/// que o DTO de update não declare derruba a requisição com
/// `property <campo> should not exist`. `UpdateInventoryItemDto` NÃO declara
/// `kind` — o tipo (produto/serviço) é imutável depois de criado.
///
/// Enquanto create e update compartilhavam o mesmo `toJson()`, editar um produto
/// falhava nas duas portas: no PATCH direto (online) e no replay da fila
/// offline — nesse caso a mutação ficava `failed` e aparecia para o usuário na
/// tela "Alterações pendentes".
void main() {
  const draft = ItemDraft(
    name: 'Óleo 5W30',
    kind: 'product',
    sku: 'OL-5W30',
    salePrice: 49.9,
    costPrice: 30,
    currentStock: 12,
    minStock: 2,
    ncm: '27101932',
  );

  group('criação', () {
    test('envia kind (o backend exige no create)', () {
      expect(draft.toJson()['kind'], 'product');
      expect(draft.toJson()['name'], 'Óleo 5W30');
    });
  });

  group('edição', () {
    test('NÃO envia kind — é imutável e o backend rejeita a chave', () {
      expect(draft.toUpdateJson().containsKey('kind'), isFalse);
    });

    test('preserva todos os outros campos editáveis', () {
      final json = draft.toUpdateJson();
      expect(json['name'], 'Óleo 5W30');
      expect(json['sku'], 'OL-5W30');
      expect(json['salePrice'], 49.9);
      expect(json['costPrice'], 30);
      expect(json['currentStock'], 12);
      expect(json['minStock'], 2);
      expect(json['ncm'], '27101932');
    });

    test('difere do create apenas por kind', () {
      final create = draft.toJson()..remove('kind');
      expect(draft.toUpdateJson(), create);
    });

    test('serviço também não vaza kind na edição', () {
      const servico = ItemDraft(
        name: 'Troca de óleo',
        kind: 'service',
        durationMinutes: 30,
        salePrice: 80,
        codigoServico: '14.01',
        aliquotaIss: 5,
      );
      final json = servico.toUpdateJson();
      expect(json.containsKey('kind'), isFalse);
      expect(json['durationMinutes'], 30);
      expect(json['codigoServico'], '14.01');
      expect(json['aliquotaIss'], 5);
    });
  });
}
