import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Rate limiter para rotas públicas SEM auth (página de acompanhamento da OS:
 * track + mensagens + chat do cliente). Enforça SOMENTE o throttler nomeado
 * `public`; o `default`/`auth` são tratados por outros guards e excluídos aqui.
 *
 * Chave = o TOKEN do link (`/public/track/:token/...`), NÃO o IP. Assim cada
 * link tem seu próprio budget e clientes atrás do mesmo IP de NAT/operadora não
 * colidem entre si (o que derrubava o chat com 429). Sem token resolvível, cai
 * de volta pro IP (defensivo).
 */
@Injectable()
export class PublicThrottlerGuard extends ThrottlerGuard {
  async onModuleInit(): Promise<void> {
    await super.onModuleInit();
    this.throttlers = this.throttlers.filter((t) => t.name === 'public');
  }

  protected async getTracker(req: Record<string, unknown>): Promise<string> {
    const params = req.params as { token?: string } | undefined;
    const token = params?.token?.trim();
    if (token) return `track:${token}`;
    return (
      (req.ip as string) ??
      (req.ips as string[] | undefined)?.[0] ??
      'unknown'
    );
  }
}
