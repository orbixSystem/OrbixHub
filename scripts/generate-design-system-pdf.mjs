/**
 * Gera docs/design-system.pdf a partir de docs/design-system.html
 * usando o Chromium embutido no Playwright.
 *
 * Uso (da raiz do monorepo):
 *   node scripts/generate-design-system-pdf.mjs
 */

import { chromium } from 'playwright';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');

const htmlPath = resolve(root, 'docs', 'design-system.html');
const pdfPath  = resolve(root, 'docs', 'design-system.pdf');

if (!existsSync(htmlPath)) {
  console.error(`Arquivo não encontrado: ${htmlPath}`);
  process.exit(1);
}

console.log('Iniciando Chromium…');
const browser = await chromium.launch({ headless: true });
const page    = await browser.newPage();

// Carrega o HTML local e aguarda fontes do Google Fonts
const fileUrl = `file:///${htmlPath.replace(/\\/g, '/')}`;
console.log(`Carregando: ${fileUrl}`);
await page.goto(fileUrl, { waitUntil: 'networkidle' });

// Pausa extra para garantir que as web fonts terminaram de renderizar
await page.waitForTimeout(2500);

console.log('Gerando PDF…');
await page.pdf({
  path: pdfPath,
  format: 'A4',
  printBackground: true,
  margin: { top: '0mm', right: '0mm', bottom: '0mm', left: '0mm' },
});

await browser.close();
console.log(`\nPDF gerado com sucesso:\n  ${pdfPath}\n`);
