import { CleanupService } from './cleanup.service';
import type { PrismaService } from '../database/prisma.service';

describe('CleanupService', () => {
  it('deletes old login_attempt, expired tokens, stale refresh tokens', async () => {
    const prisma = {
      login_attempt: { deleteMany: jest.fn(async () => ({ count: 3 })) },
      one_time_token: { deleteMany: jest.fn(async () => ({ count: 2 })) },
      refresh_token: { deleteMany: jest.fn(async () => ({ count: 1 })) },
    } as unknown as PrismaService;
    const svc = new CleanupService(prisma);
    const res = await svc.runCleanup();
    expect(prisma.login_attempt.deleteMany).toHaveBeenCalled();
    expect(prisma.one_time_token.deleteMany).toHaveBeenCalled();
    expect(prisma.refresh_token.deleteMany).toHaveBeenCalled();
    expect(res).toEqual({ loginAttempts: 3, oneTimeTokens: 2, refreshTokens: 1 });
  });
});
