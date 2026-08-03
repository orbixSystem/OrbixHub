import '../../../core/error/app_exception.dart';
import '../../../core/offline/local_first.dart';
import '../../cashier/domain/local_payment.dart';
import '../domain/sale_models.dart';
import '../domain/sale_repository.dart';

/// [SaleRepository] offline-first — decorator sobre a impl real (dio).
///
/// Venda de balcão é o caso mais comum de "preciso vender agora e a internet
/// caiu". Offline a venda é criada no espelho + outbox (`sale.create`) e some da
/// fila quando o servidor aplica; o pull traz a linha oficial (já com o número
/// definitivo) sobre o mesmo id.
///
/// Três coisas que o servidor decide e o cliente NÃO tenta adivinhar:
///  - **número**: offline vai um provisório (`VND-P1`), como a OS faz (`OS-P1`);
///  - **pagamento**: derivado dos lançamentos do caixa espelhados (regra
///    compartilhada em `local_payment.dart`) — a venda nunca guarda quanto pagou;
///  - **estoque**: a baixa acontece no replay, no servidor. Offline o saldo do
///    estoque local fica desatualizado até o sync — o inverso (baixar aqui)
///    dobraria a baixa quando o servidor aplicasse a mesma venda.
///
/// Emitir nota continua exigindo conexão (o Fiscal é online-only).
class LocalFirstSaleRepository extends LocalFirstBase
    implements SaleRepository {
  LocalFirstSaleRepository({
    required this.inner,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final SaleRepository inner;

  static const _sales = 'sale';
  static const _items = 'sale_item';
  static const _entries = 'cash_entry';

  /// Tamanho de página do backend (`DEFAULT_PAGE_SIZE` do sale.service).
  static const _pageSize = 20;

  // ============================ leitura =================================

  @override
  Future<SalePage> listSales({
    String? status,
    String? customerId,
    String? q,
    String? from,
    String? to,
    int page = 1,
  }) async {
    if (isOnline()) {
      final res = await inner.listSales(
        status: status,
        customerId: customerId,
        q: q,
        from: from,
        to: to,
        page: page,
      );
      for (final s in res.items) {
        await _mirrorSale(s);
      }
      // Venda criada offline (create ainda na fila) continua na lista — senão a
      // `VND-P1` sumiria da tela assim que a rede voltasse.
      final merged = await mergePending(
        _sales,
        [for (final s in res.items) s.toJson()],
        includeExtras: page == 1,
        keepExtra: (row) => _matchesFilter(
          row,
          status: status,
          customerId: customerId,
          q: q,
          from: from,
          to: to,
        ),
      );
      return res.copyWith(
        items: [for (final row in merged) Sale.fromJson(row)],
        total: res.total + (merged.length - res.items.length),
      );
    }

    final filtered = (await rows(_sales))
        .where((row) => _matchesFilter(
              row,
              status: status,
              customerId: customerId,
              q: q,
              from: from,
              to: to,
            ))
        .toList()
      // Mesma ordenação do servidor: mais recente primeiro, id desempata.
      ..sort((a, b) {
        final porData = _createdOf(b).compareTo(_createdOf(a));
        return porData != 0
            ? porData
            : (b['id'] as String).compareTo(a['id'] as String);
      });

    final pago = paidByTitleFrom(await rows(_entries));
    final itens = await rows(_items);
    return SalePage(
      items: [
        for (final row in pageOf(filtered, page, _pageSize))
          _assemble(row, itens, pago),
      ],
      total: filtered.length,
      page: page,
      pageSize: _pageSize,
    );
  }

  @override
  Future<Sale> getSale(String id) async {
    if (!await useLocal(_sales, id)) {
      final sale = await inner.getSale(id);
      await _mirrorSale(sale);
      return sale;
    }
    final row = await rowById(_sales, id);
    if (row == null) notFoundLocally('Venda');
    return _assemble(row, await rows(_items), paidByTitleFrom(await rows(_entries)));
  }

  // ============================ escrita =================================

  @override
  Future<Sale> createSale(SaleDraft draft) async {
    if (isOnline()) {
      final sale = await inner.createSale(draft);
      await _mirrorSale(sale);
      return sale;
    }

    // Itens: offline não há como re-snapshotar nome/preço do estoque, então só
    // dá para registrar o que o rascunho já traz. O replay refaz o snapshot no
    // servidor (é lá que `createSale` consulta o inventory) e o pull corrige.
    final id = newId();
    final itens = <Map<String, dynamic>>[];
    var bruto = 0.0;
    for (final it in draft.items) {
      final unit = it.unitPrice ?? 0;
      final subtotal = round2(it.quantity * unit);
      bruto += subtotal;
      itens.add({
        'id': newId(),
        'sale_id': id,
        'kind': it.kind ?? 'product',
        'inventory_item_id': it.inventoryItemId,
        'name': it.name ?? '',
        'quantity': dec(it.quantity),
        'unit_price': dec(unit),
        'subtotal': dec(subtotal),
        'created_at': nowIso(),
        // O servidor gera OUTRO id para o item no replay (o DTO do item não
        // carrega id) — marcar como local faz a poda remover esta linha quando a
        // cópia do servidor chegar, em vez de duplicar o item.
        LocalFirstBase.localOnlyKey: true,
      });
    }
    final desconto = (draft.discount ?? 0).clamp(0, bruto).toDouble();

    await enqueue(_sales, 'create', {'id': id, ...draft.toJson()});
    final row = <String, dynamic>{
      'id': id,
      'number': await _provisionalNumber(),
      'customer_id': draft.customerId,
      // Sem o nome do cliente à mão offline: o replay preenche pelo id.
      'customer_name': null,
      'status': 'active',
      'total': dec(round2(bruto - desconto)),
      'discount': dec(desconto),
      'fiscal_status': null,
      'created_at': nowIso(),
      'updated_at': nowIso(),
    };
    await putRow(_sales, row);
    for (final item in itens) {
      await putRow(_items, item);
    }
    return _assemble(row, itens, const {});
  }

  @override
  Future<Sale> cancelSale(String id, {String? reason}) async {
    if (!await useLocal(_sales, id)) {
      final sale = await inner.cancelSale(id, reason: reason);
      await _mirrorSale(sale);
      return sale;
    }
    final row = await rowById(_sales, id);
    if (row == null) notFoundLocally('Venda');
    if (row['status'] == 'canceled') {
      // Mesma regra (e mesmo 409) do servidor — sem isto o segundo cancelamento
      // enfileiraria uma mutação que o replay vai recusar, e o usuário só
      // descobriria o erro depois de sincronizar.
      throw const AppException(
        statusCode: 409,
        error: 'Conflict',
        message: 'Venda já cancelada.',
      );
    }
    await enqueue(_sales, 'cancel', {
      'id': id,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    final canceled = {
      ...row,
      'status': 'canceled',
      'canceled_reason': reason,
      'updated_at': nowIso(),
    };
    await putRow(_sales, canceled);
    return _assemble(canceled, await rows(_items), const {});
  }

  @override
  Future<SaleFiscalResult> emitInvoice(String id) async {
    // O Fiscal fala com a SEFAZ/prefeitura: não existe emitir offline.
    if (!isOnline()) requiresConnection('emitir a nota');
    // Criada offline e ainda na fila: o servidor não conhece esta venda.
    if (await isDirty(_sales, id)) pendingSync('Esta venda');
    return inner.emitInvoice(id);
  }

  // ============================ interno =================================

  /// Espelha a venda vinda do servidor (cabeçalho + itens) sem pisar nas sujas.
  Future<void> _mirrorSale(Sale sale) async {
    await mirrorRows(_sales, [sale.toJson()]);
    await putRows(_items, [
      for (final i in sale.items) {...i.toJson(), 'sale_id': sale.id},
    ]);
    await _pruneReplayedItems(sale.id);
  }

  /// Poda os itens criados offline depois que o servidor recriou os dele (o pull
  /// é upsert e nunca remove): sem isto a linha local e a do servidor conviveriam
  /// e o detalhe da venda mostraria cada item duas vezes.
  Future<void> _pruneReplayedItems(String saleId) async {
    if (await isDirty(_sales, saleId)) return;
    for (final row in await rows(_items)) {
      if (row['sale_id'] != saleId || !isLocalOnly(row)) continue;
      await removeRow(_items, row['id'] as String);
    }
  }

  /// Monta a venda: cabeçalho + itens + pagamento derivado do caixa.
  Sale _assemble(
    Map<String, dynamic> header,
    List<Map<String, dynamic>> todosOsItens,
    Map<String, double> pagoPorTitulo,
  ) {
    final id = header['id'] as String;
    final itens = todosOsItens.where((i) => i['sale_id'] == id).toList()
      ..sort((a, b) => _createdOf(a).compareTo(_createdOf(b)));
    // Venda cancelada não pergunta o caixa (o servidor também não) — a tag de
    // pagamento dela é `cancelada`.
    final canceled = header['status'] == 'canceled';
    final total = toNum(header['total']);
    final pago = pagoPorTitulo[id] ?? 0;
    return Sale.fromJson({
      ...header,
      'items': itens,
      'payment_status':
          canceled ? 'cancelada' : derivePaymentStatusLocal(total, pago),
    });
  }

  /// Número provisório da venda criada offline: `VND-P1`, `VND-P2`, … (contador
  /// local sobre as provisórias já espelhadas). O servidor atribui o definitivo
  /// no replay — o pull traz a linha corrigida.
  Future<String> _provisionalNumber() async {
    var max = 0;
    for (final row in await rows(_sales)) {
      final number = row['number'];
      if (number is! String || !number.startsWith('VND-P')) continue;
      final n = int.tryParse(number.substring(5)) ?? 0;
      if (n > max) max = n;
    }
    return 'VND-P${max + 1}';
  }

  String _createdOf(Map<String, dynamic> row) =>
      (row['created_at'] ?? '') as String;

  /// Mesmos filtros do servidor (`listSales`): status e cliente exatos, `q`
  /// contém em número OU nome do cliente, `from`/`to` recortam `created_at`.
  bool _matchesFilter(
    Map<String, dynamic> row, {
    String? status,
    String? customerId,
    String? q,
    String? from,
    String? to,
  }) {
    if (status != null && row['status'] != status) return false;
    if (customerId != null && row['customer_id'] != customerId) return false;
    if (q != null && q.isNotEmpty) {
      final achou = matches(row['number'] as String?, q) ||
          matches(row['customer_name'] as String?, q);
      if (!achou) return false;
    }
    final criada = _createdOf(row);
    if (from != null && criada.compareTo(from) < 0) return false;
    if (to != null && criada.compareTo(to) > 0) return false;
    return true;
  }
}
