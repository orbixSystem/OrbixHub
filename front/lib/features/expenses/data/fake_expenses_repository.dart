import 'package:uuid/uuid.dart';

import '../../../core/error/app_exception.dart';
import '../domain/expense_models.dart';
import '../domain/expense_status.dart';
import '../domain/expenses_repository.dart';

/// Impl em memória do módulo Despesas.
///
/// Existe para desenvolver e revisar a TELA antes de o backend existir — mesmo
/// papel dos fakes das outras features. Não é persistência offline: some ao
/// recarregar, de propósito.
///
/// Os dados de exemplo são montados em torno de "hoje" para que os quatro
/// estados apareçam de cara (vencido, vence hoje, vence em breve, pago) — uma
/// lista toda azul não deixaria revisar as cores.
class FakeExpensesRepository implements ExpensesRepository {
  FakeExpensesRepository({DateTime? hoje}) : _hoje = hoje ?? DateTime.now() {
    _semear();
  }

  final DateTime _hoje;
  final _uuid = const Uuid();
  final List<Expense> _contas = [];
  final List<ExpenseRecurrence> _regras = [];

  // Instância (não `static const`): criar categoria muda a lista, e um fake que
  // não reflete a própria escrita mentiria para o teste.
  List<ExpenseCategory> _categorias = const <ExpenseCategory>[
    ExpenseCategory(id: 'cat-aluguel', name: 'Aluguel', icon: 'aluguel', color: '#F97316'),
    ExpenseCategory(id: 'cat-energia', name: 'Energia', icon: 'energia', color: '#EAB308'),
    ExpenseCategory(id: 'cat-agua', name: 'Água', icon: 'agua', color: '#38BDF8'),
    ExpenseCategory(id: 'cat-internet', name: 'Internet', icon: 'internet', color: '#8B5CF6'),
    ExpenseCategory(id: 'cat-telefone', name: 'Telefone', icon: 'telefone', color: '#06B6D4'),
    ExpenseCategory(id: 'cat-impostos', name: 'Impostos', icon: 'impostos', color: '#EF4444'),
    ExpenseCategory(id: 'cat-fornecedor', name: 'Fornecedor', icon: 'fornecedor', color: '#10B981', tracksSupplier: true),
    ExpenseCategory(id: 'cat-salarios', name: 'Salários', icon: 'salarios', color: '#3B82F6'),
    ExpenseCategory(id: 'cat-manutencao', name: 'Manutenção', icon: 'manutencao', color: '#A16207', tracksSupplier: true),
    ExpenseCategory(id: 'cat-outros', name: 'Outros', icon: 'outros', color: '#6B7280'),
  ];

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _semear() {
    final h = DateTime(_hoje.year, _hoje.month, _hoje.day);
    void add({
      required String desc,
      required num valor,
      required int emDias,
      String? cat,
      bool pago = false,
      String? forma,
      bool recorrente = false,
      String? obs,
      String? fornecedor,
      String? doc,
      int? parcela,
      int? deParcelas,
      String? grupo,
    }) {
      final venc = h.add(Duration(days: emDias));
      final regraId = recorrente ? 'rec-${desc.hashCode}' : null;
      if (regraId != null && !_regras.any((r) => r.id == regraId)) {
        // A REGRA como objeto, não só o id: é dela que a tela tira "próxima em
        // 10/09" ao dar baixa. Um fake sem a regra esconderia essa tela.
        _regras.add(ExpenseRecurrence(
          id: regraId,
          description: desc,
          amount: valor,
          categoryId: cat,
          dayOfMonth: venc.day,
        ));
      }
      _contas.add(Expense(
        id: _uuid.v4(),
        description: desc,
        amount: valor,
        dueDate: _iso(venc),
        categoryId: cat,
        recurrenceId: regraId,
        paidAt: pago ? venc.toIso8601String() : null,
        paidAmount: pago ? valor : null,
        paidMethod: pago ? (forma ?? 'pix') : null,
        notes: obs,
        supplierName: fornecedor,
        supplierDoc: doc,
        installmentNo: parcela,
        installmentTotal: deParcelas,
        installmentGroupId: grupo,
      ));
    }

    // Vencidas — o que pede ação hoje.
    add(desc: 'Conta de luz', valor: 0, emDias: -6, cat: 'cat-energia', recorrente: true, obs: 'Valor ainda não chegou');
    add(desc: 'Internet fibra', valor: 149.90, emDias: -2, cat: 'cat-internet', recorrente: true);
    // Vence hoje.
    add(desc: 'Aluguel do galpão', valor: 2500, emDias: 0, cat: 'cat-aluguel', recorrente: true);
    // Vence em breve (janela de 3 dias).
    add(desc: 'Água', valor: 187.40, emDias: 2, cat: 'cat-agua', recorrente: true);
    // A pagar, adiante.
    add(desc: 'Simples Nacional', valor: 1320.55, emDias: 9, cat: 'cat-impostos', recorrente: true);
    add(
      desc: 'Fornecedor de peças — NF 8842',
      valor: 3760,
      emDias: 14,
      cat: 'cat-fornecedor',
      fornecedor: 'Distribuidora Sul Peças',
      doc: '12345678000195',
    );
    add(desc: 'Salários', valor: 8400, emDias: 16, cat: 'cat-salarios', recorrente: true);
    // Compra parcelada: a 2ª de 6 cai neste mês, a 1ª já foi paga. Sem um
    // parcelamento semeado não daria para revisar o rótulo "2/6" nem o detalhe.
    const grupoCompressor = 'grp-compressor';
    add(
      desc: 'Compressor de ar',
      valor: 1166.67,
      emDias: -25,
      cat: 'cat-manutencao',
      pago: true,
      forma: 'cartao_credito',
      fornecedor: 'Ar Forte Equipamentos',
      doc: '98765432000110',
      parcela: 1,
      deParcelas: 6,
      grupo: grupoCompressor,
    );
    add(
      desc: 'Compressor de ar',
      valor: 1166.66,
      emDias: 5,
      cat: 'cat-manutencao',
      fornecedor: 'Ar Forte Equipamentos',
      doc: '98765432000110',
      parcela: 2,
      deParcelas: 6,
      grupo: grupoCompressor,
    );
    // Já pagas.
    add(desc: 'Contador', valor: 690, emDias: -12, cat: 'cat-outros', pago: true, recorrente: true);
    add(desc: 'Troca do compressor', valor: 1150, emDias: -9, cat: 'cat-manutencao', pago: true, forma: 'cartao_credito');
  }

  bool _doMes(Expense e, int ano, int mes) {
    final v = e.vencimento;
    if (v.year == ano && v.month == mes) return true;
    // Vencida e ainda em aberto continua aparecendo nos meses seguintes: somê-la
    // no mês em que venceu esconderia justamente o que precisa de ação.
    return !e.pago && v.isBefore(DateTime(ano, mes, 1));
  }

  @override
  Future<ExpensesMonth> listarMes({required int ano, required int mes}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final itens = _contas
        .where((e) => e.status == 'active' && _doMes(e, ano, mes))
        .toList()
      ..sort((a, b) => a.vencimento.compareTo(b.vencimento));

    num previsto = 0, pago = 0, aberto = 0, vencido = 0;
    for (final e in itens) {
      previsto += e.amount;
      if (e.pago) {
        pago += e.valorEfetivo;
      } else {
        aberto += e.amount;
        if (e.situacao(_hoje) == ExpenseStatus.vencido) vencido += e.amount;
      }
    }
    return ExpensesMonth(
      items: itens,
      categories: _categorias,
      recurrences: _regras
          .where((r) => itens.any((e) => e.recurrenceId == r.id))
          .toList(),
      totalPrevisto: previsto,
      totalPago: pago,
      totalEmAberto: aberto,
      totalVencido: vencido,
    );
  }

  @override
  Future<List<ExpenseCategory>> categorias() async => _categorias;

  @override
  Future<ExpenseCategory> criarCategoria({
    required String name,
    String? icon,
    String? color,
    bool tracksSupplier = false,
  }) async {
    final nome = name.trim();
    // Espelha o unique do backend (nome entre as ATIVAS): sem isso o fake
    // aceitaria duplicata e o teste passaria onde a API recusa.
    if (_categorias.any(
      (c) => c.status == 'active' && c.name.toLowerCase() == nome.toLowerCase(),
    )) {
      throw AppException(
        statusCode: 409,
        error: 'Conflict',
        message: 'Já existe uma categoria "$nome".',
      );
    }
    final nova = ExpenseCategory(
      id: _uuid.v4(),
      name: nome,
      icon: icon ?? 'outros',
      color: color ?? '#6B7280',
      tracksSupplier: tracksSupplier,
    );
    _categorias = [..._categorias, nova];
    return nova;
  }

  @override
  Future<Expense> criar(ExpenseDraft draft) async {
    final regraId = draft.recorrencia == null ? null : _uuid.v4();
    final nova = Expense(
      id: _uuid.v4(),
      description: draft.description ?? '',
      amount: draft.amount ?? 0,
      dueDate: draft.dueDate ?? _iso(_hoje),
      categoryId: draft.categoryId,
      recurrenceId: regraId,
      notes: draft.notes,
      supplierName: draft.supplierName,
      supplierDoc: draft.supplierDoc,
    );

    final n = draft.parcelas;
    if (n != null && n >= 2) {
      // Espelha o rateio do servidor (resto na primeira) para o fake mostrar os
      // mesmos valores que a API mostraria.
      final grupo = draft.installmentGroupId ?? _uuid.v4();
      final valores = _ratear(nova.amount, n);
      final primeira = nova.vencimento;
      Expense? cabeca;
      for (var i = 0; i < n; i++) {
        final ano = primeira.year + ((primeira.month - 1 + i) ~/ 12);
        final mes = ((primeira.month - 1 + i) % 12) + 1;
        final ultimo = DateTime(ano, mes + 1, 0).day;
        final dia = primeira.day > ultimo ? ultimo : primeira.day;
        final parcela = nova.copyWith(
          id: draft.installmentIds?.elementAtOrNull(i) ?? _uuid.v4(),
          amount: valores[i],
          dueDate: _iso(DateTime(ano, mes, dia)),
          installmentNo: i + 1,
          installmentTotal: n,
          installmentGroupId: grupo,
        );
        _contas.add(parcela);
        cabeca ??= parcela;
      }
      return cabeca!;
    }

    _contas.add(nova);
    if (regraId != null) {
      _regras.add(ExpenseRecurrence(
        id: regraId,
        description: nova.description,
        amount: nova.amount,
        categoryId: nova.categoryId,
        frequency: draft.recorrencia!.frequency,
        dayOfMonth: draft.recorrencia!.dayOfMonth,
        monthOfYear: draft.recorrencia!.monthOfYear,
        endsOn: draft.recorrencia!.endsOn,
      ));
      // Recorrente: materializa os próximos meses, como a esteira do servidor.
      _materializar(nova, draft.recorrencia!);
    }
    return nova;
  }

  /// Rateio em centavos, resto na primeira — mesma regra do `ratearParcelas` do
  /// backend. Duplicado aqui de propósito: o fake precisa ser fiel ao servidor.
  static List<num> _ratear(num total, int n) {
    final centavos = (total * 100).round();
    final base = centavos ~/ n;
    final resto = centavos - base * n;
    return [
      for (var i = 0; i < n; i++) (base + (i == 0 ? resto : 0)) / 100,
    ];
  }

  @override
  Future<ExpenseDetail> detalhe(String id) async {
    final i = _idx(id);
    if (i < 0) {
      throw AppException(
        statusCode: 404,
        error: 'Not Found',
        message: 'Despesa não encontrada.',
      );
    }
    final conta = _contas[i];
    final grupo = conta.installmentGroupId;
    return ExpenseDetail(
      expense: conta,
      recurrence:
          _regras.where((r) => r.id == conta.recurrenceId).firstOrNull,
      parcelas: grupo == null
          ? const []
          : (_contas.where((e) => e.installmentGroupId == grupo).toList()
            ..sort((a, b) =>
                (a.installmentNo ?? 0).compareTo(b.installmentNo ?? 0))),
    );
  }

  @override
  Future<ExpenseSupplierLookup> consultarCnpj(String cnpj) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final doc = cnpj.replaceAll(RegExp(r'\D'), '');
    return ExpenseSupplierLookup(
      doc: doc,
      razaoSocial: 'EMPRESA EXEMPLO LTDA',
      nomeFantasia: 'Exemplo Distribuidora',
      situacao: 'ATIVA',
    );
  }

  /// Gera as ocorrências futuras de uma regra (12 meses à frente).
  void _materializar(Expense base, ExpenseRecurrenceDraft regra) {
    if (regra.frequency != 'monthly') return;
    final inicio = base.vencimento;
    for (var i = 1; i <= 12; i++) {
      final ano = inicio.year + ((inicio.month - 1 + i) ~/ 12);
      final mes = ((inicio.month - 1 + i) % 12) + 1;
      // Mês curto encurta o dia: dia 31 em fevereiro cai no último dia do mês,
      // em vez de transbordar para março.
      final ultimoDia = DateTime(ano, mes + 1, 0).day;
      final dia = regra.dayOfMonth > ultimoDia ? ultimoDia : regra.dayOfMonth;
      _contas.add(base.copyWith(
        id: _uuid.v4(),
        dueDate: _iso(DateTime(ano, mes, dia)),
        paidAt: null,
        paidAmount: null,
        paidMethod: null,
      ));
    }
  }

  int _idx(String id) => _contas.indexWhere((e) => e.id == id);

  @override
  Future<Expense> editar(String id, ExpenseDraft draft) async {
    final i = _idx(id);
    if (i < 0) throw StateError('Despesa não encontrada');
    final atual = _contas[i];
    final nova = atual.copyWith(
      description: draft.description ?? atual.description,
      amount: draft.amount ?? atual.amount,
      dueDate: draft.dueDate ?? atual.dueDate,
      categoryId: draft.limparCategoria ? null : (draft.categoryId ?? atual.categoryId),
      notes: draft.notes ?? atual.notes,
      supplierName: draft.limparFornecedor
          ? null
          : (draft.supplierName ?? atual.supplierName),
      supplierDoc:
          draft.limparFornecedor ? null : (draft.supplierDoc ?? atual.supplierDoc),
    );
    _contas[i] = nova;
    return nova;
  }

  @override
  Future<Expense> marcarPaga(
    String id, {
    num? valor,
    String? forma,
    DateTime? quando,
  }) async {
    final i = _idx(id);
    if (i < 0) throw StateError('Despesa não encontrada');
    final atual = _contas[i];
    final nova = atual.copyWith(
      paidAt: (quando ?? DateTime.now()).toIso8601String(),
      paidAmount: valor ?? atual.amount,
      paidMethod: forma,
    );
    _contas[i] = nova;
    return nova;
  }

  @override
  Future<Expense> desmarcarPaga(String id) async {
    final i = _idx(id);
    if (i < 0) throw StateError('Despesa não encontrada');
    final nova = _contas[i].copyWith(
      paidAt: null,
      paidAmount: null,
      paidMethod: null,
    );
    _contas[i] = nova;
    return nova;
  }

  @override
  Future<void> cancelar(String id) async {
    final i = _idx(id);
    if (i < 0) return;
    _contas[i] = _contas[i].copyWith(status: 'canceled');
  }
}
