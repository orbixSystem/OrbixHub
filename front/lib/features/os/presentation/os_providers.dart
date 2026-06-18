import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/os_models.dart';
import '../domain/os_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final osRepositoryProvider = Provider<OsRepository>((ref) {
  throw UnimplementedError(
      'osRepositoryProvider must be overridden in di.dart');
});

/// Filtros correntes da lista de OS.
class OrderListQuery {
  const OrderListQuery({this.q, this.status});

  final String? q;
  final String? status; // null = todas

  OrderListQuery copyWith({String? q, Object? status = _sentinel}) =>
      OrderListQuery(
        q: q ?? this.q,
        status: status == _sentinel ? this.status : status as String?,
      );

  static const _sentinel = Object();
}

/// Estado dos filtros (busca + status).
class OrderListQueryNotifier extends Notifier<OrderListQuery> {
  @override
  OrderListQuery build() => const OrderListQuery();

  void setQuery(String value) =>
      state = state.copyWith(q: value.trim().isEmpty ? null : value.trim());

  /// Filtro de status: null = todas.
  void setStatus(String? status) => state = state.copyWith(status: status);
}

final orderListQueryProvider =
    NotifierProvider<OrderListQueryNotifier, OrderListQuery>(
        OrderListQueryNotifier.new);

/// Lista de OS — reage aos filtros. autoDispose para re-buscar ao reentrar.
final orderListProvider = FutureProvider.autoDispose<OrderPage>((ref) {
  final query = ref.watch(orderListQueryProvider);
  return ref.read(osRepositoryProvider).listOrders(
        q: query.q,
        status: query.status,
      );
});

/// Uma OS por id (tela de detalhe).
final orderProvider =
    FutureProvider.autoDispose.family<ServiceOrder, String>((ref, id) {
  return ref.read(osRepositoryProvider).getOrder(id);
});
