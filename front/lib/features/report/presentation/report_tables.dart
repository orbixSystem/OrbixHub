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

/// Responsável legível (null → "Sem responsável").
String assignedLabel(String? v) =>
    (v == null || v.isEmpty) ? 'Sem responsável' : v;

// --- Builders de ReportTable (fonte única p/ CSV + PDF). Linha de total no fim. ---

ReportTable osOperationalTable(OsOperationalReport r) => ReportTable(
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
            assignedLabel(o.assignedTo),
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

ReportTable teamTable(TeamReport r) => ReportTable(
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
            assignedLabel(t.assignedTo),
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

ReportTable inventoryTable(InventoryReport r) => ReportTable(
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
        ['TOTAL', '', '', '', '', '', formatMoney(r.stockValue), ''],
      ],
    );

ReportTable customersTable(CustomersReport r) => ReportTable(
      title: 'Clientes',
      headers: const ['Nome', 'Tipo', 'Cadastro'],
      rows: [
        for (final c in r.rows)
          [c.name, customerTypeLabel(c.type), fmtDate(c.createdAt)],
      ],
    );
