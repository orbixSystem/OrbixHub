import '../../../core/offline/local_first.dart';
import '../../cashier/domain/cashier_format.dart';
import '../../cashier/domain/local_payment.dart';
import '../domain/receivables_models.dart';
import '../domain/receivables_repository.dart';

/// [ReceivablesRepository] offline-first — decorator sobre a impl real (dio).
///
/// O fiado não tem tabela própria (nem no servidor): é DERIVADO de venda/OS com
/// saldo. Online, o servidor compõe tudo. Offline, derivamos do espelho local:
/// para cada OS e cada venda de balcão não cancelada, `total − Σ recebimentos` é
/// o que falta receber. `sale`/`sale_item` estão no sync (ver `sync.registry.ts`),
/// então a carteira offline cobre as DUAS origens — não é mais um recorte.
///
/// Nada aqui escreve: receber é lançamento no caixa, que já tem o próprio
/// caminho offline (`LocalFirstCashierRepository`) — e como a carteira lê as
/// mesmas linhas que o lançamento grava, receber offline abate a dívida na hora.
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
  static const _sales = 'sale';
  static const _saleItems = 'sale_item';
  static const _entries = 'cash_entry';

  /// Um centavo de tolerância: resíduo de arredondamento não é dívida (mesma
  /// régua do backend).
  static const _eps = paymentEps;

  /// Status de OS que não geram dívida (rascunho ainda não foi vendido).
  static const _osSemDivida = {'cancelada', 'rascunho'};

  /// Idem para a venda de balcão — que nasce `active` e só sai por cancelamento.
  static const _vendaSemDivida = {'canceled'};

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
      // Sem cap: offline a carteira sai INTEIRA do espelho (OS + venda), então
      // não há o que avisar. O `truncated` do servidor é outra coisa — lá existe
      // teto de páginas.
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

  /// Títulos em aberto derivados do espelho local: OS **e** venda de balcão,
  /// menos o que o caixa já recebeu de cada uma.
  Future<List<_TituloLocal>> _titulosLocais() async {
    // Σ recebido por título — regra compartilhada com o histórico de vendas e
    // espelho da do servidor (ver `local_payment.dart`).
    final pago = paidByTitleFrom(await rows(_entries));

    return [
      ..._titulosDe(
        linhas: await rows(_orders),
        itens: await rows(_orderItems),
        chaveDoPai: 'order_id',
        colunaTotalDoItem: 'total',
        origem: 'os',
        statusSemDivida: _osSemDivida,
        pago: pago,
      ),
      ..._titulosDe(
        linhas: await rows(_sales),
        itens: await rows(_saleItems),
        chaveDoPai: 'sale_id',
        // O item da venda chama a linha de `subtotal`; o da OS, de `total`.
        colunaTotalDoItem: 'subtotal',
        origem: 'sale',
        statusSemDivida: _vendaSemDivida,
        pago: pago,
      ),
    ];
  }

  /// Monta os títulos em aberto de UMA origem (OS ou venda). As duas tabelas têm
  /// a mesma forma para o que o fiado precisa — cabeçalho com total/cliente e
  /// filhos apontando para o pai —, só mudam os nomes das colunas e o vocabulário
  /// de status (`cancelada` na OS, `canceled` na venda).
  List<_TituloLocal> _titulosDe({
    required List<Map<String, dynamic>> linhas,
    required List<Map<String, dynamic>> itens,
    required String chaveDoPai,
    required String colunaTotalDoItem,
    required String origem,
    required Set<String> statusSemDivida,
    required Map<String, double> pago,
  }) {
    final itensPorPai = <String, List<ReceivableItem>>{};
    for (final i in itens) {
      final pai = i[chaveDoPai] as String?;
      if (pai == null) continue;
      (itensPorPai[pai] ??= []).add(ReceivableItem(
        name: (i['name'] ?? '').toString(),
        kind: i['kind'] as String?,
        quantity: moneyToDouble((i['quantity'] ?? '0').toString()),
        unitPrice: moneyToDouble((i['unit_price'] ?? '0').toString()),
        total: moneyToDouble((i[colunaTotalDoItem] ?? '0').toString()),
      ));
    }

    final out = <_TituloLocal>[];
    for (final linha in linhas) {
      if (linha['deleted_at'] != null) continue;
      if (statusSemDivida.contains((linha['status'] ?? '').toString())) continue;

      final id = linha['id'] as String?;
      if (id == null) continue;
      final total = moneyToDouble((linha['total'] ?? '0').toString());
      final recebido = pago[id] ?? 0;
      final saldo = _round2(total - recebido);
      if (saldo <= _eps) continue; // pago (ou resíduo de centavo) não é fiado

      out.add(_TituloLocal(
        customerId: linha['customer_id'] as String?,
        customerName: (linha['customer_name'] ?? 'Sem cliente').toString(),
        title: ReceivableTitle(
          id: id,
          origin: origem,
          number: (linha['number'] ?? '').toString(),
          createdAt: linha['created_at'] as String?,
          total: total,
          paid: _round2(recebido),
          balance: saldo,
          status: derivePaymentStatusLocal(total, recebido),
          items: itensPorPai[id] ?? const [],
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
