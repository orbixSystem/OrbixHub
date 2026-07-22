import { Client } from 'pg';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Load back/.env so the script works with just `npm run db:setup` (no inline vars).
// Variables already in the environment (CI) are never overwritten.
try {
  const envContent = readFileSync(join(__dirname, '..', '.env'), 'utf8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (!(key in process.env)) process.env[key] = value;
  }
} catch {
  // No .env file — rely on environment variables already set (CI).
}

// Applies the baseline schema AS app_owner (table owner). Creates roles too
// (the SQL is idempotent). Use ADMIN_DATABASE_URL = the app_owner connection.
async function main() {
  const url = process.env.ADMIN_DATABASE_URL;
  if (!url) throw new Error('ADMIN_DATABASE_URL is required');
  const sql = readFileSync(
    join(__dirname, '..', 'sql', 'auth-multitenant-schema.sql'),
    'utf8',
  );
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    await client.query(sql);
    // eslint-disable-next-line no-console
    console.log('Baseline applied.');
  } finally {
    await client.end();
  }
}
main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});
