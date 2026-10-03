import { MonthlySummaryJob } from './monthly-summary.job';
import { janelaDoMes, mesAnterior } from './monthly-summary.service';

/**
 * O job do dia 1º.
 *
 * Duas garantias que só aparecem quando algo dá errado — e por isso têm de ser
 * testadas antes de dar: um tenant problemático não pode impedir os outros de
 * receberem o resumo, e um e-mail que falha não pode fazer um resumo JÁ GRAVADO
 * contar como falha (seria regerado, e cada geração custa uma chamada paga).
 */
function montar(
  tenants: Array<{ tenant_id: string; tenant_name: string }>,
  opcoes: { quebraEm?: string; avisoQuebraEm?: string } = {},
) {
  const prisma = { $queryRaw: jest.fn(async () => tenants) };
  const gerados: string[] = [];
  const summary = {
    gerarParaTenant: jest.fn(async (tenantId: string, _ref: Date, _nome: string) => {
      if (tenantId === opcoes.quebraEm) throw new Error('dado estranho');
      gerados.push(tenantId);
      return { period: '2026-09-01', periodo: { rotulo: 'Setembro/2026' } } as never;
    }),
  };
  const avisados: string[] = [];
  const notifier = {
    avisar: jest.fn(async (tenantId: string) => {
      if (tenantId === opcoes.avisoQuebraEm) throw new Error('smtp fora');
      avisados.push(tenantId);
    }),
  };
  const job = new MonthlySummaryJob(
    prisma as never,
    summary as never,
    notifier as never,
  );
  return { job, summary, notifier, gerados, avisados, prisma };
}

const TRES = [
  { tenant_id: 't1', tenant_name: 'Oficina A' },
  { tenant_id: 't2', tenant_name: 'Oficina B' },
  { tenant_id: 't3', tenant_name: 'Oficina C' },
];

describe('MonthlySummaryJob', () => {
  it('gera e avisa para todos os tenants elegíveis', async () => {
    const { job, gerados, avisados } = montar(TRES);

    const r = await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    expect(gerados).toEqual(['t1', 't2', 't3']);
    expect(avisados).toEqual(['t1', 't2', 't3']);
    expect(r).toEqual({ gerados: 3, falhas: 0 });
  });

  it('analisa o mês ANTERIOR ao da execução', async () => {
    const { job, summary } = montar([TRES[0]]);

    await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    // Rodando em 1º de outubro, o relatório é de setembro — o mês que fechou.
    const ref = summary.gerarParaTenant.mock.calls[0][1];
    expect(janelaDoMes(ref).rotulo).toBe('Setembro/2026');
  });

  it('um tenant quebrado NÃO impede os outros', async () => {
    const { job, gerados } = montar(TRES, { quebraEm: 't2' });

    const r = await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    // Sem isto, um dado estranho numa oficina deixaria todas as outras sem
    // relatório — e ninguém descobriria até alguém reclamar.
    expect(gerados).toEqual(['t1', 't3']);
    expect(r).toEqual({ gerados: 2, falhas: 1 });
  });

  it('falha no aviso não invalida o resumo já gravado', async () => {
    const { job, gerados } = montar(TRES, { avisoQuebraEm: 't2' });

    const r = await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    // O resumo de t2 existe e está visível no app; contá-lo como falha o faria
    // ser regerado — outra chamada paga pelo mesmo mês, e um texto diferente
    // para um relatório que o dono talvez já tenha lido.
    expect(gerados).toContain('t2');
    expect(r).toEqual({ gerados: 3, falhas: 0 });
  });

  it('sem tenants elegíveis, não chama nada', async () => {
    const { job, summary, notifier } = montar([]);

    const r = await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    expect(summary.gerarParaTenant).not.toHaveBeenCalled();
    expect(notifier.avisar).not.toHaveBeenCalled();
    expect(r).toEqual({ gerados: 0, falhas: 0 });
  });
});

describe('janela do mês', () => {
  it('vai do primeiro ao último instante, em UTC', () => {
    const j = janelaDoMes(new Date('2026-09-17T15:00:00Z'));
    expect(j.from.toISOString()).toBe('2026-09-01T00:00:00.000Z');
    expect(j.to.toISOString()).toBe('2026-09-30T23:59:59.999Z');
    expect(j.rotulo).toBe('Setembro/2026');
  });

  it('fevereiro bissexto termina no dia 29', () => {
    const j = janelaDoMes(new Date('2028-02-10T00:00:00Z'));
    expect(j.to.toISOString()).toBe('2028-02-29T23:59:59.999Z');
  });

  it('o mês anterior a janeiro é dezembro do ano passado', () => {
    expect(janelaDoMes(mesAnterior(new Date('2027-01-05T00:00:00Z'))).rotulo).toBe(
      'Dezembro/2026',
    );
  });
});
