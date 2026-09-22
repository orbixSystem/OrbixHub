import { IamService } from './iam.service';
import { BadRequestException } from '@nestjs/common';
import type { IamRepository } from './iam.repository';
import type { PrismaService } from '../../common/database/prisma.service';
import type { TenantContext } from '../../common/database/tenant-context';
import type { PasswordService } from '../../common/crypto/password.service';
import type { RefreshService } from '../auth/refresh.service';
import type { AccessTokenService } from '../../common/auth/jwt.service';
import type { AuditService } from '../../common/audit/audit.service';
import type { ReauthService } from './reauth.service';

function deps() {
  const repo = {
    listRoles: jest.fn(async () => [
      { id: 'role-owner', key: 'owner' },
      { id: 'role-mech', key: 'mechanic' },
    ]),
    listPermissions: jest.fn(),
    createInvite: jest.fn(async () => ({ id: 'inv1' })),
  };
  return { repo };
}

function makeSvc(prisma: unknown) {
  const { repo } = deps();
  return new IamService(
    repo as unknown as IamRepository,
    prisma as unknown as PrismaService,
    {} as unknown as TenantContext,
    {} as unknown as PasswordService,
    {} as unknown as RefreshService,
    {} as unknown as AccessTokenService,
    {} as unknown as AuditService,
    {} as unknown as ReauthService,
  );
}

describe('IamService.acceptInvite', () => {
  it('rejects an unknown/expired token', async () => {
    const svc = makeSvc({ $queryRaw: jest.fn(async () => []) });
    await expect(svc.acceptInvite({ token: 'nope' })).rejects.toThrow(
      BadRequestException,
    );
  });

  it('rejects a canceled invite', async () => {
    const row = {
      invite_id: 'inv1',
      tenant_id: 't1',
      email_normalized: 'a@b.com',
      role_id: 'role-mech',
      expires_at: new Date(Date.now() + 60_000),
      accepted_at: null,
      canceled_at: new Date(),
    };
    const svc = makeSvc({ $queryRaw: jest.fn(async () => [row]) });
    await expect(svc.acceptInvite({ token: 'x' })).rejects.toThrow(
      'Convite inválido ou expirado.',
    );
  });

  it('rejects an expired invite', async () => {
    const row = {
      invite_id: 'inv1',
      tenant_id: 't1',
      email_normalized: 'a@b.com',
      role_id: 'role-mech',
      expires_at: new Date(Date.now() - 60_000),
      accepted_at: null,
      canceled_at: null,
    };
    const svc = makeSvc({ $queryRaw: jest.fn(async () => [row]) });
    await expect(svc.acceptInvite({ token: 'x' })).rejects.toThrow(
      'Convite inválido ou expirado.',
    );
  });

  it('treats null expires_at as never-expires (passes the expiry guard)', async () => {
    const row = {
      invite_id: 'inv1',
      tenant_id: 't1',
      email_normalized: 'a@b.com',
      role_id: 'role-mech',
      expires_at: null,
      accepted_at: null,
      canceled_at: null,
    };
    // No matching user + no password/fullName => the guard is passed and the
    // flow proceeds far enough to throw the *account creation* error instead.
    const prisma = {
      $queryRaw: jest.fn(async () => [row]),
      users: { findUnique: jest.fn(async () => null) },
    };
    const svc = makeSvc(prisma);
    await expect(svc.acceptInvite({ token: 'x' })).rejects.toThrow(
      'Informe nome e senha para criar a conta.',
    );
  });
});

/**
 * O bug que este teste existe para impedir de voltar:
 *
 * a busca procurava `role.name = 'owner'`. Em `role`, `name` e o ROTULO que
 * aparece na tela ('Dono') e o identificador e `key`. A consulta nao casava com
 * nada, devolvia vazio em vez de estourar, e o efeito era um ambiente que
 * simplesmente nao tinha dono: o painel mostrava "sem contato" para todo mundo
 * e nenhuma cobranca saiu por e-mail — tudo em silencio, por meses.
 */
describe('IamService.donoDoTenant', () => {
  const comMembership = (m: unknown) => {
    const findFirst = jest.fn(async () => m);
    const tenant = {
      runWithTenant: (_t: string, fn: () => unknown) => fn(),
      getClient: () => ({ membership: { findFirst } }),
    } as unknown as TenantContext;
    const { repo } = deps();
    const svc = new IamService(
      repo as unknown as IamRepository,
      {} as unknown as PrismaService,
      tenant,
      {} as unknown as PasswordService,
      {} as unknown as RefreshService,
      {} as unknown as AccessTokenService,
      {} as unknown as AuditService,
      {} as unknown as ReauthService,
    );
    return { svc, findFirst };
  };

  it('procura o papel por KEY, nao pelo rotulo', async () => {
    const { svc, findFirst } = comMembership({
      users: { full_name: 'Zé', email_normalized: 'ze@oficina.com' },
    });

    await svc.donoDoTenant('t1');

    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ role: { key: 'owner' } }),
      }),
    );
  });

  it('devolve nome e e-mail do dono', async () => {
    const { svc } = comMembership({
      users: { full_name: 'Zé', email_normalized: 'ze@oficina.com' },
    });

    await expect(svc.donoDoTenant('t1')).resolves.toEqual({
      name: 'Zé',
      email: 'ze@oficina.com',
    });
  });

  it('sem membership de dono -> null (e quem chama decide o que fazer)', async () => {
    const { svc } = comMembership(null);
    await expect(svc.donoDoTenant('t1')).resolves.toBeNull();
  });
});
