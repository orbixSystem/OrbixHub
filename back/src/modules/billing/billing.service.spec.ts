/** O correio de cobrança não é o assunto destes testes. */
const correioFalso = () => ({
  avisoDeVencimento: jest.fn(async () => true),
  acessoVencido: jest.fn(async () => true),
  acessoBloqueado: jest.fn(async () => true),
});

import { BillingService } from './billing.service';

describe('BillingService.createTrial', () => {
  it('creates a trialing subscription for TRIAL_PLAN_KEY and reconciles modules on the caller tx', async () => {
    const reconcile = jest.fn(async () => undefined);
    const db = {
      subscription: { create: jest.fn(async () => ({ id: 'sub1' })) },
    };
    const tenant = { getClient: () => db } as never;
    const repo = {
      findPlanByKey: jest.fn(async (k: string) => ({ id: 'plan-trial', key: k })),
      reconcile,
    };
    const env = { TRIAL_PLAN_KEY: 'trial', TRIAL_DAYS: 14, BILLING_REQUIRE_PAYMENT: false } as never;
    const audit = { log: jest.fn() } as never;
    const gateway = {} as never;

    const svc = new BillingService(tenant, repo as never, env, audit, gateway, correioFalso() as never);
    await svc.createTrial('t1');

    expect(repo.findPlanByKey).toHaveBeenCalledWith('trial');
    expect(db.subscription.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ tenant_id: 't1', plan_id: 'plan-trial', status: 'trialing' }),
      }),
    );
    expect(reconcile).toHaveBeenCalledWith('t1', 'plan-trial');
  });
});

/**
 * O aviso tem que sair NA HORA em que a data e salva dentro da janela.
 *
 * Antes so o job da meia-noite avaliava: quem atende punha o vencimento para
 * daqui a dois dias, nao acontecia nada, e a conclusao obvia — a unica
 * disponivel — era que o e-mail nao funciona.
 */
describe('BillingService.ajustarAssinatura — aviso de vencimento', () => {
  const emDias = (d: number) => new Date(Date.now() + d * 86_400_000);

  const montar = (salvo: Record<string, unknown>) => {
    const correio = {
      avisoDeVencimento: jest.fn(async () => true),
      acessoVencido: jest.fn(async () => true),
      acessoBloqueado: jest.fn(async () => true),
    };
    const repo = {
      getSubscription: jest.fn(async () => ({ status: 'active', block_reason: null })),
      ajustarAssinatura: jest.fn(async () => ({
        plan: { key: 'p', name: 'P', price_cents: 0, billing_period: 'monthly' },
        tenant_id: 't1',
        status: 'active',
        trial_ends_at: null,
        current_period_end: null,
        aviso_vencimento_para: null,
        block_reason: null,
        ...salvo,
      })),
      marcarAvisoEnviado: jest.fn(),
    };
    const svc = new BillingService(
      { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never,
      repo as never,
      {} as never,
      { log: jest.fn() } as never,
      {} as never,
      correio as never,
    );
    return { svc, correio, repo };
  };

  it('data dentro da janela -> avisa e marca a data anunciada', async () => {
    const vence = emDias(2);
    const { svc, correio, repo } = montar({ current_period_end: vence });

    await svc.ajustarAssinatura('t1', { accessEndsAt: vence });

    expect(correio.avisoDeVencimento).toHaveBeenCalledWith('t1', expect.any(Number));
    expect(repo.marcarAvisoEnviado).toHaveBeenCalledWith(vence);
  });

  it('data longe -> nao avisa (o job pega quando chegar a hora)', async () => {
    const vence = emDias(60);
    const { svc, correio } = montar({ current_period_end: vence });

    await svc.ajustarAssinatura('t1', { accessEndsAt: vence });

    expect(correio.avisoDeVencimento).not.toHaveBeenCalled();
  });

  it('mesma data ja avisada -> nao repete', async () => {
    const vence = emDias(3);
    const { svc, correio } = montar({
      current_period_end: vence,
      aviso_vencimento_para: vence,
    });

    await svc.ajustarAssinatura('t1', { accessEndsAt: vence });

    expect(correio.avisoDeVencimento).not.toHaveBeenCalled();
  });
});
