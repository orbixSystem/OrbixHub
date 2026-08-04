import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/expense_models.dart';
import '../domain/expenses_repository.dart';

/// Declarado aqui (lança por padrão) e ganha a impl concreta em `di.dart`,
/// espelhando os demais repos. Testes sobrescrevem com o fake.
final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  throw UnimplementedError(
      'expensesRepositoryProvider deve ser sobrescrito em di.dart');
});

/// Mês em foco na tela (dia sempre 1 — o recorte é o mês inteiro).
class MesEmFocoNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month);
  }

  void definir(DateTime mes) => state = DateTime(mes.year, mes.month);

  /// `month ± 1` fora da faixa 1..12 é normalizado pelo próprio [DateTime]
  /// (mês 13 vira janeiro do ano seguinte), então não precisa de caso especial
  /// na virada do ano.
  void avancar() => state = DateTime(state.year, state.month + 1);
  void voltar() => state = DateTime(state.year, state.month - 1);
  void hoje() {
    final agora = DateTime.now();
    state = DateTime(agora.year, agora.month);
  }
}

final mesEmFocoProvider =
    NotifierProvider<MesEmFocoNotifier, DateTime>(MesEmFocoNotifier.new);

/// Contas do mês em foco. `autoDispose` para revalidar ao voltar à tela: marcar
/// uma conta como paga em outro aparelho muda o que se vê aqui.
final despesasDoMesProvider =
    FutureProvider.autoDispose<ExpensesMonth>((ref) {
  final mes = ref.watch(mesEmFocoProvider);
  return ref.read(expensesRepositoryProvider).listarMes(
        ano: mes.year,
        mes: mes.month,
      );
});

/// Filtro da tela. `todas` é o default: a cliente abre para ver o mês, não para
/// caçar um estado específico.
enum FiltroDespesa { todas, emAberto, vencidas, pagas }

class FiltroDespesaNotifier extends Notifier<FiltroDespesa> {
  @override
  FiltroDespesa build() => FiltroDespesa.todas;

  void definir(FiltroDespesa f) => state = f;
}

final filtroDespesaProvider =
    NotifierProvider<FiltroDespesaNotifier, FiltroDespesa>(
        FiltroDespesaNotifier.new);
