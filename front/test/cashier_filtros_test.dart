import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_timeline.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';

/// Filtros e busca do histórico.
///
/// A regra que importa: eles são aplicados no SERVIDOR (e no espelho SQLite
/// quando offline), não sobre a página já carregada — filtrar em memória
/// quebraria a paginação e daria resultado diferente conforme a conexão.
/// A função pura aqui garante a COERÊNCIA entre as duas fontes (vendas vêm de um
/// endpoint, lançamentos de outro), inclusive a regra que o servidor não sabe
/// aplicar sozinho: venda em fiado não é entrada de caixa.

Sale _venda({
  String id = 'v1',
  String? cliente = 'Maria Souza',
  String pagamento = 'pago',
  String total = '100.00',
  String criada = '2026-08-01T10:00:00Z',
  List<SaleItem> itens = const [],
}) =>
    Sale(
      id: id,
      number: 'VND-0001',
      customerName: cliente,
      paymentStatus: pagamento,
      total: total,
      createdAt: criada,
      items: itens,
    );

CashEntry _lanc({
  String id = 'e1',
  String direcao = 'in',
  String categoria = 'os_payment',
  String? descricao,
  String criado = '2026-08-01T11:00:00Z',
}) =>
    CashEntry(
      id: id,
      direction: direcao,
      amount: '50.00',
      method: 'dinheiro',
      category: categoria,
      description: descricao,
      createdAt: criado,
    );

void main() {
  group('filtro por tipo', () {
    final eventos = buildCashierTimeline(
      entries: [
        _lanc(id: 'entrada', direcao: 'in', categoria: 'os_payment'),
        _lanc(id: 'despesa', direcao: 'out', categoria: 'despesa'),
        _lanc(id: 'sangria', direcao: 'out', categoria: 'sangria'),
      ],
      sales: [
        _venda(id: 'paga', pagamento: 'pago'),
        _venda(id: 'fiado', pagamento: 'a_receber'),
      ],
    );

    test('tudo devolve todos', () {
      expect(
        filterCashierTimeline(eventos, filtro: CashierFilter.tudo),
        hasLength(5),
      );
    });

    test('vendas devolve só vendas (pagas e em fiado)', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.vendas);
      expect(r, hasLength(2));
      expect(r.every((e) => e.ehVenda), isTrue);
    });

    test('entradas EXCLUI venda em fiado — nada entrou no caixa', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.entradas);
      expect(r.map((e) => e.id), containsAll(['entry:entrada', 'sale:paga']));
      expect(r.map((e) => e.id), isNot(contains('sale:fiado')));
    });

    test('saídas traz despesa e sangria, sem venda', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.saidas);
      expect(r.map((e) => e.id), ['entry:despesa', 'entry:sangria']);
    });

    test('despesas isola só despesa (sangria não é custo)', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.despesas);
      expect(r.map((e) => e.id), ['entry:despesa']);
    });
  });

  group('busca textual', () {
    final eventos = buildCashierTimeline(
      entries: [
        _lanc(id: 'oleo', categoria: 'despesa', direcao: 'out',
            descricao: 'Óleo do compressor'),
        _lanc(id: 'os', descricao: 'OS-0042 · João Silva'),
      ],
      sales: [
        _venda(id: 'maria', cliente: 'Maria Souza', itens: [
          const SaleItem(
            id: 'i1',
            name: 'Palheta',
            quantity: '2',
            unitPrice: '50.00',
            subtotal: '100.00',
          ),
        ]),
      ],
    );

    test('encontra pelo nome do cliente da venda', () {
      final r = filterCashierTimeline(eventos, busca: 'maria');
      expect(r.map((e) => e.id), ['sale:maria']);
    });

    test('encontra pelo cliente na descrição do recebimento de OS', () {
      final r = filterCashierTimeline(eventos, busca: 'joão');
      expect(r.map((e) => e.id), ['entry:os']);
    });

    test('ignora acento — ninguém digita acento no atendimento', () {
      expect(filterCashierTimeline(eventos, busca: 'joao'), hasLength(1));
      expect(filterCashierTimeline(eventos, busca: 'oleo'), hasLength(1));
      expect(filterCashierTimeline(eventos, busca: 'óleo'), hasLength(1));
    });

    test('ignora caixa', () {
      expect(filterCashierTimeline(eventos, busca: 'MARIA'), hasLength(1));
    });

    test('encontra pelo item vendido', () {
      final r = filterCashierTimeline(eventos, busca: 'palheta');
      expect(r.map((e) => e.id), ['sale:maria']);
    });

    test('busca vazia não filtra', () {
      expect(filterCashierTimeline(eventos, busca: '   '), hasLength(3));
    });

    test('sem resultado devolve vazio (não devolve tudo)', () {
      expect(filterCashierTimeline(eventos, busca: 'inexistente'), isEmpty);
    });
  });

  group('filtro + busca combinados', () {
    test('a busca respeita o filtro de tipo', () {
      final eventos = buildCashierTimeline(
        entries: [
          _lanc(id: 'd', categoria: 'despesa', direcao: 'out',
              descricao: 'Peça para o João'),
        ],
        sales: [_venda(id: 'v', cliente: 'João Silva')],
      );
      // "João" aparece nos dois, mas o filtro restringe a despesa.
      final r = filterCashierTimeline(
        eventos,
        filtro: CashierFilter.despesas,
        busca: 'joão',
      );
      expect(r.map((e) => e.id), ['entry:d']);
    });
  });

  group('rótulos', () {
    test('todos os filtros têm rótulo em pt-BR', () {
      for (final f in CashierFilter.values) {
        expect(cashierFilterLabel(f), isNotEmpty);
      }
      expect(cashierFilterLabel(CashierFilter.despesas), 'Despesas');
    });
  });
}
