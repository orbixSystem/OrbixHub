import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import {
  SubjectHistoryEntry,
  SubjectHistoryProvider,
} from '../customers/subject-history.provider';
import { OsRepository } from './os.repository';

/**
 * Implementação do seam de histórico do módulo `customers`: a OS alimenta a
 * timeline do veículo/cliente. "Aponta, não invade" — o `customers` chama estes
 * métodos via o token `SubjectHistoryProvider`; só a OS toca as próprias tabelas.
 *
 * Os métodos são chamados de dentro do `CustomersService` (já em contexto de
 * tenant via CLS), mas fora de uma transação aberta — por isso abrem a própria
 * `withTenantTx` (que aplica `SET LOCAL app.current_tenant_id`).
 */
@Injectable()
export class OsSubjectHistoryProvider extends SubjectHistoryProvider {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: OsRepository,
  ) {
    super();
  }

  async listBySubject(subjectId: string): Promise<SubjectHistoryEntry[]> {
    const orders = await this.tenant.withTenantTx(() =>
      this.repo.listOrdersBySubject(subjectId),
    );
    return orders.map((o) => this.toEntry(o));
  }

  async listByCustomer(customerId: string): Promise<SubjectHistoryEntry[]> {
    const orders = await this.tenant.withTenantTx(() =>
      this.repo.listOrdersByCustomer(customerId),
    );
    return orders.map((o) => this.toEntry(o));
  }

  private toEntry(o: {
    id: string;
    number: string;
    status: string;
    created_at: Date;
    subject_id: string | null;
    subject_label: string | null;
  }): SubjectHistoryEntry {
    return {
      id: o.id,
      kind: 'os',
      title: `OS ${o.number}`,
      status: o.status,
      occurredAt: o.created_at.toISOString(),
      subjectId: o.subject_id ?? undefined,
      subjectLabel: o.subject_label ?? undefined,
    };
  }
}
