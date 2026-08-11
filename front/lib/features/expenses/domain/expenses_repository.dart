import 'expense_models.dart';

/// Contrato do módulo Despesas (contas a pagar / lembrete de pagamento).
///
/// Backend é a verdade (RLS + `finance.read`/`finance.write` + gating do módulo
/// `expenses`); o cliente reflete para UX. Impl real (dio) + fake, trocadas por
/// injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class ExpensesRepository {
  /// Contas de um mês (1 = janeiro), com as categorias e os totais.
  ///
  /// O mês é o recorte natural: a cliente pensa "o que tenho pra pagar em
  /// setembro", não "as próximas 50 contas". As contas VENCIDAS de meses
  /// anteriores que continuam em aberto vêm junto — some-las do mês em que
  /// venceram seria esconder justamente o que precisa de ação.
  Future<ExpensesMonth> listarMes({required int ano, required int mes});

  /// Cria uma conta. Com [ExpenseDraft.recorrencia] preenchido, o servidor cria
  /// a regra e materializa as ocorrências; com [ExpenseDraft.parcelas], cria as N
  /// parcelas (e `amount` é lido como TOTAL da dívida, rateado pelo servidor).
  ///
  /// Devolve sempre a PRIMEIRA linha criada — é a que a tela acabou de cadastrar.
  Future<Expense> criar(ExpenseDraft draft);

  /// Uma conta com o contexto do detalhe: a regra que a gerou e as irmãs de
  /// parcelamento.
  ///
  /// É também a porta do caminho **caixa → despesa**: o lançamento do caixa
  /// guarda o id desta conta, então o clique no extrato chega aqui.
  Future<ExpenseDetail> detalhe(String id);

  /// Dados públicos da empresa pelo CNPJ, para preencher o fornecedor.
  ///
  /// Consulta externa: exige rede e pode falhar por indisponibilidade da fonte —
  /// o formulário trata como opcional, nunca bloqueia o cadastro.
  Future<ExpenseSupplierLookup> consultarCnpj(String cnpj);

  /// Edita uma conta já existente (só ela — não mexe na regra que a gerou).
  Future<Expense> editar(String id, ExpenseDraft draft);

  /// Marca como paga. [valor] nulo usa o valor previsto da conta — o caminho
  /// comum é um toque só, sem abrir formulário.
  Future<Expense> marcarPaga(
    String id, {
    num? valor,
    String? forma,
    DateTime? quando,
  });

  /// Desfaz o pagamento (erro de clique acontece). Não apaga histórico: só
  /// devolve a conta para "em aberto".
  Future<Expense> desmarcarPaga(String id);

  /// Exclui a conta — soft delete (regra 6): ela vai para a LIXEIRA, de onde
  /// pode voltar ([restaurar]) ou ser apagada de vez ([excluirDeVez]).
  ///
  /// Numa compra PARCELADA o servidor exclui o grupo inteiro: uma compra
  /// dividida em 6x é uma dívida só, e excluir metade dela deixaria o total
  /// encolhendo sozinho com buraco na numeração. Qualquer parcela já paga
  /// bloqueia — desfaça a baixa antes.
  Future<void> cancelar(String id);

  /// As contas EXCLUÍDAS com vencimento no mês — a lixeira.
  ///
  /// Listagem separada de [listarMes] porque é outra consulta, não um recorte:
  /// aquela olha só `status='active'`, esta só as canceladas. Os totais que vêm
  /// no [ExpensesMonth] continuam descrevendo as ATIVAS do mês — quanto se tem a
  /// pagar não muda por causa do que está no lixo.
  Future<ExpensesMonth> listarExcluidas({required int ano, required int mes});

  /// Tira da lixeira e devolve para a lista (parcelada volta inteira).
  Future<void> restaurar(String id);

  /// APAGA de vez — irreversível.
  ///
  /// Só funciona a partir da lixeira e só em conta que **nunca foi paga**: conta
  /// paga tem lançamento no caixa apontando de volta para ela, e apagá-la
  /// deixaria o extrato com um clique que não abre nada. O servidor recusa nos
  /// dois casos.
  Future<void> excluirDeVez(String id);

  /// Categorias ativas do tenant.
  Future<List<ExpenseCategory>> categorias();

  /// Cria uma categoria de despesa.
  ///
  /// `icon` precisa ser uma das chaves conhecidas (ver `chavesDeIcone`) e `color`
  /// um hex `#RRGGBB` — o backend valida as duas e recusa o resto. Ausentes, ele
  /// aplica os defaults dele, então a tela não precisa inventar valor.
  Future<ExpenseCategory> criarCategoria({
    required String name,
    String? icon,
    String? color,

    /// Esta categoria tem fornecedor do outro lado (peças, manutenção) ou não
    /// (aluguel, imposto, salário)? Decide se o cadastro de despesa pede o campo.
    bool tracksSupplier = false,
  });
}
