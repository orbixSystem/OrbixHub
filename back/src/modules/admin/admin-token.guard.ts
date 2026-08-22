import { CanActivate, ExecutionContext, Injectable, Inject, UnauthorizedException } from '@nestjs/common';
import { timingSafeEqual } from 'node:crypto';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';

/**
 * Autentica o SISTEMA DE ADMIN, não uma pessoa.
 *
 * Token de serviço em vez de OIDC de propósito: o admin usa Authentik para
 * gente, mas se a chamada máquina-a-máquina dependesse dele, o provisionamento
 * e a cobrança parariam junto com o Authentik.
 *
 * Sem `ADMIN_API_TOKEN` configurado, TODA rota administrativa fica fechada —
 * ausência de segredo não pode virar porta aberta.
 */
@Injectable()
export class AdminTokenGuard implements CanActivate {
  constructor(@Inject(ENV) private readonly env: Env) {}

  canActivate(ctx: ExecutionContext): boolean {
    const esperado = this.env.ADMIN_API_TOKEN;
    if (!esperado) {
      throw new UnauthorizedException('API administrativa desabilitada.');
    }

    const header = ctx.switchToHttp().getRequest<{ headers?: Record<string, string> }>()
      .headers?.authorization;
    const recebido = header?.startsWith('Bearer ') ? header.slice(7) : '';
    if (!recebido) throw new UnauthorizedException();

    // Comparação em tempo constante: comparar com `===` vaza, pelo tempo, quantos
    // caracteres iniciais o atacante acertou.
    const a = Buffer.from(recebido);
    const b = Buffer.from(esperado);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new UnauthorizedException();
    }
    return true;
  }
}
