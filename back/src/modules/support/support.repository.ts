import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';

export interface NovaMensagem {
  body: string;
  fromOrbix: boolean;
  authorUserId?: string | null;
  authorName?: string | null;
}

/**
 * Único lugar que toca `support_message`. Tabela tenant-scoped: todo acesso roda
 * sob `withTenantTx`/`runWithTenant` — o isolamento é da RLS, não de um `where`
 * na query.
 */
@Injectable()
export class SupportRepository {
  constructor(private readonly tenant: TenantContext) {}

  /**
   * Thread inteira, mais antiga primeiro (é conversa, lê-se de cima para baixo).
   * Sem paginação de propósito: uma thread de suporte por tenant não cresce a
   * ponto de justificar — quando crescer, entra `changedSince` como no resto.
   */
  async listar(tenantId: string) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      return db.support_message.findMany({ orderBy: { created_at: 'asc' } });
    });
  }

  async criar(tenantId: string, msg: NovaMensagem) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      return db.support_message.create({
        data: {
          tenant_id: tenantId,
          body: msg.body,
          from_orbix: msg.fromOrbix,
          author_user_id: msg.authorUserId ?? null,
          author_name: msg.authorName ?? null,
        },
      });
    });
  }

  /**
   * Marca como lidas as mensagens do OUTRO lado. Quem lê é quem chama: o
   * cliente marca as da Orbix; o admin (depois) marca as do cliente.
   */
  async marcarLidas(tenantId: string, fromOrbix: boolean) {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      await db.support_message.updateMany({
        where: { from_orbix: fromOrbix, read_at: null },
        data: { read_at: new Date() },
      });
    });
  }

  /** Quantas mensagens da Orbix o cliente ainda não leu (badge discreto). */
  async naoLidasPeloCliente(tenantId: string): Promise<number> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      return db.support_message.count({
        where: { from_orbix: true, read_at: null },
      });
    });
  }
}
