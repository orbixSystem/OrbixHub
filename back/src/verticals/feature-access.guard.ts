import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { AuthUser } from '../common/auth/auth.types';
import { BillingService } from '../modules/billing/billing.service';
import { TenancyService } from '../modules/tenancy/tenancy.service';
import { FeatureService } from './feature.service';
import { REQUIRES_FEATURE } from './requires-feature.decorator';

/**
 * Guard de capacidade. Roda a mesma resolução do /me
 * (`módulo habilitado ∧ disponível ∧ ligada`) e recusa com 403 quando a
 * capacidade não vale para o tenant.
 *
 * Sem isto, um tenant de nicho genérico continuava alcançando a rota de
 * consulta por placa chamando a API direto — o app escondia o botão, o servidor
 * não barrava. Esconder ≠ proteger.
 */
@Injectable()
export class FeatureAccessGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly features: FeatureService,
    private readonly billing: BillingService,
    private readonly tenancy: TenancyService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const key = this.reflector.getAllAndOverride<string | undefined>(
      REQUIRES_FEATURE,
      [ctx.getHandler(), ctx.getClass()],
    );
    if (!key) return true;

    const user = ctx.switchToHttp().getRequest<{ user?: AuthUser }>().user;
    if (!user) return false;

    const vertical = await this.tenancy.getTenantVertical(user.tenantId);
    const modulos = await this.billing.getEnabledModules(user.tenantId);
    const ligadas = await this.features.ligadas(user.tenantId, vertical, modulos);
    if (ligadas.includes(key)) return true;

    throw new ForbiddenException(
      'Esta funcionalidade não está disponível para a sua empresa.',
    );
  }
}
