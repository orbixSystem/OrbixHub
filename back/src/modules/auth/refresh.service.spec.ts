import { RefreshService } from './refresh.service';
import type { AuthRepository } from './auth.repository';
import type { Env } from '../../common/config/env.schema';

interface StoredRow {
  id: string;
  tokenHash: string;
  token_hash: string;
  family_id: string;
  user_id: string;
  tenant_id: string;
  expires_at: Date;
  revoked_at: Date | null;
  rotated_to: string | null;
  created_at: Date;
}

function makeRepo() {
  const store = new Map<string, StoredRow>();
  return {
    store,
    createRefreshToken: jest.fn(
      async (d: {
        userId: string;
        tenantId: string;
        familyId: string;
        tokenHash: string;
        expiresAt: Date;
      }) => {
        const row: StoredRow = {
          id: `id-${store.size + 1}`,
          tokenHash: d.tokenHash,
          token_hash: d.tokenHash,
          family_id: d.familyId,
          user_id: d.userId,
          tenant_id: d.tenantId,
          expires_at: d.expiresAt,
          revoked_at: null,
          rotated_to: null,
          created_at: new Date(),
        };
        store.set(d.tokenHash, row);
        return row;
      },
    ),
    findRefreshByHash: jest.fn(async (h: string) => store.get(h) ?? null),
    markRotated: jest.fn(async (id: string, to: string) => {
      for (const r of store.values())
        if (r.id === id) {
          r.rotated_to = to;
          r.revoked_at = new Date();
        }
    }),
    revokeFamily: jest.fn(async (fam: string) => {
      for (const r of store.values())
        if (r.family_id === fam) r.revoked_at = new Date();
    }),
  };
}

const env = { REFRESH_TTL_DAYS: 14 } as unknown as Env;

describe('RefreshService', () => {
  it('issues a new token for a tenant', async () => {
    const repo = makeRepo();
    const svc = new RefreshService(repo as unknown as AuthRepository, env);
    const { refreshToken } = await svc.issue('u1', 't1');
    expect(refreshToken).toBeTruthy();
    expect(repo.createRefreshToken).toHaveBeenCalled();
  });

  it('rotates a valid token (old becomes rotated, new is returned)', async () => {
    const repo = makeRepo();
    const svc = new RefreshService(repo as unknown as AuthRepository, env);
    const { refreshToken } = await svc.issue('u1', 't1');
    const rotated = await svc.rotate(refreshToken);
    expect(rotated.refreshToken).not.toBe(refreshToken);
    expect(rotated.userId).toBe('u1');
    expect(rotated.tenantId).toBe('t1');
  });

  it('reuse of an already-rotated token (outside tolerance) revokes the family', async () => {
    const repo = makeRepo();
    // Clock far in the future so that, after the first rotation marks the row
    // revoked at the real wall-clock time, the second presentation is well
    // beyond the tolerance window and triggers reuse detection.
    const future = Date.now() + 365 * 86_400_000;
    const svc = new RefreshService(
      repo as unknown as AuthRepository,
      env,
      () => future,
    );
    const { refreshToken } = await svc.issue('u1', 't1');
    await svc.rotate(refreshToken); // first rotation ok
    await expect(svc.rotate(refreshToken)).rejects.toThrow(
      /reuse|revogad|unauthor/i,
    );
    expect(repo.revokeFamily).toHaveBeenCalled();
  });

  it('re-presenting the just-rotated token within tolerance returns a valid pair without revoking the family', async () => {
    const repo = makeRepo();
    let now = 1000;
    const svc = new RefreshService(
      repo as unknown as AuthRepository,
      env,
      () => now,
    );
    const { refreshToken } = await svc.issue('u1', 't1');
    const first = await svc.rotate(refreshToken);
    now += 2000; // 2s later, within ~10s window
    const second = await svc.rotate(refreshToken);
    // Raw successor tokens aren't persisted, so byte-equality is not achievable.
    // Assert idempotent success: a valid token returned and family NOT revoked.
    expect(second.refreshToken).toBeTruthy();
    expect(repo.revokeFamily).not.toHaveBeenCalled();
    expect(first.refreshToken).toBeTruthy();
  });
});
