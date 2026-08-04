import 'expense_models.dart';
import 'expense_status.dart';

/// Ordenação e busca da lista de contas — puras, para serem testadas sem UI.

/// Peso da urgência. Menor = aparece antes.
///
/// A ordem não é a do vencimento cru: **vencido vem antes de vence-hoje**. Uma
/// conta que já passou do prazo é a única que está gerando multa agora, então é
/// ela que precisa da primeira linha. O servidor já devolve por `due_date asc`,
/// mas isso sozinho misturaria uma conta paga do dia 2 antes de uma vencida do
/// dia 5 — o que a lista precisa é de urgência, não de cronologia.
int _peso(ExpenseStatus s) => switch (s) {
      ExpenseStatus.vencido => 0,
      ExpenseStatus.venceHoje => 1,
      ExpenseStatus.venceEmBreve => 2,
      ExpenseStatus.aPagar => 3,
      // Pago sai do caminho: é histórico, não tarefa. Fica no fim mesmo quando
      // venceu antes de todas as outras.
      ExpenseStatus.pago => 4,
    };

/// Ordena por URGÊNCIA e, dentro do mesmo grupo, por vencimento.
///
/// Desempate final pela descrição para a ordem ser ESTÁVEL: duas contas do mesmo
/// dia trocando de lugar entre dois carregamentos faria a lista "piscar" e o
/// usuário perder o dedo na linha que ia tocar.
List<Expense> ordenarPorUrgencia(
  List<Expense> contas, {
  required DateTime hoje,
}) {
  ExpenseStatus st(Expense e) => statusDaDespesa(
        dueDate: DateTime.parse(e.dueDate),
        paidAt: e.paidAt == null ? null : DateTime.parse(e.paidAt!),
        hoje: hoje,
      );

  final copia = [...contas];
  copia.sort((a, b) {
    final pa = _peso(st(a));
    final pb = _peso(st(b));
    if (pa != pb) return pa.compareTo(pb);

    final va = DateTime.parse(a.dueDate);
    final vb = DateTime.parse(b.dueDate);
    // Dentro de "vencido", a MAIS ANTIGA primeiro (atrasa há mais tempo). Nos
    // outros grupos, a mais próxima primeiro. Nos dois casos é `asc` — o que
    // muda é a leitura, não a regra.
    final porData = va.compareTo(vb);
    if (porData != 0) return porData;

    return a.description.toLowerCase().compareTo(b.description.toLowerCase());
  });
  return copia;
}

/// Filtra por texto, olhando descrição E nome da categoria.
///
/// A categoria entra na busca porque "energia" é como a pessoa pensa a conta,
/// mesmo quando a descrição diz "CPFL 08/2026". `nomeDaCategoria` é passado de
/// fora (a conta guarda só o `category_id` — regra 1: nada de a busca sair
/// procurando dados de outro lugar por conta própria).
List<Expense> filtrarPorTexto(
  List<Expense> contas,
  String busca, {
  String Function(String categoryId)? nomeDaCategoria,
}) {
  final q = busca.trim().toLowerCase();
  if (q.isEmpty) return contas;
  return contas.where((e) {
    if (e.description.toLowerCase().contains(q)) return true;
    final cat = e.categoryId;
    if (cat == null || nomeDaCategoria == null) return false;
    return nomeDaCategoria(cat).toLowerCase().contains(q);
  }).toList(growable: false);
}

/// As contas a pagar **desta semana** — o filtro que o dono pediu.
///
/// "Semana" aqui é *hoje + os próximos 7 dias*, e não segunda-a-domingo: quem
/// pergunta "o que tenho pra pagar esta semana" na quinta-feira quer saber até a
/// quinta seguinte, não perder de vista o que vence no sábado por causa de uma
/// fronteira de calendário.
///
/// As **vencidas entram**, sempre: nada é mais "para pagar esta semana" que uma
/// conta que já passou do prazo. Pagas ficam fora — é fila de trabalho, não
/// histórico.
List<Expense> contasDaSemana(
  List<Expense> contas, {
  required DateTime hoje,
  int dias = 7,
}) {
  final limite = DateTime(hoje.year, hoje.month, hoje.day)
      .add(Duration(days: dias));
  return contas.where((e) {
    if (e.pago) return false;
    final v = DateTime.tryParse(e.dueDate);
    if (v == null) return false;
    // Comparação por dia CIVIL em UTC: `due_date` chega como meia-noite UTC, e
    // converter para local jogaria o dia 1º para o mês anterior em fuso a oeste.
    final dia = DateTime(v.toUtc().year, v.toUtc().month, v.toUtc().day);
    return !dia.isAfter(limite);
  }).toList(growable: false);
}

/// Quantas contas pedem atenção HOJE (vencidas + vencendo hoje).
///
/// É o número que vale um destaque no topo: "3 contas vencendo" é acionável;
/// "12 contas no mês" é só volume.
int contasQuePedemAtencao(List<Expense> contas, {required DateTime hoje}) {
  var n = 0;
  for (final e in contas) {
    final s = statusDaDespesa(
      dueDate: DateTime.parse(e.dueDate),
      paidAt: e.paidAt == null ? null : DateTime.parse(e.paidAt!),
      hoje: hoje,
    );
    if (s == ExpenseStatus.vencido || s == ExpenseStatus.venceHoje) n++;
  }
  return n;
}
