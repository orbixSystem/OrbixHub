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
    String sort = 'recent',
    int page = 1,
  }) async {
    final term = q?.toLowerCase();
    final filtered = _customers.where((c) {
      final statusOk =
          status == 'all' ? c.status != 'deleted' : c.status == status;
      final matches = term == null ||
          c.name.toLowerCase().contains(term) ||
          (c.document?.toLowerCase().contains(term) ?? false) ||
          (c.phone?.toLowerCase().contains(term) ?? false);
      return statusOk && matches;
    }).toList();
    // Ordenação espelhando o contrato do backend. 'recent'/'oldest' usam a ordem
    // de inserção (proxy de created_at) já que o fake não guarda timestamps.
    switch (sort) {
      case 'name_asc':
        filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'name_desc':
        filtered.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'oldest':
        // já está na ordem de inserção
        break;
      case 'recent':
      default:
        // mais recentes primeiro = inversa da ordem de inserção
        final reversed = filtered.reversed.toList();
        filtered
          ..clear()
          ..addAll(reversed);
    }
    const pageSize = 20;
    final total = filtered.length;
    final start = (page - 1) * pageSize;
    final items = start >= total
        ? <Customer>[]
        : filtered.sublist(start, (start + pageSize).clamp(0, total));
    return CustomerPage(
        items: items, total: total, page: page, pageSize: pageSize);
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
      plateData: draft.plateData,
      plateDataAt: draft.plateData == null ? null : '2026-08-01T12:00:00Z',
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
      // Consulta só é sobrescrita quando veio no draft (reconsulta).
      plateData: draft.plateData ?? _subjects[i].plateData,
      plateDataAt: draft.plateData == null
          ? _subjects[i].plateDataAt
          : '2026-08-01T12:00:00Z',
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

  @override
  Future<Subject> setSubjectPhoto(
    String id, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final i = _subjects.indexWhere((s) => s.id == id);
    _subjects[i] = _subjects[i].copyWith(
      photoUrl: 'https://picsum.photos/seed/$id/640/480',
    );
    return _subjects[i];
  }

  @override
  Future<Subject> removeSubjectPhoto(String id) async {
    final i = _subjects.indexWhere((s) => s.id == id);
    _subjects[i] = _subjects[i].copyWith(photoUrl: null);
    return _subjects[i];
  }

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

  int _plateLookups = 0;

  @override
  Future<PlateInfo> plateLookup(String plate) async {
    _plateLookups += 1;
    return PlateInfo(
      placa: plate.toUpperCase(),
      marca: 'VW',
      modelo: 'CROSSFOX',
      marcaModelo: 'VW/CROSSFOX',
      versao: 'CROSSFOX',
      ano: '2007',
      anoModelo: '2007',
      cor: 'PRATA',
      chassi: '9BWKB05Z174110137',
      municipio: 'São Leopoldo',
      uf: 'RS',
      situacao: 'Sem restrição',
      combustivel: 'Alcool / Gasolina',
      cilindradas: '1599',
      passageiros: '5',
      tipoVeiculo: 'Automovel',
      consultadoEm: '20/07/2022 15:10:09',
      fipe: const PlateFipe(
        codigoFipe: '005225-6',
        marca: 'VW - VolksWagen',
        modelo: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
        valor: 'R\$ 28.799,00',
        mesReferencia: 'maio de 2022',
        score: 101,
      ),
      fipeTodos: const [
        PlateFipe(
          codigoFipe: '005225-6',
          marca: 'VW - VolksWagen',
          modelo: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
          valor: 'R\$ 28.799,00',
          mesReferencia: 'maio de 2022',
          score: 101,
        ),
        PlateFipe(
          codigoFipe: '005340-6',
          marca: 'VW - VolksWagen',
          modelo: 'CROSSFOX 1.6 T.Flex 8V (Antigo)',
          valor: 'R\$ 25.000,00',
          mesReferencia: 'maio de 2022',
          score: 3,
        ),
      ],
      // Equivalente no catálogo FIPE do cadastro (o que destrava a cascata).
      fipeMatch: const PlateFipeMatch(
        marca: PlateFipeRef(value: 'VW - VolksWagen', codigo: '59'),
        modelo: PlateFipeRef(
          value: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
          codigo: '2368',
        ),
        ano: PlateFipeRef(value: '2007'),
      ),
      extra: const {
        'ano_fabricacao': '2007',
        'cap_maxima_tracao': '198',
        'eixos': '2',
        'peso_bruto_total': '158',
        'restricao_1': 'SEM RESTRICAO',
        'tipo_carroceria': 'NAO APLICAVEL',
        'tipo_doc_prop': 'Fisica',
      },
      cached: _plateLookups > 1,
      usage: PlateQuota(
        period: '2026-07',
        used: _plateLookups,
        limit: 1000,
        remaining: 1000 - _plateLookups,
        enabled: true,
      ),
    );
  }

  @override
  Future<PlateQuota> plateUsage() async => PlateQuota(
        period: '2026-07',
        used: _plateLookups,
        limit: 1000,
        remaining: 1000 - _plateLookups,
        enabled: true,
      );

  @override
  Future<CnpjEmpresa> lookupCnpj(String cnpj) async => const CnpjEmpresa(
        cnpj: '19.131.243/0001-97',
        razaoSocial: 'OPEN KNOWLEDGE BRASIL',
        nomeFantasia: 'REDE PELO CONHECIMENTO LIVRE',
        situacao: 'ATIVA',
        telefone: '1123851939',
        // `email` nulo de propósito: é o caso comum na base da Receita.
        logradouro: 'PAULISTA 37',
        bairro: 'BELA VISTA',
        municipio: 'SAO PAULO',
        uf: 'SP',
      );
}
