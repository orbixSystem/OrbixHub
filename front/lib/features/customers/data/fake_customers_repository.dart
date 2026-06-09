import '../domain/customers_models.dart';
import '../domain/customers_repository.dart';

/// In-memory [CustomersRepository] for tests/offline. Mirrors the contract,
/// including archive-instead-of-delete and document uniqueness per store.
class FakeCustomersRepository implements CustomersRepository {
  FakeCustomersRepository({
    CustomersConfig? config,
    List<Customer>? customers,
    List<Subject>? subjects,
  })  : _config = config ?? const CustomersConfig(),
        _customers = [...?customers],
        _subjects = [...?subjects];

  final CustomersConfig _config;
  final List<Customer> _customers;
  final List<Subject> _subjects;
  int _seq = 0;

  String _id(String prefix) => '$prefix-${_seq++}';

  @override
  Future<CustomersConfig> fetchConfig() async => _config;

  @override
  Future<CustomerPage> listCustomers({
    String? q,
    String status = 'active',
    int page = 1,
  }) async {
    final term = q?.toLowerCase();
    final items = _customers.where((c) {
      final statusOk =
          status == 'all' ? c.status != 'deleted' : c.status == status;
      final matches = term == null ||
          c.name.toLowerCase().contains(term) ||
          (c.document?.toLowerCase().contains(term) ?? false) ||
          (c.phone?.toLowerCase().contains(term) ?? false);
      return statusOk && matches;
    }).toList();
    return CustomerPage(items: items, total: items.length);
  }

  @override
  Future<Customer> getCustomer(String id) async =>
      _customers.firstWhere((c) => c.id == id);

  @override
  Future<Customer> createCustomer(CustomerDraft draft) async {
    final c = Customer(
      id: _id('cus'),
      name: draft.name ?? '',
      type: draft.type ?? 'PF',
      document: draft.document,
      phone: draft.phone,
      email: draft.email,
      address: draft.address,
      notes: draft.notes,
    );
    _customers.add(c);
    return c;
  }

  @override
  Future<Customer> updateCustomer(String id, CustomerDraft draft) async {
    final i = _customers.indexWhere((c) => c.id == id);
    final updated = _customers[i].copyWith(
      name: draft.name ?? _customers[i].name,
      type: draft.type ?? _customers[i].type,
      document: draft.document ?? _customers[i].document,
      phone: draft.phone ?? _customers[i].phone,
      email: draft.email ?? _customers[i].email,
      address: draft.address ?? _customers[i].address,
      notes: draft.notes ?? _customers[i].notes,
    );
    _customers[i] = updated;
    return updated;
  }

  @override
  Future<Customer> archiveCustomer(String id) async =>
      _setCustomerStatus(id, 'archived');

  @override
  Future<Customer> unarchiveCustomer(String id) async =>
      _setCustomerStatus(id, 'active');

  @override
  Future<Customer> deleteCustomer(String id) async =>
      _setCustomerStatus(id, 'deleted');

  Customer _setCustomerStatus(String id, String status) {
    final i = _customers.indexWhere((c) => c.id == id);
    _customers[i] = _customers[i].copyWith(status: status);
    return _customers[i];
  }

  @override
  Future<SubjectPage> listSubjects({
    String? q,
    String? customerId,
    String status = 'active',
  }) async {
    final term = q?.toLowerCase();
    final items = _subjects.where((s) {
      final statusOk =
          status == 'all' ? s.status != 'deleted' : s.status == status;
      final customerOk = customerId == null || s.customerId == customerId;
      final matches =
          term == null || (s.identifier?.toLowerCase().contains(term) ?? false);
      return statusOk && customerOk && matches;
    }).toList();
    return SubjectPage(items: items, total: items.length);
  }

  @override
  Future<Subject> createSubject(String customerId, SubjectDraft draft) async {
    final s = Subject(
      id: _id('sub'),
      customerId: customerId,
      label: draft.label,
      identifier: draft.identifier,
      attributes: draft.attributes ?? const {},
    );
    _subjects.add(s);
    return s;
  }

  @override
  Future<Subject> updateSubject(String id, SubjectDraft draft) async {
    final i = _subjects.indexWhere((s) => s.id == id);
    final updated = _subjects[i].copyWith(
      label: draft.label ?? _subjects[i].label,
      identifier: draft.identifier ?? _subjects[i].identifier,
      attributes: draft.attributes ?? _subjects[i].attributes,
    );
    _subjects[i] = updated;
    return updated;
  }

  @override
  Future<Subject> archiveSubject(String id) async =>
      _setSubjectStatus(id, 'archived');

  @override
  Future<Subject> unarchiveSubject(String id) async =>
      _setSubjectStatus(id, 'active');

  @override
  Future<Subject> deleteSubject(String id) async =>
      _setSubjectStatus(id, 'deleted');

  Subject _setSubjectStatus(String id, String status) {
    final i = _subjects.indexWhere((s) => s.id == id);
    _subjects[i] = _subjects[i].copyWith(status: status);
    return _subjects[i];
  }

  @override
  Future<List<SubjectHistoryEntry>> subjectHistory(String id) async => const [];

  @override
  Future<List<SubjectHistoryEntry>> customerHistory(
    String customerId, {
    String? subjectId,
  }) async =>
      const [];

  @override
  Future<List<LookupOption>> lookup(
    String fonte, {
    String? marca,
    String? modelo,
    String? q,
  }) async {
    final all = switch (fonte) {
      'fipe.marcas' => const [
          LookupOption(
            value: 'Ford',
            label: 'Ford',
            meta: {'codigo': '22', 'logoUrl': 'https://example.test/ford.png'},
          ),
          LookupOption(value: 'Fiat', label: 'Fiat', meta: {'codigo': '23'}),
        ],
      'fipe.modelos' => marca == null
          ? const <LookupOption>[]
          : const [
              LookupOption(value: 'Ka', label: 'Ka', meta: {'codigo': '1'}),
              LookupOption(value: 'Fiesta', label: 'Fiesta', meta: {'codigo': '2'}),
            ],
      'fipe.anos' => (marca == null || modelo == null)
          ? const <LookupOption>[]
          : const [
              LookupOption(value: '2024', label: '2024'),
              LookupOption(value: '2023', label: '2023'),
            ],
      _ => const <LookupOption>[],
    };
    final term = q?.trim().toLowerCase();
    if (term == null || term.isEmpty) return all;
    return all.where((o) => o.label.toLowerCase().contains(term)).toList();
  }
}
