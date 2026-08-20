import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import { PrismaService } from '../../common/database/prisma.service';

export interface MembershipRow {
  tenant_id: string;
  tenant_slug: string;
  role_key: string;
}

@Injectable()
export class AuthRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  // ---- users (no RLS) ----
  findUserByEmail(emailNormalized: string) {
    return this.prisma.users.findUnique({
      where: { email_normalized: emailNormalized },
    });
  }
  findUserById(id: string) {
    return this.prisma.users.findUnique({ where: { id } });
  }

  // ---- tenant (no RLS — global table) ----
  /** Looks a tenant up by its (normalized) CNPJ. Used to enforce uniqueness. */
  findTenantByCnpj(cnpj: string) {
    return this.prisma.tenant.findUnique({ where: { cnpj } });
  }

  /** Uses the SECURITY DEFINER function so the picker works pre-context. */
  async findUserMemberships(userId: string): Promise<MembershipRow[]> {
    return this.prisma.$queryRaw<MembershipRow[]>`
      SELECT tenant_id, tenant_slug, role_key
      FROM auth_find_user_memberships(${userId}::uuid)
    `;
  }

  async recordLoginAttempt(
    emailNormalized: string,
    success: boolean,
    userId?: string,
    ip?: string,
  ) {
    await this.prisma.login_attempt.create({
      data: {
        email_normalized: emailNormalized,
        success,
        user_id: userId ?? null,
        ip: ip ?? null,
      },
    });
  }

  async incrementFailedLogin(
    userId: string,
    lockMinutes: number,
    threshold: number,
  ) {
    const user = await this.prisma.users.update({
      where: { id: userId },
      data: { failed_login_count: { increment: 1 } },
    });
    if (user.failed_login_count >= threshold) {
      await this.prisma.users.update({
        where: { id: userId },
        data: { locked_until: new Date(Date.now() + lockMinutes * 60_000) },
      });
    }
    return user;
  }

  async resetFailedLogin(userId: string) {
    await this.prisma.users.update({
      where: { id: userId },
      data: { failed_login_count: 0, locked_until: null },
    });
  }

  async setLastTenant(userId: string, tenantId: string) {
    await this.prisma.users.update({
      where: { id: userId },
      data: { last_tenant_id: tenantId },
    });
  }

  async markEmailVerified(userId: string) {
    await this.prisma.users.update({
      where: { id: userId },
      data: { email_verified_at: new Date() },
    });
  }

  async updatePassword(userId: string, passwordHash: string) {
    await this.prisma.users.update({
      where: { id: userId },
      data: { password_hash: passwordHash },
    });
  }

  // ---- one_time_token (no RLS) ----
  async createOneTimeToken(
    userId: string,
    purpose: string,
    tokenHash: string,
    ttlMinutes: number,
  ) {
    await this.prisma.one_time_token.create({
      data: {
        user_id: userId,
        purpose,
        token_hash: tokenHash,
        expires_at: new Date(Date.now() + ttlMinutes * 60_000),
      },
    });
  }
  findOneTimeToken(tokenHash: string, purpose: string) {
    return this.prisma.one_time_token.findFirst({
      where: {
        token_hash: tokenHash,
        purpose,
        consumed_at: null,
        expires_at: { gt: new Date() },
      },
    });
  }
  async consumeOneTimeToken(id: string) {
    await this.prisma.one_time_token.update({
      where: { id },
      data: { consumed_at: new Date() },
    });
  }

  // ---- refresh_token (no RLS) ----
  createRefreshToken(data: {
    userId: string;
    tenantId: string;
    familyId: string;
    tokenHash: string;
    expiresAt: Date;
  }) {
    return this.prisma.refresh_token.create({
      data: {
        user_id: data.userId,
        tenant_id: data.tenantId,
        family_id: data.familyId,
        token_hash: data.tokenHash,
        expires_at: data.expiresAt,
      },
    });
  }
  findRefreshByHash(tokenHash: string) {
    return this.prisma.refresh_token.findUnique({
      where: { token_hash: tokenHash },
    });
  }
  async markRotated(id: string, rotatedToId: string) {
    await this.prisma.refresh_token.update({
      where: { id },
      data: { rotated_to: rotatedToId, revoked_at: new Date() },
    });
  }
  async revokeFamily(familyId: string) {
    await this.prisma.refresh_token.updateMany({
      where: { family_id: familyId, revoked_at: null },
      data: { revoked_at: new Date() },
    });
  }
  async revokeAllForUser(userId: string) {
    await this.prisma.refresh_token.updateMany({
      where: { user_id: userId, revoked_at: null },
      data: { revoked_at: new Date() },
    });
  }

  /**
   * Atomic register: tenant + users (no RLS), then membership under the new
   * tenant's RLS context, then createTrial (injected callback) inside the SAME
   * transaction via bindTx. A failure anywhere rolls the whole register back.
   * `createTrial` is injected as a callback to respect the module boundary.
   */
  async createTenantWithOwner(params: {
    tenantName: string;
    slug: string;
    cnpj: string;
    legalName: string;
    tradeName: string | null;
    fullName: string;
    emailNormalized: string;
    passwordHash: string;
    /** Nicho escolhido no cadastro; null = pacote padrão. */
    vertical: string | null;
    createTrial: (tenantId: string) => Promise<void>;
  }): Promise<{ userId: string; tenantId: string }> {
    return this.prisma.$transaction(
      async (tx) => {
        const tenant = await tx.tenant.create({
          data: {
            name: params.tenantName,
            slug: params.slug,
            cnpj: params.cnpj,
            legal_name: params.legalName,
            trade_name: params.tradeName,
            vertical: params.vertical,
          },
        });
        const user = await tx.users.create({
          data: {
            email_normalized: params.emailNormalized,
            full_name: params.fullName,
            password_hash: params.passwordHash,
            last_tenant_id: tenant.id,
          },
        });
        const ownerRole = await tx.role.findFirstOrThrow({
          where: { key: 'owner' },
        });
        // Switch RLS context to the new tenant for the tenant-scoped writes.
        await tx.$executeRaw`SELECT set_config('app.current_tenant_id', ${tenant.id}, true)`;
        await tx.membership.create({
          data: {
            tenant_id: tenant.id,
            user_id: user.id,
            role_id: ownerRole.id,
          },
        });
        // Run createTrial INSIDE this same tx, under the new tenant's context,
        // by exposing `tx` through the CLS bridge so BillingService.getClient()
        // sees it. Keeps the trial atomic with tenant/user/membership inserts
        // and satisfies the RLS WITH CHECK on subscription/tenant_module.
        await this.tenant.bindTx(tx, tenant.id, async () => {
          await params.createTrial(tenant.id);
        });
        return { userId: user.id, tenantId: tenant.id };
      },
      { timeout: 10000 },
    );
  }
}
