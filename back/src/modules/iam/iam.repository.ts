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

  async removeMember(membershipId: string): Promise<void> {
    await this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      await db.membership.delete({ where: { id: membershipId } });
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
    ttlMinutes: number;
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
          expires_at: new Date(Date.now() + data.ttlMinutes * 60_000),
        },
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
