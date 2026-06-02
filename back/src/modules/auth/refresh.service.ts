import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { AuthRepository } from './auth.repository';
import { generateOpaqueToken, hashToken } from '../../common/crypto/tokens';

const TOLERANCE_MS = 10_000;

interface RotateResult {
  refreshToken: string;
  userId: string;
  tenantId: string;
  familyId: string;
}

@Injectable()
export class RefreshService {
  constructor(
    private readonly repo: AuthRepository,
    @Inject(ENV) private readonly env: Env,
    private readonly now: () => number = () => Date.now(),
  ) {}

  async issue(
    userId: string,
    tenantId: string,
    familyId: string = randomUUID(),
  ): Promise<RotateResult> {
    const raw = generateOpaqueToken();
    const expiresAt = new Date(
      this.now() + this.env.REFRESH_TTL_DAYS * 86_400_000,
    );
    await this.repo.createRefreshToken({
      userId,
      tenantId,
      familyId,
      tokenHash: hashToken(raw),
      expiresAt,
    });
    return { refreshToken: raw, userId, tenantId, familyId };
  }

  async rotate(presented: string): Promise<RotateResult> {
    const hash = hashToken(presented);
    const row = await this.repo.findRefreshByHash(hash);
    if (!row) throw new UnauthorizedException('Invalid refresh token');
    if (new Date(row.expires_at).getTime() < this.now()) {
      throw new UnauthorizedException('Expired refresh token');
    }

    // Already rotated/revoked?
    if (row.revoked_at || row.rotated_to) {
      // Tolerance: same token re-presented shortly after its rotation → mint a
      // fresh token in the SAME family instead of nuking the family (mobile
      // retry / dual tab). Idempotent from the client's perspective.
      const rotatedAt = row.revoked_at
        ? new Date(row.revoked_at).getTime()
        : 0;
      if (row.rotated_to && this.now() - rotatedAt <= TOLERANCE_MS) {
        return this.issue(row.user_id, row.tenant_id, row.family_id);
      }
      // Outside tolerance → reuse attack → revoke the whole family.
      await this.repo.revokeFamily(row.family_id);
      throw new UnauthorizedException('Refresh token reuse detected');
    }

    // Normal rotation: mint successor in same family, mark old as rotated.
    const next = await this.issue(row.user_id, row.tenant_id, row.family_id);
    const nextRow = await this.repo.findRefreshByHash(
      hashToken(next.refreshToken),
    );
    if (nextRow) await this.repo.markRotated(row.id, nextRow.id);
    return next;
  }

  async revokeFamilyOf(presented: string): Promise<void> {
    const row = await this.repo.findRefreshByHash(hashToken(presented));
    if (row) await this.repo.revokeFamily(row.family_id);
  }
}
