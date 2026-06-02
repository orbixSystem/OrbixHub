import { Module } from '@nestjs/common';
import { TenancyController } from './tenancy.controller';
import { TenancyService } from './tenancy.service';
import { TenancyRepository } from './tenancy.repository';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule], // for AuthRepository (exported)
  controllers: [TenancyController],
  providers: [TenancyService, TenancyRepository],
})
export class TenancyModule {}
