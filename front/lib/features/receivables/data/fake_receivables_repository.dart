import '../domain/receivables_models.dart';
import '../domain/receivables_repository.dart';

/// Fake in-memory do controle de fiado — dev/teste (não é persistência offline).
///
/// Reproduz o que importa da regra do servidor: agrupa por cliente, soma só o
/// saldo em aberto, ordena do maior devedor para o menor e mantém os títulos do
/// mais antigo para o mais novo (a ordem em que se cobra).
class FakeReceivablesRepository implements ReceivablesRepository {
  FakeReceivablesRepository({
    List<ReceivableTitle>? titulos,
    this.truncated = false,
    this.pendingSettlement = const PendingSettlement(),
    this.pendingTitles = const [],
  }) : _titulos = titulos ?? _exemplo;

  /// Título → cliente. `null` = venda de balcão sem cliente.
  final List<ReceivableTitle> _titulos;
  final bool truncated;

  /// Entregues e nunca acertados no caixa — o aviso do topo da aba Fiado.
  final PendingSettlement pendingSettlement;

  /// Os títulos por trás do aviso (o drill-down de "quais são?").
  final List<ReceivableTitle> pendingTitles;

  /// Mapa título→(clienteId, nome). Mantido fora do modelo porque o servidor só
  /// devolve o dono no agregado, não em cada título.
  static final Map<String, (String?, String)> _donos = {
    'os-1': ('c1', 'João Silva'),
    'os-2': ('c1', 'João Silva'),
    'sale-1': ('c2', 'Maria Souza'),
    'sale-2': (null, 'Sem cliente'),
  };

  static const _exemplo = <ReceivableTitle>[
    ReceivableTitle(
      id: 'os-1',
      origin: 'os',
      number: 'OS-0042',
      createdAt: '2026-07-02T10:00:00Z',
      total: 480,
      paid: 0,
      balance: 480,
      status: 'a_receber',
      items: [
        ReceivableItem(
            name: 'Troca de óleo',
            kind: 'service',
            quantity: 1,
            unitPrice: 120,
            total: 120),
        ReceivableItem(
            name: 'Óleo 5W30',
            kind: 'product',
            quantity: 4,
            unitPrice: 90,
            total: 360),
      ],
    ),
    ReceivableTitle(
      id: 'os-2',
      origin: 'os',
      number: 'OS-0051',
      createdAt: '2026-07-18T14:30:00Z',
      total: 300,
      paid: 100,
      balance: 200,
      status: 'parcial',
      items: [
        ReceivableItem(
            name: 'Alinhamento',
            kind: 'service',
            quantity: 1,
            unitPrice: 300,
            total: 300),
      ],
    ),
    ReceivableTitle(
      id: 'sale-1',
      origin: 'sale',
      number: '15',
      createdAt: '2026-07-25T09:00:00Z',
      total: 150,
      paid: 0,
      balance: 150,
      status: 'a_receber',
      items: [
        ReceivableItem(
            name: 'Palheta',
            kind: 'product',
            quantity: 2,
            unitPrice: 75,
            total: 150),
      ],
    ),
  ];

  @override
  Future<DebtorsPage> listDebtors() async {
    final porCliente = <String, Debtor>{};
    for (final t in _titulos) {
      final (id, nome) = _donos[t.id] ?? (null, 'Sem cliente');
      final chave = id ?? '__sem__';
      final atual = porCliente[chave];
      if (atual == null) {
        porCliente[chave] = Debtor(
          customerId: id,
          customerName: nome,
          totalDue: t.balance,
          titleCount: 1,
          oldestAt: t.createdAt,
        );
      } else {
        porCliente[chave] = atual.copyWith(
          totalDue: atual.totalDue + t.balance,
          titleCount: atual.titleCount + 1,
          oldestAt: _maisAntigo(atual.oldestAt, t.createdAt),
        );
      }
    }
    final items = porCliente.values.toList()
      ..sort((a, b) => b.totalDue.compareTo(a.totalDue));
    return DebtorsPage(
      items: items,
      totalDue: items.fold<num>(0, (acc, d) => acc + d.totalDue),
      pendingSettlement: pendingSettlement,
      truncated: truncated,
    );
  }

  @override
  Future<OpenTitlesPage> listOpenTitles() async {
    final items = [
      for (final t in _titulos)
        t.copyWith(
          customerId: _donos[t.id]?.$1,
          customerName: _donos[t.id]?.$2 ?? 'Sem cliente',
        ),
    ]..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return OpenTitlesPage(
      items: items,
      totalDue: items.fold<num>(0, (acc, t) => acc + t.balance),
      truncated: truncated,
    );
  }

  @override
  Future<OpenTitlesPage> listPendingSettlement() async {
    final items = [
      for (final t in pendingTitles)
        t.copyWith(
          customerId: _donos[t.id]?.$1,
          customerName: _donos[t.id]?.$2 ?? 'Sem cliente',
        ),
    ];
    return OpenTitlesPage(
      items: items,
      totalDue: items.fold<num>(0, (acc, t) => acc + t.balance),
    );
  }

  @override
  Future<DebtorDetail> titlesOf(String? customerId) async {
    final meus = _titulos
        .where((t) => (_donos[t.id]?.$1) == customerId)
        .toList()
      ..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
    return DebtorDetail(
      customerName: meus.isEmpty
          ? 'Sem cliente'
          : (_donos[meus.first.id]?.$2 ?? 'Sem cliente'),
      totalDue: meus.fold<num>(0, (acc, t) => acc + t.balance),
      items: meus,
    );
  }

  static String? _maisAntigo(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) <= 0 ? a : b;
  }
}
