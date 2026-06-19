import { Module } from '@nestjs/common';
import { IamController } from './iam.controller';
import { EmployeesController } from './employees.controller';
import { InvitesController } from './invites.controller';
import { IamService } from './iam.service';
import { EmployeesService } from './employees.service';
import { ReauthService } from './reauth.service';
import { IamRepository } from './iam.repository';
import { AuthModule } from '../auth/auth.module';

@Module({
  // AuthModule re-exports RefreshService (+ AuthRepository), which IamService
  // injects. AccessTokenService, PasswordService, AuditService and
  // MailerService are provided by @Global() modules.
  imports: [AuthModule],
  controllers: [IamController, EmployeesController, InvitesController],
  providers: [IamService, EmployeesService, ReauthService, IamRepository],
  // IamService é service público (resolveMemberName) consumido por outros
  // módulos — ex.: OS mostra o responsável no link de acompanhamento.
  exports: [IamService],
})
export class IamModule {}
