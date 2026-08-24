import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { AuthUser } from '../../../common/auth/auth.types';
import { AuditService } from '../../../common/audit/audit.service';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';
import { PlateCacheStore } from './plate-cache.store';
import { PlateFipeMatcher } from './plate-fipe-matcher.service';
import { PlateQuotaStore } from './plate-quota.store';
import {
  normalizePlate,
  PLATE_PROVIDER,
  PlateHit,
  PlateProvider,
} from './plate.provider';

/** Uso da cota mensal — devolvido junto de toda consulta e em GET /plates/usage. */
export interface PlateQuotaUsage {
  period: string; // 'YYYY-MM'
  used: number;
  limit: number;
  remaining: number;
  enabled: boolean;
}

export type PlateLookupResponse = PlateHit & {
  cached: boolean;
  usage: PlateQuotaUsage;
};

/**
 * Consulta de veículo por placa (API Placas/wdapi2) com cache global e cota
 * mensal. Ordem do fluxo (cada passo protege o seguinte):
 *   1. valida o formato da placa — inválida nem toca cache/cota;
 *   2. cache fresco (≤30d) → serve do banco SEM consumir cota;
 *   3. reserva 1 da cota ATOMICAMENTE (estourou → 429 amigável);
 *   4. chamada externa FORA de qualquer transação de banco;
 *   5. provedor não atendeu → devolve a cota; atendeu → grava cache + auditoria.
 */
@Injectable()
export class PlateLookupService {
  constructor(
    private readonly cache: PlateCacheStore,
    private readonly quota: PlateQuotaStore,
    private readonly audit: AuditService,
    private readonly fipeMatcher: PlateFipeMatcher,
    @Inject(PLATE_PROVIDER) private readonly provider: PlateProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async lookup(user: AuthUser, rawPlate: string): Promise<PlateLookupResponse> {
    const plate = normalizePlate(rawPlate);
    if (!plate) {
      throw new BadRequestException(
        'Placa inválida — use o formato ABC1234 ou ABC1D23.',
      );
    }

    // Cache fresco não gasta cota (mesma placa consultada de novo é grátis).
    const cached = await this.cache.get(plate);
    if (cached) {
      // Hit gravado antes do match FIPE (ou quando a FIPE estava fora): calcula
      // agora e regrava — assim o autofill não fica pior por ter cache.
      if (!cached.fipeMatch) {
        const fipeMatch = await this.fipeMatcher.match(cached);
        if (fipeMatch) {
          const enriched = { ...cached, fipeMatch };
          await this.cache.upsert(plate, enriched, 'apiplacas');
          return { ...enriched, cached: true, usage: await this.usage() };
        }
      }
      return { ...cached, cached: true, usage: await this.usage() };
    }

    if (!this.env.PLACAS_ENABLED || !this.env.PLACAS_TOKEN) {
      throw new ServiceUnavailableException(
        'Consulta de placas não configurada neste ambiente.',
      );
    }

    // Reserva atômica ANTES da chamada externa — concorrência nunca estoura o limite.
    const period = PlateQuotaStore.currentPeriod();
    const limit = this.env.PLACAS_MONTHLY_LIMIT;
    const usedAfter = await this.quota.tryConsume(period, limit);
    if (usedAfter === null) {
      throw new HttpException(
        `Limite mensal de consultas de placa atingido (${limit}/mês). Libera de novo no próximo mês.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // Chamada externa fora de qualquer transação de banco (regra de ouro).
    const outcome = await this.provider.lookup(plate);

    switch (outcome.status) {
      case 'ok': {
        // Equivalente no catálogo FIPE do cadastro (best-effort, fora de tx).
        const fipeMatch = await this.fipeMatcher.match(outcome.hit);
        const hit = fipeMatch ? { ...outcome.hit, fipeMatch } : outcome.hit;
        await this.cache.upsert(plate, hit, 'apiplacas');
        // Mutação de cota (custo real) é auditada: quem gastou, qual placa.
        await this.audit.log(user.tenantId, user.userId, 'plate_lookup', plate, {
          used: usedAfter,
          limit,
        });
        return { ...hit, cached: false, usage: await this.usage() };
      }
      case 'not_found':
        // O provedor respondeu (consulta consumida lá) — mantém o consumo local.
        throw new NotFoundException(
          'Nenhum veículo encontrado para esta placa.',
        );
      case 'invalid':
        await this.quota.refund(period);
        throw new BadRequestException(
          'Placa inválida — use o formato ABC1234 ou ABC1D23.',
        );
      case 'provider_limit':
        await this.quota.refund(period);
        throw new HttpException(
          'Limite de consultas do provedor de placas atingido.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      case 'unavailable':
      default:
        await this.quota.refund(period);
        throw new ServiceUnavailableException(
          'Consulta de placas indisponível no momento. Tente novamente.',
        );
    }
  }

  /** Uso corrente da cota mensal (leitura barata; alimenta o contador do front). */
  async usage(): Promise<PlateQuotaUsage> {
    const period = PlateQuotaStore.currentPeriod();
    const limit = this.env.PLACAS_MONTHLY_LIMIT;
    const used = await this.quota.used(period);
    return {
      period,
      used,
      limit,
      remaining: Math.max(0, limit - used),
      enabled: this.env.PLACAS_ENABLED && Boolean(this.env.PLACAS_TOKEN),
    };
  }
}
