import 'expense_models.dart';
import 'expense_status.dart';

/// Deriva os totais de um mês a partir das contas.
///
/// Online quem soma é o SERVIDOR (ele vê o mês inteiro mesmo se a lista vier
/// paginada). Offline não há quem somar, então derivamos aqui — e por isso a
/// função é pura e testada: totais errados numa tela de contas a pagar levam a
/// decisão errada sobre dinheiro.
///
/// As quatro somas, e por que cada uma é o que é:
///  - **previsto**: o `amount` de TODAS as contas do mês, pagas ou não. É o peso
///    do mês, não o que falta;
///  - **pago**: o que REALMENTE saiu (`paidAmount`), com `amount` como reserva
///    quando a baixa não registrou valor. Juros e desconto fazem o pago divergir
///    do previsto, e o que saiu é o que saiu;
///  - **em aberto**: o `amount` do que não foi pago — é o "quanto ainda devo";
///  - **vencido**: subconjunto do em-aberto que passou do prazo. Some ao em
///    aberto, não é uma quarta fatia independente.
ExpensesMonth totaisDoMes({
  required List<Expense> contas,
  required List<ExpenseCategory> categorias,
  required DateTime hoje,
}) {
  num previsto = 0;
  num pago = 0;
  num emAberto = 0;
  num vencido = 0;

  for (final e in contas) {
    previsto += e.amount;

    if (e.paidAt != null) {
      // Reserva no `amount`: baixa antiga pode não ter gravado `paid_amount`, e
      // somar zero faria o mês parecer não pago.
      pago += e.paidAmount ?? e.amount;
      continue;
    }

    emAberto += e.amount;
    final s = statusDaDespesa(
      dueDate: DateTime.parse(e.dueDate),
      hoje: hoje,
    );
    if (s == ExpenseStatus.vencido) vencido += e.amount;
  }

  return ExpensesMonth(
    items: contas,
    categories: categorias,
    totalPrevisto: previsto,
    totalPago: pago,
    totalEmAberto: emAberto,
    totalVencido: vencido,
  );
}

/// As contas cujo VENCIMENTO cai no mês pedido.
///
/// `due_date` é coluna `date` no banco e chega como meia-noite **UTC**
/// (`2026-08-01T00:00:00.000Z`). Por isso lemos os componentes em UTC, e NUNCA
/// `toLocal()`: em fuso a oeste de UTC (o nosso), converter joga o dia 1º para
/// 31 do mês anterior — uma conta do começo de agosto apareceria em julho, e a
/// de 1º de setembro invadiria agosto. É o mesmo cuidado que
/// `statusDaDespesa` documenta: data é dia civil, não instante.
List<Expense> contasDoMes(
  List<Expense> todas, {
  required int ano,
  required int mes,
}) =>
    todas.where((e) {
      final d = DateTime.tryParse(e.dueDate);
      if (d == null) return false;
      final civil = d.toUtc();
      return civil.year == ano && civil.month == mes;
    }).toList(growable: false);
