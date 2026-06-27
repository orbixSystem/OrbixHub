import PDFDocument from 'pdfkit';
import type { OsReportRow } from '../../os/dto/metrics.dto';
import type { ExportCompany } from './inventory-export';

/** Opções do export de OS: empresa (cabeçalho do PDF) + rótulo do período. */
export interface OsExportOptions {
  company?: ExportCompany;
  periodLabel?: string;
}

const TITLE = 'OS — Operacional';

const HEADERS = [
  'Número',
  'Cliente',
  'Status',
  'Técnico',
  'Total',
  'Abertura',
  'Conclusão',
  'Ciclo',
] as const;

const brl = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});
const money = (n: number): string => brl.format(n);

// Data dd/MM/yyyy no fuso BR (espelha o `fmtDate` do front, que usa hora local).
const dateFmt = new Intl.DateTimeFormat('pt-BR', {
  timeZone: 'America/Sao_Paulo',
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
});
const fmtDate = (iso: string | null): string =>
  iso ? dateFmt.format(new Date(iso)) : '—';

/** Ciclo (ms) → "8.2h"/"3d" (espelha o `formatCycle` do front). Null → "—". */
function fmtCycle(ms: number | null): string {
  if (ms == null) return '—';
  const hours = ms / (1000 * 60 * 60);
  if (hours < 24) return `${hours.toFixed(hours < 10 ? 1 : 0)}h`;
  const days = hours / 24;
  return `${days.toFixed(days < 10 ? 1 : 0)}d`;
}

/** Rótulo PT-BR do status (espelha o `osStatusLabel` do front). */
function statusLabel(status: string): string {
  switch (status) {
    case 'aberta':
      return 'Aberta';
    case 'aguardando_aprovacao':
      return 'Aguardando aprovação';
    case 'aprovada':
      return 'Aprovada';
    case 'em_execucao':
      return 'Em execução';
    case 'concluida':
      return 'Concluída';
    case 'entregue':
      return 'Entregue';
    case 'cancelada':
      return 'Cancelada';
    default:
      return status;
  }
}

/**
 * Responsável legível a partir do `assigned_to` (userId). Null/vazio → "Sem
 * responsável"; id ausente do mapa (membro removido/inativo) → "—" (nunca o
 * uuid). Espelha o `assignedLabel` do front.
 */
function assignedLabel(id: string | null, names: Map<string, string>): string {
  if (!id) return 'Sem responsável';
  return names.get(id) ?? '—';
}

/** Linhas (strings) do relatório, na ordem dos HEADERS. Sem a linha de TOTAL. */
function dataRows(
  rows: OsReportRow[],
  names: Map<string, string>,
): string[][] {
  return rows.map((o) => [
    o.number,
    o.customer_name,
    statusLabel(o.status),
    assignedLabel(o.assigned_to, names),
    money(o.total),
    fmtDate(o.opened_at),
    fmtDate(o.finished_at),
    fmtCycle(o.cycleMs),
  ]);
}

/** Linha de TOTAL (espelha o builder do front: contagem de OS + soma de total). */
function totalRow(rows: OsReportRow[]): string[] {
  const total = rows.reduce((a, b) => a + b.total, 0);
  return ['TOTAL', `${rows.length} OS`, '', '', money(total), '', '', ''];
}

// --- CSV --------------------------------------------------------------------

/** Escapa um campo CSV (aspas se contiver `;`, `"`, quebra de linha). */
function csvField(v: string): string {
  if (/[";\r\n]/.test(v)) return `"${v.replace(/"/g, '""')}"`;
  return v;
}

/**
 * CSV do relatório completo de OS. `;` (padrão BR p/ Excel) + `\r\n`, com linha
 * de TOTAL no fim. Prefixa BOM UTF-8 para o Excel reconhecer acentos.
 */
export function buildOsCsv(
  rows: OsReportRow[],
  names: Map<string, string>,
): Buffer {
  const lines: string[][] = [
    [...HEADERS],
    ...dataRows(rows, names),
    totalRow(rows),
  ];
  const body = lines.map((row) => row.map(csvField).join(';')).join('\r\n');
  return Buffer.from('﻿' + body, 'utf-8');
}

// --- PDF (pdfkit) -----------------------------------------------------------

const BRAND = '#EC5E12';
const GRAPHITE = '#15171C';
const MUTED = '#6B7079';
const LINE = '#E7E4DD';

// Larguras relativas das 8 colunas (somam 1). Total alinhado à direita.
const COL_WEIGHTS = [0.1, 0.22, 0.15, 0.16, 0.12, 0.09, 0.09, 0.07];
const RIGHT_ALIGN = new Set([4]);
const ROW_H = 18;

/**
 * PDF do relatório completo de OS (pdfkit, Helvetica/WinAnsi — cobre acentos
 * PT-BR sem fontes externas). Cabeçalho da empresa + título + período + tabela
 * com quebra de página automática + linha de total. Resolve com o Buffer pronto.
 */
export function buildOsPdf(
  rows: OsReportRow[],
  names: Map<string, string>,
  opts: OsExportOptions = {},
): Promise<Buffer> {
  const { company, periodLabel } = opts;
  const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 28 });
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
  doc.text(`${rows.length} OS`);
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

  for (const row of dataRows(rows, names)) {
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
  drawCells(totalRow(rows), y, true);
  y += ROW_H + 8;

  doc
    .font('Helvetica')
    .fontSize(8)
    .fillColor(BRAND)
    .text('Gerado pelo OrbixHub', left, y);

  doc.end();
  return done;
}
