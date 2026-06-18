import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Rate limiter para escritas públicas SEM auth (ex.: chat do cliente no link de
 * acompanhamento da OS). Enforça SOMENTE o throttler nomeado `public` (10/min),
 * keyed por IP. O `default`/`auth` são tratados por outros guards e excluídos aqui.
 */
@Injectable()
export class PublicThrottlerGuard extends ThrottlerGuard {
  async onModuleInit(): Promise<void> {
    await super.onModuleInit();
    this.throttlers = this.throttlers.filter((t) => t.name === 'public');
  }

  protected async getTracker(req: Record<string, unknown>): Promise<string> {
    return (
      (req.ip as string) ??
      (req.ips as string[] | undefined)?.[0] ??
      'unknown'
    );
  }
}
