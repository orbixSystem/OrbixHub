import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import type { AuthUser } from '../../common/auth/auth.types';
import { isUniqueViolation } from '../../common/database/prisma-errors';

/** Status possível de uma mutação de replay (persistido em `sync_mutation.result`). */
export type SyncStatus = 'applied' | 'discarded' | 'error';

/** Resultado a persistir/devolver de uma mutação. */
export interface SyncMutationOutcome {
  status: SyncStatus;
  entityId?: string;
  message?: string;
}

/** Linha bruta de `sync_mutation` que interessa ao idempotency lookup. */
export interface SyncMutationRow {
  client_mutation_id: string;
  result: string;
  entity_id: string | null;
  error_message: string | null;
}

/**
 * Único ponto que toca a tabela `sync_mutation` (RLS + FORCE). Idempotência por
 * (tenant do CLS, autor, clientMutationId) — S8. Roda sob `withTenantTx`; o
 * tenant vem sempre do CLS/JWT verificado, nunca do corpo.
 */
@Injectable()
export class SyncRepository {
  constructor(private readonly tenant: TenantContext) {}

  /** Busca a mutação já registrada deste autor+cliente (idempotência — S8). */
  findMutation(
    user: AuthUser,
    clientMutationId: string,
  ): Promise<SyncMutationRow | null> {
    return this.tenant.withTenantTx(() => {
      const db = this.tenant.getClient();
      return db.sync_mutation.findFirst({
        where: {
          author_user_id: user.userId,
          client_mutation_id: clientMutationId,
        },
        select: {
          client_mutation_id: true,
          result: true,
          entity_id: true,
          error_message: true,
        },
      });
    });
  }

  /**
   * Registra o desfecho de uma mutação (applied/discarded/error). Corrida de
   * lotes idênticos (dois pushes simultâneos do mesmo outbox): o unique
   * `(tenant, autor, clientMutationId)` derruba o perdedor com P2002 — em vez
   * de estourar o push inteiro (500), devolvemos o desfecho que o VENCEDOR
   * gravou. Retorna `null` quando este registro venceu (usa-se o outcome local).
   */
  async recordMutation(
    user: AuthUser,
    m: { clientMutationId: string; entity: string; op: string },
    outcome: SyncMutationOutcome,
  ): Promise<SyncMutationRow | null> {
    try {
      await this.tenant.withTenantTx(async () => {
        const db = this.tenant.getClient();
        await db.sync_mutation.create({
          data: {
            tenant_id: user.tenantId,
            author_user_id: user.userId,
            client_mutation_id: m.clientMutationId,
            entity: m.entity,
            op: m.op,
            result: outcome.status,
            error_message: outcome.message ?? null,
            entity_id: outcome.entityId ?? null,
          },
        });
      });
      return null;
    } catch (e) {
      if (!isUniqueViolation(e)) throw e;
      return this.findMutation(user, m.clientMutationId);
    }
  }
}
