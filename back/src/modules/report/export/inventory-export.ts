import PDFDocument from 'pdfkit';
import type { InventoryMetricsReport } from '../../inventory/dto/metrics.dto';

/** Identificação da empresa impressa no topo do PDF (vinda do `/me` no front). */
export interface ExportCompany {
  name?: string;
  legalName?: string;
  cnpj?: string;
}

const TITLE = 'Posição de estoque';

const HEADERS = [
  'Item',
  'SKU',
  'Estoque',
  'Mínimo',
  'Custo',
  'Venda',
  'Valor',
  'Abaixo do mín.',
  'Margem',
] as const;

/**
 * Margem bruta prevista: (venda − custo) / custo. `null` sem os dois preços —
 * mostrar "0%" mentiria (é falta de dado, não margem zero). Ponto-no-tempo com
 * os preços ATUAIS, coerente com `stockValue` (mesmo critério já usado ali):
 * não há snapshot histórico de custo por venda, então isto não pretende
 * responder "quanto lucrei nas vendas passadas", só "qual a margem hoje".
 */
function margemPct(cost: number | null, sale: number | null): number | null {
  if (cost == null || sale == null || cost <= 0) return null;
  return ((sale - cost) / cost) * 100;
}

const pctOrDash = (n: number | null): string =>
  n == null ? '—' : `${n.toLocaleString('pt-BR', { maximumFractionDigits: 1 })}%`;

const brl = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});

const money = (n: number): string => brl.format(n);
const num = (n: number): string =>
  Number.isInteger(n) ? String(n) : n.toLocaleString('pt-BR');
const moneyOrDash = (n: number | null): string => (n == null ? '—' : money(n));
const numOrDash = (n: number | null): string => (n == null ? '—' : num(n));

/** Linhas (strings) do relatório, na ordem dos HEADERS. Sem a linha de TOTAL. */
function dataRows(report: InventoryMetricsReport): string[][] {
  return report.rows.map((r) => [
    r.name,
    r.sku ?? '—',
    num(r.current_stock),
    numOrDash(r.min_stock),
    moneyOrDash(r.cost_price),
    moneyOrDash(r.sale_price),
    money(r.stockValue),
    r.belowMin ? 'Sim' : 'Não',
    pctOrDash(margemPct(r.cost_price, r.sale_price)),
  ]);
}

// --- CSV --------------------------------------------------------------------

/** Escapa um campo CSV (aspas se contiver `;`, `"`, quebra de linha). */
function csvField(v: string): string {
  if (/[";\r\n]/.test(v)) return `"${v.replace(/"/g, '""')}"`;
  return v;
}

/**
 * CSV do relatório completo. `;` (padrão BR p/ Excel) + `\r\n`, com linha de
 * TOTAL no fim. Prefixa BOM UTF-8 para o Excel reconhecer acentos. Buffer pronto.
 */
export function buildInventoryCsv(report: InventoryMetricsReport): Buffer {
  const lines: string[][] = [
    [...HEADERS],
    ...dataRows(report),
    ['TOTAL', '', '', '', '', '', money(report.stockValue), '', ''],
  ];
  const body = lines
    .map((row) => row.map(csvField).join(';'))
    .join('\r\n');
  return Buffer.from('﻿' + body, 'utf-8');
}

// --- PDF (pdfkit) -----------------------------------------------------------

const BRAND = '#EC5E12';
const GRAPHITE = '#15171C';
const MUTED = '#6B7079';
const LINE = '#E7E4DD';

// Larguras relativas das 9 colunas (somam 1). Numéricas alinhadas à direita.
const COL_WEIGHTS = [0.23, 0.13, 0.09, 0.09, 0.10, 0.10, 0.11, 0.08, 0.07];
const RIGHT_ALIGN = new Set([2, 3, 4, 5, 6, 8]);
const ROW_H = 18;

/**
 * PDF do relatório completo (pdfkit, fonte Helvetica/WinAnsi — cobre acentos
 * PT-BR sem arquivos de fonte externos). Cabeçalho da empresa + título + total +
 * tabela com quebra de página automática. Resolve com o Buffer pronto.
 */
export function buildInventoryPdf(
  report: InventoryMetricsReport,
  company?: ExportCompany,
): Promise<Buffer> {
  const doc = new PDFDocument({ size: 'A4', margin: 28 });
  const chunks: Buffer[] = [];

  const done = new Promise<Buffer>((resolve, reject) => {
    doc.on('data', (c: Buffer) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });

  const left = doc.page.margins.left;
  const right = doc.page.width - doc.page.margins.right;
  const bottom = doc.page.height - doc.page.margins.bottom;
  const contentW = right - left;
  const colW = COL_WEIGHTS.map((w) => w * contentW);
  const colX: number[] = [];
  COL_WEIGHTS.reduce((x, w, i) => {
    colX[i] = x;
    return x + w * contentW;
  }, left);

  // Cabeçalho da empresa.
  if (company?.name) {
    doc.fillColor(GRAPHITE).font('Helvetica-Bold').fontSize(14).text(company.name);
    doc.font('Helvetica').fontSize(9).fillColor(MUTED);
    if (company.legalName && company.legalName !== company.name) {
      doc.text(company.legalName);
    }
    if (company.cnpj) doc.text(`CNPJ: ${company.cnpj}`);
    doc.moveDown(0.6);
  }

  doc.fillColor(GRAPHITE).font('Helvetica-Bold').fontSize(16).text(TITLE);
  doc
    .font('Helvetica')
    .fontSize(9)
    .fillColor(MUTED)
    .text(`Valor em estoque: ${money(report.stockValue)}`);
  doc.moveDown(0.5);

  const drawCells = (cells: string[], y: number, bold: boolean) => {
    doc
      .font(bold ? 'Helvetica-Bold' : 'Helvetica')
      .fontSize(8)
      .fillColor(GRAPHITE);
    cells.forEach((c, i) => {
      doc.text(c, colX[i] + 2, y + 5, {
        width: colW[i] - 4,
        align: RIGHT_ALIGN.has(i) ? 'right' : 'left',
        lineBreak: false,
        ellipsis: true,
      });
    });
  };

  let y = doc.y;
  const drawHeader = () => {
    doc.rect(left, y, contentW, ROW_H).fill(LINE);
    drawCells([...HEADERS], y, true);
    y += ROW_H;
  };
  drawHeader();

  const rows = dataRows(report);
  for (const row of rows) {
    if (y + ROW_H > bottom) {
      doc.addPage();
      y = doc.page.margins.top;
      drawHeader();
    }
    drawCells(row, y, false);
    doc
      .moveTo(left, y + ROW_H)
      .lineTo(right, y + ROW_H)
      .strokeColor(LINE)
      .lineWidth(0.5)
      .stroke();
    y += ROW_H;
  }

  // Linha de total.
  if (y + ROW_H > bottom) {
    doc.addPage();
    y = doc.page.margins.top;
  }
  doc.rect(left, y, contentW, ROW_H).fillOpacity(0.12).fill(BRAND);
  doc.fillOpacity(1);
  drawCells(
    ['TOTAL', '', '', '', '', '', money(report.stockValue), '', ''],
    y,
    true,
  );
  y += ROW_H + 8;

  doc.font('Helvetica').fontSize(8).fillColor(BRAND).text('Gerado pelo OrbixHub', left, y);

  doc.end();
  return done;
}
