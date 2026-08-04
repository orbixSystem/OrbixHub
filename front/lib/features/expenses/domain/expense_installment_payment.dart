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

/// Quanto sai do caixa numa baixa em bloco — o número que o botão precisa mostrar
/// ANTES do toque.
///
/// Soma o `amount` (o previsto), não o `valorEfetivo`: nenhuma delas foi paga
/// ainda, então não há valor efetivo. Confirmar "Quitar restante" sem ver o total
/// seria pedir para a pessoa assinar em branco.
num totalDasParcelas(List<Expense> parcelas) =>
    parcelas.fold<num>(0, (soma, p) => soma + p.amount);
