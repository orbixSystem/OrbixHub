import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_timeline.dart';
import 'package:orbixhub_front/features/receivables/domain/receivables_models.dart';
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
  String status = 'active',
}) =>
    Sale(
      id: id,
      number: 'VND-0001',
      customerName: cliente,
      paymentStatus: pagamento,
      total: total,
      createdAt: criada,
      items: itens,
      status: status,
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

  /// "O que foi desfeito hoje?" era uma pergunta que só se respondia varrendo a
  /// lista à procura do texto riscado.
  group('filtro de canceladas', () {
    final eventos = buildCashierTimeline(
      entries: [
        _lanc(id: 'estornado', direcao: 'out', categoria: 'sangria'),
      ],
      sales: [
        _venda(id: 'ok', pagamento: 'pago'),
        _venda(id: 'morta', pagamento: 'cancelada', status: 'canceled'),
      ],
    );

    test('traz só a venda cancelada', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.canceladas);
      expect(r.map((e) => e.id), ['sale:morta']);
    });

    test('lançamento não entra: desfazer lançamento é estorno, não cancelamento',
        () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.canceladas);
      expect(r.every((e) => e.ehVenda), isTrue);
    });

    test('"Vendas" continua trazendo a cancelada — ela é uma venda', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.vendas);
      expect(r.map((e) => e.id), containsAll(['sale:ok', 'sale:morta']));
    });

    test('venda cancelada não conta como entrada de caixa', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.entradas);
      expect(r.map((e) => e.id), isNot(contains('sale:morta')));
    });

    test('a linha se anuncia como cancelada', () {
      final cancelada =
          eventos.firstWhere((e) => e.id == 'sale:morta');
      expect(cashierEventTitle(cancelada), 'Venda cancelada');
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

  // A lente com que se chega de manhã: "o que falta receber?". Antes ela não
  // existia — e a OS a receber nem aparecia no histórico, só a venda.
  group('filtro "A receber"', () {
    final eventos = buildCashierTimeline(
      entries: [_lanc(id: 'entrada', direcao: 'in', categoria: 'os_payment')],
      sales: [
        _venda(id: 'paga', pagamento: 'pago'),
        _venda(id: 'fiado', pagamento: 'a_receber'),
        _venda(id: 'cancelada', pagamento: 'a_receber', status: 'canceled'),
      ],
      osTitles: const [
        ReceivableTitle(
          id: 'os-1',
          origin: 'os',
          number: 'OS-0002',
          balance: 292,
          total: 292,
          createdAt: '2026-08-01T09:00:00Z',
        ),
      ],
    );

    test('reúne venda em fiado E OS em fiado', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.fiado);
      expect(r.map((e) => e.id), containsAll(['sale:fiado', 'os:os-1']));
      expect(r, hasLength(2));
    });

    test('não traz venda paga, venda cancelada nem lançamento', () {
      final r = filterCashierTimeline(eventos, filtro: CashierFilter.fiado);
      final ids = r.map((e) => e.id);
      expect(ids, isNot(contains('sale:paga')));
      expect(ids, isNot(contains('sale:cancelada')));
      expect(ids, isNot(contains('entry:entrada')));
    });

    test('OS em fiado fica fora das lentes de dinheiro', () {
      // Não é entrada (nada entrou), nem saída, nem despesa — e antes deste
      // desvio essas lentes liam `entry!` num evento sem lançamento.
      for (final f in [
        CashierFilter.entradas,
        CashierFilter.saidas,
        CashierFilter.despesas,
        CashierFilter.vendas,
        CashierFilter.canceladas,
      ]) {
        final r = filterCashierTimeline(eventos, filtro: f);
        expect(r.map((e) => e.id), isNot(contains('os:os-1')), reason: '$f');
      }
    });

    test('a busca alcança o cliente e o número da OS', () {
      final comCliente = buildCashierTimeline(
        entries: const [],
        sales: const [],
        osTitles: const [
          ReceivableTitle(
            id: 'os-1',
            origin: 'os',
            number: 'OS-0002',
            balance: 292,
            customerName: 'Prefeitura Municipal',
          ),
        ],
      );
      expect(
        filterCashierTimeline(comCliente, busca: 'prefeitura'),
        hasLength(1),
      );
      expect(filterCashierTimeline(comCliente, busca: 'OS-0002'), hasLength(1));
    });
  });

  group('rótulos', () {
    test('todos os filtros têm rótulo em pt-BR', () {
      for (final f in CashierFilter.values) {
        expect(cashierFilterLabel(f), isNotEmpty);
      }
      expect(cashierFilterLabel(CashierFilter.despesas), 'Despesas');
      expect(cashierFilterLabel(CashierFilter.fiado), 'A receber');
    });
  });
}
