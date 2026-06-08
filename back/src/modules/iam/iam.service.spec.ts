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

describe('IamService.acceptInvite', () => {
  it('rejects an unknown/expired token', async () => {
    const { repo } = deps();
    const prisma = { $queryRaw: jest.fn(async () => []) };
    const tenant = {};
    const passwords = {};
    const refresh = {};
    const accessTokens = {};
    const audit = {};
    const reauth = {};
    const svc = new IamService(
      repo as unknown as IamRepository,
      prisma as unknown as PrismaService,
      tenant as unknown as TenantContext,
      passwords as unknown as PasswordService,
      refresh as unknown as RefreshService,
      accessTokens as unknown as AccessTokenService,
      audit as unknown as AuditService,
      reauth as unknown as ReauthService,
    );
    await expect(svc.acceptInvite({ token: 'nope' })).rejects.toThrow(
      BadRequestException,
    );
  });
});
