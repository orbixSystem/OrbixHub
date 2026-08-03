import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/presentation/sales_history.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';

/// Histórico de vendas — "o que vendi, para quem, quando".
///
/// É uma lente DIFERENTE do extrato do caixa: o extrato é o livro-caixa
/// (dinheiro que entrou/saiu, inclusive despesa e sangria), enquanto aqui a
/// unidade é a venda. Uma venda em fiado não move o caixa e por isso nunca
/// apareceria no extrato — mas aparece aqui, que é justamente o ponto.

SaleItem _item(String nome, {String qtd = '1', String preco = '50.00'}) =>
    SaleItem(
      id: 'i-$nome',
      name: nome,
      quantity: qtd,
      unitPrice: preco,
      subtotal: preco,
    );

const _paga = Sale(
  id: 'v1',
  number: 'VND-0001',
  customerName: 'Maria Souza',
  status: 'active',
  total: '270.00',
  paymentStatus: 'pago',
  createdAt: '2026-08-01T13:05:00Z',
  items: [],
);

Widget _tela(List<Sale> vendas) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: SalesHistoryList(sales: vendas)),
        ),
      ),
    );

void main() {
  group('resumoItens — o QUE foi vendido em uma linha', () {
    test('um item sem quantidade redundante', () {
      expect(resumoItens([_item('Alinhamento')]), 'Alinhamento');
    });

    test('quantidade aparece quando > 1, sem casas inúteis', () {
      expect(resumoItens([_item('Óleo 5W30', qtd: '4')]), '4× Óleo 5W30');
      expect(resumoItens([_item('Óleo', qtd: '4.000')]), '4× Óleo');
    });

    test('quantidade fracionada é preservada', () {
      expect(resumoItens([_item('Mão de obra', qtd: '1.5')]), '1.5× Mão de obra');
    });

    test('resume os primeiros e conta o resto', () {
      final r = resumoItens([
        _item('Óleo', qtd: '4'),
        _item('Filtro'),
        _item('Palheta'),
        _item('Aditivo'),
      ]);
      expect(r, '4× Óleo, Filtro, e mais 2');
    });

    test('venda sem itens não inventa texto', () {
      expect(resumoItens(const []), '');
    });
  });

  group('fmtDataHora — o QUANDO', () {
    test('formata dia/mês e hora', () {
      // Fuso local: comparo os componentes, não a string crua.
      final s = fmtDataHora('2026-08-01T13:05:00Z');
      expect(s, isNotNull);
      expect(s, matches(r'^\d{2}/\d{2} \d{2}:\d{2}$'));
    });

    test('sem data devolve null (a linha simplesmente omite)', () {
      expect(fmtDataHora(null), isNull);
      expect(fmtDataHora('nao-e-data'), isNull);
    });
  });

  group('lista de vendas', () {
    testWidgets('mostra para quem, quanto e o que foi vendido', (tester) async {
      await tester.pumpWidget(_tela([
        _paga.copyWith(items: [_item('Óleo 5W30', qtd: '4'), _item('Filtro')]),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Maria Souza'), findsOneWidget);
      expect(find.text('R\$ 270,00'), findsWidgets);
      expect(find.textContaining('4× Óleo 5W30, Filtro'), findsOneWidget);
      expect(find.textContaining('VND-0001'), findsOneWidget);
    });

    testWidgets('venda de balcão sem cliente não parece erro', (tester) async {
      await tester.pumpWidget(_tela([_paga.copyWith(customerName: null)]));
      await tester.pumpAndSettle();

      expect(find.text('Venda no balcão'), findsOneWidget);
    });

    testWidgets('soma o vendido e conta as vendas', (tester) async {
      await tester.pumpWidget(_tela([
        _paga,
        _paga.copyWith(id: 'v2', number: 'VND-0002', total: '130.00'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Vendido'), findsOneWidget);
      expect(find.text('R\$ 400,00'), findsOneWidget); // 270 + 130
      expect(find.text('2'), findsOneWidget);
      expect(find.text('vendas'), findsOneWidget);
    });

    testWidgets('cancelada não entra na soma e aparece marcada', (tester) async {
      await tester.pumpWidget(_tela([
        _paga,
        _paga.copyWith(id: 'v2', number: 'VND-0002', total: '999.00', status: 'canceled'),
      ]));
      await tester.pumpAndSettle();

      // Só a venda ativa soma.
      expect(find.text('R\$ 270,00'), findsWidgets);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.text('canceladas'), findsOneWidget);
    });

    testWidgets('mostra a situação do pagamento (fiado é visível aqui)',
        (tester) async {
      await tester.pumpWidget(_tela([
        _paga.copyWith(paymentStatus: 'a_receber'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('A receber'), findsOneWidget);
    });

    testWidgets('período sem venda ensina o que fazer', (tester) async {
      await tester.pumpWidget(_tela(const []));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma venda no período'), findsOneWidget);
    });
  });

  group('filtros do repositório (fake espelha o backend)', () {
    final vendas = [
      _paga.copyWith(id: 'a', number: 'VND-0001', createdAt: '2026-07-05T10:00:00Z'),
      _paga.copyWith(
          id: 'b',
          number: 'VND-0002',
          customerName: 'João Silva',
          createdAt: '2026-08-02T10:00:00Z'),
    ];

    test('recorta por período', () async {
      final repo = FakeSaleRepository(sales: vendas);
      final julho = await repo.listSales(
        from: '2026-07-01T00:00:00Z',
        to: '2026-07-31T23:59:59Z',
      );
      expect(julho.items.map((s) => s.number), ['VND-0001']);
    });

    test('busca por nome do cliente', () async {
      final repo = FakeSaleRepository(sales: vendas);
      final r = await repo.listSales(q: 'joão');
      expect(r.items.map((s) => s.number), ['VND-0002']);
    });

    test('busca por número da venda', () async {
      final repo = FakeSaleRepository(sales: vendas);
      final r = await repo.listSales(q: 'VND-0001');
      expect(r.items.map((s) => s.id), ['a']);
    });

    test('sem filtro devolve tudo', () async {
      final repo = FakeSaleRepository(sales: vendas);
      expect((await repo.listSales()).items, hasLength(2));
    });
  });
}
