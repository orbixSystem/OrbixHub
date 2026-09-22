// Helpers PUROS do Caixa (rótulos PT-BR + formatação) — sem Flutter, testáveis.

const cashierMethods = <String>[
  'pix',
  'dinheiro',
  'cartao_credito',
  'cartao_debito',
  'outro',
];

/// Categorias oferecidas na UI (recebimento de OS é registrado pelo fluxo Receber).
const cashierManualCategories = <String>[
  'venda_avulsa',
  'despesa',
  'sangria',
  'suprimento',
];

String methodLabel(String method) {
  switch (method) {
    case 'pix':
      return 'Pix';
    case 'dinheiro':
      return 'Dinheiro';
    case 'cartao_credito':
      return 'Cartão crédito';
    case 'cartao_debito':
      return 'Cartão débito';
    case 'outro':
    default:
      return 'Outro';
  }
}

String categoryLabel(String category) {
  switch (category) {
    case 'os_payment':
      return 'Recebimento OS';
    case 'venda_avulsa':
      return 'Venda avulsa';
    case 'despesa':
      return 'Despesa';
    case 'sangria':
      return 'Sangria';
    case 'suprimento':
      return 'Suprimento';
    default:
      return category;
  }
}

/// Direção derivada da categoria (espelha a regra do backend): despesa/sangria
/// são saída; o resto é entrada.
bool isOutflowCategory(String category) =>
    category == 'despesa' || category == 'sangria';

/// Parse tolerante de um valor monetário serializado (String/num) para double.
double moneyToDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// Formata em reais (pt-BR simples, sem dependência de intl): "R$ 1.234,56".
String formatMoney(Object? v) {
  final value = moneyToDouble(v);
  final negative = value < 0;
  final cents = value.abs().toStringAsFixed(2);
  final parts = cents.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '${negative ? '-' : ''}R\$ $buf,${parts[1]}';
}

/// Valor para PREENCHER um campo de entrada: só dígitos e vírgula, sem "R$" nem
/// separador de milhar — o que o `DecimalInputFormatter` aceita e o parse do
/// caixa entende (`1234,56`).
String formatAmountForInput(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// Conferência do fechamento: diferença entre o contado e o esperado.
/// Positiva = sobra, negativa = falta, zero = fechou certinho.
double cashDifference({required double counted, required double expected}) =>
    double.parse((counted - expected).toStringAsFixed(2));

/// Rótulo da conferência do caixa — a mesma frase usada durante a digitação e no
/// resultado do fechamento, para não haver duas linguagens para o mesmo fato.
String cashDifferenceLabel(double difference) {
  if (difference == 0) return 'Caixa fechado certinho (sem diferença).';
  return difference > 0
      ? 'Caixa fechado com SOBRA de ${formatMoney(difference)}.'
      : 'Caixa fechado com FALTA de ${formatMoney(difference.abs())}.';
}

/// "03/08 14:32" (hora local), ou null quando não há data — a linha simplesmente
/// omite em vez de mostrar um placeholder.
String? fmtDataHora(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

// ===================== Balanço do Caixa =====================

/// Resultado do cálculo do balanço — função pura, testável sem widget.
///
/// Regras de negócio:
/// - **Recebido**: soma de entries `os_payment` + `venda_avulsa` (não estornadas)
/// - **Saídas**: soma de entries `sangria` (não estornadas) — saque do caixa
/// - **Depósitos**: soma de entries `suprimento` (não estornadas) — dinheiro injetado
/// - **Pendente**: soma dos totais das OS com `paymentStatus` a_receber/parcial
/// - **Saldo**: Recebido + Depósitos - Saídas
class BalanceSummary {
  const BalanceSummary({
    required this.recebido,
    required this.saidas,
    required this.depositos,
    required this.pendente,
  });

  final double recebido;
  final double saidas;
  final double depositos;
  final double pendente;

  double get saldo => recebido + depositos - saidas;
}

/// Calcula o balanço a partir das entries do caixa e OS pendentes.
///
/// [entries] — lançamentos do período (do cashierController ou summary).
/// [pendingOsTotals] — lista de valores (total) das OS pendentes.
///
/// Ignora entries estornadas (`reversedAt != null`).
BalanceSummary computeBalance({
  required Iterable<({String category, String? reversedAt, Object? amount})>
      entries,
  required Iterable<Object?> pendingOsTotals,
}) {
  double recebido = 0;
  double saidas = 0;
  double depositos = 0;

  for (final e in entries) {
    if (e.reversedAt != null) continue; // estornada — não conta
    final v = moneyToDouble(e.amount);
    switch (e.category) {
      case 'os_payment':
      case 'venda_avulsa':
        recebido += v;
      case 'sangria':
        saidas += v;
      case 'suprimento':
        depositos += v;
      case 'despesa':
        saidas += v;
      default:
        break;
    }
  }

  double pendente = 0;
  for (final t in pendingOsTotals) {
    pendente += moneyToDouble(t);
  }

  return BalanceSummary(
    recebido: recebido,
    saidas: saidas,
    depositos: depositos,
    pendente: pendente,
  );
}

/// Quantidade sem casas decimais inúteis ("4" em vez de "4,000").
String fmtQuantidade(String raw) {
  final v = double.tryParse(raw.replaceAll(',', '.'));
  if (v == null) return raw;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
