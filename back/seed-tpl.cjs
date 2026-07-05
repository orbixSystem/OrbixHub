// Direct-DB seeder for service-order templates (dev only).
// Discovers the tenant via the API (/me), then bulk-inserts as app_owner inside
// a tx with `SET LOCAL app.current_tenant_id` so RLS WITH CHECK passes. Fast
// (one generate_series INSERT). Run: node seed-tpl.cjs 1000
const { PrismaClient } = require('@prisma/client');

const API = 'http://localhost:4500/api';
const ADMIN_URL = process.env.SEED_DB_URL; // app_owner
const COUNT = Number(process.argv[2] || 1000);
if (!ADMIN_URL) { console.error('set SEED_DB_URL (app_owner)'); process.exit(1); }

async function tenantId() {
  const lr = await fetch(`${API}/auth/login`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'dono@teste.com', password: 'senha12345' }),
  });
  const lb = await lr.json();
  const token = lb.accessToken || lb.access_token || lb.token;
  const me = await fetch(`${API}/me`, { headers: { authorization: `Bearer ${token}` } });
  const mb = await me.json();
  const tid = mb.activeTenant?.id || mb.tenant?.id || mb.tenantId || mb.tenant_id;
  if (!tid) throw new Error('no tenant id in /me: ' + JSON.stringify(mb).slice(0, 300));
  return tid;
}

async function main() {
  const tid = await tenantId();
  console.log('tenant', tid);
  const prisma = new PrismaClient({ datasources: { db: { url: ADMIN_URL } } });
  try {
    const result = await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe(`SET LOCAL app.current_tenant_id = '${tid}'`);
      const before = await tx.$queryRawUnsafe(
        `SELECT count(*)::int AS c FROM service_order_template WHERE deleted_at IS NULL`);
      const have = before[0].c;
      const from = have + 1;
      if (from <= COUNT) {
        await tx.$executeRawUnsafe(`
          INSERT INTO service_order_template (tenant_id, name, description)
          SELECT '${tid}',
                 'Pacote ' || lpad(g::text, 4, '0') || ' — teste',
                 'Template de teste #' || lpad(g::text, 4, '0') ||
                 ' para validar busca e rolagem infinita.'
          FROM generate_series(${from}, ${COUNT}) g`);
        // 1 item per newly-created template (those without items yet).
        await tx.$executeRawUnsafe(`
          INSERT INTO service_order_template_item (tenant_id, template_id, kind, name, quantity, unit_price)
          SELECT t.tenant_id, t.id, 'service', 'Mão de obra', 1, 80
          FROM service_order_template t
          WHERE t.tenant_id = '${tid}' AND t.deleted_at IS NULL
            AND NOT EXISTS (SELECT 1 FROM service_order_template_item i WHERE i.template_id = t.id)`);
      }
      const after = await tx.$queryRawUnsafe(
        `SELECT count(*)::int AS c FROM service_order_template WHERE deleted_at IS NULL`);
      return { have, total: after[0].c };
    });
    console.log(`had ${result.have}, total alive now ${result.total}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
