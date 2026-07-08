import { CustomersMetricsService } from './customers-metrics.service';
import type { TenantContext } from '../../common/database/tenant-context';
import type { CustomersRepository } from './customers.repository';

/** TenantContext fake: executa o callback direto (sem banco). */
const tenant = {
  withTenantTx: <T>(fn: () => Promise<T>) => fn(),
} as unknown as TenantContext;

const row = (n: number) => ({
  id: `c${n}`,
  name: `Cliente ${n}`,
  type: n % 2 === 0 ? 'pj' : 'pf',
  created_at: new Date(`2026-06-0${n}T12:00:00.000Z`),
});

const range = {
  from: new Date('2026-06-01T00:00:00.000Z'),
  to: new Date('2026-06-30T23:59:59.999Z'),
};

function makeRepo(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    countActive: jest.fn(async () => 42),
    countNewInRange: jest.fn(async () => 3),
    listNewInRange: jest.fn(async () => [row(1), row(2), row(3)]),
    listNewInRangePage: jest.fn(async () => ({
      rows: [row(1), row(2)],
      total: 7,
    })),
    newInRangeSeries: jest.fn(async () => [
      { day: '2026-06-01', type: 'pf', count: 2 },
      { day: '2026-06-02', type: 'pj', count: 1 },
    ]),
    ...overrides,
  } as unknown as CustomersRepository;
}

describe('CustomersMetricsService.metricsReportPage', () => {
  it('newInRange/total = TOTAL do período, não o tamanho da página', async () => {
    const repo = makeRepo();
    const svc = new CustomersMetricsService(tenant, repo);
    const out = await svc.metricsReportPage({ ...range, page: 1, pageSize: 2 });

    expect(out.rows).toHaveLength(2); // página
    expect(out.total).toBe(7); // total no período
    expect(out.newInRange).toBe(7); // idem — não rows.length
    expect(out.active).toBe(42);
    expect(out.page).toBe(1);
    expect(out.pageSize).toBe(2);
  });

  it('traduz page/pageSize em skip/take (página 3 de 50)', async () => {
    const repo = makeRepo();
    const svc = new CustomersMetricsService(tenant, repo);
    await svc.metricsReportPage({ ...range, page: 3, pageSize: 50 });

    expect(repo.listNewInRangePage).toHaveBeenCalledWith(
      range.from,
      range.to,
      100, // (3-1)*50
      50,
    );
  });

  it('normaliza page/pageSize inválidos para 1/50', async () => {
    const repo = makeRepo();
    const svc = new CustomersMetricsService(tenant, repo);
    const out = await svc.metricsReportPage({ ...range, page: 0, pageSize: 0 });

    expect(out.page).toBe(1);
    expect(out.pageSize).toBe(50);
    expect(repo.listNewInRangePage).toHaveBeenCalledWith(
      range.from,
      range.to,
      0,
      50,
    );
  });

  it('inclui a série por dia/tipo (gráfico independe da paginação)', async () => {
    const svc = new CustomersMetricsService(tenant, makeRepo());
    const out = await svc.metricsReportPage({ ...range, page: 1, pageSize: 2 });

    expect(out.series).toEqual([
      { day: '2026-06-01', type: 'pf', count: 2 },
      { day: '2026-06-02', type: 'pj', count: 1 },
    ]);
  });

  it('serializa rows/range em ISO', async () => {
    const svc = new CustomersMetricsService(tenant, makeRepo());
    const out = await svc.metricsReportPage({ ...range, page: 1, pageSize: 2 });

    expect(out.range).toEqual({
      from: range.from.toISOString(),
      to: range.to.toISOString(),
    });
    expect(out.rows[0]).toEqual({
      id: 'c1',
      name: 'Cliente 1',
      type: 'pf',
      created_at: '2026-06-01T12:00:00.000Z',
    });
  });
});

describe('CustomersMetricsService.metricsReport (export completo)', () => {
  it('continua retornando TODAS as linhas (caminho do CSV/PDF)', async () => {
    const svc = new CustomersMetricsService(tenant, makeRepo());
    const out = await svc.metricsReport(range);

    expect(out.rows).toHaveLength(3);
    expect(out.newInRange).toBe(3);
    expect(out.active).toBe(42);
  });
});
