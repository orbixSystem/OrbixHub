import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

@Injectable()
export class AuthThrottlerGuard extends ThrottlerGuard {
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
