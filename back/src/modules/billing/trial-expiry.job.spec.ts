import { TrialExpiryJob } from './trial-expiry.job';

const envWith = (enforce: boolean, carencia = 3) =>
  ({
    BILLING_ENFORCE_SUBSCRIPTION: enforce,
    BILLING_GRACE_DAYS: carencia,
    APP_PUBLIC_URL: 'https://hub.exemplo.com',
  }) as never;

/** O correio, falso — o que importa aqui é O QUE o job decide, não o e-mail. */
const correioFalso = () => ({
  avisoDeVencimento: jest.fn(async () => true),
  acessoVencido: jest.fn(async () => true),
  acessoBloqueado: jest.fn(async () => true),
});

describe('TrialExpiryJob', () => {
  it('transitions each expired trial to past_due and audits', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => [
        { tenant_id: 't1', subscription_id: 's1' },
        { tenant_id: 't2', subscription_id: 's2' },
      ]),
      findExpiredAccess: jest.fn(async () => []),
      findVencimentoProximo: jest.fn(async () => []),
      marcarAvisoEnviado: jest.fn(),
      findGraceExpired: jest.fn(async () => []),
      updateSubscriptionStatus: jest.fn(async () => ({ id: 's' })),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;
    const job = new TrialExpiryJob(repo, tenant, audit, correioFalso() as never, envWith(true));

    await job.run();

    const repoMock = repo as unknown as { updateSubscriptionStatus: jest.Mock };
    const auditMock = audit as unknown as { log: jest.Mock };
    expect(repoMock.updateSubscriptionStatus).toHaveBeenCalledTimes(2);
    expect(repoMock.updateSubscriptionStatus).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'past_due', block_reason: expect.any(String) }),
    );
    expect(auditMock.log).toHaveBeenCalledWith(
      't1', null, 'subscription_change', 'trial_expired', expect.any(Object),
    );
  });

  it('no expired trials -> no writes', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => []),
      findExpiredAccess: jest.fn(async () => []),
      findVencimentoProximo: jest.fn(async () => []),
      marcarAvisoEnviado: jest.fn(),
      findGraceExpired: jest.fn(async () => []),
      updateSubscriptionStatus: jest.fn(),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;
    await new TrialExpiryJob(repo, tenant, audit, correioFalso() as never, envWith(true)).run();
    const repoMock = repo as unknown as { updateSubscriptionStatus: jest.Mock };
    expect(repoMock.updateSubscriptionStatus).not.toHaveBeenCalled();
  });

  it('BILLING_ENFORCE_SUBSCRIPTION=false -> nem consulta os trials vencidos', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => [{ tenant_id: 't1', subscription_id: 's1' }]),
      findExpiredAccess: jest.fn(async () => [{ tenant_id: 't2', subscription_id: 's2' }]),
      findVencimentoProximo: jest.fn(async () => []),
      marcarAvisoEnviado: jest.fn(),
      findGraceExpired: jest.fn(async () => []),
      updateSubscriptionStatus: jest.fn(),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;
    await new TrialExpiryJob(repo, tenant, audit, correioFalso() as never, envWith(false)).run();
    const repoMock = repo as unknown as {
      findExpiredTrials: jest.Mock;
      updateSubscriptionStatus: jest.Mock;
    };
    const auditMock = audit as unknown as { log: jest.Mock };
    expect(repoMock.findExpiredTrials).not.toHaveBeenCalled();
    expect(repoMock.updateSubscriptionStatus).not.toHaveBeenCalled();
    expect(auditMock.log).not.toHaveBeenCalled();
  });

  it('acesso fora do prazo também vira past_due, com motivo próprio', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => []),
      findExpiredAccess: jest.fn(async () => [
        { tenant_id: 't9', subscription_id: 's9' },
      ]),
      findVencimentoProximo: jest.fn(async () => []),
      marcarAvisoEnviado: jest.fn(),
      findGraceExpired: jest.fn(async () => []),
      updateSubscriptionStatus: jest.fn(async () => ({ id: 's9' })),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;

    await new TrialExpiryJob(repo, tenant, audit, correioFalso() as never, envWith(true)).run();

    const repoMock = repo as unknown as { updateSubscriptionStatus: jest.Mock };
    const auditMock = audit as unknown as { log: jest.Mock };
    expect(repoMock.updateSubscriptionStatus).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'past_due', block_reason: expect.any(String) }),
    );
    // Motivo separado do trial: quem lê a auditoria precisa saber se caiu por
    // fim de teste ou por contrato vencido — a conversa com o cliente é outra.
    expect(auditMock.log).toHaveBeenCalledWith(
      't9', null, 'subscription_change', 'access_expired', expect.any(Object),
    );
  });

  it('passada a carência, somente-leitura vira bloqueio total', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => []),
      findExpiredAccess: jest.fn(async () => []),
      findVencimentoProximo: jest.fn(async () => []),
      marcarAvisoEnviado: jest.fn(),
      findGraceExpired: jest.fn(async () => [{ tenant_id: 't7', subscription_id: 's7' }]),
      updateSubscriptionStatus: jest.fn(async () => ({ id: 's7' })),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;

    await new TrialExpiryJob(repo, tenant, audit, correioFalso() as never, envWith(true)).run();

    const repoMock = repo as unknown as {
      findGraceExpired: jest.Mock;
      updateSubscriptionStatus: jest.Mock;
    };
    const auditMock = audit as unknown as { log: jest.Mock };

    // `canceled`, não `past_due`: é o corte de quem teve os dias de carência e
    // não pagou. Repetir past_due deixaria o cliente eternamente em leitura.
    expect(repoMock.updateSubscriptionStatus).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'canceled', block_reason: expect.any(String) }),
    );
    expect(repoMock.findGraceExpired).toHaveBeenCalledWith(3);
    expect(auditMock.log).toHaveBeenCalledWith(
      't7', null, 'subscription_change', 'grace_expired', expect.any(Object),
    );
  });

  it('a carência é lida do ambiente, não fixada no código', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => []),
      findExpiredAccess: jest.fn(async () => []),
      findVencimentoProximo: jest.fn(async () => []),
      marcarAvisoEnviado: jest.fn(),
      findGraceExpired: jest.fn(async () => []),
      updateSubscriptionStatus: jest.fn(),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;

    await new TrialExpiryJob(
      repo,
      tenant,
      { log: jest.fn() } as never,
      correioFalso() as never,
      envWith(true, 7),
    ).run();

    expect((repo as unknown as { findGraceExpired: jest.Mock }).findGraceExpired)
      .toHaveBeenCalledWith(7);
  });

  describe('aviso antes de vencer', () => {
    const repoQueVence = (vence_em: Date) =>
      ({
        findExpiredTrials: jest.fn(async () => []),
        findExpiredAccess: jest.fn(async () => []),
        findGraceExpired: jest.fn(async () => []),
        findVencimentoProximo: jest.fn(async () => [
          { tenant_id: 't1', subscription_id: 's1', vence_em },
        ]),
        marcarAvisoEnviado: jest.fn(),
        updateSubscriptionStatus: jest.fn(),
      }) as never;

    const tenantFalso = () =>
      ({ runWithTenant: (_t: string, fn: () => unknown) => fn() }) as never;

    const rodar = (repo: never, correio: object, enforce = true) =>
      new TrialExpiryJob(
        repo,
        tenantFalso(),
        { log: jest.fn() } as never,
        correio as never,
        envWith(enforce),
      ).run();

    const marcou = (repo: never) =>
      (repo as unknown as { marcarAvisoEnviado: jest.Mock }).marcarAvisoEnviado;

    it('avisa e marca A DATA que anunciou', async () => {
      const vence = new Date(Date.now() + 10 * 86_400_000);
      const repo = repoQueVence(vence);
      const correio = correioFalso();

      await rodar(repo, correio);

      expect(correio.avisoDeVencimento).toHaveBeenCalledWith('t1', expect.any(Number));
      // Marcar a DATA, e não um booleano, é o que faz o aviso voltar a valer
      // quando o prazo é renovado.
      expect(marcou(repo)).toHaveBeenCalledWith(vence);
    });

    /**
     * Marcar antes de enviar trocaria "avisei uma vez" por "tentei uma vez": o
     * cliente perderia o único aviso por causa de um SMTP que piscou.
     */
    it('e-mail nao saiu -> nao marca, para tentar de novo amanha', async () => {
      const repo = repoQueVence(new Date(Date.now() + 5 * 86_400_000));
      const correio = { ...correioFalso(), avisoDeVencimento: jest.fn(async () => false) };

      await rodar(repo, correio);

      expect(marcou(repo)).not.toHaveBeenCalled();
    });

    it('cobranca desligada -> nao avisa ninguem', async () => {
      const repo = repoQueVence(new Date(Date.now() + 5 * 86_400_000));
      const correio = correioFalso();

      await rodar(repo, correio, false);

      expect(correio.avisoDeVencimento).not.toHaveBeenCalled();
    });
  });
});
