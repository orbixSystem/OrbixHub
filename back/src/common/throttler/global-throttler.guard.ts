import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Global rate limiter (registered as APP_GUARD). Enforces ONLY the `default`
 * IP-only throttler. The strict `auth` throttler is deliberately excluded here
 * so route-level @Throttle({ auth: ... }) on register/login/forgot does NOT
 * clamp the global IP budget to 5/min — that strict limit is enforced solely by
 * the IP+email AuthThrottlerGuard.
 */
@Injectable()
export class GlobalThrottlerGuard extends ThrottlerGuard {
  async onModuleInit(): Promise<void> {
    await super.onModuleInit();
    this.throttlers = this.throttlers.filter((t) => t.name !== 'auth');
  }
}
