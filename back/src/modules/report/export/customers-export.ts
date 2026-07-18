import PDFDocument from 'pdfkit';
import type { CustomersMetricsReport } from '../../customers/dto/metrics.dto';
import type { ExportCompany } from './inventory-export';

/** Opções do export de clientes: empresa (cabeçalho do PDF) + rótulo do período. */
export interface CustomersExportOptions {
  company?: ExportCompany;
  periodLabel?: string;
}

const TITLE = 'Clientes';

const HEADERS = ['Nome', 'Tipo', 'Cadastro'] as const;

// Data dd/MM/yyyy no fuso BR (espelha o `fmtDate` do front).
const dateFmt = new Intl.DateTimeFormat('pt-BR', {
  timeZone: 'America/Sao_Paulo',
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
});
const fmtDate = (iso: string | null): string =>
  iso ? dateFmt.format(new Date(iso)) : '—';

/** Rótulo PT-BR do tipo de cliente (espelha o `customerTypeLabel` do front). */
function typeLabel(type: string): string {
  switch (type) {
    case 'pf':
      return 'Pessoa física';
    case 'pj':
      return 'Pessoa jurídica';
    default:
      return type;
  }
}

/** Linhas (strings) do relatório, na ordem dos HEADERS. Sem a linha de TOTAL. */
function dataRows(report: CustomersMetricsReport): string[][] {
  return report.rows.map((c) => [
    c.name,
    typeLabel(c.type),
    fmtDate(c.created_at),
  ]);
}

/** Linha de TOTAL: contagem de clientes novos no período. */
function totalRow(report: CustomersMetricsReport): string[] {
  return ['TOTAL', `${report.rows.length} cliente(s)`, ''];
}

// --- CSV --------------------------------------------------------------------

/** Escapa um campo CSV (aspas se contiver `;`, `"`, quebra de linha). */
function csvField(v: string): string {
  if (/[";\r\n]/.test(v)) return `"${v.replace(/"/g, '""')}"`;
  return v;
}

/**
 * CSV do relatório completo de clientes (novos no período). `;` (padrão BR p/
 * Excel) + `\r\n`, com linha de TOTAL no fim. Prefixa BOM UTF-8 para o Excel
 * reconhecer acentos. Buffer pronto.
 */
export function buildCustomersCsv(report: CustomersMetricsReport): Buffer {
  const lines: string[][] = [
    [...HEADERS],
    ...dataRows(report),
    totalRow(report),
  ];
  const body = lines.map((row) => row.map(csvField).join(';')).join('\r\n');
  return Buffer.from('﻿' + body, 'utf-8');
}

// --- PDF (pdfkit) -----------------------------------------------------------

const BRAND = '#EC5E12';
const GRAPHITE = '#15171C';
const MUTED = '#6B7079';
const LINE = '#E7E4DD';

// Larguras relativas das 3 colunas (somam 1).
const COL_WEIGHTS = [0.5, 0.25, 0.25];
const ROW_H = 18;

/**
 * PDF do relatório completo de clientes (pdfkit, Helvetica/WinAnsi — cobre
 * acentos PT-BR sem fontes externas). Cabeçalho da empresa + título + período +
 * resumo (ativos/novos) + tabela com quebra de página automática + linha de
 * total. Resolve com o Buffer pronto.
 */
export function buildCustomersPdf(
  report: CustomersMetricsReport,
  opts: CustomersExportOptions = {},
): Promise<Buffer> {
  const { company, periodLabel } = opts;
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
    doc
      .fillColor(GRAPHITE)
      .font('Helvetica-Bold')
      .fontSize(14)
      .text(company.name);
    doc.font('Helvetica').fontSize(9).fillColor(MUTED);
    if (company.legalName && company.legalName !== company.name) {
      doc.text(company.legalName);
    }
    if (company.cnpj) doc.text(`CNPJ: ${company.cnpj}`);
    doc.moveDown(0.6);
  }

  doc.fillColor(GRAPHITE).font('Helvetica-Bold').fontSize(16).text(TITLE);
  doc.font('Helvetica').fontSize(9).fillColor(MUTED);
  if (periodLabel) doc.text(`Período: ${periodLabel}`);
  doc.text(
    `Clientes ativos: ${report.active} · Novos no período: ${report.newInRange}`,
  );
  doc.moveDown(0.5);

  const drawCells = (cells: string[], y: number, bold: boolean) => {
    doc
      .font(bold ? 'Helvetica-Bold' : 'Helvetica')
      .fontSize(8)
      .fillColor(GRAPHITE);
    cells.forEach((c, i) => {
      doc.text(c, colX[i] + 2, y + 5, {
        width: colW[i] - 4,
        align: 'left',
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

  for (const row of dataRows(report)) {
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
  drawCells(totalRow(report), y, true);
  y += ROW_H + 8;

  doc
    .font('Helvetica')
    .fontSize(8)
    .fillColor(BRAND)
    .text('Gerado pelo OrbixHub', left, y);

  doc.end();
  return done;
}
