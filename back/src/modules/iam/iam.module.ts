import { Module } from '@nestjs/common';
import { IamController } from './iam.controller';
import { IamService } from './iam.service';
import { IamRepository } from './iam.repository';
import { AuthModule } from '../auth/auth.module';

@Module({
  // AuthModule re-exports RefreshService (+ AuthRepository), which IamService
  // injects. AccessTokenService, PasswordService, AuditService and
  // MailerService are provided by @Global() modules.
  imports: [AuthModule],
  controllers: [IamController],
  providers: [IamService, IamRepository],
})
export class IamModule {}
