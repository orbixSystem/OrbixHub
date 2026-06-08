import { BadRequestException, Injectable, Optional } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { IamRepository } from './iam.repository';
import { ReauthService } from './reauth.service';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';
import { PasswordService } from '../../common/crypto/password.service';
import { RefreshService } from '../auth/refresh.service';
import { AccessTokenService } from '../../common/auth/jwt.service';
import { AuditService } from '../../common/audit/audit.service';
import { MailerService } from '../../common/mailer/mailer.service';
import { generateOpaqueToken, hashToken } from '../../common/crypto/tokens';
import { normalizeEmail } from '../auth/email';
import {
  CreateInviteDto,
  AcceptInviteDto,
  ResendInviteDto,
} from './dto/iam.dto';
import type { RoleKey, AuthUser } from '../../common/auth/auth.types';

const INVITE_EXPIRY_MIN: Record<string, number | null> = {
  '15min': 15,
  '30min': 30,
  '1day': 1440,
  '15days': 21600,
  never: null,
};

/** Compute expiresAt Date|null from an expiresIn key (default '15days'). */
function inviteExpiresAt(expiresIn?: string): Date | null {
  const key = expiresIn ?? '15days';
  const min = key in INVITE_EXPIRY_MIN ? INVITE_EXPIRY_MIN[key] : 21600;
  return min === null ? null : new Date(Date.now() + min * 60_000);
}

interface InviteRow {
  invite_id: string;
  tenant_id: string;
  email_normalized: string;
  role_id: string;
  expires_at: Date | null;
  accepted_at: Date | null;
  canceled_at: Date | null;
}

@Injectable()
export class IamService {
  constructor(
    private readonly repo: IamRepository,
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
    private readonly passwords: PasswordService,
    private readonly refresh: RefreshService,
    private readonly accessTokens: AccessTokenService,
    private readonly audit: AuditService,
    private readonly reauth: ReauthService,
    @Optional() private readonly mailer?: MailerService,
  ) {}

  listMembers() {
    return this.repo.listMembers();
  }
  listRoles() {
    return this.repo.listRoles();
  }
  listPermissions() {
    return this.repo.listPermissions();
  }

  async listRolesWithPermissions() {
    const [roles, rps, perms] = await Promise.all([
      this.repo.listRoles(),
      this.prisma.role_permission.findMany(),
      this.repo.listPermissions(),
    ]);
    const pMap = new Map(perms.map((p) => [p.id, p.key]));
    return roles.map((r) => ({
      key: r.key,
      name: r.name,
      permissions: rps
        .filter((rp) => rp.role_id === r.id)
        .map((rp) => pMap.get(rp.permission_id)),
    }));
  }

  async createInvite(
    tenantId: string,
    invitedBy: string,
    dto: CreateInviteDto,
  ): Promise<{ invited: true }> {
    await this.reauth.assertReauth(invitedBy, dto.currentPassword);
    const roles = await this.repo.listRoles();
    const role = roles.find((r) => r.key === dto.role);
    if (!role) throw new BadRequestException('Papel inválido.');
    const raw = generateOpaqueToken();
    const email = normalizeEmail(dto.email);
    const expiresAt = inviteExpiresAt(dto.expiresIn);
    await this.repo.createInvite({
      tenantId,
      emailNormalized: email,
      roleId: role.id,
      tokenHash: hashToken(raw),
      invitedBy,
      expiresAt,
    });
    // Email is best-effort (and runs outside any DB tx). Swallow failures so a
    // mailer outage never breaks invite creation.
    try {
      await this.mailer?.send({ to: email, token: raw, kind: 'invite' });
    } catch {
      /* ignore */
    }
    // audit.log opens its own tenant tx — call it AFTER the invite tx commits.
    await this.audit.log(tenantId, invitedBy, 'invite', email);
    return { invited: true };
  }

  listPendingInvites(tenantId: string) {
    // Runs under the request's tenant via the repo's withTenantTx (CLS); the
    // explicit tenantId is kept for signature symmetry with the other methods.
    void tenantId;
    return this.repo.listPendingInvites();
  }

  async resendInvite(
    tenantId: string,
    actor: AuthUser,
    inviteId: string,
    dto: ResendInviteDto,
  ): Promise<{ invited: true }> {
    await this.reauth.assertReauth(actor.userId, dto.currentPassword);
    const invite = await this.repo.getInvite(inviteId);
    if (!invite || invite.accepted_at || invite.canceled_at) {
      throw new BadRequestException('Convite não encontrado.');
    }
    const raw = generateOpaqueToken();
    const expiresAt = inviteExpiresAt(dto.expiresIn);
    await this.repo.rotateInviteToken(inviteId, hashToken(raw), expiresAt);
    try {
      await this.mailer?.send({
        to: invite.email_normalized,
        token: raw,
        kind: 'invite',
      });
    } catch {
      /* ignore */
    }
    await this.audit.log(
      tenantId,
      actor.userId,
      'invite',
      invite.email_normalized,
    );
    return { invited: true };
  }

  async cancelInvite(
    tenantId: string,
    actor: AuthUser,
    inviteId: string,
  ): Promise<{ ok: true }> {
    const invite = await this.repo.getInvite(inviteId);
    if (!invite || invite.accepted_at || invite.canceled_at) {
      throw new BadRequestException('Convite não encontrado.');
    }
    await this.repo.cancelInvite(inviteId);
    await this.audit.log(
      tenantId,
      actor.userId,
      'invite',
      invite.email_normalized,
    );
    return { ok: true };
  }

  async acceptInvite(
    dto: AcceptInviteDto,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const rows = await this.prisma.$queryRaw<InviteRow[]>`
      SELECT * FROM auth_find_invite_by_hash(${hashToken(dto.token)})
    `;
    const invite = rows[0];
    const expired =
      invite?.expires_at != null &&
      new Date(invite.expires_at).getTime() < Date.now();
    if (!invite || invite.accepted_at || invite.canceled_at || expired) {
      throw new BadRequestException('Convite inválido ou expirado.');
    }

    // Find or create the user (global table, no RLS).
    let user = await this.prisma.users.findUnique({
      where: { email_normalized: invite.email_normalized },
    });
    if (!user) {
      if (!dto.password || !dto.fullName) {
        throw new BadRequestException('Informe nome e senha para criar a conta.');
      }
      user = await this.prisma.users.create({
        data: {
          email_normalized: invite.email_normalized,
          full_name: dto.fullName,
          password_hash: await this.passwords.hash(dto.password),
          last_tenant_id: invite.tenant_id,
        },
      });
    }
    const theUser = user;

    // Create membership + mark invite accepted under the invite's tenant context.
    await this.tenant.runWithTenant(invite.tenant_id, async () => {
      const db = this.tenant.getClient();
      await db.membership.create({
        data: {
          tenant_id: invite.tenant_id,
          user_id: theUser.id,
          role_id: invite.role_id,
        },
      });
      await db.invite.update({
        where: { id: invite.invite_id },
        data: { accepted_at: new Date() },
      });
    });

    const roles = await this.repo.listRoles();
    const roleKey = (roles.find((r) => r.id === invite.role_id)?.key ??
      'mechanic') as RoleKey;
    const accessToken = this.accessTokens.sign({
      sub: theUser.id,
      tid: invite.tenant_id,
      role: roleKey,
      jti: randomUUID(),
    });
    const { refreshToken } = await this.refresh.issue(
      theUser.id,
      invite.tenant_id,
    );
    return { accessToken, refreshToken };
  }
}
