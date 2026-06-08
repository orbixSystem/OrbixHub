import { Body, Controller, Delete, Get, HttpCode, Param, Post } from '@nestjs/common';
import { Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { IamService } from './iam.service';
import { ResendInviteDto } from './dto/iam.dto';

@Controller()
export class InvitesController {
  constructor(private readonly iam: IamService) {}

  @Get('invites')
  @Permissions('users.manage')
  pending(@CurrentUser() user: AuthUser) {
    return this.iam.listPendingInvites(user.tenantId);
  }

  @Post('invites/:id/resend')
  @Permissions('users.manage')
  @HttpCode(200)
  resend(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ResendInviteDto,
  ) {
    return this.iam.resendInvite(user.tenantId, user, id, dto);
  }

  @Delete('invites/:id')
  @Permissions('users.manage')
  @HttpCode(200)
  cancel(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.iam.cancelInvite(user.tenantId, user, id);
  }
}
