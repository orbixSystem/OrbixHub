import 'expense_models.dart';

/// Quando a conta vai ser cobrada DE NOVO.
///
/// Pedido do dono: ao marcar uma despesa como paga, dizer qual é a próxima data —
/// senão dar baixa parece encerrar o assunto, quando na verdade o aluguel volta no
/// mês que vem.
///
/// Tudo aqui é PURO e recebe `hoje`/a regra por parâmetro: é conta de calendário,
/// o tipo de código que erra em fevereiro e na virada de ano, e teste barato é a
/// única forma honesta de garantir.

/// Último dia do mês (1..12) — resolve fevereiro e ano bissexto.
///
/// Dia 0 do mês seguinte é o último deste. `DateTime.utc` porque vencimento é dia
/// civil: em fuso a oeste, o construtor local empurraria a data um dia para trás.
int ultimoDiaDoMes(int ano, int mes) => DateTime.utc(ano, mes + 1, 0).day;

/// Data de uma ocorrência mensal, com o dia PEDIDO encurtando em mês curto.
///
/// "Todo dia 31" cai em 28/02 (29 em bissexto), nunca transborda para 03/03 —
/// transbordar faria a conta de fevereiro aparecer em março e desaparecer do mês
/// em que é devida. Espelha `dataDaOcorrencia` do backend.
DateTime dataDaOcorrencia(int ano, int mes, int diaPedido) {
  final ultimo = ultimoDiaDoMes(ano, mes);
  return DateTime.utc(ano, mes, diaPedido > ultimo ? ultimo : diaPedido);
}

/// A próxima ocorrência de [regra] DEPOIS de [depoisDe].
///
/// `null` quando a regra já terminou (`endsOn` no passado) ou está desativada —
/// nesse caso não existe "próxima", e mostrar uma data inventada seria pior que
/// não mostrar nada.
DateTime? proximaOcorrencia(
  ExpenseRecurrence regra, {
  required DateTime depoisDe,
}) {
  if (!regra.ativa) return null;

  final base = DateTime.utc(depoisDe.year, depoisDe.month, depoisDe.day);
  final fim = regra.endsOn == null ? null : DateTime.tryParse(regra.endsOn!);

  final candidata = switch (regra.frequency) {
    // Anual: mesmo mês do ano seguinte se a deste ano já passou.
    'yearly' => _proximaAnual(regra, base),
    _ => _proximaMensal(regra, base),
  };
  if (candidata == null) return null;
  if (fim != null && candidata.isAfter(fim.toUtc())) return null;
  return candidata;
}

DateTime? _proximaMensal(ExpenseRecurrence regra, DateTime base) {
  // Tenta o mês da própria base: a conta do dia 20 paga no dia 5 tem a "próxima"
  // ainda dentro deste mês.
  final desteMes = dataDaOcorrencia(base.year, base.month, regra.dayOfMonth);
  if (desteMes.isAfter(base)) return desteMes;
  final ano = base.month == 12 ? base.year + 1 : base.year;
  final mes = base.month == 12 ? 1 : base.month + 1;
  return dataDaOcorrencia(ano, mes, regra.dayOfMonth);
}

DateTime? _proximaAnual(ExpenseRecurrence regra, DateTime base) {
  final mes = regra.monthOfYear;
  // Anual sem mês não sabe quando vencer (o backend barra na criação; aqui não
  // inventamos um mês para não mostrar data errada).
  if (mes == null) return null;
  final desteAno = dataDaOcorrencia(base.year, mes, regra.dayOfMonth);
  if (desteAno.isAfter(base)) return desteAno;
  return dataDaOcorrencia(base.year + 1, mes, regra.dayOfMonth);
}

/// A próxima cobrança de [conta], seja ela fixa ou parcelada.
///
/// São duas fontes diferentes de propósito:
///  - **fixa**: calculada da regra, porque a ocorrência seguinte é uma linha de
///    outro mês que a tela não tem em mãos;
///  - **parcelada**: a IRMÃ seguinte, que é um fato já gravado — calcular daria
///    a data errada se alguém tivesse corrigido o vencimento de uma parcela.
///
/// `null` = não há próxima (conta avulsa, última parcela, ou regra encerrada).
DateTime? proximaCobranca(
  Expense conta, {
  required List<ExpenseRecurrence> regras,
  required List<Expense> irmas,
}) {
  if (conta.parcelada) {
    final seguintes = irmas
        .where((p) =>
            p.installmentNo != null &&
            p.installmentNo! > (conta.installmentNo ?? 0))
        .toList()
      ..sort((a, b) => a.installmentNo!.compareTo(b.installmentNo!));
    return seguintes.isEmpty ? null : seguintes.first.vencimento;
  }

  final id = conta.recurrenceId;
  if (id == null) return null;
  final regra = regras.where((r) => r.id == id).firstOrNull;
  if (regra == null) return null;
  return proximaOcorrencia(regra, depoisDe: conta.vencimento);
}
