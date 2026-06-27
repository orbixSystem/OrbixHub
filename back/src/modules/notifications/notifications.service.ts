import { Injectable } from '@nestjs/common';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { NotificationsRepository } from './notifications.repository';

const DEFAULT_LIMIT = 50;

export interface NotifyInput {
  type: string;
  title: string;
  body?: string;
  refType?: string;
  refId?: string;
}

/**
 * Sistema de notificações genérico e tenant-wide (qualquer staff do tenant vê).
 * Criado por qualquer módulo via `notify(...)` ("aponta, não invade": outros
 * módulos chamam este service público, nunca tocam a tabela `notification`).
 */
@Injectable()
export class NotificationsService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: NotificationsRepository,
  ) {}

  /**
   * Cria uma notificação para o tenant. tenant explícito + `runWithTenant` para
   * funcionar também em fluxos sem CLS (públicos/jobs) — ex.: o `messages` chama
   * isto ao chegar mensagem do cliente pelo link público.
   */
  async notify(tenantId: string, input: NotifyInput) {
    return this.tenant.runWithTenant(tenantId, () =>
      this.repo.create(tenantId, {
        type: input.type,
        title: input.title,
        body: input.body ?? null,
        ref_type: input.refType ?? null,
        ref_id: input.refId ?? null,
      }),
    );
  }

  async list(user: AuthUser) {
    return this.tenant.withTenantTx(async () => {
      const [items, unread] = await Promise.all([
        this.repo.list(user.tenantId, { limit: DEFAULT_LIMIT }),
        this.repo.unreadCount(user.tenantId),
      ]);
      return { items, unread };
    });
  }

  async unreadCount(user: AuthUser) {
    const unread = await this.tenant.withTenantTx(() =>
      this.repo.unreadCount(user.tenantId),
    );
    return { unread };
  }

  async markRead(user: AuthUser, id: string) {
    await this.tenant.withTenantTx(() => this.repo.markRead(id));
    return { id, read: true };
  }

  async markAllRead(user: AuthUser) {
    const result = await this.tenant.withTenantTx(() =>
      this.repo.markAllRead(user.tenantId),
    );
    return { read: result.count };
  }
}
