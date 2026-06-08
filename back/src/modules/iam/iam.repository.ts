import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import { PrismaService } from '../../common/database/prisma.service';

export interface MemberView {
  membershipId: string;
  userId: string;
  email: string | undefined;
  fullName: string | undefined;
  role: string | undefined;
}

export interface EmployeeView {
  membershipId: string;
  userId: string;
  fullName: string | undefined;
  email: string | undefined;
  role: string | undefined;
  status: string;
  lastAccess: Date | null;
  accessExpiresAt: Date | null;
}

export interface PendingInviteView {
  id: string;
  email: string;
  role: string | undefined;
  expiresAt: Date | null;
  createdAt: Date;
}

@Injectable()
export class IamRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  /** Members of the active tenant (membership is RLS — context required). */
  async listMembers(): Promise<MemberView[]> {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const memberships = await db.membership.findMany();
      // join users + role manually (users/role are global, no RLS)
      const userIds = memberships.map((m) => m.user_id);
      const roleIds = memberships.map((m) => m.role_id);
      const users = await this.prisma.users.findMany({
        where: { id: { in: userIds } },
      });
      const roles = await this.prisma.role.findMany({
        where: { id: { in: roleIds } },
      });
      const uMap = new Map(users.map((u) => [u.id, u]));
      const rMap = new Map(roles.map((r) => [r.id, r]));
      return memberships.map((m) => ({
        membershipId: m.id,
        userId: m.user_id,
        email: uMap.get(m.user_id)?.email_normalized,
        fullName: uMap.get(m.user_id)?.full_name,
        role: rMap.get(m.role_id)?.key,
      }));
    });
  }

  async listEmployees(): Promise<EmployeeView[]> {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const memberships = await db.membership.findMany();
      const userIds = memberships.map((m) => m.user_id);
      const roleIds = memberships.map((m) => m.role_id);
      const [users, roles, lastLogins] = await Promise.all([
        this.prisma.users.findMany({ where: { id: { in: userIds } } }),
        this.prisma.role.findMany({ where: { id: { in: roleIds } } }),
        this.prisma.login_attempt.groupBy({
          by: ['user_id'],
          where: { success: true, user_id: { in: userIds } },
          _max: { created_at: true },
        }),
      ]);
      const uMap = new Map(users.map((u) => [u.id, u]));
      const rMap = new Map(roles.map((r) => [r.id, r]));
      const lMap = new Map(
        lastLogins.map((l) => [l.user_id, l._max.created_at ?? null]),
      );
      return memberships.map((m) => ({
        membershipId: m.id,
        userId: m.user_id,
        fullName: uMap.get(m.user_id)?.full_name,
        email: uMap.get(m.user_id)?.email_normalized,
        role: rMap.get(m.role_id)?.key,
        status: m.status,
        lastAccess: lMap.get(m.user_id) ?? null,
        accessExpiresAt: m.access_expires_at ?? null,
      }));
    });
  }

  /** {id, userId, roleKey, status} of ONE membership in the active tenant, or null. */
  async getMembership(membershipId: string) {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const m = await db.membership.findUnique({ where: { id: membershipId } });
      if (!m) return null;
      const role = await this.prisma.role.findUnique({
        where: { id: m.role_id },
      });
      return { id: m.id, userId: m.user_id, roleKey: role?.key, status: m.status };
    });
  }

  /** How many ACTIVE owners exist in the active tenant. */
  async countActiveOwners(): Promise<number> {
    const owner = await this.prisma.role.findUnique({
      where: { key: 'owner' },
    });
    if (!owner) return 0;
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      return db.membership.count({
        where: { role_id: owner.id, status: 'active' },
      });
    });
  }

  async setRole(membershipId: string, roleKey: string): Promise<void> {
    const role = await this.prisma.role.findUnique({
      where: { key: roleKey },
    });
    if (!role) throw new Error(`unknown role ${roleKey}`);
    await this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      await db.membership.update({
        where: { id: membershipId },
        data: { role_id: role.id },
      });
    });
  }

  async setStatus(
    membershipId: string,
    status: 'active' | 'disabled',
  ): Promise<void> {
    await this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      await db.membership.update({
        where: { id: membershipId },
        data: { status },
      });
    });
  }

  listRoles() {
    return this.prisma.role.findMany();
  }

  listPermissions() {
    return this.prisma.permission.findMany();
  }

  // ---- invites (RLS) ----
  async createInvite(data: {
    tenantId: string;
    emailNormalized: string;
    roleId: string;
    tokenHash: string;
    invitedBy: string;
    expiresAt: Date | null;
    accessExpiresAt: Date | null;
  }) {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      return db.invite.create({
        data: {
          tenant_id: data.tenantId,
          email_normalized: data.emailNormalized,
          role_id: data.roleId,
          token_hash: data.tokenHash,
          invited_by: data.invitedBy,
          expires_at: data.expiresAt,
          access_expires_at: data.accessExpiresAt,
        },
      });
    });
  }

  /** Pending (not accepted, not canceled, not expired) invites of active tenant. */
  async listPendingInvites(): Promise<PendingInviteView[]> {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const invites = await db.invite.findMany({
        where: {
          accepted_at: null,
          canceled_at: null,
          OR: [{ expires_at: null }, { expires_at: { gt: new Date() } }],
        },
      });
      const roleIds = invites.map((i) => i.role_id);
      const roles = await this.prisma.role.findMany({
        where: { id: { in: roleIds } },
      });
      const rMap = new Map(roles.map((r) => [r.id, r.key]));
      return invites.map((i) => ({
        id: i.id,
        email: i.email_normalized,
        role: rMap.get(i.role_id),
        expiresAt: i.expires_at,
        createdAt: i.created_at,
      }));
    });
  }

  async getInvite(id: string) {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      return db.invite.findUnique({ where: { id } });
    });
  }

  async rotateInviteToken(
    id: string,
    tokenHash: string,
    expiresAt: Date | null,
  ): Promise<void> {
    await this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      await db.invite.update({
        where: { id },
        data: { token_hash: tokenHash, expires_at: expiresAt },
      });
    });
  }

  async cancelInvite(id: string): Promise<void> {
    await this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      await db.invite.update({
        where: { id },
        data: { canceled_at: new Date() },
      });
    });
  }

  /**
   * Invite acceptance happens WITHOUT a JWT, so the tenant is unknown at request
   * time. `invite` is RLS and app_user cannot read it without a tenant context.
   * Resolution is therefore done via the SECURITY DEFINER function
   * `auth_find_invite_by_hash` (see sql/auth-multitenant-schema.sql, Task 6.2),
   * called from IamService.acceptInvite. The membership write then runs under
   * `runWithTenant(invite.tenant_id, ...)`.
   */
}
