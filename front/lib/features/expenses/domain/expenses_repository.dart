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

  /// Cancela a conta (sem hard delete — regra 6).
  Future<void> cancelar(String id);

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
  });
}
