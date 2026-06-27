import { UnauthorizedException } from '@nestjs/common';
import { ReauthService } from './reauth.service';

describe('ReauthService', () => {
  function make(userRow: unknown, verifyResult: boolean) {
    const prisma = { users: { findUnique: jest.fn(async () => userRow) } } as never;
    const passwords = { verify: jest.fn(async () => verifyResult) } as never;
    return new ReauthService(prisma, passwords);
  }

  it('passes when the current password matches', async () => {
    const svc = make({ id: 'u1', password_hash: 'h' }, true);
    await expect(svc.assertReauth('u1', 'pw')).resolves.toBeUndefined();
  });

  it('throws 401 when the password is wrong', async () => {
    const svc = make({ id: 'u1', password_hash: 'h' }, false);
    await expect(svc.assertReauth('u1', 'bad')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('throws 401 when the user is not found', async () => {
    const svc = make(null, true);
    await expect(svc.assertReauth('nope', 'pw')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
