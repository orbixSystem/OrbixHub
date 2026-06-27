/**
 * Seed de DESENVOLVIMENTO — popula uma oficina-demo realista para rodar o app
 * com dados de cara (clientes, veículos, estoque, OS em vários status, chat).
 *
 * NÃO é migration nem seed de produção. Idempotente: recria o tenant 'oficina-demo'
 * do zero a cada execução (apaga o anterior em cascata). Roda como app_owner
 * (BYPASSRLS) — segue o mesmo padrão de scripts/ci-db-setup.ts.
 *
 * Uso:  npm run seed:dev --workspace back     (ou via launch.json "Back: seed (dev data)")
 * Pré-requisito: schema aplicado (ci-db-setup.ts) e DB no ar.
 */
import { Client } from 'pg';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import * as argon2 from 'argon2';

// --- mini-loader de .env (sem depender do pacote dotenv) ---
function loadEnv() {
  try {
    const txt = readFileSync(join(__dirname, '..', '.env'), 'utf8');
    for (const line of txt.split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m && process.env[m[1]] === undefined) {
        process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
      }
    }
  } catch {
    /* sem .env — usa o que já estiver no ambiente */
  }
}

const DEMO_SLUG = 'oficina-demo';
const PASSWORD = 'Dev@12345';
const OWNER_EMAIL = 'dono@oficina-demo.dev';
const MECH_EMAIL = 'mecanico@oficina-demo.dev';

async function main() {
  loadEnv();
  const url =
    process.env.SEED_DATABASE_URL ||
    process.env.ADMIN_DATABASE_URL ||
    process.env.MIGRATION_DATABASE_URL;
  if (!url) {
    throw new Error(
      'Defina ADMIN_DATABASE_URL (app_owner) no back/.env — ex.: postgresql://app_owner:owner_pw@localhost:5432/orbixhub',
    );
  }

  const passwordHash = await argon2.hash(PASSWORD, {
    type: argon2.argon2id,
    memoryCost: Number(process.env.ARGON_MEMORY_KIB ?? 19456),
    timeCost: Number(process.env.ARGON_TIME_COST ?? 2),
    parallelism: Number(process.env.ARGON_PARALLELISM ?? 1),
  });

  const db = new Client({ connectionString: url });
  await db.connect();
  const q = (text: string, params: unknown[] = []) => db.query(text, params);
  const one = async (text: string, params: unknown[] = []) =>
    (await q(text, params)).rows[0];

  try {
    await q('BEGIN');

    // ---- catálogo (resolve ids por chave; criados pelo schema) ----
    const idByKey = async (table: string, key: string) => {
      const r = await one(`SELECT id FROM ${table} WHERE key = $1`, [key]);
      if (!r) throw new Error(`${table} '${key}' não encontrado — rode ci-db-setup.ts antes`);
      return r.id as string;
    };
    const roleOwner = await idByKey('role', 'owner');
    const roleMech = await idByKey('role', 'mechanic');
    const planPro = await idByKey('plan', 'pro');
    const modules = ['os', 'inventory', 'customers', 'report'];
    const moduleIds: Record<string, string> = {};
    for (const k of modules) moduleIds[k] = await idByKey('module', k);

    // ---- limpa execução anterior (idempotente) ----
    await q(`DELETE FROM tenant WHERE slug = $1`, [DEMO_SLUG]); // cascata: domínio + membership + subscription
    await q(`DELETE FROM users WHERE email_normalized = ANY($1::text[])`, [
      [OWNER_EMAIL, MECH_EMAIL],
    ]);

    // ---- tenant + assinatura + módulos ----
    const tenant = await one(
      `INSERT INTO tenant (name, slug, cnpj, legal_name, trade_name, settings)
       VALUES ($1,$2,$3,$4,$5,$6::jsonb) RETURNING id`,
      [
        'Oficina Demo OrbixHub',
        DEMO_SLUG,
        '12345678000199',
        'Oficina Demo OrbixHub LTDA',
        'Oficina Demo',
        JSON.stringify({ phone: '(11) 4000-0000', email: 'contato@oficina-demo.dev' }),
      ],
    );
    const tid = tenant.id as string;

    await q(
      `INSERT INTO subscription (tenant_id, plan_id, status, trial_ends_at, current_period_start, current_period_end)
       VALUES ($1,$2,'trialing', now() + interval '14 days', now(), now() + interval '14 days')`,
      [tid, planPro],
    );
    for (const k of modules) {
      await q(
        `INSERT INTO tenant_module (tenant_id, module_id, enabled, source) VALUES ($1,$2,true,'plan')`,
        [tid, moduleIds[k]],
      );
    }

    // ---- usuários + memberships ----
    const mkUser = async (email: string, name: string) =>
      (
        await one(
          `INSERT INTO users (email_normalized, full_name, password_hash, email_verified_at, last_tenant_id)
           VALUES ($1,$2,$3, now(), $4) RETURNING id`,
          [email, name, passwordHash, tid],
        )
      ).id as string;
    const ownerId = await mkUser(OWNER_EMAIL, 'Ana Proprietária');
    const mechId = await mkUser(MECH_EMAIL, 'Carlos Mecânico');
    await q(
      `INSERT INTO membership (tenant_id, user_id, role_id, status) VALUES ($1,$2,$3,'active'),($1,$4,$5,'active')`,
      [tid, ownerId, roleOwner, mechId, roleMech],
    );

    // ---- clientes + veículos (subjects) ----
    const mkCustomer = async (
      name: string,
      type: 'PF' | 'PJ',
      doc: string,
      phone: string,
      email: string,
    ) =>
      (
        await one(
          `INSERT INTO customer (tenant_id, name, type, document, phone, email, status)
           VALUES ($1,$2,$3,$4,$5,$6,'active') RETURNING id`,
          [tid, name, type, doc, phone, email],
        )
      ).id as string;
    const mkSubject = async (
      customerId: string,
      label: string,
      identifier: string,
      attrs: Record<string, unknown>,
    ) =>
      (
        await one(
          `INSERT INTO subject (tenant_id, customer_id, label, identifier, attributes, status)
           VALUES ($1,$2,$3,$4,$5::jsonb,'active') RETURNING id`,
          [tid, customerId, label, identifier, JSON.stringify(attrs)],
        )
      ).id as string;

    const joao = await mkCustomer('João da Silva', 'PF', '12345678900', '(11) 98888-0001', 'joao@email.dev');
    const maria = await mkCustomer('Maria Oliveira', 'PF', '98765432100', '(11) 97777-0002', 'maria@email.dev');
    const transp = await mkCustomer('Transportadora Rápida LTDA', 'PJ', '11222333000181', '(11) 3030-0003', 'frota@transprapida.dev');

    const gol = await mkSubject(joao, 'VW Gol 1.0', 'ABC1D23', { marca: 'Volkswagen', modelo: 'Gol', ano: 2018, cor: 'Prata' });
    const civic = await mkSubject(maria, 'Honda Civic', 'DEF4G56', { marca: 'Honda', modelo: 'Civic', ano: 2020, cor: 'Preto' });
    const sprinter = await mkSubject(transp, 'Mercedes Sprinter', 'GHI7J89', { marca: 'Mercedes-Benz', modelo: 'Sprinter', ano: 2019, cor: 'Branco' });

    // ---- estoque: produtos + serviços ----
    const mkProduct = async (
      name: string,
      sku: string,
      brand: string,
      sale: number,
      cost: number,
      stock: number,
      min: number,
      unit = 'un',
    ) =>
      (
        await one(
          `INSERT INTO inventory_item (tenant_id, name, sku, brand, unit, kind, sale_price, cost_price, current_stock, min_stock, is_active)
           VALUES ($1,$2,$3,$4,$5,'product',$6,$7,$8,$9,true) RETURNING id`,
          [tid, name, sku, brand, unit, sale, cost, stock, min],
        )
      ).id as string;
    const mkService = async (name: string, sku: string, sale: number, durationMin: number) =>
      (
        await one(
          `INSERT INTO inventory_item (tenant_id, name, sku, kind, sale_price, duration_minutes, is_active)
           VALUES ($1,$2,$3,'service',$4,$5,true) RETURNING id`,
          [tid, name, sku, sale, durationMin],
        )
      ).id as string;

    const oleo = await mkProduct('Óleo Motor 5W30 Sintético 1L', 'OLEO0001', 'Mobil', 45.9, 28.0, 40, 10, 'L');
    const filtroOleo = await mkProduct('Filtro de Óleo', 'FILT0001', 'Tecfil', 32.0, 18.0, 25, 5);
    const pastilha = await mkProduct('Pastilha de Freio Dianteira', 'PAST0001', 'Bosch', 180.0, 110.0, 12, 4);
    await mkProduct('Filtro de Ar', 'FILT0002', 'Tecfil', 55.0, 30.0, 3, 5); // abaixo do mínimo (demo)
    const svcTroca = await mkService('Troca de Óleo e Filtro', 'SERV0001', 80.0, 30);
    const svcAlinhar = await mkService('Alinhamento e Balanceamento', 'SERV0002', 120.0, 60);
    const svcRevisao = await mkService('Revisão Completa', 'SERV0003', 350.0, 120);

    // ---- ordens de serviço (com itens + timeline) ----
    type Item = { kind: 'product' | 'service'; ref: string; name: string; qty: number; price: number };
    const mkOrder = async (opts: {
      number: string;
      customerId: string;
      customerName: string;
      subjectId: string;
      subjectLabel: string;
      status: string;
      complaint: string;
      diagnosis?: string;
      assigned?: boolean;
      items: Item[];
      ageMin: number;
    }) => {
      const total = opts.items.reduce((s, it) => s + it.qty * it.price, 0);
      const isClosed = ['concluida', 'entregue'].includes(opts.status);
      const isRunning = opts.status === 'em_execucao' || isClosed;
      const order = await one(
        `INSERT INTO service_order
           (tenant_id, number, customer_id, customer_name, subject_id, subject_label, status,
            assigned_to, opened_by, complaint, diagnosis, total, stock_applied,
            opened_at, started_at, finished_at, closed_at, created_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,
            now() - ($14 || ' minutes')::interval,
            $15, $16, $17, now() - ($14 || ' minutes')::interval)
         RETURNING id, public_token`,
        [
          tid, opts.number, opts.customerId, opts.customerName, opts.subjectId, opts.subjectLabel,
          opts.status, opts.assigned ? mechId : null, ownerId, opts.complaint, opts.diagnosis ?? null,
          total, isRunning,
          String(opts.ageMin),
          isRunning ? new Date(Date.now() - (opts.ageMin - 20) * 60000) : null,
          isClosed ? new Date(Date.now() - (opts.ageMin - 60) * 60000) : null,
          opts.status === 'entregue' ? new Date(Date.now() - (opts.ageMin - 90) * 60000) : null,
        ],
      );
      for (const it of opts.items) {
        await q(
          `INSERT INTO service_order_item (tenant_id, order_id, kind, inventory_item_id, name, quantity, unit_price, total)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [tid, order.id, it.kind, it.ref, it.name, it.qty, it.price, it.qty * it.price],
        );
      }
      // timeline: criação + (se rodou) mudança de status + nota
      await q(
        `INSERT INTO service_order_event (tenant_id, order_id, kind, message, status_snapshot, visible_public, created_by)
         VALUES ($1,$2,'created', 'OS aberta', 'aberta', true, $3)`,
        [tid, order.id, ownerId],
      );
      if (isRunning) {
        await q(
          `INSERT INTO service_order_event (tenant_id, order_id, kind, message, status_snapshot, visible_public, created_by)
           VALUES ($1,$2,'status_change', 'Serviço iniciado', 'em_execucao', true, $3)`,
          [tid, order.id, mechId],
        );
      }
      return order;
    };

    await mkOrder({
      number: 'OS-0001', customerId: joao, customerName: 'João da Silva', subjectId: gol, subjectLabel: 'VW Gol 1.0 — ABC1D23',
      status: 'entregue', complaint: 'Troca de óleo periódica', diagnosis: 'Óleo e filtro trocados; veículo ok.', assigned: true,
      ageMin: 4320,
      items: [
        { kind: 'service', ref: svcTroca, name: 'Troca de Óleo e Filtro', qty: 1, price: 80.0 },
        { kind: 'product', ref: oleo, name: 'Óleo Motor 5W30 Sintético 1L', qty: 4, price: 45.9 },
        { kind: 'product', ref: filtroOleo, name: 'Filtro de Óleo', qty: 1, price: 32.0 },
      ],
    });
    const osCivic = await mkOrder({
      number: 'OS-0002', customerId: maria, customerName: 'Maria Oliveira', subjectId: civic, subjectLabel: 'Honda Civic — DEF4G56',
      status: 'em_execucao', complaint: 'Barulho ao frear e volante puxando', diagnosis: 'Trocar pastilhas e alinhar.', assigned: true,
      ageMin: 180,
      items: [
        { kind: 'service', ref: svcAlinhar, name: 'Alinhamento e Balanceamento', qty: 1, price: 120.0 },
        { kind: 'product', ref: pastilha, name: 'Pastilha de Freio Dianteira', qty: 1, price: 180.0 },
      ],
    });
    await mkOrder({
      number: 'OS-0003', customerId: transp, customerName: 'Transportadora Rápida LTDA', subjectId: sprinter, subjectLabel: 'Mercedes Sprinter — GHI7J89',
      status: 'aberta', complaint: 'Revisão preventiva da frota', assigned: false, ageMin: 30, items: [],
    });
    await mkOrder({
      number: 'OS-0004', customerId: joao, customerName: 'João da Silva', subjectId: gol, subjectLabel: 'VW Gol 1.0 — ABC1D23',
      status: 'concluida', complaint: 'Revisão dos 60 mil km', diagnosis: 'Revisão completa realizada.', assigned: true,
      ageMin: 1440,
      items: [{ kind: 'service', ref: svcRevisao, name: 'Revisão Completa', qty: 1, price: 350.0 }],
    });

    // ---- chat público na OS em execução (demo de acompanhamento em tempo real) ----
    const conv = await one(
      `INSERT INTO conversation (tenant_id, ref_type, ref_id, title, channel, ref_label, staff_unread, last_message_at)
       VALUES ($1,'os',$2,$3,'public_link',$4,1, now()) RETURNING id`,
      [tid, osCivic.id, 'Maria Oliveira', 'OS-0002'],
    );
    await q(
      `INSERT INTO message (tenant_id, conversation_id, sender, author_name, body, created_at)
       VALUES ($1,$2,'customer','Maria Oliveira','Olá, tem previsão para o meu carro ficar pronto?', now() - interval '20 minutes'),
              ($1,$2,'staff','Carlos Mecânico','Oi Maria! Estamos finalizando o alinhamento, fica pronto hoje à tarde.', now() - interval '12 minutes'),
              ($1,$2,'customer','Maria Oliveira','Perfeito, obrigada!', now() - interval '8 minutes')`,
      [tid, conv.id],
    );

    await q('COMMIT');

    // ---- conferência ----
    const counts = await q(
      `SELECT 'customers' t, count(*)::int n FROM customer WHERE tenant_id=$1
       UNION ALL SELECT 'subjects', count(*)::int FROM subject WHERE tenant_id=$1
       UNION ALL SELECT 'inventory', count(*)::int FROM inventory_item WHERE tenant_id=$1
       UNION ALL SELECT 'service_orders', count(*)::int FROM service_order WHERE tenant_id=$1
       UNION ALL SELECT 'messages', count(*)::int FROM message WHERE tenant_id=$1`,
      [tid],
    );
    // eslint-disable-next-line no-console
    console.log('\n✅ Seed de demonstração aplicado.');
    // eslint-disable-next-line no-console
    console.table(counts.rows);
    // eslint-disable-next-line no-console
    console.log(
      `\nTenant: Oficina Demo OrbixHub (slug: ${DEMO_SLUG})\n` +
        `Login DONO:     ${OWNER_EMAIL}  /  ${PASSWORD}\n` +
        `Login MECÂNICO: ${MECH_EMAIL}  /  ${PASSWORD}\n` +
        `Acompanhamento público da OS-0002: token ${osCivic.public_token}\n`,
    );
  } catch (e) {
    await q('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    await db.end();
  }
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});
