import 'expense_models.dart';

/// Quais parcelas pagar quando se pede "pagar N" ou "quitar o restante".
///
/// Pura e testada porque decide **onde o dinheiro vai**: escolher a parcela errada
/// deixa a compra com um buraco no meio (a 4ª paga e a 2ª aberta), e o cliente
/// descobre isso no telefonema do fornecedor.
///
/// Não existe endpoint de "pagar em bloco" no servidor, de propósito: a baixa em
/// bloco é N baixas, e o `POST /expenses/:id/pay` já faz uma delas com tudo que
/// precisa (lançamento no caixa, auditoria, idempotência por `cashEntryId`). Um
/// endpoint novo teria o MESMO perfil de falha parcial — o `pay` chama o caixa fora
/// de transação de propósito — e ainda exigiria uma op de sync nova para o modo
/// offline, criando dois caminhos para a mesma coisa. Aqui a tela repete a operação
/// que já é provada, e funciona igual com e sem rede.

/// As parcelas que uma baixa em bloco deve atingir, na ORDEM de pagamento.
///
/// Regras:
///  - começa na parcela [aPartirDe] (a que o usuário abriu) e segue pelas
///    seguintes — nunca volta para trás. Antecipar não é pagar o atrasado: se a 2ª
///    está aberta e a pessoa abriu a 4ª pedindo "pagar 2", ela quer a 4ª e a 5ª;
///  - pula as já pagas, sem gastá-las da cota: "pagar 2" com a próxima já paga
///    resolve duas AINDA ABERTAS;
///  - ordena por número de parcela, não por vencimento: o número é a identidade da
///    parcela, e um vencimento corrigido à mão não deve reordenar a dívida;
///  - [quantidade] nulo = todas as restantes ("quitar").
List<Expense> parcelasParaPagar(
  List<Expense> doGrupo, {
  required Expense aPartirDe,
  int? quantidade,
}) {
  final numeroBase = aPartirDe.installmentNo;
  if (numeroBase == null) {
    // Não é parcelada: a "baixa em bloco" é a própria conta, se estiver aberta.
    return aPartirDe.pago ? const [] : [aPartirDe];
  }

  final candidatas = doGrupo
      .where((p) => !p.pago && (p.installmentNo ?? 0) >= numeroBase)
      .toList()
    ..sort((a, b) => (a.installmentNo ?? 0).compareTo(b.installmentNo ?? 0));

  if (quantidade == null) return candidatas;
  if (quantidade <= 0) return const [];
  return candidatas.take(quantidade).toList(growable: false);
}

/// A parcela EM ABERTO mais antiga que precisa ser paga antes de [alvo] — ou
/// `null` quando é a vez de [alvo] (ou quando não é parcelada).
///
/// **Parcela se paga na ordem.** Pagar a 5ª com a 1ª vencida deixa a compra ao
/// contrário do combinado com o fornecedor e lança no caixa a saída da parcela
/// errada. O engano é fácil de cometer: no mês da última parcela a lista mostra
/// também as anteriores (conta vencida não some do mês seguinte), e a mais
/// atrasada aparece no TOPO por urgência — dá para dar baixa nela achando que é
/// a do mês em que se está.
///
/// O servidor é quem manda (recusa com 409 nomeando a parcela); esta função
/// existe para a tela não OFERECER o que vai ser recusado.
Expense? parcelaQueBloqueia(
  List<Expense> doGrupo, {
  required Expense alvo,
}) {
  final numero = alvo.installmentNo;
  if (numero == null) return null;
  final pendentes = doGrupo
      .where((p) => !p.pago && (p.installmentNo ?? 0) < numero)
      .toList()
    ..sort((a, b) => (a.installmentNo ?? 0).compareTo(b.installmentNo ?? 0));
  return pendentes.firstOrNull;
}

/// As parcelas do grupo que têm baixa a desfazer, em ordem de número.
///
/// Ao contrário de [parcelasParaPagar], NÃO tem regra de "não voltar atrás": quem
/// desfaz está corrigindo um erro já cometido, e o erro pode estar em qualquer mês
/// ("dei baixa na de outubro sem querer"). Escolher a parcela é da usuária — a
/// função só diz quais existem. Devolver as pagas de todo o grupo é justamente o
/// que permite o seletor perguntar QUAL mês desfazer, em vez de assumir a atual.
///
/// Desfazer fora de ordem pode deixar a compra com um buraco (a 3ª aberta e a 4ª
/// paga). Isso é aceito de propósito: o buraco é o estado REAL depois do estorno,
/// e escondê-lo forçando a desfazer em cascata mexeria em dinheiro que ninguém
/// mandou mexer.
List<Expense> parcelasParaDesfazer(
  List<Expense> doGrupo, {
  required Expense aPartirDe,
}) {
  if (aPartirDe.installmentNo == null) {
    // Não é parcelada: só ela mesma, e só se estiver paga.
    return aPartirDe.pago ? [aPartirDe] : const [];
  }
  return doGrupo.where((p) => p.pago).toList()
    ..sort((a, b) => (a.installmentNo ?? 0).compareTo(b.installmentNo ?? 0));
}

/// Quanto sai do caixa numa baixa em bloco — o número que o botão precisa mostrar
/// ANTES do toque.
///
/// Soma o `amount` (o previsto), não o `valorEfetivo`: nenhuma delas foi paga
/// ainda, então não há valor efetivo. Confirmar "Quitar restante" sem ver o total
/// seria pedir para a pessoa assinar em branco.
num totalDasParcelas(List<Expense> parcelas) =>
    parcelas.fold<num>(0, (soma, p) => soma + p.amount);
