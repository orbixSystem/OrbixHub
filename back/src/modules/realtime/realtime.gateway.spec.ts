import { RealtimeGateway } from './realtime.gateway';
import type { Socket } from 'socket.io';
import type { AccessTokenService } from '../../common/auth/jwt.service';
import type { MessagesService } from '../messages/messages.service';
import type { OsPublicService } from '../os/os-public.service';
import type { Env } from '../../common/config/env.schema';

const TOKEN_DE_SERVICO = 'token-de-servico-com-32-caracteres!!';

function socket(ip = '203.0.113.7') {
  const s = {
    data: {} as Record<string, unknown>,
    handshake: { headers: { 'x-forwarded-for': `1.2.3.4, ${ip}` }, address: ip },
    join: jest.fn(),
    disconnect: jest.fn(),
  };
  return s as unknown as Socket & { disconnect: jest.Mock; join: jest.Mock };
}

function gateway(env: Partial<Env> = {}) {
  const osPublic = {
    resolveConversationByToken: jest.fn(async () => null),
  } as unknown as OsPublicService;
  const messages = {} as MessagesService;
  const tokens = {} as AccessTokenService;
  return new RealtimeGateway(osPublic, messages, tokens, {
    ADMIN_API_TOKEN: TOKEN_DE_SERVICO,
    ...env,
  } as Env);
}

describe('RealtimeGateway — sala da Orbix', () => {
  it('aceita o token de serviço', () => {
    const g = gateway();
    const c = socket();
    expect(g.subscribeOrbix({ token: TOKEN_DE_SERVICO }, c)).toEqual({ ok: true });
    expect(c.join).toHaveBeenCalledWith('orbix:suporte');
  });

  it('recusa e NÃO entra na sala com token errado', () => {
    const g = gateway();
    const c = socket();
    expect(g.subscribeOrbix({ token: 'chute' }, c)).toEqual({ ok: false });
    expect(c.join).not.toHaveBeenCalled();
  });

  it('fica fechado quando não há token de serviço configurado', () => {
    const g = gateway({ ADMIN_API_TOKEN: undefined });
    const c = socket();
    // Nem o valor "certo" abre: sem segredo configurado, a porta não existe.
    expect(g.subscribeOrbix({ token: TOKEN_DE_SERVICO }, c)).toEqual({ ok: false });
    expect(c.join).not.toHaveBeenCalled();
  });

  it('derruba a conexão depois de 10 chutes — sem isto era oráculo infinito', () => {
    const g = gateway();
    const c = socket();

    for (let i = 0; i < 9; i++) g.subscribeOrbix({ token: `chute-${i}` }, c);
    expect(c.disconnect).not.toHaveBeenCalled();

    g.subscribeOrbix({ token: 'chute-10' }, c);
    expect(c.disconnect).toHaveBeenCalledWith(true);
  });

  it('reconectar não zera o custo: a cota por IP segue valendo', () => {
    const g = gateway();

    // Três sockets do MESMO IP gastam 10 falhas cada = 30, o teto da janela.
    for (let i = 0; i < 3; i++) {
      const c = socket('198.51.100.9');
      for (let t = 0; t < 10; t++) g.subscribeOrbix({ token: `chute-${t}` }, c);
    }

    // Socket novo, IP queimado: nem o token CERTO passa enquanto a janela dura.
    const novo = socket('198.51.100.9');
    expect(g.subscribeOrbix({ token: TOKEN_DE_SERVICO }, novo)).toEqual({ ok: false });
    expect(novo.join).not.toHaveBeenCalled();

    // Outro IP não paga pelo vizinho.
    const outro = socket('203.0.113.200');
    expect(g.subscribeOrbix({ token: TOKEN_DE_SERVICO }, outro)).toEqual({ ok: true });
  });

  it('conta o IP pelo ÚLTIMO X-Forwarded-For — o primeiro o cliente escreve', () => {
    const g = gateway();

    // Mesmo IP real (do nosso proxy), forjando um "cliente" diferente a cada vez.
    for (let i = 0; i < 3; i++) {
      const c = {
        data: {},
        handshake: {
          headers: { 'x-forwarded-for': `10.0.0.${i}, 198.51.100.50` },
          address: '198.51.100.50',
        },
        join: jest.fn(),
        disconnect: jest.fn(),
      } as unknown as Socket;
      for (let t = 0; t < 10; t++) g.subscribeOrbix({ token: `chute-${t}` }, c);
    }

    const novo = socket('198.51.100.50');
    expect(g.subscribeOrbix({ token: TOKEN_DE_SERVICO }, novo)).toEqual({ ok: false });
  });
});

describe('RealtimeGateway — sala pública', () => {
  it('também limita chute de token de link', async () => {
    const g = gateway();
    const c = socket('192.0.2.44');

    for (let i = 0; i < 10; i++) {
      await g.subscribePublic({ token: `chute-${i}` }, c);
    }
    expect(c.disconnect).toHaveBeenCalledWith(true);
    expect(c.join).not.toHaveBeenCalled();
  });
});
