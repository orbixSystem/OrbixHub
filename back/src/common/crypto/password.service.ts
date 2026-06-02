import { Inject, Injectable } from '@nestjs/common';
import * as argon2 from 'argon2';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';

@Injectable()
export class PasswordService {
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
}
