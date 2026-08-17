import 'package:freezed_annotation/freezed_annotation.dart';

part 'os_models.freezed.dart';
part 'os_models.g.dart';

/// Item de uma ordem de serviço. `kind ∈ product|service`. Pode apontar para um
/// item do estoque (`inventoryItemId`) — guardamos só o id + um *snapshot* do
/// nome/preço no momento da adição ("aponta, não invade"). Decimais como String.
/// Campos de agenda: `assignedTo`, `scheduledStart`, `estimatedDuration`, `scheduledEnd`.
@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String id,
    @Default('product') String kind, // 'product' | 'service'
    @JsonKey(name: 'inventory_item_id') String? inventoryItemId,
    required String name,
    @Default('1') String quantity,
    @JsonKey(name: 'unit_price') @Default('0') String unitPrice,
    @Default('0') String discount,
    @Default('0') String total,
    // Agenda
    @JsonKey(name: 'assigned_to') String? assignedTo,
    @JsonKey(name: 'scheduled_start') String? scheduledStart,
    @JsonKey(name: 'estimated_duration') int? estimatedDuration,
    @JsonKey(name: 'scheduled_end') String? scheduledEnd,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

/// Evento da linha do tempo da OS (criação, troca de status, nota, foto). Vem
/// do backend já em ordem decrescente (mais recente primeiro). `message` é a
/// descrição livre; `statusSnapshot` registra o status no momento (útil em
/// `status_change`); `visiblePublic` indica se o evento é exibido ao cliente.
@freezed
abstract class OrderEvent with _$OrderEvent {
  const factory OrderEvent({
    required String id,
    @Default('note') String kind, // 'created' | 'status_change' | 'note' | 'photo'
    String? message,
    @JsonKey(name: 'status_snapshot') String? statusSnapshot,
    @JsonKey(name: 'visible_public') @Default(false) bool visiblePublic,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _OrderEvent;

  factory OrderEvent.fromJson(Map<String, dynamic> json) =>
      _$OrderEventFromJson(json);
}

/// Foto anexada à OS. O backend devolve `url` já utilizável em `Image.network`
/// (provider local: `http://localhost:4500/files/...`). `caption` é opcional.
@freezed
abstract class OrderPhoto with _$OrderPhoto {
  const factory OrderPhoto({
    required String id,
    required String url,
    String? caption,
    // Nº de comentários na foto — badge na miniatura (0 = sem selo).
    @JsonKey(name: 'comment_count') @Default(0) int commentCount,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _OrderPhoto;

  factory OrderPhoto.fromJson(Map<String, dynamic> json) =>
      _$OrderPhotoFromJson(json);
}

/// Comentário numa foto da OS (thread). `authorKind ∈ 'staff'|'customer'`.
/// A API de comentários responde em camelCase (igual ao endpoint público) —
/// snake_case aqui fazia todo comentário cair no default 'staff' ("Equipe").
@freezed
abstract class PhotoComment with _$PhotoComment {
  const factory PhotoComment({
    @Default('staff') String authorKind,
    String? authorName,
    @Default('') String body,
    String? createdAt,
  }) = _PhotoComment;

  factory PhotoComment.fromJson(Map<String, dynamic> json) =>
      _$PhotoCommentFromJson(json);
}

/// Item de um template de OS. Igual ao item de OS, mas sem totais calculados:
/// `kind ∈ product|service`, aponta para o estoque (`inventoryItemId`) OU é
/// avulso (`name`). Decimais como String.
@freezed
abstract class OsTemplateItem with _$OsTemplateItem {
  const factory OsTemplateItem({
    String? id,
    @Default('product') String kind, // 'product' | 'service'
    @JsonKey(name: 'inventory_item_id') String? inventoryItemId,
    @Default('') String name,
    @Default('1') String quantity,
    @JsonKey(name: 'unit_price') String? unitPrice,
  }) = _OsTemplateItem;

  factory OsTemplateItem.fromJson(Map<String, dynamic> json) =>
      _$OsTemplateItemFromJson(json);
}

/// Template de OS (`GET /os/templates`): um conjunto de itens reaproveitável que
/// pode ser aplicado a uma OS (`POST /os/orders/:id/apply-template/:templateId`).
@freezed
abstract class OsTemplate with _$OsTemplate {
  const factory OsTemplate({
    required String id,
    required String name,
    String? description,
    @Default(<OsTemplateItem>[]) List<OsTemplateItem> items,
    // Soma (quantidade × preço corrente do estoque) calculada pelo backend.
    String? total,
  }) = _OsTemplate;

  factory OsTemplate.fromJson(Map<String, dynamic> json) =>
      _$OsTemplateFromJson(json);
}

/// Uma página de templates (busca server-side em `GET /os/templates`):
/// itens da página + total do conjunto filtrado. `hasMore` indica se há mais
/// páginas a carregar (rolagem infinita). Classe simples — não precisa freezed.
class OsTemplatePage {
  const OsTemplatePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<OsTemplate> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;
}

/// Draft de item de template (create/update). `inventoryItemId` aponta para o
/// estoque OU usa `name`/`unitPrice` para item avulso.
class OsTemplateItemDraft {
  const OsTemplateItemDraft({
    this.kind = 'product',
    this.inventoryItemId,
    this.name,
    this.quantity,
    this.unitPrice,
  });

  final String kind; // 'product' | 'service'
  final String? inventoryItemId;
  final String? name;
  final double? quantity;
  final double? unitPrice;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        if (name != null) 'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
      };
}

/// Draft de criação/edição de template (POST/PATCH). Só envia campos presentes.
class OsTemplateDraft {
  const OsTemplateDraft({
    required this.name,
    this.description,
    this.items = const <OsTemplateItemDraft>[],
  });

  final String name;
  final String? description;
  final List<OsTemplateItemDraft> items;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

/// Ordem de serviço. Aponta para cliente/veículo de outros módulos por id e
/// guarda um retrato (`customerName`/`subjectLabel`) para histórico. `status`
/// segue a FSM do backend. Decimais (`discount`/`total`) chegam como String.
@freezed
abstract class ServiceOrder with _$ServiceOrder {
  const factory ServiceOrder({
    required String id,
    required String number,
    @JsonKey(name: 'customer_id') required String customerId,
    @JsonKey(name: 'customer_name') String? customerName,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'subject_label') String? subjectLabel,
    @Default('aberta') String status,
    @JsonKey(name: 'assigned_to') String? assignedTo,
    @JsonKey(name: 'assigned_to_name') String? assignedToName,
    String? complaint,
    String? diagnosis,
    @JsonKey(name: 'scheduled_start') String? scheduledStart,
    @JsonKey(name: 'scheduled_end') String? scheduledEnd,
    @JsonKey(name: 'started_at') String? startedAt,
    @JsonKey(name: 'finished_at') String? finishedAt,
    @JsonKey(name: 'public_token') String? publicToken,
    String? discount,
    String? total,
    // Status de pagamento DERIVADO do caixa (a_receber | parcial | pago). Vem
    // flat tanto na listagem quanto no detalhe; a venda nasce 'a_receber'.
    @JsonKey(name: 'payment_status')
    @Default('a_receber')
    String paymentStatus,
    // Snapshot do status fiscal (o Fiscal é dono): nao_emitida|processando|emitida|rejeitada.
    @JsonKey(name: 'fiscal_status') String? fiscalStatus,
    // Conversa (chat) desta OS — atalho staff para /mensagens/:id. Só no detalhe.
    @JsonKey(name: 'conversation_id') String? conversationId,
    @Default(<OrderItem>[]) List<OrderItem> items,
    @Default(<OrderEvent>[]) List<OrderEvent> events,
    @Default(<OrderPhoto>[]) List<OrderPhoto> photos,
    @JsonKey(name: 'created_at') String? createdAt,
    // Resumo de pagamento — o mesmo objeto que já vem embutido em toda
    // resposta de OS (derivado do caixa, "aponta, não invade": a OS não sabe
    // COMO o pagamento é calculado, só reflete o resultado). `paymentStatus`
    // acima é só a tag; aqui vêm os valores para "Finalizar" oferecer
    // recebimento e para o botão "Receber pagamento" saber o saldo.
    OsPaymentSummary? payment,
  }) = _ServiceOrder;

  factory ServiceOrder.fromJson(Map<String, dynamic> json) =>
      _$ServiceOrderFromJson(json);
}

/// Total/pago/saldo da OS — espelha `PaymentDetail` do módulo caixa (mesma
/// forma, sem a lista de lançamentos: a OS só precisa dos números).
@freezed
abstract class OsPaymentSummary with _$OsPaymentSummary {
  const factory OsPaymentSummary({
    @Default(0) num total,
    @Default(0) num paid,
    @Default(0) num balance,
    @Default('a_receber') String status,
  }) = _OsPaymentSummary;

  factory OsPaymentSummary.fromJson(Map<String, dynamic> json) =>
      _$OsPaymentSummaryFromJson(json);
}

/// Página de ordens (`GET /os/orders`).
@freezed
abstract class OrderPage with _$OrderPage {
  const factory OrderPage({
    @Default(<ServiceOrder>[]) List<ServiceOrder> items,
    @Default(0) int total,
    @Default(1) int page,
    @Default(20) int pageSize,
  }) = _OrderPage;

  factory OrderPage.fromJson(Map<String, dynamic> json) =>
      _$OrderPageFromJson(json);
}

/// Draft de criação de OS. Só envia campos não-nulos. Chaves em camelCase
/// (o backend espera `customerId`, `subjectId`, `scheduledStart`, …).
///
/// Aceita DOIS caminhos (o backend exige um dos dois):
/// - **cliente existente:** `customerId` (+ `subjectId` opcional);
/// - **cliente novo na hora:** `newCustomerName` (obrigatório) + opcionalmente
///   `newCustomerPhone`, `newSubjectIdentifier` (placa/identificação) e
///   `newSubjectAttributes` (ex.: `{marca, modelo}`).
class OrderDraft {
  const OrderDraft({
    this.customerId,
    this.subjectId,
    this.newCustomerName,
    this.newCustomerPhone,
    this.newSubjectIdentifier,
    this.newSubjectAttributes,
    this.newSubjectPlateData,
    this.complaint,
    this.diagnosis,
    this.scheduledStart,
    this.scheduledEnd,
    this.assignedTo,
    this.discount,
  });

  final String? customerId;
  final String? subjectId;
  final String? newCustomerName;
  final String? newCustomerPhone;
  final String? newSubjectIdentifier;
  final Map<String, dynamic>? newSubjectAttributes;

  /// Retorno da consulta por placa do veículo criado junto com a OS —
  /// persistido nas colunas exclusivas do veículo (alimenta a ficha depois).
  final Map<String, dynamic>? newSubjectPlateData;
  final String? complaint;
  final String? diagnosis;
  final String? scheduledStart;
  final String? scheduledEnd;
  final String? assignedTo;

  /// Desconto do cabeçalho fechado já na abertura (a OS nasce sem itens; o
  /// total passa a considerá-lo quando o primeiro item entra).
  final double? discount;

  Map<String, dynamic> toJson() => {
        if (customerId != null) 'customerId': customerId,
        if (subjectId != null) 'subjectId': subjectId,
        if (newCustomerName != null) 'newCustomerName': newCustomerName,
        if (newCustomerPhone != null) 'newCustomerPhone': newCustomerPhone,
        if (newSubjectIdentifier != null)
          'newSubjectIdentifier': newSubjectIdentifier,
        if (newSubjectAttributes != null && newSubjectAttributes!.isNotEmpty)
          'newSubjectAttributes': newSubjectAttributes,
        if (newSubjectPlateData != null)
          'newSubjectPlateData': newSubjectPlateData,
        if (complaint != null) 'complaint': complaint,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (scheduledStart != null) 'scheduledStart': scheduledStart,
        if (scheduledEnd != null) 'scheduledEnd': scheduledEnd,
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (discount != null) 'discount': discount,
      };
}

/// Patch de edição de OS (PATCH). Só envia campos presentes.
class OrderPatch {
  const OrderPatch({
    this.complaint,
    this.diagnosis,
    this.scheduledStart,
    this.scheduledEnd,
    this.assignedTo,
    this.discount,
  });

  final String? complaint;
  final String? diagnosis;
  final String? scheduledStart;
  final String? scheduledEnd;
  final String? assignedTo;
  final double? discount;

  Map<String, dynamic> toJson() => {
        if (complaint != null) 'complaint': complaint,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (scheduledStart != null) 'scheduledStart': scheduledStart,
        if (scheduledEnd != null) 'scheduledEnd': scheduledEnd,
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (discount != null) 'discount': discount,
      };
}

/// Draft de item de OS (create/update). `inventoryItemId` aponta para o estoque
/// (produto/serviço do catálogo) OU usa `name`/`unitPrice` para item avulso.
class OrderItemDraft {
  const OrderItemDraft({
    this.kind = 'product',
    this.inventoryItemId,
    this.name,
    this.quantity,
    this.unitPrice,
    this.discount,
  });

  final String kind; // 'product' | 'service'
  final String? inventoryItemId;
  final String? name;
  final double? quantity;
  final double? unitPrice;
  final double? discount;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (inventoryItemId != null) 'inventoryItemId': inventoryItemId,
        if (name != null) 'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
        if (discount != null) 'discount': discount,
      };
}

/// Patch de item de OS (qtd/preço/desconto).
class OrderItemPatch {
  const OrderItemPatch({this.quantity, this.unitPrice, this.discount});

  final double? quantity;
  final double? unitPrice;
  final double? discount;

  Map<String, dynamic> toJson() => {
        if (quantity != null) 'quantity': quantity,
        if (unitPrice != null) 'unitPrice': unitPrice,
        if (discount != null) 'discount': discount,
      };
}

/// Opção de cliente para o autocomplete da "Nova OS".
@freezed
abstract class CustomerOption with _$CustomerOption {
  const factory CustomerOption({
    required String id,
    required String name,
    String? document,
    String? phone,
  }) = _CustomerOption;

  factory CustomerOption.fromJson(Map<String, dynamic> json) =>
      _$CustomerOptionFromJson(json);
}

/// Opção de veículo/subject (do cliente selecionado).
@freezed
abstract class SubjectOption with _$SubjectOption {
  const factory SubjectOption({
    required String id,
    String? label,
    String? identifier,
  }) = _SubjectOption;

  factory SubjectOption.fromJson(Map<String, dynamic> json) =>
      _$SubjectOptionFromJson(json);
}

/// Opção de membro da equipe para o dropdown "Responsável" da OS. `id` é o uuid
/// do membro (o backend valida `assignedTo` como uuid). Modelo simples (sem
/// freezed) — só transporta `{ id, name }` para o dropdown.
class MemberOption {
  const MemberOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Responsável SUGERIDO ao criar uma OS: o usuário logado, quando ele é membro
/// elegível da equipe.
///
/// O campo é obrigatório e nascia vazio, obrigando a escolher sem nenhuma pista
/// — quem abre a OS quase sempre é quem responde por ela. `assigned_to` guarda o
/// userId (não o membershipId), então o id da sessão casa direto com
/// [MemberOption.id].
///
/// Função pura para ser testável sem dirigir o wizard de criação:
/// - preserva [jaEscolhido] (a lista de membros carrega de forma assíncrona e
///   pode chegar depois de o usuário já ter escolhido);
/// - devolve `null` quando não há sessão ou quando o logado não está na equipe
///   (ex.: dono que não é mecânico) — nunca inventa um responsável.
String? responsavelSugerido({
  required String? meuUserId,
  required List<MemberOption> membros,
  String? jaEscolhido,
}) {
  if (jaEscolhido != null) return jaEscolhido;
  if (meuUserId == null || meuUserId.isEmpty) return null;
  return membros.any((m) => m.id == meuUserId) ? meuUserId : null;
}

/// Opção de item do estoque para o picker (produto/serviço a adicionar à OS).
@freezed
abstract class InventoryOption with _$InventoryOption {
  const factory InventoryOption({
    required String id,
    required String name,
    @Default('product') String kind,
    @JsonKey(name: 'sale_price') String? salePrice,
    @JsonKey(name: 'current_stock') String? currentStock,
  }) = _InventoryOption;

  factory InventoryOption.fromJson(Map<String, dynamic> json) =>
      _$InventoryOptionFromJson(json);
}
