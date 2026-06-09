import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../domain/customers_models.dart';

/// Config do módulo (rótulo/campos dinâmicos). Estável na sessão; não autoDispose.
final customersConfigProvider = FutureProvider<CustomersConfig>((ref) {
  return ref.read(customersRepositoryProvider).fetchConfig();
});

/// Busca corrente da lista de clientes (nome/documento/telefone).
class CustomerQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final customerQueryProvider =
    NotifierProvider<CustomerQuery, String>(CustomerQuery.new);

/// Toggle "Arquivados": off = só ativos; on = SÓ arquivados (nunca os dois ao
/// mesmo tempo, nunca os soft-deleted).
class ShowArchived extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final showArchivedProvider =
    NotifierProvider<ShowArchived, bool>(ShowArchived.new);

/// Lista de clientes — reage à busca/toggle. autoDispose para re-buscar ao reentrar.
final customersListProvider = FutureProvider.autoDispose<CustomerPage>((ref) {
  final q = ref.watch(customerQueryProvider);
  final showArchived = ref.watch(showArchivedProvider);
  return ref.read(customersRepositoryProvider).listCustomers(
        q: q.trim().isEmpty ? null : q.trim(),
        status: showArchived ? 'archived' : 'active',
      );
});

/// Um cliente por id (tela de detalhe).
final customerProvider =
    FutureProvider.autoDispose.family<Customer, String>((ref, id) {
  return ref.read(customersRepositoryProvider).getCustomer(id);
});

/// Subjects de um cliente.
final subjectsForCustomerProvider =
    FutureProvider.autoDispose.family<SubjectPage, String>((ref, customerId) {
  return ref
      .read(customersRepositoryProvider)
      .listSubjects(customerId: customerId);
});

/// Filtro da timeline do cliente: id do veículo selecionado (null = todos).
typedef CustomerHistoryArgs = ({String customerId, String? subjectId});

/// Timeline do cliente (vazia até a OS existir), com filtro opcional por carro.
final customerHistoryProvider = FutureProvider.autoDispose
    .family<List<SubjectHistoryEntry>, CustomerHistoryArgs>((ref, args) {
  return ref
      .read(customersRepositoryProvider)
      .customerHistory(args.customerId, subjectId: args.subjectId);
});
