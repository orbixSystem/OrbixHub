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
  const prisma = {
    $queryRaw: jest.fn(async (..._args: unknown[]) => tenants),
  };
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
  // Sem pausa entre tenants no teste: o respiro existe para a cota do
  // provedor, e esperar 5s por oficina aqui só tornaria a suíte lenta.
  const job = new MonthlySummaryJob(
    prisma as never,
    summary as never,
    notifier as never,
    { GEMINI_INTERVALO_MS: 0, GEMINI_ORCAMENTO_DIARIO: 50 } as never,
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

  it('respeita a pausa entre oficinas (cota do provedor é por minuto)', async () => {
    // Sem isto, 31 oficinas viram 31 chamadas em sequência e, da décima em
    // diante, tudo volta 429 — todo mundo recebe o texto automático. Foi o que
    // aconteceu na primeira execução real.
    const { job, gerados } = montar(TRES);
    (job as unknown as {
      env: { GEMINI_INTERVALO_MS: number; GEMINI_ORCAMENTO_DIARIO: number };
    }).env = { GEMINI_INTERVALO_MS: 30, GEMINI_ORCAMENTO_DIARIO: 50 };

    const inicio = Date.now();
    await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    expect(gerados).toHaveLength(3);
    // Duas pausas para três oficinas (a primeira não espera).
    expect(Date.now() - inicio).toBeGreaterThanOrEqual(55);
  });

  it('para no orçamento do dia e deixa o resto para amanhã', async () => {
    // A faixa gratuita do provedor é de 20 requisições por DIA. Sem teto, uma
    // base maior que isso faria as últimas oficinas receberem o texto
    // automático todo mês — e ninguém notaria, porque o resumo chega assim
    // mesmo. A esteira roda de novo amanhã e pega de onde parou.
    const { job, gerados } = montar(TRES);
    (job as unknown as {
      env: { GEMINI_INTERVALO_MS: number; GEMINI_ORCAMENTO_DIARIO: number };
    }).env = { GEMINI_INTERVALO_MS: 0, GEMINI_ORCAMENTO_DIARIO: 2 };

    const r = await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    expect(gerados).toEqual(['t1', 't2']);
    expect(r).toEqual({ gerados: 2, falhas: 0 });
  });

  it('pergunta ao banco só por quem AINDA não tem o resumo do mês', async () => {
    // Quem já tem — inclusive o automático — não é refeito: reescrever amanhã
    // o texto que o dono leu hoje faria o relatório mudar sozinho.
    const { job, prisma } = montar(TRES);
    await job.gerarParaTodos(new Date('2026-10-01T04:00:00Z'));

    const sql = String(prisma.$queryRaw.mock.calls[0][0]);
    expect(sql).toContain('report_find_tenants_missing_monthly_summary');
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

/**
 * O gatilho de UMA oficina.
 *
 * A esteira atende por ordem alfabética com orçamento diário: numa base com
 * mil oficinas, conferir o texto de uma delas custaria esperar a vez chegar —
 * e no banco local de desenvolvimento ela simplesmente nunca chega.
 */
describe('MonthlySummaryJob.gerarParaUm', () => {
  it('gera e avisa só a oficina pedida', async () => {
    const { job, gerados, avisados, summary } = montar([]);
    // O job pergunta o NOME da oficina; o fake de tenants responde a isso.
    (job as never as { prisma: { $queryRaw: jest.Mock } }).prisma.$queryRaw =
      jest.fn(async () => [{ name: 'Oficina Demo' }]);

    const r = await job.gerarParaUm('t9', new Date('2026-10-04T00:00:00Z'));

    expect(r).toEqual({ gerados: 1, falhas: 0 });
    expect(gerados).toEqual(['t9']);
    expect(avisados).toEqual(['t9']);
    // O mês analisado é o ANTERIOR ao "agora" recebido — a mesma regra do cron.
    const ref = summary.gerarParaTenant.mock.calls[0][1] as Date;
    expect(janelaDoMes(ref).rotulo).toBe('Setembro/2026');
  });

  it('oficina inexistente é erro, não um resumo vazio', async () => {
    const { job } = montar([]);
    (job as never as { prisma: { $queryRaw: jest.Mock } }).prisma.$queryRaw =
      jest.fn(async () => []);

    await expect(
      job.gerarParaUm('nao-existe', new Date('2026-10-04T00:00:00Z')),
    ).rejects.toThrow('Oficina não encontrada.');
  });

  it('falha ao gerar não derruba a chamada — ela é contada', async () => {
    const { job } = montar([], { quebraEm: 't9' });
    (job as never as { prisma: { $queryRaw: jest.Mock } }).prisma.$queryRaw =
      jest.fn(async () => [{ name: 'Oficina Demo' }]);

    await expect(
      job.gerarParaUm('t9', new Date('2026-10-04T00:00:00Z')),
    ).resolves.toEqual({ gerados: 0, falhas: 1 });
  });

  it('aviso que falha não faz o resumo já gravado contar como falha', async () => {
    const { job, gerados } = montar([], { avisoQuebraEm: 't9' });
    (job as never as { prisma: { $queryRaw: jest.Mock } }).prisma.$queryRaw =
      jest.fn(async () => [{ name: 'Oficina Demo' }]);

    await expect(
      job.gerarParaUm('t9', new Date('2026-10-04T00:00:00Z')),
    ).resolves.toEqual({ gerados: 1, falhas: 0 });
    expect(gerados).toEqual(['t9']);
  });
});
