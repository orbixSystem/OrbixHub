import 'customers_models.dart';

/// Contrato do módulo Clientes & Veículos. O backend é a verdade (RLS +
/// permissões + gating de módulo); o cliente só reflete para UX. Impl real (dio)
/// + fake, trocadas por injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class CustomersRepository {
  // ---- config (rótulo/campos dinâmicos) ----
  Future<CustomersConfig> fetchConfig();

  // ---- customers ----
  Future<CustomerPage> listCustomers(
      {String? q, String status, String sort, int page});
  Future<Customer> getCustomer(String id);
  Future<Customer> createCustomer(CustomerDraft draft);
  Future<Customer> updateCustomer(String id, CustomerDraft draft);
  Future<Customer> archiveCustomer(String id);
  Future<Customer> unarchiveCustomer(String id);

  /// Exclui o cliente — soft delete no backend (status 'deleted'); some das
  /// listagens. Nunca apaga de fato.
  Future<Customer> deleteCustomer(String id);

  // ---- subjects ----
  Future<SubjectPage> listSubjects({String? q, String? customerId, String status});
  Future<Subject> createSubject(String customerId, SubjectDraft draft);
  Future<Subject> updateSubject(String id, SubjectDraft draft);
  Future<Subject> archiveSubject(String id);
  Future<Subject> unarchiveSubject(String id);

  /// Define a foto do veículo (upload multipart p/ o storage/S3). Retorna o
  /// subject atualizado (com `photoUrl`).
  Future<Subject> setSubjectPhoto(
    String id, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  });

  /// Remove a foto do veículo.
  Future<Subject> removeSubjectPhoto(String id);

  /// Exclui o subject — soft delete no backend (status 'deleted'); some das
  /// listagens. Nunca apaga de fato.
  Future<Subject> deleteSubject(String id);
  Future<List<SubjectHistoryEntry>> subjectHistory(String id);

  /// Timeline do cliente (histórico geral). `subjectId` filtra por veículo.
  Future<List<SubjectHistoryEntry>> customerHistory(
    String customerId, {
    String? subjectId,
  });

  // ---- autocomplete (marca/modelo/ano via FIPE, no backend) ----
  /// Opções para um campo com `fonte`. `marca`/`modelo` = códigos dos ancestrais
  /// selecionados na cascata (modelo exige marca; ano exige marca+modelo). `q` =
  /// texto digitado. Lista vazia se a fonte não tiver dados.
  Future<List<LookupOption>> lookup(
    String fonte, {
    String? marca,
    String? modelo,
    String? q,
  });

  // ---- consulta de veículo por placa (API Placas via backend) ----
  /// Consulta os dados do veículo pela placa. Online-only: o token e o
  /// contador de cota (1000/mês) vivem no backend; cache de 30 dias por placa
  /// lá não consome cota. Erros amigáveis: 400 placa inválida, 404 sem
  /// resultado, 429 cota estourada, 503 serviço indisponível.
  Future<PlateInfo> plateLookup(String plate);

  /// Contador da cota mensal (X de N consultas usadas no mês corrente).
  Future<PlateQuota> plateUsage();
}
