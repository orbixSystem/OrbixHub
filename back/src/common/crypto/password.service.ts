import { Inject, Injectable } from '@nestjs/common';
import * as argon2 from 'argon2';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';

@Injectable()
export class PasswordService {
  /**
   * Cached, real argon2id hash (configured params) used solely to equalize
   * timing on the unknown-email login path. Computed lazily once, then reused
   * so every unknown-email request pays a genuine argon2 VERIFY — matching the
   * cost of a real verify and resisting user-enumeration via timing.
   */
  private dummyHash: Promise<string> | null = null;

  constructor(@Inject(ENV) private readonly env: Env) {}

  hash(plain: string): Promise<string> {
    return argon2.hash(plain, {
      type: argon2.argon2id,
      memoryCost: this.env.ARGON_MEMORY_KIB,
      timeCost: this.env.ARGON_TIME_COST,
      parallelism: this.env.ARGON_PARALLELISM,
    });
  }

  async verify(hash: string, plain: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, plain);
    } catch {
      return false;
    }
  }

  /**
   * Timing-equalization for the unknown-email login branch: runs a REAL
   * argon2id verify of `plain` against a cached dummy hash (same params as a
   * real verify) and always returns false. The dummy hash is computed once and
   * memoized, so the per-request cost is an argon2 verify, never a no-op.
   */
  async dummyVerify(plain: string): Promise<boolean> {
    if (!this.dummyHash) {
      this.dummyHash = this.hash('orbix-dummy-password-for-timing');
    }
    const hash = await this.dummyHash;
    return this.verify(hash, plain);
  }
}
