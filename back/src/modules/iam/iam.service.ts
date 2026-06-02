import { BadRequestException, Injectable, Optional } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { IamRepository } from './iam.repository';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';
import { PasswordService } from '../../common/crypto/password.service';
import { RefreshService } from '../auth/refresh.service';
import { AccessTokenService } from '../../common/auth/jwt.service';
import { AuditService } from '../../common/audit/audit.service';
import { MailerService } from '../../common/mailer/mailer.service';
import { generateOpaqueToken, hashToken } from '../../common/crypto/tokens';
import { normalizeEmail } from '../auth/email';
import { CreateInviteDto, AcceptInviteDto } from './dto/iam.dto';
import type { RoleKey } from '../../common/auth/auth.types';

interface InviteRow {
  invite_id: string;
  tenant_id: string;
  email_normalized: string;
  role_id: string;
  expires_at: Date;
  accepted_at: Date | null;
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
    @Optional() private readonly mailer?: MailerService,
  ) {}

  listMembers() {
    return this.repo.listMembers();
  }
  removeMember(id: string) {
    return this.repo.removeMember(id);
  }
  listRoles() {
    return this.repo.listRoles();
  }
  listPermissions() {
    return this.repo.listPermissions();
  }

  async createInvite(
    tenantId: string,
    invitedBy: string,
    dto: CreateInviteDto,
  ): Promise<{ invited: true }> {
    const roles = await this.repo.listRoles();
    const role = roles.find((r) => r.key === dto.role);
    if (!role) throw new BadRequestException('Papel inválido.');
    const raw = generateOpaqueToken();
    const email = normalizeEmail(dto.email);
    await this.repo.createInvite({
      tenantId,
      emailNormalized: email,
      roleId: role.id,
      tokenHash: hashToken(raw),
      invitedBy,
      ttlMinutes: 60 * 24 * 7,
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

  async acceptInvite(
    dto: AcceptInviteDto,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const rows = await this.prisma.$queryRaw<InviteRow[]>`
      SELECT * FROM auth_find_invite_by_hash(${hashToken(dto.token)})
    `;
    const invite = rows[0];
    if (
      !invite ||
      invite.accepted_at ||
      new Date(invite.expires_at).getTime() < Date.now()
    ) {
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
