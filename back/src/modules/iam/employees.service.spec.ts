import {
  BadRequestException,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { EmployeesService } from './employees.service';

function make(
  overrides: {
    membership?: {
      id: string;
      userId: string;
      roleKey?: string;
      status: string;
    } | null;
    activeOwners?: number;
    reauthOk?: boolean;
  } = {},
) {
  const repo = {
    getMembership: jest.fn(
      async () =>
        overrides.membership ?? {
          id: 'm2',
          userId: 'u2',
          roleKey: 'mechanic',
          status: 'active',
        },
    ),
    countActiveOwners: jest.fn(async () => overrides.activeOwners ?? 2),
    setRole: jest.fn(async () => {}),
    setStatus: jest.fn(async () => {}),
    listEmployees: jest.fn(async () => []),
  } as never;
  const reauth = {
    assertReauth: jest.fn(
      overrides.reauthOk === false
        ? async () => {
            throw new UnauthorizedException();
          }
        : async () => {},
    ),
  } as never;
  const audit = { log: jest.fn(async () => {}) } as never;
  return { svc: new EmployeesService(repo, reauth, audit), repo, reauth, audit };
}

const actor = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  jti: 'j1',
} as never; // AuthUser

describe('EmployeesService', () => {
  describe('changeRole', () => {
    it('G6: reauth failure rejects and never calls setRole', async () => {
      const { svc, repo, reauth } = make({ reauthOk: false });
      await expect(
        svc.changeRole('m2', 'gerente', actor, 'wrong-pass'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect((reauth as never as { assertReauth: jest.Mock }).assertReauth)
        .toHaveBeenCalledTimes(1);
      expect(
        (repo as never as { setRole: jest.Mock }).setRole,
      ).not.toHaveBeenCalled();
    });

    it('G2: cannot change own role', async () => {
      const { svc, repo } = make({
        membership: { id: 'm1', userId: 'u1', roleKey: 'owner', status: 'active' },
      });
      await expect(
        svc.changeRole('m1', 'mechanic', actor, 'pass'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(
        (repo as never as { setRole: jest.Mock }).setRole,
      ).not.toHaveBeenCalled();
    });

    it('G3: non-owner cannot grant owner role', async () => {
      const nonOwner = {
        userId: 'u1',
        tenantId: 't1',
        role: 'gerente',
        jti: 'j1',
      } as never;
      const { svc, repo } = make({
        membership: { id: 'm2', userId: 'u2', roleKey: 'mechanic', status: 'active' },
      });
      await expect(
        svc.changeRole('m2', 'owner', nonOwner, 'pass'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(
        (repo as never as { setRole: jest.Mock }).setRole,
      ).not.toHaveBeenCalled();
    });

    it('G1: demoting the last ACTIVE owner is blocked', async () => {
      const { svc, repo } = make({
        membership: { id: 'm2', userId: 'u2', roleKey: 'owner', status: 'active' },
        activeOwners: 1,
      });
      await expect(
        svc.changeRole('m2', 'gerente', actor, 'pass'),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(
        (repo as never as { setRole: jest.Mock }).setRole,
      ).not.toHaveBeenCalled();
    });

    it('G1: demoting an active owner succeeds when another active owner remains', async () => {
      const { svc, repo, audit } = make({
        membership: { id: 'm2', userId: 'u2', roleKey: 'owner', status: 'active' },
        activeOwners: 2,
      });
      await expect(
        svc.changeRole('m2', 'gerente', actor, 'pass'),
      ).resolves.toEqual({ ok: true });
      expect(
        (repo as never as { setRole: jest.Mock }).setRole,
      ).toHaveBeenCalledWith('m2', 'gerente');
      expect(
        (audit as never as { log: jest.Mock }).log,
      ).toHaveBeenCalledWith('t1', 'u1', 'role_change', 'm2', { to: 'gerente' });
    });

    it('G1 refinement: demoting a DISABLED owner is NOT blocked even with 1 active owner', async () => {
      const { svc, repo } = make({
        membership: { id: 'm2', userId: 'u2', roleKey: 'owner', status: 'disabled' },
        activeOwners: 1,
      });
      await expect(
        svc.changeRole('m2', 'gerente', actor, 'pass'),
      ).resolves.toEqual({ ok: true });
      expect(
        (repo as never as {
          countActiveOwners: jest.Mock;
        }).countActiveOwners,
      ).not.toHaveBeenCalled();
      expect(
        (repo as never as { setRole: jest.Mock }).setRole,
      ).toHaveBeenCalledWith('m2', 'gerente');
    });

    it('rejects when target membership not found', async () => {
      const { svc, repo } = make();
      (repo as never as { getMembership: jest.Mock }).getMembership.mockResolvedValueOnce(
        null,
      );
      await expect(
        svc.changeRole('nope', 'gerente', actor, 'pass'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('deactivate', () => {
    it('G5: cannot deactivate self', async () => {
      const { svc, repo } = make({
        membership: { id: 'm1', userId: 'u1', roleKey: 'owner', status: 'active' },
      });
      await expect(
        svc.deactivate('m1', actor, 'pass'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(
        (repo as never as { setStatus: jest.Mock }).setStatus,
      ).not.toHaveBeenCalled();
    });

    it('G1: cannot deactivate the last active owner', async () => {
      const { svc, repo } = make({
        membership: { id: 'm2', userId: 'u2', roleKey: 'owner', status: 'active' },
        activeOwners: 1,
      });
      await expect(
        svc.deactivate('m2', actor, 'pass'),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(
        (repo as never as { setStatus: jest.Mock }).setStatus,
      ).not.toHaveBeenCalled();
    });

    it('G4/happy: deactivate sets status disabled (never deletes) and audits', async () => {
      const { svc, repo, audit } = make({
        membership: { id: 'm2', userId: 'u2', roleKey: 'mechanic', status: 'active' },
      });
      await expect(svc.deactivate('m2', actor, 'pass')).resolves.toEqual({
        ok: true,
      });
      expect(
        (repo as never as { setStatus: jest.Mock }).setStatus,
      ).toHaveBeenCalledWith('m2', 'disabled');
      expect(
        (audit as never as { log: jest.Mock }).log,
      ).toHaveBeenCalledWith('t1', 'u1', 'member_deactivate', 'm2');
    });

    it('G6: reauth failure rejects and never changes status', async () => {
      const { svc, repo } = make({ reauthOk: false });
      await expect(
        svc.deactivate('m2', actor, 'wrong'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(
        (repo as never as { setStatus: jest.Mock }).setStatus,
      ).not.toHaveBeenCalled();
    });
  });

  describe('activate', () => {
    it('sets status active and audits member_activate', async () => {
      const { svc, repo, audit } = make({
        membership: { id: 'm2', userId: 'u2', roleKey: 'mechanic', status: 'disabled' },
      });
      await expect(svc.activate('m2', actor, 'pass')).resolves.toEqual({
        ok: true,
      });
      expect(
        (repo as never as { setStatus: jest.Mock }).setStatus,
      ).toHaveBeenCalledWith('m2', 'active');
      expect(
        (audit as never as { log: jest.Mock }).log,
      ).toHaveBeenCalledWith('t1', 'u1', 'member_activate', 'm2');
    });

    it('G6: reauth failure rejects and never changes status', async () => {
      const { svc, repo } = make({ reauthOk: false });
      await expect(
        svc.activate('m2', actor, 'wrong'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
      expect(
        (repo as never as { setStatus: jest.Mock }).setStatus,
      ).not.toHaveBeenCalled();
    });
  });

  describe('listEmployees', () => {
    it('delegates to repo.listEmployees', async () => {
      const { svc, repo } = make();
      await svc.listEmployees();
      expect(
        (repo as never as { listEmployees: jest.Mock }).listEmployees,
      ).toHaveBeenCalledTimes(1);
    });
  });
});
