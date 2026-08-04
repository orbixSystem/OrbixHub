import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sale/domain/sale_models.dart';
import '../../sale/domain/sale_repository.dart';
import '../../sale/presentation/sale_providers.dart';
import '../domain/cashier_models.dart';
import '../domain/cashier_timeline.dart';
import '../domain/cashier_repository.dart';

/// Declarado aqui (lança por padrão) e ganha a impl real (dio) em `di.dart`,
/// espelhando os demais repos. Testes sobrescrevem com o fake.
final cashierRepositoryProvider = Provider<CashierRepository>((ref) {
  throw UnimplementedError('cashierRepositoryProvider deve ser sobrescrito em di.dart');
});

/// Estado da tela do Caixa do dia: sessão aberta (ou null), extrato e config.
class CashierState {
  const CashierState({
    required this.session,
    required this.entries,
    required this.config,
    this.sales = const [],
  });

  final CashSession? session;
  final List<CashEntry> entries;
  final CashierConfig config;

  /// Vendas do dia — o lançamento do caixa guarda só `sale_id`, então sem isto
  /// o extrato não consegue dizer PARA QUEM foi a venda.
  final List<Sale> sales;

  bool get isOpen => session != null;

  Map<String, Sale> get salesById => {for (final s in sales) s.id: s};
}

/// Carrega e orquestra o Caixa do dia. Mutações re-buscam o estado do backend
/// (a verdade), mantendo a UI consistente.
class CashierController extends AsyncNotifier<CashierState> {
  /// Dependências capturadas UMA VEZ, no `build`, antes de qualquer `await`.
  ///
  /// Não são getters com `ref.read` por dentro: o provider é `autoDispose`, e
  /// tocar `ref` depois de um `await` — quando o notifier já pode ter sido
  /// descartado (sair da tela, invalidar após uma venda) — lança
  /// "Cannot use ref after the notifier was disposed". Ler tudo antes das
  /// chamadas de rede elimina a classe inteira desse erro.
  CashierRepository? _repoCache;

  /// Getter com cache em vez de `late final` atribuído no `build`.
  ///
  /// Era `late final`: se qualquer método rodasse antes do `build` concluir (uma
  /// venda avulsa disparando `addEntry` num provider `autoDispose` recém-criado,
  /// por exemplo), a leitura estourava `LateInitializationError` e derrubava o
  /// fluxo no meio — com a venda já criada. Inicializar na primeira leitura
  /// resolve, e o cache preserva a proteção original: depois de lido uma vez,
  /// nunca mais se toca `ref` (que pode ter sido descartado após um `await`).
  CashierRepository get _repo {
    final cache = _repoCache;
    if (cache != null) return cache;
    final repo = ref.read(cashierRepositoryProvider);
    _repoCache = repo;
    return repo;
  }

  /// `null` quando o módulo `sale` não está disponível para este tenant/cargo —
  /// o provider lança por padrão, e o Caixa funciona sem vendas (o extrato só
  /// deixa de mostrar o cliente da venda). Ler aqui, protegido, mantém as duas
  /// garantias: nada de `ref` após `await`, e degradar em vez de derrubar a tela.
  SaleRepository? _salesCache;
  bool _salesLido = false;

  /// Mesmo padrão do [_repo], com a diferença de que a AUSÊNCIA é um estado
  /// válido (módulo `sale` não contratado) — daí o flag separado, para não
  /// reconsultar o provider que lança a cada leitura.
  SaleRepository? get _sales {
    if (!_salesLido) {
      _salesLido = true;
      try {
        _salesCache = ref.read(saleRepositoryProvider);
      } on Object {
        _salesCache = null;
      }
    }
    return _salesCache;
  }

  @override
  Future<CashierState> build() {
    // Toca os dois ANTES de qualquer await: mantém a garantia original de nunca
    // usar `ref` depois de uma chamada de rede. Os getters cuidam do caso em que
    // um método chega primeiro.
    _repo;
    _sales;
    return _load();
  }

  /// Janela do dia de HOJE em hora LOCAL, convertida para UTC (o backend recorta
  /// `created_at`, que é timestamptz).
  ///
  /// O fim é o último instante do dia, não "agora": o dia é o dia inteiro, e um
  /// lançamento feito um segundo depois desta leitura ainda pertence a ele.
  ({String from, String to}) _janelaDeHoje() {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month, agora.day);
    final fim = inicio.add(const Duration(days: 1)).subtract(
          const Duration(milliseconds: 1),
        );
    return (
      from: inicio.toUtc().toIso8601String(),
      to: fim.toUtc().toIso8601String(),
    );
  }

  Future<CashierState> _load() async {
    final config = await _repo.fetchConfig();
    final session = await _repo.currentSession();
    // O recorte do "Caixa do dia" depende do MODO, não da existência de sessão:
    //
    //  - **com** cerimônia de abrir/fechar, o caixa É a sessão: o extrato dela,
    //    mesmo que atravesse a meia-noite (a gaveta ainda não foi conferida);
    //  - **sem** cerimônia (o padrão), o caixa é o DIA: meia-noite local até o
    //    fim do dia, virando por data.
    //
    // Isto não era um `if` sobre `session != null` por acidente: com a exigência
    // desligada o backend cria uma sessão IMPLÍCITA no primeiro lançamento e
    // nunca a fecha. Escolher por ela fazia "Caixa do dia" mostrar tudo desde
    // aquela sessão — semanas de movimento — e nunca virar de data.
    final dia = _janelaDeHoje();
    final page = session != null && config.requireOpenSession
        ? await _repo.listEntries(sessionId: session.id)
        : await _repo.listEntries(from: dia.from, to: dia.to);
    // Vendas de hoje, para o extrato mostrar o cliente. `sale` é contratável:
    // sem o módulo (ou sem permissão) o backend recusa e o caixa segue normal.
    List<Sale> sales = const [];
    final sale = _sales;
    if (sale != null) {
      try {
        final page = await sale.listSales(from: dia.from, to: dia.to);
        sales = page.items;
      } catch (_) {
        // Sem o módulo/permissão o backend recusa — o caixa segue normal.
        sales = const [];
      }
    }
    return CashierState(
      session: session,
      entries: page.items,
      config: config,
      sales: sales,
    );
  }

  Future<void> _refresh() async {
    // guard mantém os dados anteriores visíveis enquanto recarrega (sem flash).
    state = await AsyncValue.guard(_load);
  }

  Future<void> open({double? openingAmount, String? notes}) async {
    await _repo.openSession(openingAmount: openingAmount, notes: notes);
    await _refresh();
  }

  Future<CashSession> close({required double countedAmount, String? notes}) async {
    final closed =
        await _repo.closeSession(countedAmount: countedAmount, notes: notes);
    await _refresh();
    return closed;
  }

  Future<void> addEntry(EntryDraft draft) async {
    await _repo.createEntry(draft);
    await _refresh();
  }

  Future<void> reverse(String entryId, String reason) async {
    await _repo.reverseEntry(entryId, reason);
    await _refresh();
  }
}

/// `autoDispose`: o estado morre ao sair da tela e é remontado ao voltar.
///
/// Sem isso o provider vivia para o app inteiro e guardava a CONFIG carregada no
/// primeiro mount — quem desligava "exigir caixa aberto" em Configurações e
/// voltava continuava caindo na tela "abra o caixa", porque a config em memória
/// ainda dizia `true`. Além de corrigir isso, recarregar é o comportamento certo
/// numa tela de dinheiro: os lançamentos podem ter mudado em outro aparelho.
final cashierControllerProvider =
    AsyncNotifierProvider.autoDispose<CashierController, CashierState>(
        CashierController.new);

// ===================== Histórico do caixa (movimentos por período) =====================

/// Preset de período do Histórico do Caixa (relatório baseado nos MOVIMENTOS do
/// caixa — o que de fato entrou/saiu). 'hoje' | '7d' | '30d'.
final cashierHistoryPresetProvider =
    NotifierProvider<CashierHistoryPreset, String>(CashierHistoryPreset.new);

class CashierHistoryPreset extends Notifier<String> {
  @override
  String build() => '7d';
  void set(String preset) => state = preset;
}

/// Filtro de tipo do histórico (tudo/vendas/entradas/saídas/despesas).
final cashierHistoryFilterProvider =
    NotifierProvider<CashierHistoryFilter, CashierFilter>(
        CashierHistoryFilter.new);

class CashierHistoryFilter extends Notifier<CashierFilter> {
  @override
  CashierFilter build() => CashierFilter.tudo;
  void set(CashierFilter v) => state = v;
}

/// Busca textual do histórico (cliente, número, item, descrição).
final cashierHistoryBuscaProvider =
    NotifierProvider<CashierHistoryBusca, String>(CashierHistoryBusca.new);

class CashierHistoryBusca extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

/// Início do período de um preset ('hoje' | '7d' | '30d').
DateTime periodStart(String preset, DateTime now) => switch (preset) {
      'hoje' => DateTime(now.year, now.month, now.day),
      '30d' => now.subtract(const Duration(days: 30)),
      _ => now.subtract(const Duration(days: 7)),
    };

/// Dados do Histórico do Caixa no período: totais (por método/origem), extrato e
/// as VENDAS do mesmo recorte.
///
/// As vendas vêm juntas por dois motivos: alimentam a lente "Vendas" (o que foi
/// vendido, para quem, quando) e permitem que a linha do extrato mostre o
/// cliente — o lançamento do caixa guarda só `sale_id`, então sem este mapa o
/// movimento seria eternamente "Venda avulsa · R$ 150" sem dizer de quem.
class CashierHistoryData {
  const CashierHistoryData({
    required this.summary,
    required this.entries,
    this.sales = const [],
  });

  final CashSummary summary;
  final List<CashEntry> entries;
  final List<Sale> sales;

  /// Venda por id — usado para enriquecer as linhas do extrato.
  Map<String, Sale> get salesById => {for (final s in sales) s.id: s};
}

final cashierHistoryProvider =
    FutureProvider.autoDispose<CashierHistoryData>((ref) async {
  final preset = ref.watch(cashierHistoryPresetProvider);
  final filtro = ref.watch(cashierHistoryFilterProvider);
  final busca = ref.watch(cashierHistoryBuscaProvider).trim();
  final now = DateTime.now();
  final fromIso = periodStart(preset, now).toUtc().toIso8601String();
  final toIso = now.toUtc().toIso8601String();
  final repo = ref.read(cashierRepositoryProvider);
  final summary = await repo.summary(from: fromIso, to: toIso);

  // Os filtros vão ao SERVIDOR (e ao espelho SQLite quando offline), não a uma
  // página já carregada: filtrar em memória quebraria a paginação e daria
  // resultado diferente conforme a conexão.
  final q = busca.isEmpty ? null : busca;
  final soVendas = filtro == CashierFilter.vendas;
  final page = soVendas
      // Filtro "Vendas": não há lançamento a listar.
      ? const EntryPage()
      : await repo.listEntries(
          from: fromIso,
          to: toIso,
          q: q,
          direction: switch (filtro) {
            CashierFilter.entradas => 'in',
            CashierFilter.saidas => 'out',
            _ => null,
          },
          category: filtro == CashierFilter.despesas ? 'despesa' : null,
          page: 1,
        );
  // `sale` é módulo contratável: sem ele (ou sem permissão) o backend recusa.
  // A ausência de vendas não pode derrubar o histórico do caixa.
  // Saídas e despesas são movimento de dinheiro — venda não entra nessas lentes.
  final incluiVendas = filtro != CashierFilter.saidas &&
      filtro != CashierFilter.despesas;
  List<Sale> sales = const [];
  if (incluiVendas) {
    try {
      final vendas = await ref.read(saleRepositoryProvider).listSales(
            from: fromIso,
            to: toIso,
            q: q,
            page: 1,
          );
      sales = vendas.items;
    } catch (_) {
      sales = const [];
    }
  }
  return CashierHistoryData(
    summary: summary,
    entries: page.items,
    sales: sales,
  );
});

// Os providers de "despesa fixa" saíram com a UI que os consumia: o que se
// repete todo mês virou uma RECORRÊNCIA no módulo `Despesas`, que tem
// vencimento e baixa — não um preset de valor para digitar no caixa.
//
// Os métodos correspondentes seguem no `CashierRepository`: as rotas
// `/cashier/expense-templates` e as ops de sync ainda existem no backend, e
// removê-las é uma limpeza própria (migration não apaga tabela).
