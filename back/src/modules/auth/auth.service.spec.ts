import { AuthService } from './auth.service';
import { VerticalRegistry } from '../../verticals/vertical.registry';
import { UnauthorizedException } from '@nestjs/common';
import type { AuthRepository } from './auth.repository';
import type { RefreshService } from './refresh.service';
import type { PasswordService } from '../../common/crypto/password.service';
import type { AccessTokenService } from '../../common/auth/jwt.service';
import type { MailerService } from '../../common/mailer/mailer.service';
import type { BillingService } from '../billing/billing.service';
import type { AuditService } from '../../common/audit/audit.service';

interface Overrides {
  repo?: Record<string, unknown>;
  refresh?: Record<string, unknown>;
  passwords?: Record<string, unknown>;
}

function deps(overrides: Overrides = {}) {
  const repo = {
    findUserByEmail: jest.fn(),
    findUserById: jest.fn(),
    findUserMemberships: jest.fn(async () => [
      { tenant_id: 't1', tenant_slug: 's1', role_key: 'owner' },
    ]),
    recordLoginAttempt: jest.fn(),
    incrementFailedLogin: jest.fn(),
    resetFailedLogin: jest.fn(),
    setLastTenant: jest.fn(),
    ...overrides.repo,
  };
  const refresh = {
    issue: jest.fn(async () => ({ refreshToken: 'r' })),
    ...overrides.refresh,
  };
  const passwords = {
    verify: jest.fn(async () => true),
    hash: jest.fn(async () => 'h'),
    dummyVerify: jest.fn(async () => false),
    ...overrides.passwords,
  };
  const accessTokens = { sign: jest.fn(() => 'access') };
  const mailer = { send: jest.fn() };
  const billing = { createTrial: jest.fn() };
  const audit = { log: jest.fn() };
  const svc = new AuthService(
    repo as unknown as AuthRepository,
    refresh as unknown as RefreshService,
    passwords as unknown as PasswordService,
    accessTokens as unknown as AccessTokenService,
    mailer as unknown as MailerService,
    billing as unknown as BillingService,
    // VerticalRegistry REAL: é puro (pacotes em código, sem banco), então o
    // teste valida a rejeição de nicho inventado de verdade, não contra um mock.
    new VerticalRegistry(),
    audit as unknown as AuditService,
  );
  return { svc, repo, passwords, refresh };
}

describe('AuthService.login', () => {
  it('returns generic 401 for unknown email (anti-enumeration)', async () => {
    const { svc, repo } = deps({
      repo: { findUserByEmail: jest.fn(async () => null) },
    });
    await expect(
      svc.login({ email: 'x@y.z', password: 'pw' }),
    ).rejects.toThrow(UnauthorizedException);
    expect(repo.recordLoginAttempt).toHaveBeenCalledWith(
      'x@y.z',
      false,
      undefined,
      undefined,
    );
  });

  it('returns generic 401 for wrong password and increments lockout', async () => {
    const { svc, repo } = deps({
      repo: {
        findUserByEmail: jest.fn(async () => ({
          id: 'u1',
          password_hash: 'h',
          full_name: 'U',
        })),
      },
      passwords: { verify: jest.fn(async () => false) },
    });
    await expect(
      svc.login({ email: 'u@x.z', password: 'bad' }),
    ).rejects.toThrow(UnauthorizedException);
    expect(repo.incrementFailedLogin).toHaveBeenCalled();
  });

  it('returns generic 401 when account is locked', async () => {
    const locked = {
      id: 'u1',
      password_hash: 'h',
      full_name: 'U',
      locked_until: new Date(Date.now() + 600000),
    };
    const { svc } = deps({
      repo: { findUserByEmail: jest.fn(async () => locked) },
    });
    await expect(
      svc.login({ email: 'u@x.z', password: 'pw' }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('logs in and picks last_tenant as active', async () => {
    const user = {
      id: 'u1',
      password_hash: 'h',
      full_name: 'U',
      last_tenant_id: 't1',
    };
    const { svc } = deps({
      repo: { findUserByEmail: jest.fn(async () => user) },
    });
    const res = await svc.login({ email: 'u@x.z', password: 'pw' });
    expect(res.accessToken).toBe('access');
    expect(res.memberships).toHaveLength(1);
  });
});

describe('AuthService.register — nicho escolhido no cadastro', () => {
  const dtoBase = {
    tenantName: 'Oficina do Zé',
    slug: 'oficina-do-ze',
    cnpj: '11.222.333/0001-81',
    legalName: 'Oficina do Zé LTDA',
    fullName: 'Zé',
    email: 'ze@oficina.com',
    password: 'senha12345',
  };

  function comRegister() {
    const criado = jest.fn(
      async (_p: { vertical: string | null }) => ({
        userId: 'u1',
        tenantId: 't1',
      }),
    );
    const { svc, repo } = deps({
      repo: {
        createTenantWithOwner: criado,
        findUserMemberships: jest.fn(async () => []),
        // Caminho feliz: e-mail e CNPJ livres.
        findUserByEmail: jest.fn(async () => null),
        findTenantByCnpj: jest.fn(async () => null),
        // Pós-commit: token de verificação de e-mail (I/O externo fora da tx).
        createOneTimeToken: jest.fn(async () => undefined),
        findUserById: jest.fn(async () => ({ id: 'u1', full_name: 'Zé' })),
      },
    });
    return { svc, repo, criado };
  }

  it('grava a vertical escolhida', async () => {
    const { svc, criado } = comRegister();
    await svc.register({ ...dtoBase, vertical: 'veiculos' } as never);
    expect(criado.mock.calls[0][0]).toMatchObject({ vertical: 'veiculos' });
  });

  it('sem escolha, grava null — o servidor aplica o pacote padrão', async () => {
    const { svc, criado } = comRegister();
    await svc.register(dtoBase as never);
    expect(criado.mock.calls[0][0]).toMatchObject({ vertical: null });
  });

  it('nicho inventado pelo cliente vira null, não suja a coluna', async () => {
    // O front lista as opções por GET /verticals; isto é a rede de proteção
    // para quem chama a API direto.
    const { svc, criado } = comRegister();
    await svc.register({ ...dtoBase, vertical: 'nao-existe' } as never);
    expect(criado.mock.calls[0][0]).toMatchObject({ vertical: null });
  });
});
