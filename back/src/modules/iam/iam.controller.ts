import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { IamService } from './iam.service';
import { Public, Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { CreateInviteDto, AcceptInviteDto } from './dto/iam.dto';

@Controller()
export class IamController {
  constructor(private readonly iam: IamService) {}

  @Get('iam/members')
  @Permissions('users.manage')
  members() {
    return this.iam.listMembers();
  }

  @Get('iam/roles')
  roles() {
    return this.iam.listRoles();
  }

  @Get('iam/permissions')
  permissions() {
    return this.iam.listPermissions();
  }

  @Post('tenants/invites')
  @Permissions('users.manage')
  @HttpCode(201)
  invite(@CurrentUser() user: AuthUser, @Body() dto: CreateInviteDto) {
    return this.iam.createInvite(user.tenantId, user.userId, dto);
  }

  @Public()
  @Post('invites/accept')
  @HttpCode(200)
  accept(@Body() dto: AcceptInviteDto) {
    return this.iam.acceptInvite(dto);
  }
}
