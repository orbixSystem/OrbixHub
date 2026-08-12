import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { OsTrackingService } from './os-tracking.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Unit do envio do link de acompanhamento por e-mail. Cobre o que o atendente
 * vê antes de confirmar (sugestão do e-mail do cadastro) e o que acontece ao
 * confirmar — inclusive quando ele corrige o endereço na hora.
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
} as unknown as AuthUser;

const tenant = {
  withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
} as unknown as ConstructorParameters<typeof OsTrackingService>[0];

const order = {
  id: 'os1',
  number: 'OS-0007',
  customer_id: 'c1',
  customer_name: 'Maria Silva',
  public_token: 'tok-123',
  deleted_at: null,
};

function makeService(
  opts: {
    customerEmail?: string | null;
    customerThrows?: boolean;
    mailThrows?: boolean;
    publicToken?: string | null;
  } = {},
) {
  const repo = {
    findOrderById: jest.fn().mockResolvedValue({
      ...order,
      public_token:
        opts.publicToken === undefined ? order.public_token : opts.publicToken,
    }),
    createEvent: jest.fn().mockResolvedValue(undefined),
  };
  const customers = {
    getCustomer: opts.customerThrows
      ? jest.fn().mockRejectedValue(new Error('Cliente não encontrado.'))
      : jest.fn().mockResolvedValue({
          id: 'c1',
          name: 'Maria Silva',
          email: opts.customerEmail ?? null,
        }),
  };
  const tenancy = {
    getCompanyView: jest
      .fn()
      .mockResolvedValue({ companyName: 'Oficina do Zé', email: 'ze@of.com' }),
  };
  const mailer = {
    sendMessage: opts.mailThrows
      ? jest.fn().mockRejectedValue(new Error('SMTP fora do ar'))
      : jest.fn().mockResolvedValue(undefined),
  };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const svc = new OsTrackingService(
    tenant,
    repo as never,
    customers as never,
    tenancy as never,
    mailer as never,
    audit as never,
    { APP_PUBLIC_URL: 'https://hub.orbixsystem.com' } as never,
  );
  return { svc, repo, customers, mailer, audit };
}

describe('OsTrackingService.getRecipient', () => {
  it('sugere o e-mail do cadastro para o atendente conferir', async () => {
    const { svc } = makeService({ customerEmail: 'maria@ex.com' });
    await expect(svc.getRecipient(user, 'os1')).resolves.toEqual({
      customer_name: 'Maria Silva',
      email: 'maria@ex.com',
    });
  });

  it('cliente sem e-mail: devolve null (a tela abre com o campo vazio)', async () => {
    const { svc } = makeService({ customerEmail: '   ' });
    await expect(svc.getRecipient(user, 'os1')).resolves.toMatchObject({
      email: null,
    });
  });

  it('cliente inacessível não quebra a tela — só não sugere e-mail', async () => {
    const { svc } = makeService({ customerThrows: true });
    await expect(svc.getRecipient(user, 'os1')).resolves.toMatchObject({
      email: null,
    });
  });
});

describe('OsTrackingService.sendLinkByEmail', () => {
  it('envia para o endereço CONFIRMADO (não para o do cadastro) e registra na timeline', async () => {
    const { svc, mailer, repo, customers, audit } = makeService({
      customerEmail: 'antigo@ex.com',
    });

    const result = await svc.sendLinkByEmail(user, 'os1', {
      email: '  Novo@Ex.com ',
    });

    expect(result).toEqual({ sent: true, to: 'novo@ex.com' });
    const sent = mailer.sendMessage.mock.calls[0][0];
    expect(sent.to).toBe('novo@ex.com');
    expect(sent.html).toContain('https://hub.orbixsystem.com/#/t/tok-123');
    expect(sent.text).toContain('https://hub.orbixsystem.com/#/t/tok-123');
    // A oficina é a marca do e-mail; a resposta do cliente volta pra ela.
    expect(sent.fromName).toBe('Oficina do Zé');
    expect(sent.replyTo).toBe('ze@of.com');
    // Enviar NÃO mexe no cadastro do cliente.
    expect(customers.getCustomer).not.toHaveBeenCalled();
    expect(repo.createEvent).toHaveBeenCalledWith(
      't1',
      'os1',
      expect.objectContaining({ kind: 'note', visiblePublic: false }),
    );
    expect(audit.log).toHaveBeenCalledWith(
      't1',
      'u1',
      'os_tracking_link_email',
      'os1',
      { to: 'novo@ex.com' },
    );
  });

  it('OS sem token público: recusa antes de tentar enviar', async () => {
    const { svc, mailer } = makeService({ publicToken: null });
    await expect(
      svc.sendLinkByEmail(user, 'os1', { email: 'a@b.com' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(mailer.sendMessage).not.toHaveBeenCalled();
  });

  it('SMTP fora do ar vira 503 e NÃO deixa nota de "enviado" na timeline', async () => {
    const { svc, repo, audit } = makeService({ mailThrows: true });
    await expect(
      svc.sendLinkByEmail(user, 'os1', { email: 'a@b.com' }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(repo.createEvent).not.toHaveBeenCalled();
    expect(audit.log).not.toHaveBeenCalled();
  });
});
