library;

/// Rateio e vencimentos de uma compra parcelada.
///
/// Espelha `ratearParcelas`/`datasDasParcelas` do backend (`expenses.config.ts`),
/// e a duplicação é deliberada: o servidor continua sendo a autoridade, mas o
/// cliente precisa das duas coisas para (a) mostrar "6x de R$ 194,44" ENQUANTO a
/// pessoa digita e (b) criar as parcelas sem rede. Divergência de centavo se
/// corrige no pull seguinte.
///
/// Funções puras, sem I/O — dinheiro e calendário são exatamente o que se testa
/// barato e se erra caro.

/// Teto de parcelas. Espelha `MAX_PARCELAS` do backend e o CHECK da 0040.
const maxParcelas = 48;

/// Rateia [total] em [n] parcelas, em centavos, sem perder nem inventar dinheiro.
///
/// Os centavos de resto vão na PRIMEIRA parcela (convenção brasileira: as
/// seguintes ficam redondas). R$ 100 em 3x = 33,34 + 33,33 + 33,33.
///
/// A conta é feita em centavos INTEIROS: dividir em ponto flutuante e arredondar
/// cada parcela faz a soma fechar em 99,99 ou 100,01 — e a soma das parcelas tem
/// de ser o total combinado com o fornecedor, senão a dívida cadastrada não é a
/// dívida real.
List<num> ratearParcelas(num total, int n) {
  if (n < 1) return const [];
  final centavos = (total * 100).round();
  final base = centavos ~/ n;
  final resto = centavos - base * n;
  return [
    for (var i = 0; i < n; i++) (base + (i == 0 ? resto : 0)) / 100,
  ];
}

/// Último dia do mês (1..12) — resolve fevereiro e ano bissexto.
int _ultimoDia(int ano, int mes) => DateTime.utc(ano, mes + 1, 0).day;

/// Vencimentos das parcelas: o primeiro é o informado, os demais de mês em mês.
///
/// Mês curto ENCURTA o dia (1ª em 31/01 → 2ª em 28/02 → 3ª em 31/03). Transbordar
/// para 03/03 jogaria a parcela de fevereiro no mês de março, onde a cliente não
/// a procura.
///
/// Devolve datas em **UTC**, como o `due_date` (coluna `date`) chega do servidor —
/// misturar fuso local aqui deslocaria o dia em fuso a oeste.
List<DateTime> datasDasParcelas(DateTime primeiro, int n) {
  final dia = primeiro.day;
  final ano0 = primeiro.year;
  final mes0 = primeiro.month;
  return [
    for (var i = 0; i < n; i++)
      () {
        final corrido = mes0 + i - 1;
        final ano = ano0 + corrido ~/ 12;
        final mes = corrido % 12 + 1;
        final ultimo = _ultimoDia(ano, mes);
        return DateTime.utc(ano, mes, dia > ultimo ? ultimo : dia);
      }(),
  ];
}
