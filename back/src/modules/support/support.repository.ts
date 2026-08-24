import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';

export interface NovaMensagem {
  ticketId: string;
  body: string;
  fromOrbix: boolean;
  authorUserId?: string | null;
  authorName?: string | null;
}

/**
 * Único lugar que toca `support_ticket` e `support_message`. Tabelas
 * tenant-scoped: todo acesso roda sob `runWithTenant` — o isolamento é da RLS,
 * não de um `where` na query.
 */
@Injectable()
export class SupportRepository {
  constructor(private readonly tenant: TenantContext) {}

  /**
   * Chamados do tenant, o de movimento mais recente primeiro — e não o mais
   * novo: um chamado antigo que acabou de receber resposta é o que interessa.
   * Traz a contagem de não lidas para o ponto na lista.
   *
   * `paraOrbix` diz de QUEM é o ponto vermelho: o cliente conta as respostas da
   * Orbix que ainda não leu; a Orbix conta as mensagens do cliente. É a mesma
   * lista vista dos dois lados do balcão.
   */
  async listarTickets(tenantId: string, paraOrbix = false) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const tickets = await db.support_ticket.findMany({
        orderBy: { last_message_at: 'desc' },
      });
      const naoLidas = await db.support_message.groupBy({
        by: ['ticket_id'],
        where: { from_orbix: !paraOrbix, read_at: null },
        _count: { _all: true },
      });
      const porTicket = new Map(
        naoLidas.map((n) => [n.ticket_id, n._count._all] as const),
      );
      return tickets.map((t) => ({ ...t, naoLidas: porTicket.get(t.id) ?? 0 }));
    });
  }

  async acharTicket(tenantId: string, ticketId: string) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      return db.support_ticket.findFirst({ where: { id: ticketId } });
    });
  }

  async criarTicket(
    tenantId: string,
    subject: string,
    createdBy: string,
  ): Promise<{ id: string }> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      return db.support_ticket.create({
        data: { tenant_id: tenantId, subject, created_by: createdBy },
        select: { id: true },
      });
    });
  }

  /** Mensagens do chamado, mais antiga primeiro (é conversa). */
  async mensagens(tenantId: string, ticketId: string) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      return db.support_message.findMany({
        where: { ticket_id: ticketId },
        orderBy: { created_at: 'asc' },
      });
    });
  }

  /**
   * Grava a mensagem e mexe `last_message_at` na mesma transação — é o que
   * reordena a lista.
   *
   * NÃO mexe em `status`: quem decide abrir e fechar é o SERVICE, e antes daqui
   * uma mensagem do cliente reabria o chamado sozinha. Isso tirava da Orbix o
   * controle sobre o que estava fechado — hoje o caminho é um pedido explícito
   * de reabertura.
   */
  async criarMensagem(tenantId: string, msg: NovaMensagem) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const criada = await db.support_message.create({
        data: {
          tenant_id: tenantId,
          ticket_id: msg.ticketId,
          body: msg.body,
          from_orbix: msg.fromOrbix,
          author_user_id: msg.authorUserId ?? null,
          author_name: msg.authorName ?? null,
        },
      });
      await db.support_ticket.update({
        where: { id: msg.ticketId },
        data: {
          last_message_at: criada.created_at,
          updated_at: new Date(),
        },
      });
      return criada;
    });
  }

  /** Marca como lidas as mensagens do outro lado, dentro de um chamado. */
  async marcarLidas(tenantId: string, ticketId: string, fromOrbix: boolean) {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      await db.support_message.updateMany({
        where: { ticket_id: ticketId, from_orbix: fromOrbix, read_at: null },
        data: { read_at: new Date() },
      });
    });
  }

  async definirStatus(tenantId: string, ticketId: string, status: string) {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      await db.support_ticket.updateMany({
        where: { id: ticketId },
        data: { status, updated_at: new Date() },
      });
    });
  }

  /** Total de respostas da Orbix ainda não lidas, somando os chamados. */
  async naoLidasPeloCliente(tenantId: string): Promise<number> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      return db.support_message.count({
        where: { from_orbix: true, read_at: null },
      });
    });
  }
}
