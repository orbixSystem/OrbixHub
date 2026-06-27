import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cashier_models.dart';
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
  });

  final CashSession? session;
  final List<CashEntry> entries;
  final CashierConfig config;

  bool get isOpen => session != null;
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
    final page = await _repo.listEntries(sessionId: session?.id);
    return CashierState(session: session, entries: page.items, config: config);
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
