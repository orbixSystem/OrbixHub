import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_format.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_timeline.dart';
import 'package:orbixhub_front/features/cashier/domain/sale_summary.dart';
import 'package:orbixhub_front/features/cashier/presentation/cashier_timeline_list.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';

/// Histórico do caixa como UMA linha do tempo.
///
/// Antes eram duas lentes (Movimentos | Vendas) e o usuário tinha de escolher —
/// mas o dia é um só, e alternar escondia metade do que aconteceu. Pior: venda em
/// fiado não move o caixa, então nunca aparecia no extrato de lançamentos.
///
/// A regra que mais erra é a deduplicação: uma venda paga gera a venda E o
/// lançamento do recebimento; mostrar os dois faria o mesmo fato aparecer duas
/// vezes no extrato.

SaleItem _item(String nome, {String qtd = '1', String preco = '50.00'}) =>
    SaleItem(
      id: 'i-$nome',
      name: nome,
      quantity: qtd,
      unitPrice: preco,
      subtotal: preco,
    );

Sale _venda({
  String id = 'v1',
  String numero = 'VND-0001',
  String? cliente = 'Maria Souza',
  String status = 'active',
  String pagamento = 'pago',
  String total = '270.00',
  String criada = '2026-08-01T13:00:00Z',
  List<SaleItem> itens = const [],
}) =>
    Sale(
      id: id,
      number: numero,
      customerName: cliente,
      status: status,
      paymentStatus: pagamento,
      total: total,
      createdAt: criada,
      items: itens,
    );

CashEntry _lanc({
  String id = 'e1',
  String direcao = 'in',
  String valor = '270.00',
  String categoria = 'venda_avulsa',
  String? saleKind,
  String? saleId,
  String? descricao,
  String criado = '2026-08-01T13:01:00Z',
  String? estornado,
}) =>
    CashEntry(
      id: id,
      direction: direcao,
      amount: valor,
      method: 'dinheiro',
      category: categoria,
      saleKind: saleKind,
      saleId: saleId,
      description: descricao,
      createdAt: criado,
      reversedAt: estornado,
    );

void main() {
  group('buildCashierTimeline — sem duplicar o mesmo fato', () {
    test('venda paga aparece UMA vez (o recebimento dela não duplica)', () {
      final eventos = buildCashierTimeline(
        entries: [_lanc(saleKind: 'sale', saleId: 'v1')],
        sales: [_venda()],
      );
      expect(eventos, hasLength(1));
      expect(eventos.single.ehVenda, isTrue);
    });

    test('recebimento de venda de OUTRO período continua aparecendo', () {
      // Fiado quitado depois: naquele dia é um fato novo (entrou dinheiro).
      final eventos = buildCashierTimeline(
        entries: [_lanc(saleKind: 'sale', saleId: 'v-antiga')],
        sales: const [],
      );
      expect(eventos, hasLength(1));
      expect(eventos.single.ehVenda, isFalse);
    });

    test('recebimento de OS não é confundido com venda', () {
      final eventos = buildCashierTimeline(
        entries: [_lanc(saleKind: 'os', saleId: 'os-1', categoria: 'os_payment')],
        sales: [_venda()],
      );
      expect(eventos, hasLength(2));
    });

    test('despesa, sangria e suprimento aparecem sempre', () {
      final eventos = buildCashierTimeline(
        entries: [
          _lanc(id: 'a', categoria: 'despesa', direcao: 'out'),
          _lanc(id: 'b', categoria: 'sangria', direcao: 'out'),
          _lanc(id: 'c', categoria: 'suprimento'),
        ],
        sales: const [],
      );
      expect(eventos, hasLength(3));
    });
  });

  group('buildCashierTimeline — venda em fiado', () {
    test('aparece mesmo sem ter movido o caixa', () {
      // Era exatamente o que o extrato de lançamentos escondia.
      final eventos = buildCashierTimeline(
        entries: const [],
        sales: [_venda(pagamento: 'a_receber')],
      );
      expect(eventos, hasLength(1));
      expect(cashierEventTitle(eventos.single), 'Venda em fiado');
    });

    test('venda parcial é rotulada como tal', () {
      final eventos = buildCashierTimeline(
        entries: const [],
        sales: [_venda(pagamento: 'parcial')],
      );
      expect(cashierEventTitle(eventos.single), 'Venda (pago em parte)');
    });

    test('venda cancelada é rotulada como cancelada', () {
      final eventos = buildCashierTimeline(
        entries: const [],
        sales: [_venda(status: 'canceled')],
      );
      expect(cashierEventTitle(eventos.single), 'Venda cancelada');
    });
  });

  group('buildCashierTimeline — ordem', () {
    test('mais recente primeiro, misturando vendas e lançamentos', () {
      final eventos = buildCashierTimeline(
        entries: [
          _lanc(id: 'despesa', categoria: 'despesa', direcao: 'out',
              criado: '2026-08-01T16:00:00Z'),
        ],
        sales: [
          _venda(id: 'manha', criada: '2026-08-01T09:00:00Z'),
          _venda(id: 'tarde', criada: '2026-08-01T18:00:00Z'),
        ],
      );
      expect(
        eventos.map((e) => e.id),
        ['sale:tarde', 'entry:despesa', 'sale:manha'],
      );
    });

    test('sem data não quebra a ordenação', () {
      final eventos = buildCashierTimeline(
        entries: const [],
        sales: [_venda(id: 'x', criada: 'invalido')],
      );
      expect(eventos, hasLength(1));
    });
  });

  group('movimento de caixa', () {
    test('só lançamento tem sinal (+/−); venda não', () {
      final venda = CashierEvent.venda(_venda());
      final lanc = CashierEvent.lancamento(_lanc());
      expect(cashierEventTemMovimento(venda), isFalse);
      expect(cashierEventTemMovimento(lanc), isTrue);
    });
  });

  group('resumoItens — o QUE foi vendido', () {
    test('sem quantidade redundante', () {
      expect(resumoItens([_item('Alinhamento')]), 'Alinhamento');
    });

    test('quantidade aparece quando > 1, sem casas inúteis', () {
      expect(resumoItens([_item('Óleo', qtd: '4.000')]), '4× Óleo');
    });

    test('fração preservada', () {
      expect(resumoItens([_item('Mão de obra', qtd: '1.5')]), '1.5× Mão de obra');
    });

    test('resume e conta o resto', () {
      expect(
        resumoItens([_item('A'), _item('B'), _item('C'), _item('D')]),
        'A, B, e mais 2',
      );
    });

    test('sem itens não inventa texto', () {
      expect(resumoItens(const []), '');
    });
  });

  group('fmtDataHora', () {
    test('dia/mês hora:min', () {
      expect(fmtDataHora('2026-08-01T13:05:00Z'),
          matches(r'^\d{2}/\d{2} \d{2}:\d{2}$'));
    });

    test('sem data devolve null', () {
      expect(fmtDataHora(null), isNull);
      expect(fmtDataHora('xxx'), isNull);
    });
  });

  group('a lista renderiza tudo numa só', () {
    Widget app(List<CashierEvent> eventos) => ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CashierTimelineList(events: eventos),
              ),
            ),
          ),
        );

    testWidgets('venda mostra cliente, itens e situação do pagamento',
        (tester) async {
      await tester.pumpWidget(app(buildCashierTimeline(
        entries: const [],
        sales: [
          _venda(
            pagamento: 'a_receber',
            itens: [_item('Óleo 5W30', qtd: '4'), _item('Filtro')],
          ),
        ],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Venda em fiado'), findsOneWidget);
      expect(find.textContaining('Maria Souza'), findsOneWidget);
      expect(find.textContaining('4× Óleo 5W30, Filtro'), findsOneWidget);
      expect(find.text('A receber'), findsOneWidget);
      expect(find.text('R\$ 270,00'), findsOneWidget);
    });

    testWidgets('despesa aparece com sinal negativo e descrição',
        (tester) async {
      await tester.pumpWidget(app(buildCashierTimeline(
        entries: [
          _lanc(
            categoria: 'despesa',
            direcao: 'out',
            valor: '80.00',
            descricao: 'Café e material de limpeza',
          ),
        ],
        sales: const [],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Despesa'), findsOneWidget);
      expect(find.text('− R\$ 80,00'), findsOneWidget);
      expect(find.textContaining('Café e material de limpeza'), findsOneWidget);
    });

    testWidgets('estornado aparece marcado, não desaparece', (tester) async {
      await tester.pumpWidget(app(buildCashierTimeline(
        entries: [_lanc(estornado: '2026-08-01T15:00:00Z')],
        sales: const [],
      )));
      await tester.pumpAndSettle();

      expect(find.text('Estornado'), findsOneWidget);
    });

    testWidgets('venda e despesa convivem na mesma lista', (tester) async {
      await tester.pumpWidget(app(buildCashierTimeline(
        entries: [
          _lanc(id: 'd', categoria: 'despesa', direcao: 'out', valor: '30.00'),
        ],
        sales: [_venda(pagamento: 'a_receber')],
      )));
      await tester.pumpAndSettle();

      // Sem abas: os dois tipos visíveis ao mesmo tempo.
      expect(find.text('Venda em fiado'), findsOneWidget);
      expect(find.text('Despesa'), findsOneWidget);
    });

    testWidgets('período vazio explica o que apareceria', (tester) async {
      await tester.pumpWidget(app(const []));
      await tester.pumpAndSettle();
      expect(find.text('Nada aconteceu no período'), findsOneWidget);
    });
  });
}
