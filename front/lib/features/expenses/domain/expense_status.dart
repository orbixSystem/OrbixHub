/// Situação de uma conta a pagar.
///
/// NÃO é coluna no banco: o servidor grava só `paid_at` e `due_date`, e a
/// situação é derivada disto + a data de hoje. Status materializado precisaria
/// de um job diário só para envelhecer linha — e ficaria errado entre execuções
/// (uma conta venceria à meia-noite, mas só "viraria vencida" quando o job
/// rodasse). Derivar é sempre correto no instante em que se olha.
enum ExpenseStatus {
  /// Já foi paga. Vence-quando deixa de importar.
  pago,

  /// Passou do vencimento e não foi paga. É o único estado que pede ação hoje.
  vencido,

  /// Vence exatamente hoje.
  venceHoje,

  /// Vence dentro da janela de atenção (ver [kDiasParaVencerEmBreve]).
  venceEmBreve,

  /// Vence adiante, fora da janela de atenção.
  aPagar,
}

/// Janela de "vence em breve". Três dias: tempo de reagir (pegar o boleto,
/// transferir) sem transformar o mês inteiro em alerta — se tudo é urgente,
/// nada é.
const int kDiasParaVencerEmBreve = 3;

/// Deriva a situação de uma conta.
///
/// Compara por DIA CIVIL, não por instante: `dueDate` é uma data (sem hora) e
/// comparar com `DateTime.now()` cru faria uma conta que vence hoje aparecer
/// como vencida a partir das 00:00 de hoje mesmo.
ExpenseStatus statusDaDespesa({
  required DateTime dueDate,
  DateTime? paidAt,
  required DateTime hoje,
  int diasParaEmBreve = kDiasParaVencerEmBreve,
}) {
  // Pago vence qualquer outra leitura: uma conta paga em atraso não é "vencida",
  // é resolvida. Mostrá-la em vermelho faria a cliente pagar de novo.
  if (paidAt != null) return ExpenseStatus.pago;

  final venc = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final hj = DateTime(hoje.year, hoje.month, hoje.day);
  final dias = venc.difference(hj).inDays;

  if (dias < 0) return ExpenseStatus.vencido;
  if (dias == 0) return ExpenseStatus.venceHoje;
  if (dias <= diasParaEmBreve) return ExpenseStatus.venceEmBreve;
  return ExpenseStatus.aPagar;
}

/// Rótulo curto para a UI (PT-BR).
String rotuloStatus(ExpenseStatus s) => switch (s) {
      ExpenseStatus.pago => 'Pago',
      ExpenseStatus.vencido => 'Vencido',
      ExpenseStatus.venceHoje => 'Vence hoje',
      ExpenseStatus.venceEmBreve => 'Vence em breve',
      ExpenseStatus.aPagar => 'A pagar',
    };

/// Quantos dias faltam (negativo = atraso). Usado no texto auxiliar da linha.
int diasAte(DateTime dueDate, DateTime hoje) {
  final venc = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final hj = DateTime(hoje.year, hoje.month, hoje.day);
  return venc.difference(hj).inDays;
}
