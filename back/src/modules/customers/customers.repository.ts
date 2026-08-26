import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import {
  ChangeCursor,
  ChangedSincePage,
  queryChangedSince,
} from '../../common/database/changed-since';

/** Entidades do módulo customers expostas ao pull de sync offline. */
export type CustomersSyncEntity = 'customer' | 'subject';

/** Ordenação da lista de clientes; desempate estável por `id`. */
const CUSTOMER_ORDER_BY: Record<
  string,
  Prisma.customerOrderByWithRelationInput[]
> = {
  recent: [{ created_at: 'desc' }, { id: 'desc' }],
  oldest: [{ created_at: 'asc' }, { id: 'asc' }],
  name_asc: [{ name: 'asc' }, { id: 'asc' }],
  name_desc: [{ name: 'desc' }, { id: 'desc' }],
};

export interface CustomerFilter {
  q?: string;
  status: 'active' | 'archived' | 'all';
  sort?: string;
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
      /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro (S9: sem upsert). */
      id?: string;
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
        orderBy:
          CUSTOMER_ORDER_BY[filter.sort ?? 'recent'] ?? CUSTOMER_ORDER_BY.recent,
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
      /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro (S9: sem upsert). */
      id?: string;
      label: string | null;
      identifier: string | null;
      tipo: string | null;
      marca: string | null;
      modelo: string | null;
      numeroSerie: string | null;
      attributes: Record<string, unknown> | undefined;
      /** Consulta por placa (opcional); carimba plate_data_at quando vem. */
      plateData?: Record<string, unknown>;
    },
  ) {
    const db = this.tenant.getClient();
    return db.subject.create({
      data: {
        id: data.id,
        tenant_id: tenantId,
        customer_id: customerId,
        label: data.label,
        identifier: data.identifier,
        tipo: data.tipo,
        marca: data.marca,
        modelo: data.modelo,
        numero_serie: data.numeroSerie,
        attributes: (data.attributes as Prisma.InputJsonValue) ?? undefined,
        ...(data.plateData !== undefined
          ? {
              plate_data: data.plateData as Prisma.InputJsonValue,
              plate_data_at: new Date(),
            }
          : {}),
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
      tipo: string | null;
      marca: string | null;
      modelo: string | null;
      numeroSerie: string | null;
      attributes: Record<string, unknown>;
      plateData: Record<string, unknown>;
    }>,
  ) {
    const db = this.tenant.getClient();
    const { attributes, plateData, numeroSerie, ...rest } = data;
    return db.subject.update({
      where: { id },
      data: {
        ...rest,
        ...(numeroSerie !== undefined ? { numero_serie: numeroSerie } : {}),
        ...(attributes !== undefined
          ? { attributes: attributes as Prisma.InputJsonValue }
          : {}),
        // Reconsultar a placa renova o carimbo de quando o dado foi obtido.
        ...(plateData !== undefined
          ? {
              plate_data: plateData as Prisma.InputJsonValue,
              plate_data_at: new Date(),
            }
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

  /** Define/limpa a foto do subject (url pública + chave do storage). */
  updateSubjectPhoto(
    id: string,
    data: { url: string | null; storageKey: string | null },
  ) {
    const db = this.tenant.getClient();
    return db.subject.update({
      where: { id },
      data: {
        photo_url: data.url,
        photo_storage_key: data.storageKey,
        updated_at: new Date(),
      },
    });
  }

  // ---- métricas (agregações sob RLS — sem WHERE tenant manual) ----
  /** Total de clientes ativos. */
  countActive() {
    const db = this.tenant.getClient();
    return db.customer.count({ where: { status: 'active' } });
  }

  /** Novos clientes (created_at no range), independente de status. */
  countNewInRange(from: Date, to: Date) {
    const db = this.tenant.getClient();
    return db.customer.count({
      where: { created_at: { gte: from, lte: to } },
    });
  }

  /** Linhas de novos clientes no range (export COMPLETO do relatório). */
  listNewInRange(from: Date, to: Date) {
    const db = this.tenant.getClient();
    return db.customer.findMany({
      where: { created_at: { gte: from, lte: to } },
      orderBy: { created_at: 'desc' },
      select: { id: true, name: true, type: true, created_at: true },
    });
  }

  /**
   * Linhas de novos clientes no range PAGINADAS (tela — scroll infinito) + total
   * no mesmo where. Espelha o padrão de `listCustomers`/`listForReportPage` da OS.
   */
  async listNewInRangePage(from: Date, to: Date, skip: number, take: number) {
    const db = this.tenant.getClient();
    const where: Prisma.customerWhereInput = {
      created_at: { gte: from, lte: to },
    };
    const [rows, total] = await Promise.all([
      db.customer.findMany({
        where,
        orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
        skip,
        take,
        select: { id: true, name: true, type: true, created_at: true },
      }),
      db.customer.count({ where }),
    ]);
    return { rows, total };
  }

  /**
   * Série do gráfico: novos clientes agrupados por dia-calendário (servidor) e
   * por tipo, no range. Tenant-scoped por RLS (sem WHERE tenant manual) —
   * parametrizado via Prisma.sql, como os agregados de `os.repository`.
   */
  newInRangeSeries(from: Date, to: Date) {
    const db = this.tenant.getClient();
    return db.$queryRaw<
      Array<{ day: string; type: string; count: number }>
    >(Prisma.sql`
      SELECT to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS day,
             type,
             COUNT(*)::int AS count
      FROM customer
      WHERE created_at >= ${from} AND created_at <= ${to}
      GROUP BY 1, 2
      ORDER BY 1, 2
    `);
  }

  // ---- sync pull (offline) ----
  /**
   * Página de mudanças de `customer`/`subject` desde o cursor (ambas com
   * `updated_at`). Sync pull — ver `common/database/changed-since.ts`.
   */
  listChangedSince(
    table: CustomersSyncEntity,
    cursor: ChangeCursor | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    const db = this.tenant.getClient();
    return queryChangedSince(db, table, 'updated_at', cursor, limit);
  }
}
