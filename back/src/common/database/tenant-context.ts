import { Injectable } from '@nestjs/common';
import { ClsService } from 'nestjs-cls';
import { Prisma } from '@prisma/client';
import { PrismaService } from './prisma.service';

const TID_KEY = 'tenantId';
const TX_KEY = 'tx';

export type TxClient = Prisma.TransactionClient;

@Injectable()
export class TenantContext {
  constructor(
    private readonly cls: ClsService,
    private readonly prisma: PrismaService,
  ) {}

  /** Store the verified tenant id for the current request (called by the interceptor). */
  setTenantId(tid: string) {
    this.cls.set(TID_KEY, tid);
  }

  getTenantId(): string | undefined {
    return this.cls.get(TID_KEY);
  }

  /**
   * Returns the tx-scoped client when inside withTenantTx/runWithTenant,
   * otherwise the base client (which, on RLS tables, sees zero rows because
   * no app.current_tenant_id is set). Repositories MUST use this.
   */
  getClient(): PrismaService | TxClient {
    return this.cls.get(TX_KEY) ?? this.prisma;
  }

  /**
   * Short interactive tx using the CURRENT request's tenant (from CLS).
   * Sets SET LOCAL app.current_tenant_id, exposes tx via getClient(), commits.
   * Throws if no tenant is in context.
   */
  async withTenantTx<T>(fn: () => Promise<T>): Promise<T> {
    const tid = this.getTenantId();
    if (!tid) throw new Error('withTenantTx called without a tenant in context');
    return this.runWithTenant(tid, fn);
  }

  /**
   * Short interactive tx for an explicitly-resolved tenant (public flows:
   * webhooks, tracking pages). The tenantId must be server-resolved, never
   * taken from the client.
   */
  async runWithTenant<T>(tenantId: string, fn: () => Promise<T>): Promise<T> {
    return this.prisma.$transaction(
      async (tx) => {
        // Parameterized: $executeRaw with a tagged template binds $1 safely.
        await tx.$executeRaw`SELECT set_config('app.current_tenant_id', ${tenantId}, true)`;
        return this.cls.run({ ...this.cls.get() }, async () => {
          // copy existing store, then inject tx for getClient()
          this.cls.set(TID_KEY, tenantId);
          this.cls.set(TX_KEY, tx);
          return fn();
        });
      },
      // maxWait: time to ACQUIRE a connection from the pool — directly fixes
      // "Unable to start a transaction in the given time" under burst load.
      // timeout: max wall-clock time for the whole transaction body.
      { maxWait: 15000, timeout: 20000 },
    );
  }

  /**
   * Bind an already-open transaction + tenant into CLS for the duration of fn.
   * Used when an outer transaction is managed elsewhere (e.g. service-level
   * orchestration) and inner repository calls must observe the same tx/tenant.
   */
  async bindTx<T>(tx: TxClient, tenantId: string, fn: () => Promise<T>): Promise<T> {
    return this.cls.run({ ...this.cls.get() }, async () => {
      this.cls.set(TID_KEY, tenantId);
      this.cls.set(TX_KEY, tx);
      return fn();
    });
  }

  /** Run DB work explicitly WITHOUT any tenant context (auth tables only). */
  async withoutTenant<T>(fn: (db: PrismaService) => Promise<T>): Promise<T> {
    return fn(this.prisma);
  }
}
