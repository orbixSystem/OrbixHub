import '../domain/receivables_filtro.dart';
import '../domain/receivables_models.dart';
import '../domain/receivables_query.dart';
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
    this.vencimentos = const {},
  }) : _titulos = titulos ?? _exemplo;

  /// Título → cliente. `null` = venda de balcão sem cliente.
  final List<ReceivableTitle> _titulos;
  final bool truncated;

  /// Entregues e nunca acertados no caixa — o aviso do topo da aba Fiado.
  final PendingSettlement pendingSettlement;

  /// Os títulos por trás do aviso (o drill-down de "quais são?").
  final List<ReceivableTitle> pendingTitles;

  /// Prazo combinado por título (`id` → `YYYY-MM-DD`), como o servidor devolve
  /// a próxima parcela em aberto. Sem entrada aqui o título é "sem prazo" — e
  /// sem prazo não há vencimento nem atraso, igual à regra real.
  final Map<String, String> vencimentos;

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
  Future<DebtorsPage> listDebtors(DebtorsQuery query) async {
    final porCliente = <String, DevedorParaFiltro>{};
    for (final t in _titulos) {
      // O dono sai do PRÓPRIO título quando ele o traz; `_donos` cobre só os
      // títulos de exemplo, que nasceram sem esses campos.
      final (id, nome) = _dono(t);
      // MESMA chave do servidor (`customerId ?? 'nome:<nome>'`). Agrupar todo
      // mundo sem cadastro num balde só — o que este fake fazia — é exatamente
      // o bug que a cliente filmou, e um fake que não consegue reproduzi-lo não
      // serve para provar a correção.
      final chave = id ?? 'nome:$nome';
      final titulo = TituloParaFiltro(
        origin: t.origin,
        createdAt: t.createdAt,
        balance: t.balance,
        proximaParcelaEm: vencimentos[t.id],
      );
      final atual = porCliente[chave];
      porCliente[chave] = atual == null
          ? DevedorParaFiltro(
              customerId: id,
              customerName: nome,
              totalDue: t.balance,
              titleCount: 1,
              oldestAt: t.createdAt,
              titulos: [titulo],
            )
          : DevedorParaFiltro(
              customerId: atual.customerId,
              customerName: atual.customerName,
              totalDue: atual.totalDue + t.balance,
              titleCount: atual.titleCount + 1,
              oldestAt: _maisAntigo(atual.oldestAt, t.createdAt),
              titulos: [...atual.titulos, titulo],
            );
    }

    final hoje = DateTime.now().toUtc();
    final classificados =
        porCliente.values.map((d) => classificar(d, hoje)).toList();
    final filtrados = filtrarDevedores(
      classificados,
      q: query.q,
      vencimento: query.vencimento,
      origem: query.origem,
      hoje: hoje,
    );
    final pagina = paginar(
      ordenarDevedores(filtrados, query.sort),
      query.page,
      query.pageSize,
    );
    final vencidos = classificados.where((d) => d.overdue);

    return DebtorsPage(
      items: [
        for (final d in pagina.items)
          Debtor(
            customerId: d.customerId,
            customerName: d.customerName,
            totalDue: d.totalDue,
            titleCount: d.titleCount,
            oldestAt: d.oldestAt,
            nextDueAt: d.nextDueAt,
            overdue: d.overdue,
          ),
      ],
      total: pagina.total,
      page: query.page,
      pageSize: query.pageSize,
      totalDue: classificados.fold<num>(0, (acc, d) => acc + d.totalDue),
      overdueTotal: vencidos.fold<num>(0, (acc, d) => acc + d.totalDue),
      overdueCount: vencidos.length,
      pendingSettlement: pendingSettlement,
      truncated: truncated,
    );
  }

  @override
  Future<OpenTitlesPage> listOpenTitles() async {
    final items = [
      for (final t in _titulos)
        t.copyWith(customerId: _dono(t).$1, customerName: _dono(t).$2),
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
        t.copyWith(customerId: _dono(t).$1, customerName: _dono(t).$2),
    ];
    return OpenTitlesPage(
      items: items,
      totalDue: items.fold<num>(0, (acc, t) => acc + t.balance),
    );
  }

  @override
  Future<DebtorDetail> titlesOf(String? customerId, {String? apelido}) async {
    final meus = _titulos
        .where((t) => _ehDoDevedor(t, customerId, apelido))
        .toList()
      ..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
    return DebtorDetail(
      customerName: meus.isEmpty ? 'Sem cliente' : _dono(meus.first).$2,
      totalDue: meus.fold<num>(0, (acc, t) => acc + t.balance),
      items: meus,
    );
  }

  /// Mesma regra do servidor: cliente cadastrado casa por id; anônimo casa
  /// pelo APELIDO, porque é assim que a carteira os agrupa.
  ///
  /// O dono sai da MESMA resolução usada na listagem (`_dono`): antes este
  /// método olhava só o mapa `_donos`, então um título montado no teste com
  /// `customerId`/`customerName` próprios aparecia na carteira e sumia ao abrir
  /// o devedor — um fake que mente sobre o servidor.
  bool _ehDoDevedor(ReceivableTitle t, String? customerId, String? apelido) {
    final (id, nome) = _dono(t);
    if (id != customerId) return false;
    if (customerId != null) return true;
    final doTitulo = nome == 'Sem cliente' ? '' : nome;
    return doTitulo == (apelido ?? '').trim();
  }

  /// Dono do título: o mapa de exemplo quando o id é conhecido, senão o que o
  /// próprio título carrega.
  (String?, String) _dono(ReceivableTitle t) =>
      _donos[t.id] ??
      (
        t.customerId,
        (t.customerName ?? '').trim().isEmpty
            ? 'Sem cliente'
            : t.customerName!.trim(),
      );

  static String? _maisAntigo(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) <= 0 ? a : b;
  }
}
