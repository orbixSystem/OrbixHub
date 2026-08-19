import 'package:flutter_riverpod/flutter_riverpod.dart';

// `connectivityControllerProvider` vive no composition root (mesmo caminho que o
// `session_controller` usa).
import '../../../di.dart';
import '../domain/receivables_models.dart';
import '../domain/receivables_repository.dart';

/// Declarado aqui (lança por padrão) e ganha a impl real (dio) em `di.dart`,
/// espelhando os demais repos. Testes sobrescrevem com o fake.
final receivablesRepositoryProvider = Provider<ReceivablesRepository>((ref) {
  throw UnimplementedError(
      'receivablesRepositoryProvider deve ser sobrescrito em di.dart');
});

/// Carteira de fiado (devedores + total). `autoDispose` para revalidar ao voltar
/// à aba — receber um fiado muda o saldo e a lista precisa refletir.
///
/// Observa o STATUS da conexão porque a carteira tem duas fontes: online vem do
/// servidor, offline é derivada do espelho local. Sem isto, quem abriu a aba sem
/// internet continuaria vendo a carteira do aparelho depois da conexão voltar.
final debtorsProvider = FutureProvider.autoDispose<DebtorsPage>((ref) {
  ref.watch(connectivityControllerProvider.select((s) => s.status));
  return ref.read(receivablesRepositoryProvider).listDebtors();
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

final debtorTitlesProvider =
    FutureProvider.autoDispose.family<DebtorDetail, String?>((ref, customerId) {
  ref.watch(connectivityControllerProvider.select((s) => s.status));
  return ref.read(receivablesRepositoryProvider).titlesOf(customerId);
});
