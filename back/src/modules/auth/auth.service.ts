import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AuthRepository } from './auth.repository';
import { RefreshService } from './refresh.service';
import { PasswordService } from '../../common/crypto/password.service';
import { AccessTokenService } from '../../common/auth/jwt.service';
import { MailerService } from '../../common/mailer/mailer.service';
import { BillingService } from '../billing/billing.service';
import { AuditService } from '../../common/audit/audit.service';
import { generateOpaqueToken, hashToken } from '../../common/crypto/tokens';
import { normalizeEmail } from './email';
import { validateSlug } from './slug';
import type { RoleKey } from '../../common/auth/auth.types';
import {
  RegisterDto,
  LoginDto,
  VerifyEmailDto,
  ForgotPasswordDto,
  ResetPasswordDto,
} from './dto/auth.dto';

const LOCK_THRESHOLD = 5; // failures before lock
const LOCK_MINUTES = 20; // lock duration
const OTT_TTL_MIN = 30; // email/reset token TTL
const GENERIC_CREDENTIALS = 'Credenciais inválidas.';

@Injectable()
export class AuthService {
  constructor(
    private readonly repo: AuthRepository,
    private readonly refresh: RefreshService,
    private readonly passwords: PasswordService,
    private readonly accessTokens: AccessTokenService,
    private readonly mailer: MailerService,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
  ) {}

  private issueAccess(userId: string, tenantId: string, role: RoleKey) {
    return this.accessTokens.sign({
      sub: userId,
      tid: tenantId,
      role,
      jti: randomUUID(),
    });
  }

  async register(dto: RegisterDto) {
    const slugError = validateSlug(dto.slug);
    if (slugError) throw new BadRequestException(slugError);

    const email = normalizeEmail(dto.email);
    const existing = await this.repo.findUserByEmail(email);
    if (existing) {
      throw new ConflictException('Slug ou e-mail já em uso.');
    }

    const passwordHash = await this.passwords.hash(dto.password);

    let ids: { userId: string; tenantId: string };
    try {
      ids = await this.repo.createTenantWithOwner({
        tenantName: dto.tenantName,
        slug: dto.slug,
        fullName: dto.fullName,
        emailNormalized: email,
        passwordHash,
        createTrial: (tenantId) => this.billing.createTrial(tenantId),
      });
    } catch (e) {
      // unique violation on slug or email
      if ((e as { code?: string }).code === 'P2002') {
        throw new ConflictException('Slug ou e-mail já em uso.');
      }
      throw e;
    }

    // AFTER commit: external I/O (email). A mailer failure must NOT roll back.
    const rawToken = generateOpaqueToken();
    await this.repo.createOneTimeToken(
      ids.userId,
      'email_verify',
      hashToken(rawToken),
      OTT_TTL_MIN,
    );
    try {
      await this.mailer.send({
        to: email,
        token: rawToken,
        kind: 'email_verify',
      });
    } catch {
      /* swallow: verification email can be re-sent; cadastro stays committed */
    }

    const accessToken = this.issueAccess(ids.userId, ids.tenantId, 'owner');
    const { refreshToken } = await this.refresh.issue(
      ids.userId,
      ids.tenantId,
    );
    const user = await this.repo.findUserById(ids.userId);
    return {
      accessToken,
      refreshToken,
      user: { id: user!.id, email, fullName: user!.full_name },
      tenant: { id: ids.tenantId, slug: dto.slug, name: dto.tenantName },
    };
  }

  async login(dto: LoginDto, ip?: string) {
    const email = normalizeEmail(dto.email);
    const user = await this.repo.findUserByEmail(email);

    // Always do work shaped the same way to resist enumeration & timing.
    if (!user) {
      // Real argon2 verify against a cached dummy hash (same params) so the
      // unknown-email path costs the same as a real verify (anti-timing).
      await this.passwords.dummyVerify(dto.password);
      await this.repo.recordLoginAttempt(email, false, undefined, ip);
      throw new UnauthorizedException(GENERIC_CREDENTIALS);
    }

    if (user.locked_until && new Date(user.locked_until).getTime() > Date.now()) {
      await this.repo.recordLoginAttempt(email, false, user.id, ip);
      throw new UnauthorizedException(GENERIC_CREDENTIALS); // generic when locked
    }

    const ok = await this.passwords.verify(user.password_hash, dto.password);
    if (!ok) {
      await this.repo.incrementFailedLogin(
        user.id,
        LOCK_MINUTES,
        LOCK_THRESHOLD,
      );
      await this.repo.recordLoginAttempt(email, false, user.id, ip);
      throw new UnauthorizedException(GENERIC_CREDENTIALS);
    }

    await this.repo.resetFailedLogin(user.id);
    await this.repo.recordLoginAttempt(email, true, user.id, ip);

    const memberships = await this.repo.findUserMemberships(user.id);
    if (memberships.length === 0) {
      throw new UnauthorizedException(GENERIC_CREDENTIALS);
    }

    // Active tenant = last used if still a member, else the single/first.
    const active =
      memberships.find((m) => m.tenant_id === user.last_tenant_id) ??
      memberships[0];
    await this.repo.setLastTenant(user.id, active.tenant_id);

    const accessToken = this.issueAccess(
      user.id,
      active.tenant_id,
      active.role_key as RoleKey,
    );
    const { refreshToken } = await this.refresh.issue(
      user.id,
      active.tenant_id,
    );

    // audit.log opens its own tx — call AFTER all other DB work, outside any tx.
    await this.audit.log(active.tenant_id, user.id, 'login');

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, email, fullName: user.full_name },
      memberships: memberships.map((m) => ({
        tenantId: m.tenant_id,
        tenantSlug: m.tenant_slug,
        role: m.role_key,
      })),
    };
  }

  async verifyEmail(dto: VerifyEmailDto) {
    const row = await this.repo.findOneTimeToken(
      hashToken(dto.token),
      'email_verify',
    );
    if (!row || !row.user_id) {
      throw new BadRequestException('Token inválido ou expirado.');
    }
    await this.repo.markEmailVerified(row.user_id);
    await this.repo.consumeOneTimeToken(row.id);
    return { verified: true };
  }

  async forgotPassword(dto: ForgotPasswordDto) {
    const email = normalizeEmail(dto.email);
    const user = await this.repo.findUserByEmail(email);
    if (user) {
      const raw = generateOpaqueToken();
      await this.repo.createOneTimeToken(
        user.id,
        'password_reset',
        hashToken(raw),
        OTT_TTL_MIN,
      );
      try {
        await this.mailer.send({
          to: email,
          token: raw,
          kind: 'password_reset',
        });
      } catch {
        /* ignore */
      }
    }
    return { ok: true }; // ALWAYS 200, identical response (anti-enumeration)
  }

  async resetPassword(dto: ResetPasswordDto) {
    const row = await this.repo.findOneTimeToken(
      hashToken(dto.token),
      'password_reset',
    );
    if (!row || !row.user_id) {
      throw new BadRequestException('Token inválido ou expirado.');
    }
    const hash = await this.passwords.hash(dto.newPassword);
    await this.repo.updatePassword(row.user_id, hash);
    await this.repo.consumeOneTimeToken(row.id);
    await this.repo.revokeAllForUser(row.user_id); // kill all sessions
    // password change is global — log under last tenant if any
    const user = await this.repo.findUserById(row.user_id);
    if (user?.last_tenant_id) {
      await this.audit.log(user.last_tenant_id, user.id, 'password_change');
    }
    return { ok: true };
  }

  async switchTenant(userId: string, tenantId: string) {
    const memberships = await this.repo.findUserMemberships(userId);
    const target = memberships.find((m) => m.tenant_id === tenantId);
    if (!target) throw new UnauthorizedException('Sem acesso a essa oficina.');
    await this.repo.setLastTenant(userId, tenantId);
    const accessToken = this.issueAccess(
      userId,
      tenantId,
      target.role_key as RoleKey,
    );
    const { refreshToken } = await this.refresh.issue(userId, tenantId);
    return { accessToken, refreshToken };
  }

  async refreshTokens(presented: string) {
    const r = await this.refresh.rotate(presented);
    const memberships = await this.repo.findUserMemberships(r.userId);
    const m =
      memberships.find((x) => x.tenant_id === r.tenantId) ?? memberships[0];
    const accessToken = this.issueAccess(
      r.userId,
      r.tenantId,
      (m?.role_key ?? 'mechanic') as RoleKey,
    );
    return { accessToken, refreshToken: r.refreshToken };
  }

  async logout(presented: string) {
    await this.refresh.revokeFamilyOf(presented);
  }
}
