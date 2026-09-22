import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// `connectivityControllerProvider` vive no composition root (mesmo caminho que o
// `session_controller` usa).
import '../../../di.dart';
import '../domain/receivables_models.dart';
import '../domain/receivables_query.dart';
import '../domain/receivables_repository.dart';

/// Declarado aqui (lança por padrão) e ganha a impl real (dio) em `di.dart`,
/// espelhando os demais repos. Testes sobrescrevem com o fake.
final receivablesRepositoryProvider = Provider<ReceivablesRepository>((ref) {
  throw UnimplementedError(
      'receivablesRepositoryProvider deve ser sobrescrito em di.dart');
});

/// Filtros correntes do "A receber".
///
/// autoDispose: sair da tela zera busca e filtros — mesma decisão do Estoque,
/// onde uma busca abandonada continuava filtrando quando a pessoa voltava e a
/// caixa em branco mentia.
class DebtorsQueryNotifier extends Notifier<DebtorsQuery> {
  Timer? _debounce;

  @override
  DebtorsQuery build() {
    ref.onDispose(() => _debounce?.cancel());
    return const DebtorsQuery();
  }

  /// Busca com espera: cada mudança deste estado re-busca a carteira inteira,
  /// então publicar a cada tecla dispararia uma requisição por letra.
  void setQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      final novo = q.isEmpty ? null : q;
      if (novo == state.q) return;
      state = state.copyWith(q: novo, page: 1);
    });
  }

  // Trocar filtro/ordem volta para a página 1: a página 3 do filtro antigo
  // pode nem existir no novo.
  void setVencimento(VencimentoFiltro v) =>
      state = state.copyWith(vencimento: v, page: 1);
  void setOrigem(OrigemFiltro o) => state = state.copyWith(origem: o, page: 1);
  void setSort(OrdemDevedores s) => state = state.copyWith(sort: s, page: 1);
  void goToPage(int p) => state = state.copyWith(page: p < 1 ? 1 : p);

  /// Zera o que esconde, preservando a ordenação escolhida.
  void clearFilters() => state = DebtorsQuery(sort: state.sort);
}

final debtorsQueryProvider =
    NotifierProvider.autoDispose<DebtorsQueryNotifier, DebtorsQuery>(
        DebtorsQueryNotifier.new);

/// Carteira do "A receber" (página de devedores + totais da carteira inteira).
///
/// Observa o STATUS da conexão porque a carteira tem duas fontes: online vem do
/// servidor, offline é derivada do espelho local. Sem isto, quem abriu a tela
/// sem internet continuaria vendo a carteira do aparelho depois da conexão voltar.
final debtorsProvider = FutureProvider.autoDispose<DebtorsPage>((ref) {
  ref.watch(connectivityControllerProvider.select((s) => s.status));
  final query = ref.watch(debtorsQueryProvider);
  return ref.read(receivablesRepositoryProvider).listDebtors(query);
});

/// Títulos em aberto de um cliente (`null` = vendas sem cliente identificado).
/// Os títulos por trás do aviso "N finalizados não passaram pelo caixa".
/// Carregado só quando o operador abre o drill-down — o resumo já vem no
/// [debtorsProvider], então a lista não precisa custar nada no caminho comum.
final pendingSettlementProvider =
    FutureProvider.autoDispose<OpenTitlesPage>((ref) {
  ref.watch(connectivityControllerProvider.select((s) => s.status));
  return ref.read(receivablesRepositoryProvider).listPendingSettlement();
});

/// Chave do detalhe de um devedor.
///
/// Inclui o APELIDO porque venda de balcão não tem cliente cadastrado: com a
/// chave sendo só o `customerId`, dois apelidos diferentes (ambos com id nulo)
/// compartilhariam a MESMA entrada de cache e um veria os títulos do outro —
/// o mesmo bug que o servidor tinha, reproduzido no cliente.
typedef DebtorKey = ({String? customerId, String? apelido});

final debtorTitlesProvider =
    FutureProvider.autoDispose.family<DebtorDetail, DebtorKey>((ref, k) {
  ref.watch(connectivityControllerProvider.select((s) => s.status));
  return ref
      .read(receivablesRepositoryProvider)
      .titlesOf(k.customerId, apelido: k.apelido);
});
