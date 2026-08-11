/// Pagamento DERIVADO do espelho local — o equivalente offline de
/// `sumPaidForSales` + `derivePaymentStatus` (back/src/modules/cashier).
///
/// Nem a OS nem a venda guardam quanto já foi pago: isso é sempre somado dos
/// lançamentos do caixa. Online o servidor soma; offline somamos aqui, das
/// MESMAS linhas espelhadas. Por isso esta regra vive num lugar só — a carteira
/// de fiado e o histórico de vendas precisam concordar entre si e com o servidor.
library;

/// Um centavo de tolerância — o mesmo `EPS` do backend.
const paymentEps = 0.005;

/// Σ recebido por título (id de OS **ou** de venda), a partir dos `cash_entry`
/// espelhados.
///
/// Espelha `sumPaidForSales`: entradas (`direction: 'in'`) NÃO estornadas,
/// agrupadas por `sale_id`. Deliberadamente **não** filtra por `sale_kind`,
/// porque o servidor também não filtra — quem separa OS de venda é a tabela em
/// que o id é procurado, não o rótulo do lançamento. Ser mais estrito aqui faria
/// o app mostrar dívida sem internet que desaparece com internet, e uma carteira
/// que muda conforme a conexão é pior que uma carteira imperfeita.
Map<String, double> paidByTitleFrom(List<Map<String, dynamic>> cashEntries) {
  final pago = <String, double>{};
  for (final e in cashEntries) {
    if (e['direction'] != 'in') continue;
    if (e['reversed_at'] != null) continue; // estorno: o dinheiro não entrou
    final id = e['sale_id'] as String?;
    if (id == null) continue;
    pago[id] = (pago[id] ?? 0) + _toDouble(e['amount']);
  }
  return pago;
}

/// `a_receber` | `parcial` | `pago` — mesma régua (e mesma ordem de testes) do
/// `derivePaymentStatus` do backend.
String derivePaymentStatusLocal(num total, num paid) {
  if (paid <= paymentEps) return 'a_receber';
  if (paid + paymentEps >= total) return 'pago';
  return 'parcial';
}

/// Arredonda a centavos como o backend, para a aritmética em double não acumular
/// deriva de centavo entre cliente e servidor.
double round2Money(num v) => (v * 100).roundToDouble() / 100;

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Uma parcela calculada localmente (para criar o plano offline).
class InstallmentScheduleItem {
  const InstallmentScheduleItem({required this.amount, required this.dueDate});
  final double amount;
  final DateTime dueDate;
}

/// Espelha `createInstallmentPlan`/`nextOccurrenceOfDay` do backend: divide o
/// total igualmente entre as parcelas (ajuste de centavo na ÚLTIMA) e calcula
/// os vencimentos mensais a partir de [firstDueDate] (ou da próxima ocorrência
/// de [dueDayOfMonth]). Usado SÓ offline — online o servidor já faz essa
/// conta; aqui é só pra dar ao cliente uma PRÉVIA correta do plano sem rede.
///
/// Sem clamp de dia-no-mês: `dueDayOfMonth` é limitado a 1–28 na validação
/// (mesmo limite do backend), então todo mês tem esse dia — não há fevereiro
/// sem dia 30 pra se preocupar.
List<InstallmentScheduleItem> computeInstallmentSchedule({
  required double totalAmount,
  required int installmentCount,
  required int dueDayOfMonth,
  DateTime? firstDueDate,
  DateTime? now,
}) {
  final base = round2Money(totalAmount / installmentCount);
  final last = round2Money(totalAmount - base * (installmentCount - 1));

  var current = firstDueDate ?? _nextOccurrenceOfDay(dueDayOfMonth, now ?? DateTime.now());
  final items = <InstallmentScheduleItem>[];
  for (var i = 0; i < installmentCount; i++) {
    items.add(InstallmentScheduleItem(
      amount: i == installmentCount - 1 ? last : base,
      dueDate: current,
    ));
    current = DateTime(current.year, current.month + 1, dueDayOfMonth);
  }
  return items;
}

/// Próxima ocorrência de [day] a partir de [now] (estritamente depois — meia-
/// noite de hoje quase nunca é "depois" do instante atual, então "hoje" na
/// prática só é escolhido se [now] for exatamente meia-noite).
DateTime _nextOccurrenceOfDay(int day, DateTime now) {
  final candidate = DateTime(now.year, now.month, day);
  if (!candidate.isAfter(now)) {
    return DateTime(now.year, now.month + 1, day);
  }
  return candidate;
}
