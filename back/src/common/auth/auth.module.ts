import { Global, Module } from '@nestjs/common';
import { AccessTokenService } from './jwt.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PermissionsGuard } from './permissions.guard';

@Global()
@Module({
  providers: [AccessTokenService, JwtAuthGuard, PermissionsGuard],
  exports: [AccessTokenService, JwtAuthGuard, PermissionsGuard],
})
export class CommonAuthModule {}
