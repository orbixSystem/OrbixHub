import { BadRequestException } from '@nestjs/common';
import { SupportService } from './support.service';
import type { SupportRepository } from './support.repository';
import type { MailerService } from '../../common/mailer/mailer.service';
import type { TenancyService } from '../tenancy/tenancy.service';
import type { AuditService } from '../../common/audit/audit.service';
import type { Env } from '../../common/config/env.schema';
import type { AuthUser } from '../../common/auth/auth.types';

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  jti: 'j',
};

function make(
  over: {
    supportEmail?: string;
    sendMessage?: jest.Mock;
    empresa?: Record<string, unknown>;
  } = {},
) {
  const criada = {
    id: 'm1',
    body: 'preciso de ajuda',
    from_orbix: false,
    author_name: 'Zé',
    created_at: new Date('2026-08-21T10:00:00Z'),
  };
  const repo = {
    listar: jest.fn(async () => []),
    criar: jest.fn(async () => criada),
    marcarLidas: jest.fn(async () => undefined),
    naoLidasPeloCliente: jest.fn(async () => 2),
  } as unknown as SupportRepository;

  const sendMessage = over.sendMessage ?? jest.fn(async () => undefined);
  const mailer = { sendMessage } as unknown as MailerService;
  const tenancy = {
    getCompanyView: jest.fn(async () =>
      over.empresa ?? { companyName: 'Oficina do Zé', email: 'ze@oficina.com' },
    ),
  } as unknown as TenancyService;
  const audit = { log: jest.fn(async () => undefined) } as unknown as AuditService;
  const env = { SUPPORT_EMAIL: over.supportEmail } as unknown as Env;

  const svc = new SupportService(repo, mailer, tenancy, audit, env);
  return { svc, repo, sendMessage, audit };
}

describe('SupportService.enviar', () => {
  it('recusa mensagem vazia ou só espaços', async () => {
    const { svc } = make();
    await expect(svc.enviar(user, '   ')).rejects.toBeInstanceOf(BadRequestException);
    await expect(svc.enviar(user, '')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('recusa mensagem acima do limite', async () => {
    const { svc } = make();
    const gigante = 'x'.repeat(SupportService.MAX_BODY + 1);
    await expect(svc.enviar(user, gigante)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('grava a mensagem e audita', async () => {
    const { svc, repo, audit } = make({ supportEmail: 'suporte@orbix.com' });
    await svc.enviar(user, '  preciso de ajuda  ');

    // Texto vai aparado; o lado é sempre o do cliente.
    expect(repo.criar).toHaveBeenCalledWith('t1', {
      body: 'preciso de ajuda',
      fromOrbix: false,
      authorUserId: 'u1',
      authorName: null,
    });
    expect(audit.log).toHaveBeenCalledWith('t1', 'u1', 'support_message', 'm1');
  });

  it('avisa a Orbix por e-mail, com replyTo no e-mail da empresa', async () => {
    const { svc, sendMessage } = make({ supportEmail: 'suporte@orbix.com' });
    await svc.enviar(user, 'a nota não sai');

    const msg = sendMessage.mock.calls[0][0] as Record<string, string>;
    expect(msg.to).toBe('suporte@orbix.com');
    expect(msg.subject).toContain('Oficina do Zé');
    // Responder do próprio e-mail chega em quem pediu ajuda.
    expect(msg.replyTo).toBe('ze@oficina.com');
    expect(msg.text).toContain('a nota não sai');
  });

  it('sem SUPPORT_EMAIL configurado, grava e não tenta enviar', async () => {
    const { svc, repo, sendMessage } = make();
    await svc.enviar(user, 'oi');
    expect(repo.criar).toHaveBeenCalled();
    expect(sendMessage).not.toHaveBeenCalled();
  });

  it('e-mail fora do ar NÃO perde a mensagem', async () => {
    // A gravação vem antes do envio de propósito: se o SMTP cair, o cliente não
    // pode receber erro e reenviar — a mensagem já está salva e o admin a lerá.
    const quebrado = jest.fn(async () => {
      throw new Error('smtp fora');
    });
    const { svc, repo } = make({
      supportEmail: 'suporte@orbix.com',
      sendMessage: quebrado,
    });

    await expect(svc.enviar(user, 'socorro')).resolves.toMatchObject({
      body: 'preciso de ajuda',
    });
    expect(repo.criar).toHaveBeenCalled();
  });

  it('empresa sem nome cai no id do tenant, não quebra o assunto', async () => {
    const { svc, sendMessage } = make({
      supportEmail: 'suporte@orbix.com',
      empresa: {},
    });
    await svc.enviar(user, 'oi');
    const msg = sendMessage.mock.calls[0][0] as Record<string, string>;
    expect(msg.subject).toContain('t1');
  });
});

describe('SupportService.thread', () => {
  it('ler marca as mensagens da Orbix como lidas', async () => {
    // Abrir a tela É a leitura; exigir um clique a mais faria o badge mentir.
    const { svc, repo } = make();
    await svc.thread(user);
    expect(repo.marcarLidas).toHaveBeenCalledWith('t1', true);
  });
});
