import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { IamRepository } from './iam.repository';
import { ReauthService } from './reauth.service';
import { AuditService } from '../../common/audit/audit.service';
import type { AuthUser } from '../../common/auth/auth.types';

@Injectable()
export class EmployeesService {
  constructor(
    private readonly repo: IamRepository,
    private readonly reauth: ReauthService,
    private readonly audit: AuditService,
  ) {}

  listEmployees() {
    return this.repo.listEmployees();
  }

  /** Membros ativos para o seletor de atribuição (sem campos sensíveis). */
  listAssignableMembers() {
    return this.repo.listAssignableMembers();
  }

  async changeRole(
    membershipId: string,
    newRole: string,
    actor: AuthUser,
    currentPassword: string,
  ) {
    await this.reauth.assertReauth(actor.userId, currentPassword); // G6
    const target = await this.repo.getMembership(membershipId);
    if (!target) throw new BadRequestException('Funcionário não encontrado.');
    if (target.userId === actor.userId) {
      throw new ForbiddenException('Não é possível alterar o próprio cargo.'); // G2
    }
    if (newRole === 'owner' && actor.role !== 'owner') {
      throw new ForbiddenException('Apenas o dono concede o cargo de dono.'); // G3
    }
    if (target.roleKey === 'owner' && target.status === 'active' && newRole !== 'owner') {
      const owners = await this.repo.countActiveOwners(); // G1
      if (owners <= 1) {
        throw new BadRequestException('A oficina precisa de pelo menos um dono ativo.');
      }
    }
    await this.repo.setRole(membershipId, newRole);
    await this.audit.log(actor.tenantId, actor.userId, 'role_change', membershipId, {
      to: newRole,
    });
    return { ok: true };
  }

  async deactivate(membershipId: string, actor: AuthUser, currentPassword: string) {
    await this.reauth.assertReauth(actor.userId, currentPassword); // G6
    const target = await this.repo.getMembership(membershipId);
    if (!target) throw new BadRequestException('Funcionário não encontrado.');
    if (target.userId === actor.userId) {
      throw new ForbiddenException('Não é possível desativar a si mesmo.'); // G5
    }
    if (target.roleKey === 'owner' && target.status === 'active') {
      const owners = await this.repo.countActiveOwners(); // G1
      if (owners <= 1) {
        throw new BadRequestException('A oficina precisa de pelo menos um dono ativo.');
      }
    }
    await this.repo.setStatus(membershipId, 'disabled'); // G4 — never deletes
    await this.audit.log(actor.tenantId, actor.userId, 'member_deactivate', membershipId);
    return { ok: true };
  }

  async activate(membershipId: string, actor: AuthUser, currentPassword: string) {
    await this.reauth.assertReauth(actor.userId, currentPassword); // G6
    const target = await this.repo.getMembership(membershipId);
    if (!target) throw new BadRequestException('Funcionário não encontrado.');
    await this.repo.setStatus(membershipId, 'active');
    await this.audit.log(actor.tenantId, actor.userId, 'member_activate', membershipId);
    return { ok: true };
  }
}
