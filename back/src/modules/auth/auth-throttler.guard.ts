import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Strict rate limiter for sensitive auth routes (register/login/forgot).
 * Enforces ONLY the named `auth` throttler (5/min) keyed by IP+email, so a
 * single account/IP pair is limited without sharing that tiny budget across all
 * users behind one egress IP. The global `default` throttler is handled by the
 * GlobalThrottlerGuard and intentionally excluded here.
 */
@Injectable()
export class AuthThrottlerGuard extends ThrottlerGuard {
  async onModuleInit(): Promise<void> {
    await super.onModuleInit();
    this.throttlers = this.throttlers.filter((t) => t.name === 'auth');
  }

  protected async getTracker(req: Record<string, unknown>): Promise<string> {
    const ip =
      (req.ip as string) ??
      (req.ips as string[] | undefined)?.[0] ??
      'unknown';
    const body = req.body as { email?: string } | undefined;
    const email = (body?.email ?? '').toLowerCase();
    return `${ip}:${email}`; // throttle per IP AND per account
  }
}
