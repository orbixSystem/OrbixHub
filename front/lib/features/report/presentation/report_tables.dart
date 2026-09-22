import '../../cashier/domain/cashier_format.dart' show methodLabel;
import '../../cashier/domain/cashier_models.dart' show CashSummary;
import '../../dashboard/presentation/widgets/metric_card.dart'
    show formatMoney, formatCycle;
import '../../os/presentation/os_status.dart' show osStatusLabel;
import '../domain/report_models.dart';
import 'report_csv.dart';

/// Converte uma data ISO em "dd/MM/yyyy". Null/vazia → "—".
String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

/// "dd/MM/yyyy" a partir de uma chave 'YYYY-MM-DD' (série por dia).
String fmtDay(String day) {
  final parts = day.split('-');
  if (parts.length != 3) return day;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Rótulo PT-BR do tipo de item (produto/serviço).
String kindLabel(String kind) => switch (kind) {
      'product' => 'Produto',
      'service' => 'Serviço',
      _ => kind,
    };

/// Rótulo PT-BR do tipo de cliente.
String customerTypeLabel(String type) => switch (type) {
      'pf' => 'Pessoa física',
      'pj' => 'Pessoa jurídica',
      _ => type,
    };

/// Responsável legível a partir do `assigned_to`. Null/vazio → "Sem responsável".
/// Com [names] ({id -> nome}), resolve o uuid para o nome do membro; se o id não
/// estiver na lista (membro removido/sem acesso), cai para "—" (nunca o uuid).
String assignedLabel(String? v, [Map<String, String>? names]) {
  if (v == null || v.isEmpty) return 'Sem responsável';
  if (names == null) return v;
  return names[v] ?? '—';
}

// --- Builders de ReportTable (fonte única p/ CSV + PDF). Linha de total no fim. ---

ReportTable osOperationalTable(
  OsOperationalReport r, [
  Map<String, String>? names,
]) =>
    ReportTable(
      title: 'OS — Operacional',
      headers: const [
        'Número',
        'Cliente',
        'Status',
        'Técnico',
        'Total',
        'Abertura',
        'Conclusão',
        'Ciclo',
      ],
      rows: [
        for (final o in r.rows)
          [
            o.number,
            o.customerName,
            osStatusLabel(o.status),
            assignedLabel(o.assignedTo, names),
            formatMoney(o.total),
            fmtDate(o.openedAt),
            fmtDate(o.finishedAt),
            formatCycle(o.cycleMs),
          ],
        [
          'TOTAL',
          '${r.rows.length} OS',
          '',
          '',
          formatMoney(r.rows.fold<num>(0, (a, b) => a + b.total)),
          '',
          '',
          '',
        ],
      ],
    );

ReportTable revenueTable(RevenueReport r) => ReportTable(
      title: 'Faturamento por dia',
      headers: const ['Dia', 'OS', 'Receita'],
      rows: [
        for (final d in r.byDay)
          [fmtDay(d.day), '${d.count}', formatMoney(d.revenue)],
        ['TOTAL', '', formatMoney(r.total)],
      ],
    );

/// Despesas por categoria. As quatro colunas de dinheiro contam a mesma história
/// por ângulos diferentes: `previsto` é o custo do período, `pago` o que já saiu,
/// `em aberto` o que falta e `vencido` o pedaço do em aberto que passou do prazo.
ReportTable expensesTable(ExpensesReport r) => ReportTable(
      title: 'Despesas por categoria',
      headers: const [
        'Categoria',
        'Contas',
        'Previsto',
        'Pago',
        'Em aberto',
        'Vencido',
      ],
      rows: [
        for (final l in r.rows)
          [
            l.categoryName,
            '${l.count}',
            formatMoney(l.previsto),
            formatMoney(l.pago),
            formatMoney(l.emAberto),
            // Zero em branco: uma coluna cheia de "R$ 0,00" treina o olho a
            // ignorá-la, e é justamente a que precisa chamar atenção quando tem
            // valor.
            l.vencido > 0 ? formatMoney(l.vencido) : '',
          ],
        [
          'TOTAL',
          '${r.totals.count}',
          formatMoney(r.totals.previsto),
          formatMoney(r.totals.pago),
          formatMoney(r.totals.emAberto),
          r.totals.vencido > 0 ? formatMoney(r.totals.vencido) : '',
        ],
      ],
    );

ReportTable teamTable(TeamReport r, [Map<String, String>? names]) =>
    ReportTable(
      title: 'Rendimento da equipe',
      headers: const [
        'Responsável',
        'OS',
        'Concluídas',
        'Faturamento',
        'Ticket médio',
        'Ciclo médio',
      ],
      rows: [
        for (final t in r.rows)
          [
            assignedLabel(t.assignedTo, names),
            '${t.orders}',
            '${t.completed}',
            formatMoney(t.revenue),
            formatMoney(t.avgTicket),
            formatCycle(t.avgCycleMs),
          ],
      ],
    );

ReportTable topItemsTable(TopItemsReport r) => ReportTable(
      title: 'Top produtos/serviços',
      headers: const ['Item', 'Tipo', 'Qtde', 'Receita', 'OS'],
      rows: [
        for (final i in r.rows)
          [
            i.name,
            kindLabel(i.kind),
            '${i.qty}',
            formatMoney(i.revenue),
            '${i.orders}',
          ],
      ],
    );

/// Tabela de estoque. Paginada na tela (`includeTotal: false` — o total vai no
/// KPI acima); o export completo é gerado no servidor (não usa este builder).
ReportTable inventoryTable(InventoryReport r, {bool includeTotal = true}) =>
    ReportTable(
      title: 'Posição de estoque',
      headers: const [
        'Item',
        'SKU',
        'Estoque',
        'Mínimo',
        'Custo',
        'Venda',
        'Valor',
        'Abaixo do mín.',
      ],
      rows: [
        for (final i in r.rows)
          [
            i.name,
            i.sku ?? '—',
            '${i.currentStock}',
            i.minStock == null ? '—' : '${i.minStock}',
            i.costPrice == null ? '—' : formatMoney(i.costPrice!),
            i.salePrice == null ? '—' : formatMoney(i.salePrice!),
            formatMoney(i.stockValue),
            i.belowMin ? 'Sim' : 'Não',
          ],
        if (includeTotal)
          ['TOTAL', '', '', '', '', '', formatMoney(r.stockValue), ''],
      ],
    );

/// Rótulo PT-BR do tipo da venda (origem) na lente "Vendas".
String saleTypeLabel(String type) => switch (type) {
      'servico' => 'Serviço (OS)',
      'produto' => 'Produto (venda)',
      _ => type,
    };

/// Rótulo PT-BR do status de pagamento.
String paymentStatusLabel(String status) => switch (status) {
      'pago' => 'Paga',
      'parcial' => 'Parcial',
      'a_receber' => 'A receber',
      _ => status,
    };

ReportTable salesLedgerTable(SalesLedger r) => ReportTable(
      title: 'Vendas',
      headers: const ['Data', 'Tipo', 'Cliente', 'Origem', 'Pagamento', 'Valor'],
      rows: [
        for (final s in r.rows)
          [
            fmtDate(s.date),
            saleTypeLabel(s.type),
            s.customerName ?? 'Balcão',
            s.originNumber,
            paymentStatusLabel(s.paymentStatus),
            formatMoney(s.value),
          ],
        [
          'TOTAL',
          '${r.rows.length} venda(s)',
          '',
          '',
          '',
          formatMoney(r.rows.fold<num>(0, (a, b) => a + b.value)),
        ],
      ],
    );

/// Caixa — recebido por forma (entrou/saiu/saldo). "Recebido" = movimento do
/// caixa (não é faturamento).
ReportTable cashFlowTable(CashSummary s) => ReportTable(
      title: 'Caixa — recebido por forma',
      headers: const ['Forma', 'Entrou', 'Saiu', 'Saldo'],
      rows: [
        for (final m in s.byMethod)
          [
            methodLabel(m.method),
            formatMoney(m.inAmount),
            formatMoney(m.outAmount),
            formatMoney(m.inAmount - m.outAmount),
          ],
        [
          'TOTAL',
          formatMoney(s.totalIn),
          formatMoney(s.totalOut),
          formatMoney(s.net),
        ],
        // Linha à parte, fora do TOTAL: desconto fecha dívida sem entrar
        // dinheiro. Somá-lo à entrada faria a tabela acusar caixa que não
        // existe; omiti-lo faria a receita não bater com o faturado.
        if (s.totalDiscount > 0)
          [
            'Descontos concedidos',
            formatMoney(s.totalDiscount),
            '—',
            '—',
          ],
      ],
    );

// (O relatório de Clientes não usa mais builder de tabela: a tela é uma lista
// paginada com scroll infinito e o export CSV/PDF é gerado no servidor —
// `GET /report/customers.csv|.pdf` — como o de OS/estoque.)
