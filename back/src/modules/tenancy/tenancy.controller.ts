import { Controller, Get } from '@nestjs/common';
import { TenancyService } from './tenancy.service';
import { CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';

@Controller()
export class TenancyController {
  constructor(private readonly tenancy: TenancyService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.tenancy.me(user);
  }
}
