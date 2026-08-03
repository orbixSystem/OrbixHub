import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sale/domain/sale_models.dart';
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
  CashierRepository get _repo => ref.read(cashierRepositoryProvider);

  @override
  Future<CashierState> build() => _load();

  Future<CashierState> _load() async {
    final config = await _repo.fetchConfig();
    final session = await _repo.currentSession();
    // Com sessão: o extrato dela. Sem sessão (caixa sem cerimônia de abertura):
    // os lançamentos de HOJE — sem recorte, `listEntries` traria o histórico
    // inteiro paginado, que não é "o caixa de hoje".
    final hoje = DateTime.now();
    final page = session != null
        ? await _repo.listEntries(sessionId: session.id)
        : await _repo.listEntries(
            from: DateTime(hoje.year, hoje.month, hoje.day)
                .toUtc()
                .toIso8601String(),
            to: hoje.toUtc().toIso8601String(),
          );
    // Vendas de hoje, para o extrato mostrar o cliente. `sale` é contratável:
    // sem o módulo (ou sem permissão) o backend recusa e o caixa segue normal.
    List<Sale> sales = const [];
    try {
      final agora = DateTime.now();
      final page = await ref.read(saleRepositoryProvider).listSales(
            from: DateTime(agora.year, agora.month, agora.day)
                .toUtc()
                .toIso8601String(),
            to: agora.toUtc().toIso8601String(),
          );
      sales = page.items;
    } catch (_) {
      sales = const [];
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

final cashierControllerProvider =
    AsyncNotifierProvider<CashierController, CashierState>(CashierController.new);

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
