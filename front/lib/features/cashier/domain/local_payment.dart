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
