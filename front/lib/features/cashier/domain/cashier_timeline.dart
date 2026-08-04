import '../../sale/domain/sale_models.dart';
import 'cashier_format.dart';
import 'cashier_models.dart';

/// Linha do tempo ÚNICA do caixa: tudo que aconteceu no período, em ordem, sem
/// o usuário ter de escolher uma "lente".
///
/// O problema que isto resolve: um extrato de lançamentos mostra só movimento de
/// dinheiro, então **venda em fiado desaparece** (não move o caixa) e uma venda
/// paga aparece como "Venda avulsa · R$ 150" sem dizer o que foi vendido nem
/// para quem. Aqui a unidade é o ACONTECIMENTO — venda, despesa, sangria,
/// suprimento, recebimento — cada um com o próprio detalhe.
///
/// **Regra contra duplicidade:** uma venda paga gera dois registros (a venda e o
/// lançamento do recebimento). Mostrar os dois faria o mesmo fato aparecer duas
/// vezes. Então a venda é a linha, e o recebimento DELA some da lista quando a
/// venda está presente — o valor recebido aparece dentro da própria venda.
/// Recebimento de uma venda de outro período continua aparecendo, porque ali é
/// um fato novo (o fiado sendo quitado).
enum CashierEventKind { venda, lancamento }

class CashierEvent {
  CashierEvent.venda(Sale s)
      : kind = CashierEventKind.venda,
        at = DateTime.tryParse(s.createdAt ?? '') ?? DateTime(1970),
        sale = s,
        entry = null;

  CashierEvent.lancamento(CashEntry e)
      : kind = CashierEventKind.lancamento,
        at = DateTime.tryParse(e.createdAt ?? '') ?? DateTime(1970),
        sale = null,
        entry = e;

  final CashierEventKind kind;
  final DateTime at;
  final Sale? sale;
  final CashEntry? entry;

  bool get ehVenda => kind == CashierEventKind.venda;

  /// Chave estável para lista/animação.
  String get id => ehVenda ? 'sale:${sale!.id}' : 'entry:${entry!.id}';
}

/// Monta a linha do tempo do período: vendas + lançamentos, do mais recente para
/// o mais antigo, sem duplicar o mesmo fato.
///
/// Função pura para ser testada sem UI — a regra de deduplicação é justamente o
/// que erra fácil e o que confunde o usuário quando erra.
List<CashierEvent> buildCashierTimeline({
  required List<CashEntry> entries,
  required List<Sale> sales,
}) {
  final idsDeVendasNaLista = {for (final s in sales) s.id};

  final eventos = <CashierEvent>[
    for (final s in sales) CashierEvent.venda(s),
    for (final e in entries)
      // Recebimento de uma venda que já está na lista: o fato já é contado pela
      // linha da venda (o valor recebido aparece nela).
      if (!(e.saleKind == 'sale' &&
          e.saleId != null &&
          idsDeVendasNaLista.contains(e.saleId)))
        CashierEvent.lancamento(e),
  ];

  eventos.sort((a, b) => b.at.compareTo(a.at));
  return eventos;
}

/// Rótulo do que aconteceu, para a linha do tempo.
///
/// Venda: diz o pagamento junto, porque "vendi 300 mas é fiado" é uma informação
/// só. Lançamento: usa o rótulo da categoria já existente.
String cashierEventTitle(CashierEvent ev) {
  if (ev.ehVenda) {
    final s = ev.sale!;
    if (s.status == 'canceled') return 'Venda cancelada';
    return switch (s.paymentStatus) {
      'pago' => 'Venda',
      'parcial' => 'Venda (pago em parte)',
      _ => 'Venda em fiado',
    };
  }
  // Despesa/sangria/suprimento: o NOME dado no lançamento identifica a linha
  // melhor que a categoria. Num histórico com dez despesas, dez linhas
  // "Despesa" não dizem nada — "Aluguel", "Óleo do fornecedor" dizem. A
  // categoria continua visível no subtítulo, junto da forma e da hora.
  final e = ev.entry!;
  final nome = e.description?.trim() ?? '';
  if (nome.isEmpty) return categoryLabel(e.category);
  // Recebimento já traz o número da venda/OS na descrição, e aí o rótulo da
  // categoria é o que informa — o nome entra como complemento, não como título.
  final ehRecebimento = e.category == 'os_payment' || e.category == 'venda_avulsa';
  return ehRecebimento ? '${categoryLabel(e.category)} · $nome' : nome;
}

/// A linha da venda mostra o VALOR VENDIDO e, à parte, a situação do pagamento
/// (paga / parcial / fiado). Deliberadamente NÃO tenta traduzir a venda em
/// "quanto entrou no caixa": a listagem não traz o valor pago de uma venda
/// parcial, e inventar esse número faria o extrato mentir. Quem responde "quanto
/// entrou" é o resumo do período, que vem calculado do backend.
///
/// O sinal +/− fica só nos lançamentos, que são movimento de dinheiro de fato.
bool cashierEventTemMovimento(CashierEvent ev) => !ev.ehVenda;

/// Filtro de tipo do histórico. "Saídas" reúne despesa e sangria (as duas tiram
/// dinheiro); "Despesas" isola só a despesa, que é a pergunta de custo.
enum CashierFilter { tudo, vendas, entradas, saidas, despesas }

String cashierFilterLabel(CashierFilter f) => switch (f) {
      CashierFilter.tudo => 'Tudo',
      CashierFilter.vendas => 'Vendas',
      CashierFilter.entradas => 'Entradas',
      CashierFilter.saidas => 'Saídas',
      CashierFilter.despesas => 'Despesas',
    };

/// Aplica filtro de tipo + busca textual sobre a linha do tempo.
///
/// A busca é feita no cliente, sobre o que já está carregado: cobre cliente,
/// número, itens vendidos, forma de pagamento e descrição do lançamento — que é
/// como o usuário procura ("cadê a venda do João?", "aquela despesa de óleo").
/// Sem acento e sem caixa, porque ninguém digita "José" com acento no meio do
/// atendimento.
List<CashierEvent> filterCashierTimeline(
  List<CashierEvent> eventos, {
  CashierFilter filtro = CashierFilter.tudo,
  String busca = '',
}) {
  final termo = _semAcento(busca.trim().toLowerCase());
  return eventos.where((ev) {
    if (!_passaFiltro(ev, filtro)) return false;
    if (termo.isEmpty) return true;
    return _semAcento(_textoBuscavel(ev).toLowerCase()).contains(termo);
  }).toList();
}

bool _passaFiltro(CashierEvent ev, CashierFilter f) {
  switch (f) {
    case CashierFilter.tudo:
      return true;
    case CashierFilter.vendas:
      return ev.ehVenda;
    case CashierFilter.entradas:
      // Venda em fiado NÃO é entrada: nada entrou no caixa.
      if (ev.ehVenda) return ev.sale!.paymentStatus == 'pago';
      return ev.entry!.direction == 'in';
    case CashierFilter.saidas:
      return !ev.ehVenda && ev.entry!.direction == 'out';
    case CashierFilter.despesas:
      return !ev.ehVenda && ev.entry!.category == 'despesa';
  }
}

/// Tudo que a linha "diz", concatenado para a busca.
String _textoBuscavel(CashierEvent ev) {
  if (ev.ehVenda) {
    final s = ev.sale!;
    return [
      s.customerName ?? '',
      s.number,
      for (final i in s.items) i.name,
    ].join(' ');
  }
  final e = ev.entry!;
  return [
    categoryLabel(e.category),
    methodLabel(e.method),
    e.description ?? '',
  ].join(' ');
}

/// Remove acentos para a busca não depender de digitação exata.
String _semAcento(String v) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  var out = v;
  for (var i = 0; i < de.length; i++) {
    out = out.replaceAll(de[i], para[i]);
  }
  return out;
}
