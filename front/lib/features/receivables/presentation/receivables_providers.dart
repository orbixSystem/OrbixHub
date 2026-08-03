import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final debtorsProvider = FutureProvider.autoDispose<DebtorsPage>((ref) {
  return ref.read(receivablesRepositoryProvider).listDebtors();
});

/// Títulos em aberto de um cliente (`null` = vendas sem cliente identificado).
final debtorTitlesProvider =
    FutureProvider.autoDispose.family<DebtorDetail, String?>((ref, customerId) {
  return ref.read(receivablesRepositoryProvider).titlesOf(customerId);
});
