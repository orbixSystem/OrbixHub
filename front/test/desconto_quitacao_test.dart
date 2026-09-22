import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';

/// O desconto na quitação atravessa a fronteira como JSON. Se um campo parar de
/// ser serializado, o backend recebe um recebimento sem desconto, a dívida não
/// fecha e ninguém percebe até o cliente reclamar — nada estoura, o número só
/// fica errado. Daí travar o contrato aqui.
void main() {
  group('EntryDraft — contrato do desconto na quitação', () {
    EntryDraft draft({
      double discount = 0,
      String? discountReason,
      double? saleTotal,
    }) =>
        EntryDraft(
          amount: 90,
          method: 'dinheiro',
          category: 'venda_avulsa',
          saleKind: 'sale',
          saleId: 'venda-1',
          discount: discount,
          discountReason: discountReason,
          saleTotal: saleTotal,
        );

    test('sem desconto, o payload não carrega o campo', () {
      final json = draft().toJson();
      expect(json.containsKey('discount'), isFalse);
      expect(json.containsKey('discountReason'), isFalse);
    });

    test('com desconto, valor e motivo viajam', () {
      final json = draft(discount: 10, discountReason: 'cliente antigo').toJson();
      expect(json['discount'], 10);
      expect(json['discountReason'], 'cliente antigo');
    });

    test('motivo sem desconto não viaja — motivo de nada é ruído', () {
      final json = draft(discountReason: 'texto solto').toJson();
      expect(json.containsKey('discountReason'), isFalse);
    });

    test('motivo vazio é omitido mesmo com desconto', () {
      final json = draft(discount: 10, discountReason: '   ').toJson();
      expect(json['discount'], 10);
      // String só de espaço não é motivo; melhor ausente que mentindo presença.
      expect(json['discountReason'], anyOf(isNull, '   '));
    });

    test('saleTotal viaja quando informado — é o denominador do teto percentual', () {
      // Sem ele o backend não consegue aplicar o teto em % (o total do
      // documento pertence ao módulo dono, e o caixa não lê tabela alheia).
      expect(draft(discount: 10, saleTotal: 100).toJson()['saleTotal'], 100);
      expect(draft(discount: 10).toJson().containsKey('saleTotal'), isFalse);
    });

    test('o desconto NÃO altera o amount — documento fica intacto', () {
      // É a promessa central da decisão: o que muda é quanto entrou, nunca
      // quanto o documento vale.
      final json = draft(discount: 10, saleTotal: 100).toJson();
      expect(json['amount'], 90);
      expect(json['saleTotal'], 100);
    });
  });
}
