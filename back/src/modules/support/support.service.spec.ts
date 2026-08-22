import { BadRequestException, NotFoundException } from '@nestjs/common';
import { SupportService } from './support.service';
import type { SupportRepository } from './support.repository';
import type { MailerService } from '../../common/mailer/mailer.service';
import type { TenancyService } from '../tenancy/tenancy.service';
import type { AuditService } from '../../common/audit/audit.service';
import type { Env } from '../../common/config/env.schema';
import type { AuthUser } from '../../common/auth/auth.types';

const user: AuthUser = { userId: 'u1', tenantId: 't1', role: 'owner', jti: 'j' };

const TICKET = {
  id: 'tk1',
  subject: 'A nota não sai',
  status: 'aberto',
  last_message_at: new Date('2026-08-21T10:00:00Z'),
  created_at: new Date('2026-08-21T09:00:00Z'),
  naoLidas: 0,
};

function make(
  over: {
    supportEmail?: string;
    sendMessage?: jest.Mock;
    ticket?: unknown;
  } = {},
) {
  const criada = {
    id: 'm1',
    body: 'preciso de ajuda',
    from_orbix: false,
    author_name: null,
    created_at: new Date('2026-08-21T10:00:00Z'),
  };
  const repo = {
    listarTickets: jest.fn(async () => [TICKET]),
    acharTicket: jest.fn(async () =>
      over.ticket === undefined ? TICKET : over.ticket,
    ),
    criarTicket: jest.fn(async () => ({ id: 'tk1' })),
    mensagens: jest.fn(async () => [criada]),
    criarMensagem: jest.fn(async () => criada),
    marcarLidas: jest.fn(async () => undefined),
    definirStatus: jest.fn(async () => undefined),
    naoLidasPeloCliente: jest.fn(async () => 3),
  } as unknown as SupportRepository;

  const sendMessage = over.sendMessage ?? jest.fn(async () => undefined);
  const mailer = { sendMessage } as unknown as MailerService;
  const tenancy = {
    getCompanyView: jest.fn(async () => ({
      companyName: 'Oficina do Zé',
      email: 'ze@oficina.com',
    })),
  } as unknown as TenancyService;
  const audit = { log: jest.fn(async () => undefined) } as unknown as AuditService;
  const env = { SUPPORT_EMAIL: over.supportEmail } as unknown as Env;

  return {
    svc: new SupportService(repo, mailer, tenancy, audit, env),
    repo,
    sendMessage,
    audit,
  };
}

describe('SupportService.abrir', () => {
  it('exige assunto', async () => {
    const { svc } = make();
    await expect(svc.abrir(user, '   ', 'texto')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('exige corpo — chamado vazio não serve a ninguém', async () => {
    const { svc } = make();
    await expect(svc.abrir(user, 'Assunto', '  ')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('recusa assunto e corpo acima do limite', async () => {
    const { svc } = make();
    await expect(
      svc.abrir(user, 'x'.repeat(SupportService.MAX_SUBJECT + 1), 'ok'),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      svc.abrir(user, 'ok', 'x'.repeat(SupportService.MAX_BODY + 1)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('cria o chamado com a primeira mensagem e audita', async () => {
    const { svc, repo, audit } = make();
    await svc.abrir(user, '  A nota não sai  ', '  preciso de ajuda  ');

    expect(repo.criarTicket).toHaveBeenCalledWith('t1', 'A nota não sai', 'u1');
    expect(repo.criarMensagem).toHaveBeenCalledWith('t1', {
      ticketId: 'tk1',
      body: 'preciso de ajuda',
      fromOrbix: false,
      authorUserId: 'u1',
    });
    expect(audit.log).toHaveBeenCalledWith(
      't1',
      'u1',
      'support_message',
      'tk1',
      { assunto: 'A nota não sai' },
    );
  });

  it('avisa a Orbix com o assunto no título e replyTo na empresa', async () => {
    const { svc, sendMessage } = make({ supportEmail: 'suporte@orbix.com' });
    await svc.abrir(user, 'A nota não sai', 'detalhes aqui');

    const msg = sendMessage.mock.calls[0][0] as Record<string, string>;
    expect(msg.to).toBe('suporte@orbix.com');
    expect(msg.subject).toContain('Oficina do Zé');
    expect(msg.subject).toContain('A nota não sai');
    expect(msg.replyTo).toBe('ze@oficina.com');
    expect(msg.text).toContain('detalhes aqui');
  });

  it('sem SUPPORT_EMAIL, grava e não tenta enviar', async () => {
    const { svc, repo, sendMessage } = make();
    await svc.abrir(user, 'Assunto', 'corpo');
    expect(repo.criarTicket).toHaveBeenCalled();
    expect(sendMessage).not.toHaveBeenCalled();
  });

  it('e-mail fora do ar NÃO perde o chamado', async () => {
    // Gravação vem antes do envio: se o SMTP cair, o cliente não pode receber
    // erro achando que precisa reenviar.
    const quebrado = jest.fn(async () => {
      throw new Error('smtp fora');
    });
    const { svc, repo } = make({
      supportEmail: 'suporte@orbix.com',
      sendMessage: quebrado,
    });
    await expect(svc.abrir(user, 'Assunto', 'corpo')).resolves.toMatchObject({
      id: 'tk1',
    });
    expect(repo.criarTicket).toHaveBeenCalled();
  });
});

describe('SupportService.responder', () => {
  it('404 em chamado que não é do tenant', async () => {
    const { svc } = make({ ticket: null });
    await expect(svc.responder(user, 'tk-alheio', 'oi')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('grava no chamado informado', async () => {
    const { svc, repo } = make();
    await svc.responder(user, 'tk1', 'mais um detalhe');
    expect(repo.criarMensagem).toHaveBeenCalledWith('t1', {
      ticketId: 'tk1',
      body: 'mais um detalhe',
      fromOrbix: false,
      authorUserId: 'u1',
    });
  });
});

describe('SupportService.mensagens', () => {
  it('abrir o chamado marca as respostas da Orbix como lidas', async () => {
    // Abrir É a leitura; exigir um clique a mais faria o ponto de não lida mentir.
    const { svc, repo } = make();
    await svc.mensagens(user, 'tk1');
    expect(repo.marcarLidas).toHaveBeenCalledWith('t1', 'tk1', true);
  });

  it('404 em chamado inexistente', async () => {
    const { svc } = make({ ticket: null });
    await expect(svc.mensagens(user, 'nada')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});

describe('SupportService.resolver', () => {
  it('encerra o chamado', async () => {
    const { svc, repo } = make();
    await svc.resolver(user, 'tk1');
    expect(repo.definirStatus).toHaveBeenCalledWith('t1', 'tk1', 'resolvido');
  });
});
