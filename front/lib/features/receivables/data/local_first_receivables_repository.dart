import '../../../core/offline/local_first.dart';
import '../../cashier/domain/cashier_format.dart';
import '../domain/receivables_models.dart';
import '../domain/receivables_repository.dart';

/// [ReceivablesRepository] offline-first — decorator sobre a impl real (dio).
///
/// O fiado não tem tabela própria (nem no servidor): é DERIVADO de venda/OS com
/// saldo. Online, o servidor compõe tudo. Offline, derivamos do espelho local:
/// para cada OS não cancelada, `total − Σ recebimentos` é o que falta receber.
///
/// **Limite conhecido e exposto na UI:** `sale` (venda de balcão) NÃO está no
/// sync (ver `sync.registry.ts`), então não há espelho local dela. Offline a
/// carteira cobre as OS — o principal numa oficina — e o campo [parcialOffline]
/// diz isso à tela, para o usuário não achar que a lista está completa.
///
/// Nada aqui escreve: receber é lançamento no caixa, que já tem o próprio
/// caminho offline (`LocalFirstCashierRepository`).
class LocalFirstReceivablesRepository extends LocalFirstBase
    implements ReceivablesRepository {
  LocalFirstReceivablesRepository({
    required this.inner,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final ReceivablesRepository inner;

  static const _orders = 'service_order';
  static const _orderItems = 'service_order_item';
  static const _entries = 'cash_entry';

  /// Um centavo de tolerância: resíduo de arredondamento não é dívida (mesma
  /// régua do backend).
  static const _eps = 0.005;

  /// Status de OS que não geram dívida.
  static const _semDivida = {'cancelada', 'rascunho'};

  @override
  Future<DebtorsPage> listDebtors() async {
    if (isOnline()) return inner.listDebtors();

    final titulos = await _titulosLocais();
    final porCliente = <String, Debtor>{};
    for (final t in titulos) {
      final chave = t.customerId ?? 'nome:${t.customerName}';
      final atual = porCliente[chave];
      if (atual == null) {
        porCliente[chave] = Debtor(
          customerId: t.customerId,
          customerName: t.customerName,
          totalDue: t.title.balance,
          titleCount: 1,
          oldestAt: t.title.createdAt,
        );
      } else {
        porCliente[chave] = atual.copyWith(
          totalDue: _round2(atual.totalDue + t.title.balance),
          titleCount: atual.titleCount + 1,
          oldestAt: _maisAntigo(atual.oldestAt, t.title.createdAt),
        );
      }
    }
    final items = porCliente.values.toList()
      ..sort((a, b) => b.totalDue.compareTo(a.totalDue));
    return DebtorsPage(
      items: items,
      totalDue: _round2(items.fold<num>(0, (a, d) => a + d.totalDue)),
      // Offline a carteira não inclui vendas de balcão (sem espelho local): a
      // tela avisa em vez de deixar o usuário achar que viu tudo.
      truncated: true,
    );
  }

  @override
  Future<DebtorDetail> titlesOf(String? customerId) async {
    if (isOnline()) return inner.titlesOf(customerId);

    final doCliente = (await _titulosLocais())
        .where((t) => t.customerId == customerId)
        .toList()
      ..sort((a, b) =>
          (a.title.createdAt ?? '').compareTo(b.title.createdAt ?? ''));
    final items = [for (final t in doCliente) t.title];
    return DebtorDetail(
      customerName: doCliente.isEmpty ? 'Sem cliente' : doCliente.first.customerName,
      totalDue: _round2(items.fold<num>(0, (a, t) => a + t.balance)),
      items: items,
    );
  }

  /// Títulos em aberto derivados do espelho local (OS + recebimentos).
  Future<List<_TituloLocal>> _titulosLocais() async {
    final ordens = await rows(_orders);
    final lancamentos = await rows(_entries);
    final itens = await rows(_orderItems);

    // Σ recebido por OS: entradas não estornadas apontando para ela. O vínculo é
    // polimórfico (`sale_kind` + `sale_id`), então filtramos por `sale_kind:'os'`
    // — sem isso um recebimento de venda de balcão entraria na conta da OS caso
    // os ids algum dia deixassem de ser uuid.
    final pagoPorOs = <String, double>{};
    for (final e in lancamentos) {
      if (e['direction'] != 'in') continue;
      if (e['reversed_at'] != null) continue;
      if (e['sale_kind'] != 'os') continue;
      final id = e['sale_id'] as String?;
      if (id == null) continue;
      pagoPorOs[id] =
          (pagoPorOs[id] ?? 0) + moneyToDouble((e['amount'] ?? '0').toString());
    }

    // Itens por OS, para o detalhamento ("de quais serviços é a dívida").
    final itensPorOs = <String, List<ReceivableItem>>{};
    for (final i in itens) {
      final os = i['order_id'] as String?;
      if (os == null) continue;
      (itensPorOs[os] ??= []).add(ReceivableItem(
        name: (i['name'] ?? '').toString(),
        kind: i['kind'] as String?,
        quantity: moneyToDouble((i['quantity'] ?? '0').toString()),
        unitPrice: moneyToDouble((i['unit_price'] ?? '0').toString()),
        total: moneyToDouble((i['total'] ?? '0').toString()),
      ));
    }

    final out = <_TituloLocal>[];
    for (final o in ordens) {
      if (o['deleted_at'] != null) continue;
      final status = (o['status'] ?? '').toString();
      if (_semDivida.contains(status)) continue;

      final id = o['id'] as String?;
      if (id == null) continue;
      final total = moneyToDouble((o['total'] ?? '0').toString());
      final pago = pagoPorOs[id] ?? 0;
      final saldo = _round2(total - pago);
      if (saldo <= _eps) continue; // pago (ou resíduo) não é fiado

      out.add(_TituloLocal(
        customerId: o['customer_id'] as String?,
        customerName: (o['customer_name'] ?? 'Sem cliente').toString(),
        title: ReceivableTitle(
          id: id,
          origin: 'os',
          number: (o['number'] ?? '').toString(),
          createdAt: o['created_at'] as String?,
          total: total,
          paid: _round2(pago),
          balance: saldo,
          status: pago > _eps ? 'parcial' : 'a_receber',
          items: itensPorOs[id] ?? const [],
        ),
      ));
    }
    return out;
  }

  static double _round2(num v) => (v * 100).round() / 100;

  static String? _maisAntigo(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) <= 0 ? a : b;
  }
}

/// Título + dono, para o agrupamento (o modelo público não carrega o cliente em
/// cada título — o servidor só o expõe no agregado).
class _TituloLocal {
  const _TituloLocal({
    required this.customerId,
    required this.customerName,
    required this.title,
  });

  final String? customerId;
  final String customerName;
  final ReceivableTitle title;
}
