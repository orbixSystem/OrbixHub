import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';

export interface NotificationData {
  type: string;
  title: string;
  body?: string | null;
  ref_type?: string | null;
  ref_id?: string | null;
}

/**
 * Único ponto que toca a tabela `notification` (tenant-scoped, RLS+FORCE). Sempre
 * via `tenant.getClient()` (cliente tx-scoped); o service abre o
 * `withTenantTx`/`runWithTenant`. tenant_id nunca vem do cliente — vem do CLS/JWT.
 */
@Injectable()
export class NotificationsRepository {
  constructor(private readonly tenant: TenantContext) {}

  create(tenantId: string, data: NotificationData) {
    const db = this.tenant.getClient();
    return db.notification.create({
      data: {
        tenant_id: tenantId,
        type: data.type,
        title: data.title,
        body: data.body ?? null,
        ref_type: data.ref_type ?? null,
        ref_id: data.ref_id ?? null,
      },
    });
  }

  list(_tenantId: string, opts: { limit: number }) {
    const db = this.tenant.getClient();
    return db.notification.findMany({
      orderBy: { created_at: 'desc' },
      take: opts.limit,
    });
  }

  unreadCount(_tenantId: string): Promise<number> {
    const db = this.tenant.getClient();
    return db.notification.count({ where: { read_at: null } });
  }

  markRead(id: string) {
    const db = this.tenant.getClient();
    // updateMany (não update) p/ não vazar 404 entre tenants: a RLS já filtra,
    // e ids de outro tenant simplesmente não casam (count 0).
    return db.notification.updateMany({
      where: { id, read_at: null },
      data: { read_at: new Date() },
    });
  }

  markAllRead(_tenantId: string) {
    const db = this.tenant.getClient();
    return db.notification.updateMany({
      where: { read_at: null },
      data: { read_at: new Date() },
    });
  }
}
