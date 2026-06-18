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

  /// Adiciona uma nota à linha do tempo da OS. `visiblePublic` controla se o
  /// cliente a vê no acompanhamento. Retorna a OS atualizada (com `events`).
  Future<ServiceOrder> createNote(
    String id, {
    required String message,
    required bool visiblePublic,
  });

  // ---- fotos ----
  /// Anexa uma foto à OS (multipart `file`). Retorna a OS atualizada (com `photos`).
  Future<ServiceOrder> addPhoto(
    String orderId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? caption,
  });

  /// Remove (soft no backend) uma foto da OS. Retorna a OS atualizada.
  Future<ServiceOrder> deletePhoto(String orderId, String photoId);

  // ---- templates ----
  /// Templates de OS disponíveis (`GET /os/templates`).
  Future<List<OsTemplate>> listTemplates();

  /// Templates com seus itens (`GET /os/templates` — para a tela de gestão).
  Future<List<OsTemplate>> listTemplatesFull();

  /// Um template com seus itens (`GET /os/templates/:id`).
  Future<OsTemplate> getTemplate(String id);

  /// Cria um template (`POST /os/templates`). Exige `os.write`.
  Future<OsTemplate> createTemplate(OsTemplateDraft draft);

  /// Atualiza um template (`PATCH /os/templates/:id`). Exige `os.write`.
  Future<OsTemplate> updateTemplate(String id, OsTemplateDraft draft);

  /// Remove um template (`DELETE /os/templates/:id`). Exige `os.write`.
  Future<void> deleteTemplate(String id);

  /// Aplica um template à OS (adiciona os itens). Retorna a OS atualizada.
  Future<ServiceOrder> applyTemplate(String orderId, String templateId);

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

  /// Membros da equipe (`GET /employees`) para o dropdown "Responsável" da OS.
  /// `MemberOption.id` é o uuid do membro (o backend valida `assignedTo` como
  /// uuid). "Aponta, não invade": só lemos a lista pública de membros.
  Future<List<MemberOption>> listMembers();

  /// Config do módulo de clientes (`GET /customers/config`): usamos `usaSubjects`
  /// para decidir se mostramos a seção de veículo ao cadastrar cliente novo, e
  /// `subjectLabel.singular` como rótulo dessa seção. "Aponta, não invade".
  Future<CustomersConfig> customersConfig();
}
