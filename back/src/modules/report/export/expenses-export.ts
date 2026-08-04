/**
 * Export do relatório de Despesas por categoria.
 *
 * Só CSV aqui, de propósito: o front já gera o PDF dos relatórios com o
 * cabeçalho/logo da oficina (`report_pdf.dart`), e um segundo gerador no servidor
 * produziria dois documentos diferentes para o mesmo relatório. O CSV existe porque
 * é o que vai para o contador e para a planilha.
 */

/** Uma linha do resumo (espelha `ExpensesService.summaryByCategory`). */
export interface ExpensesByCategoryRow {
  categoryName: string;
  count: number;
  previsto: number;
  pago: number;
  emAberto: number;
  vencido: number;
}

export interface ExpensesByCategoryReport {
  rows: ExpensesByCategoryRow[];
  totals: Omit<ExpensesByCategoryRow, 'categoryName'>;
}

const HEADERS = [
  'Categoria',
  'Contas',
  'Previsto',
  'Pago',
  'Em aberto',
  'Vencido',
] as const;

const brl = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});

const money = (n: number): string => brl.format(n);

/**
 * Escapa um campo de CSV. Ponto-e-vírgula como separador (padrão que o Excel
 * pt-BR abre sem pedir importação) — então o campo é citado quando contém `;`,
 * aspas ou quebra de linha.
 */
function csvField(v: string): string {
  return /[";\r\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v;
}

export function buildExpensesCsv(report: ExpensesByCategoryReport): Buffer {
  const lines: string[][] = [
    [...HEADERS],
    ...report.rows.map((r) => [
      r.categoryName,
      String(r.count),
      money(r.previsto),
      money(r.pago),
      money(r.emAberto),
      money(r.vencido),
    ]),
    [
      'TOTAL',
      String(report.totals.count),
      money(report.totals.previsto),
      money(report.totals.pago),
      money(report.totals.emAberto),
      money(report.totals.vencido),
    ],
  ];
  const body = lines.map((row) => row.map(csvField).join(';')).join('\r\n');
  // BOM: sem ele o Excel abre os acentos errados ("Manutenção" vira "ManutenÃ§Ã£o").
  return Buffer.from('﻿' + body, 'utf-8');
}
