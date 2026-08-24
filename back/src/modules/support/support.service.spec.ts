import { BadRequestException, NotFoundException } from '@nestjs/common';
import { SupportService } from './support.service';
import type { SupportRepository } from './support.repository';
import type { MailerService } from '../../common/mailer/mailer.service';
import type { TenancyService } from '../tenancy/tenancy.service';
import type { AuditService } from '../../common/audit/audit.service';
import type { EventEmitter2 } from '@nestjs/event-emitter';
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
  const events = { emit: jest.fn() } as unknown as EventEmitter2;
  const env = { SUPPORT_EMAIL: over.supportEmail } as unknown as Env;

  return {
    svc: new SupportService(repo, mailer, tenancy, audit, events, env),
    repo,
    sendMessage,
    audit,
    events,
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

// ---------------------------------------------------------------------------
// Lado da Orbix (painel administrativo). O que importa aqui é que os dois lados
// do balcão NÃO se confundam: quem lê, quem escreve, e de quem é o ponto de
// não lida.
// ---------------------------------------------------------------------------

describe('SupportService — lado da Orbix', () => {
  it('lista os chamados contando as mensagens DO CLIENTE como não lidas', async () => {
    const { svc, repo } = make();
    await svc.ticketsDoTenant('t1');
    // `true` = ponto de vista da Orbix. Com `false` o painel mostraria as
    // próprias respostas como pendentes.
    expect(repo.listarTickets).toHaveBeenCalledWith('t1', true);
  });

  it('abrir a conversa no painel marca as mensagens do cliente como lidas', async () => {
    const { svc, repo } = make();
    await svc.mensagensParaOrbix('t1', 'tk1');
    expect(repo.marcarLidas).toHaveBeenCalledWith('t1', 'tk1', false);
  });

  it('404 em chamado que não é do tenant informado', async () => {
    const { svc } = make({ ticket: null });
    await expect(svc.mensagensParaOrbix('t1', 'sumiu')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(svc.responderComoOrbix('t1', 'sumiu', 'oi', 'Ana')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('a resposta vai assinada e SEM author_user_id', async () => {
    const { svc, repo } = make();
    await svc.responderComoOrbix('t1', 'tk1', '  já resolvemos  ', 'Ana do Suporte');
    expect(repo.criarMensagem).toHaveBeenCalledWith('t1', {
      ticketId: 'tk1',
      body: 'já resolvemos',
      fromOrbix: true,
      // Quem responde não é usuário DESTE tenant: apontar para um id de lá
      // seria mentira, e a auditoria do admin é que guarda quem foi.
      authorUserId: null,
      authorName: 'Ana do Suporte',
    });
  });

  it('recusa resposta vazia', async () => {
    const { svc } = make();
    await expect(svc.responderComoOrbix('t1', 'tk1', '   ', 'Ana')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('resolver pelo painel encerra e audita como orbix-admin', async () => {
    const { svc, repo, audit } = make();
    await svc.resolverComoOrbix('t1', 'tk1');
    expect(repo.definirStatus).toHaveBeenCalledWith('t1', 'tk1', 'resolvido');
    expect(audit.log).toHaveBeenCalledWith(
      't1',
      null,
      'support_message',
      'tk1',
      expect.objectContaining({ por: 'orbix-admin' }),
    );
  });
});

// ---------------------------------------------------------------------------
// Fechar é decisão da Orbix. Antes, uma mensagem do cliente num chamado
// resolvido o reabria sozinha — e quem fechou perdia o controle do que estava
// fechado. Hoje o cliente PEDE, e o pedido é uma pendência visível.
// ---------------------------------------------------------------------------

const FECHADO = { ...TICKET, status: 'resolvido' };

describe('SupportService — reabertura', () => {
  it('responder num chamado FECHADO é recusado', async () => {
    const { svc, repo } = make({ ticket: FECHADO });
    await expect(svc.responder(user, 'tk1', 'oi')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(repo.criarMensagem).not.toHaveBeenCalled();
  });

  it('pedido de reabertura grava a mensagem e marca a pendência', async () => {
    const { svc, repo } = make({ ticket: FECHADO });
    await svc.solicitarReabertura(user, 'tk1', '  voltou a dar erro  ');

    expect(repo.criarMensagem).toHaveBeenCalledWith('t1', {
      ticketId: 'tk1',
      body: 'voltou a dar erro',
      fromOrbix: false,
      authorUserId: 'u1',
    });
    expect(repo.definirStatus).toHaveBeenCalledWith(
      't1',
      'tk1',
      'reabertura_solicitada',
    );
  });

  it('não deixa pedir reabertura do que já está aberto', async () => {
    const { svc } = make();
    await expect(
      svc.solicitarReabertura(user, 'tk1', 'oi'),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('pedido vazio é recusado — reabrir sem dizer por quê não ajuda ninguém', async () => {
    const { svc } = make({ ticket: FECHADO });
    await expect(
      svc.solicitarReabertura(user, 'tk1', '   '),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('SupportService — aviso em tempo real', () => {
  it('mensagem do cliente avisa as telas abertas', async () => {
    const { svc, events } = make();
    await svc.responder(user, 'tk1', 'oi');
    expect(events.emit).toHaveBeenCalledWith('support.changed', {
      tenantId: 't1',
      ticketId: 'tk1',
      kind: 'mensagem',
      daOrbix: false,
    });
  });

  it('resposta da Orbix avisa marcada como nossa', async () => {
    const { svc, events } = make();
    await svc.responderComoOrbix('t1', 'tk1', 'já vimos', 'Ana');
    expect(events.emit).toHaveBeenCalledWith('support.changed', {
      tenantId: 't1',
      ticketId: 'tk1',
      kind: 'mensagem',
      daOrbix: true,
    });
  });

  it('fechar pelo painel avisa mudança de status', async () => {
    const { svc, events } = make();
    await svc.resolverComoOrbix('t1', 'tk1');
    expect(events.emit).toHaveBeenCalledWith('support.changed', {
      tenantId: 't1',
      ticketId: 'tk1',
      kind: 'status',
      daOrbix: true,
    });
  });
});
