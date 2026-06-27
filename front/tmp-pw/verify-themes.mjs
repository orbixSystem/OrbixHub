/**
 * verify-themes.mjs — Visual verification of OrbixHub theme presets via Playwright.
 *
 * For each preset × mode: screenshots dashboard, sidebar, configuracoes, customers.
 * Saves PNGs to front/tmp-pw/shots/<preset>-<modo>-<tela>.png.
 *
 * Usage (from repo root):
 *   node front/tmp-pw/verify-themes.mjs
 *
 * Requirements:
 *   - Backend running on :4500
 *   - Flutter web served on :8090 (node front/tmp-pw/serve.mjs)
 *   - playwright installed in root node_modules
 */
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BASE = 'http://localhost:8090';
const OUT = path.join(__dirname, 'shots');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const PRESETS = ['tangerina', 'vermelho', 'azul', 'verde', 'roxo', 'petroleo', 'ambar'];
const MODES = ['claro', 'escuro'];

const PRESET_LABELS = {
  tangerina: 'Tangerina',
  vermelho: 'Vermelho',
  azul: 'Azul',
  verde: 'Verde',
  roxo: 'Roxo',
  petroleo: 'Petróleo',
  ambar: 'Âmbar',
};

const MODE_LABELS = {
  claro: 'Claro',
  escuro: 'Escuro',
};

async function shot(page, name) {
  const p = path.join(OUT, `${name}.png`);
  await page.screenshot({ path: p, fullPage: false });
  console.log(`  📸 ${name}.png`);
}

async function enableSemantics(page) {
  await page.evaluate(() => {
    const el = document.querySelector(
      'flt-semantics-placeholder, [aria-label="Enable accessibility"], flt-semantics[role="button"]'
    );
    if (el) el.click();
  });
  await sleep(2500);
}

async function login(page) {
  console.log('→ logging in...');
  await page.goto(BASE, { waitUntil: 'load', timeout: 60000 });
  await sleep(9000); // Flutter boot

  await enableSemantics(page);

  const tbs = page.getByRole('textbox');
  await tbs.nth(0).fill('dono@teste.com', { timeout: 8000 });
  await tbs.nth(1).fill('senha12345', { timeout: 8000 });
  await page.getByRole('button', { name: /entrar|login/i }).first().click({ timeout: 8000 });
  await sleep(9000);
  console.log('→ logged in');
}

async function goToSettings(page) {
  await page.goto(`${BASE}/#/configuracoes`, { waitUntil: 'load', timeout: 30000 });
  await sleep(3000);
}

async function goToDashboard(page) {
  await page.goto(`${BASE}/#/`, { waitUntil: 'load', timeout: 30000 });
  await sleep(3000);
}

async function goToCustomers(page) {
  await page.goto(`${BASE}/#/m/customers`, { waitUntil: 'load', timeout: 30000 });
  await sleep(3000);
}

/**
 * Scroll down in Flutter's ListView using mouse wheel until swatches are visible.
 * Flutter's content area is to the right of the sidebar (~260px wide).
 */
async function scrollToSwatches(page) {
  // Scroll using mouse wheel on the content area
  // Position cursor in the middle of the content area
  for (let i = 0; i < 15; i++) {
    await page.mouse.wheel(0, 300);
    await sleep(100);
  }
  await sleep(1000);
}

/**
 * Select a theme preset by clicking its swatch label text.
 * Must be called after scrollToSwatches().
 */
async function selectPreset(page, presetKey) {
  const label = PRESET_LABELS[presetKey];
  console.log(`  → selecting preset: ${label}`);
  try {
    await page.getByText(label, { exact: true }).first().click({ timeout: 5000 });
    console.log(`    ✓ clicked swatch "${label}"`);
    await sleep(3000); // wait for theme apply + API save
    return true;
  } catch (e) {
    console.log(`    ⚠ could not click preset "${label}": ${String(e).slice(0, 80)}`);
    return false;
  }
}

/**
 * Select light or dark mode.
 * Must be called after scrollToSwatches() (mode buttons are in the same scroll area).
 */
async function selectMode(page, mode) {
  const label = MODE_LABELS[mode];
  console.log(`  → selecting mode: ${label}`);
  try {
    await page.getByText(label, { exact: true }).first().click({ timeout: 5000 });
    console.log(`    ✓ mode "${label}" selected`);
    await sleep(2000);
    return true;
  } catch (e) {
    console.log(`    ⚠ could not click mode "${label}": ${String(e).slice(0, 80)}`);
    return false;
  }
}

const run = async () => {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch({
    headless: false,
    args: ['--use-gl=angle', '--use-angle=gl', '--window-size=1460,940'],
  });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  page.on('console', (m) => {
    if (m.type() === 'error') {
      console.log(`  [error]`, m.text().slice(0, 160));
    }
  });

  try {
    await login(page);
    await shot(page, '00-post-login');

    console.log('\n=== Starting preset × mode verification ===\n');

    for (const preset of PRESETS) {
      console.log(`\n--- Preset: ${PRESET_LABELS[preset]} ---`);

      for (const mode of MODES) {
        console.log(`\n  Mode: ${mode}`);

        // Go to configuracoes and scroll to swatches
        await goToSettings(page);
        await scrollToSwatches(page);

        // Select the preset
        const presetOk = await selectPreset(page, preset);
        if (!presetOk) {
          console.log(`  ⚠ skipping ${preset}-${mode} (preset select failed)`);
          await shot(page, `${preset}-${mode}-FAIL`);
          continue;
        }

        // Select the mode
        await selectMode(page, mode);

        // Screenshot the configuracoes screen (with preview)
        await shot(page, `${preset}-${mode}-configuracoes`);

        // Screenshot dashboard
        await goToDashboard(page);
        await shot(page, `${preset}-${mode}-dashboard`);

        // Screenshot sidebar (clip to left panel)
        await page.screenshot({
          path: path.join(OUT, `${preset}-${mode}-sidebar.png`),
          clip: { x: 0, y: 0, width: 280, height: 900 },
        });
        console.log(`  📸 ${preset}-${mode}-sidebar.png (clipped)`);

        // Screenshot customers screen
        await goToCustomers(page);
        await shot(page, `${preset}-${mode}-clientes`);

        console.log(`  ✓ ${preset}-${mode} done`);
      }
    }

    // Reset to tangerina light (default) at end
    console.log('\n→ Resetting to tangerina/claro...');
    await goToSettings(page);
    await scrollToSwatches(page);
    await selectPreset(page, 'tangerina');
    await selectMode(page, 'claro');

    console.log('\n=== All presets screenshotted ===');
    console.log(`Screenshots saved to: ${OUT}`);

  } catch (err) {
    console.error('FATAL:', err);
    await shot(page, 'FATAL-error').catch(() => {});
  } finally {
    await browser.close();
  }
};

run().catch((e) => { console.error('FATAL', e); process.exit(1); });
