import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';

export interface CustomerFilter {
  q?: string;
  status: 'active' | 'archived' | 'all';
  skip: number;
  take: number;
}

export interface SubjectFilter {
  q?: string;
  customerId?: string;
  status: 'active' | 'archived' | 'all';
  skip: number;
  take: number;
}

/**
 * Único ponto que toca as tabelas do módulo (`customer`, `subject`). Sempre via
 * `tenant.getClient()` (cliente tx-scoped sob RLS) — o caller (service) abre o
 * `withTenantTx`. Nunca recebe `tenant_id` do cliente: vem do CLS/JWT.
 */
@Injectable()
export class CustomersRepository {
  constructor(private readonly tenant: TenantContext) {}

  private statusWhere(status: 'active' | 'archived' | 'all') {
    // 'deleted' (soft delete) é sempre oculto das listas — inclusive em 'all'.
    if (status === 'all') return { status: { in: ['active', 'archived'] } };
    return { status };
  }

  // ---------- customer ----------
  createCustomer(
    tenantId: string,
    data: {
      name: string;
      type: string;
      document: string | null;
      phone: string | null;
      email: string | null;
      address: string | null;
      notes: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    return db.customer.create({ data: { tenant_id: tenantId, ...data } });
  }

  findCustomerById(id: string) {
    const db = this.tenant.getClient();
    return db.customer.findUnique({ where: { id } });
  }

  async listCustomers(filter: CustomerFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.customerWhereInput = {
      ...this.statusWhere(filter.status),
      ...(filter.q
        ? {
            OR: [
              { name: { contains: filter.q, mode: 'insensitive' } },
              { document: { contains: filter.q, mode: 'insensitive' } },
              { phone: { contains: filter.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      db.customer.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: filter.skip,
        take: filter.take,
      }),
      db.customer.count({ where }),
    ]);
    return { items, total };
  }

  updateCustomer(
    id: string,
    data: Partial<{
      name: string;
      type: string;
      document: string | null;
      phone: string | null;
      email: string | null;
      address: string | null;
      notes: string | null;
    }>,
  ) {
    const db = this.tenant.getClient();
    return db.customer.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  setCustomerStatus(id: string, status: 'active' | 'archived' | 'deleted') {
    const db = this.tenant.getClient();
    return db.customer.update({
      where: { id },
      data: { status, updated_at: new Date() },
    });
  }

  // ---------- subject ----------
  createSubject(
    tenantId: string,
    customerId: string,
    data: {
      label: string | null;
      identifier: string | null;
      attributes: Record<string, unknown> | undefined;
    },
  ) {
    const db = this.tenant.getClient();
    return db.subject.create({
      data: {
        tenant_id: tenantId,
        customer_id: customerId,
        label: data.label,
        identifier: data.identifier,
        attributes: (data.attributes as Prisma.InputJsonValue) ?? undefined,
      },
    });
  }

  findSubjectById(id: string) {
    const db = this.tenant.getClient();
    return db.subject.findUnique({ where: { id } });
  }

  async listSubjects(filter: SubjectFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.subjectWhereInput = {
      ...this.statusWhere(filter.status),
      ...(filter.customerId ? { customer_id: filter.customerId } : {}),
      ...(filter.q
        ? { identifier: { contains: filter.q, mode: 'insensitive' } }
        : {}),
    };
    const [items, total] = await Promise.all([
      db.subject.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: filter.skip,
        take: filter.take,
      }),
      db.subject.count({ where }),
    ]);
    return { items, total };
  }

  updateSubject(
    id: string,
    data: Partial<{
      label: string | null;
      identifier: string | null;
      attributes: Record<string, unknown>;
    }>,
  ) {
    const db = this.tenant.getClient();
    const { attributes, ...rest } = data;
    return db.subject.update({
      where: { id },
      data: {
        ...rest,
        ...(attributes !== undefined
          ? { attributes: attributes as Prisma.InputJsonValue }
          : {}),
        updated_at: new Date(),
      },
    });
  }

  setSubjectStatus(id: string, status: 'active' | 'archived' | 'deleted') {
    const db = this.tenant.getClient();
    return db.subject.update({
      where: { id },
      data: { status, updated_at: new Date() },
    });
  }
}
