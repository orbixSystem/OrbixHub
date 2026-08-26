import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbixhub_front/core/theme/app_theme.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/cashier/presentation/desconto_selo.dart';

/// O modelo deixa o documento intacto de propósito: a venda continua valendo
/// R$ 100 mesmo tendo entrado R$ 90. Isso só não vira buraco contábil porque a
/// tela DIZ que houve desconto. Se este selo sumir, a conta deixa de fechar aos
/// olhos de quem confere e nada estoura — daí o teste.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> montar(WidgetTester tester, PaymentDetail p) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: DescontoSelo(payment: p)),
        ),
      );

  const semDesconto = PaymentDetail(
    total: 100,
    paid: 100,
    received: 100,
    discount: 0,
    balance: 0,
    status: 'pago',
  );

  const comDesconto = PaymentDetail(
    total: 100,
    paid: 100,
    received: 90,
    discount: 10,
    balance: 0,
    status: 'pago',
  );

  testWidgets('sem desconto o selo não aparece — linha de zero é ruído',
      (tester) async {
    await montar(tester, semDesconto);
    expect(find.textContaining('Desconto concedido'), findsNothing);
  });

  testWidgets('com desconto, mostra o valor concedido', (tester) async {
    await montar(tester, comDesconto);
    expect(find.text('Desconto concedido'), findsOneWidget);
    expect(find.textContaining('10,00'), findsWidgets);
  });

  testWidgets('explica a conta: recebido + desconto = pago, sobre o total',
      (tester) async {
    await montar(tester, comDesconto);
    // Quem confere precisa ver de onde vêm os R$ 10 que não entraram em
    // dinheiro, sem ter de deduzir.
    final texto = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(texto, contains('90,00'));
    expect(texto, contains('10,00'));
    expect(texto, contains('100,00'));
  });

  testWidgets('mostra o motivo quando informado', (tester) async {
    await montar(
      tester,
      comDesconto.copyWith(
        entries: const [
          CashEntry(
            id: 'e1',
            direction: 'in',
            amount: '90',
            method: 'dinheiro',
            category: 'venda_avulsa',
            discount: '10',
            discountReason: 'cliente antigo',
          ),
        ],
      ),
    );
    expect(find.textContaining('cliente antigo'), findsOneWidget);
  });

  testWidgets('lançamento ESTORNADO não empresta seu motivo ao selo',
      (tester) async {
    // Estornar desfaz o desconto; carregar o motivo dele adiante faria a tela
    // justificar um desconto que não existe mais.
    await montar(
      tester,
      comDesconto.copyWith(
        entries: const [
          CashEntry(
            id: 'e1',
            direction: 'in',
            amount: '90',
            method: 'dinheiro',
            category: 'venda_avulsa',
            discount: '10',
            discountReason: 'motivo de lançamento estornado',
            reversedAt: '2026-08-26T10:00:00Z',
          ),
        ],
      ),
    );
    expect(find.textContaining('estornado'), findsNothing);
  });

  test('motivos repetidos aparecem uma vez só', () {
    const e = CashEntry(
      id: 'e',
      direction: 'in',
      amount: '10',
      method: 'pix',
      category: 'venda_avulsa',
      discount: '5',
      discountReason: 'à vista',
    );
    final p = comDesconto.copyWith(entries: [e, e.copyWith(id: 'e2')]);
    expect(DescontoSelo.motivosDe(p), ['à vista']);
  });
}
