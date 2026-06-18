import '../../customers/domain/customers_models.dart';
import 'os_models.dart';

/// Contrato do módulo Ordens de Serviço. O backend é a verdade (RLS +
/// permissões + gating de módulo + FSM de status); o cliente só reflete para
/// UX. Impl real (dio) + fake, trocadas por injeção Riverpod. A UI nunca fala
/// com o dio direto.
abstract interface class OsRepository {
  // ---- orders ----
  Future<OrderPage> listOrders({
    String? q,
    String? status,
    String? customerId,
    int page,
  });
  Future<ServiceOrder> getOrder(String id);
  Future<ServiceOrder> createOrder(OrderDraft draft);
  Future<ServiceOrder> updateOrder(String id, OrderPatch patch);

  /// Soft delete (status 'cancelada'/baixa lógica no backend); some das listas.
  Future<void> deleteOrder(String id);

  /// Transição de status (FSM no backend). `aprovada` exige `os.approve`.
  Future<ServiceOrder> changeStatus(String id, String status);

  // ---- items ----
  Future<ServiceOrder> addItem(String id, OrderItemDraft draft);
  Future<ServiceOrder> updateItem(String id, String itemId, OrderItemPatch patch);
  Future<ServiceOrder> deleteItem(String id, String itemId);

  // ---- pickers (reúsam serviços públicos de outros módulos) ----
  /// Itens do estoque (produtos + serviços ativos) para adicionar à OS.
  Future<List<InventoryOption>> searchInventory(String q);

  /// Clientes (autocomplete da "Nova OS").
  Future<List<CustomerOption>> searchCustomers(String q);

  /// Veículos/subjects do cliente selecionado.
  Future<List<SubjectOption>> subjectsOf(String customerId);

  /// Config do módulo de clientes (`GET /customers/config`): usamos `usaSubjects`
  /// para decidir se mostramos a seção de veículo ao cadastrar cliente novo, e
  /// `subjectLabel.singular` como rótulo dessa seção. "Aponta, não invade".
  Future<CustomersConfig> customersConfig();
}
