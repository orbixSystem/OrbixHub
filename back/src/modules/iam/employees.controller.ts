import { Body, Controller, Get, HttpCode, Param, Patch, Post } from '@nestjs/common';
import { Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { EmployeesService } from './employees.service';
import { IamService } from './iam.service';
import { ChangeRoleDto, ReauthDto } from './dto/iam.dto';

@Controller()
export class EmployeesController {
  constructor(
    private readonly employees: EmployeesService,
    private readonly iam: IamService,
  ) {}

  @Get('roles')
  roles() {
    return this.iam.listRolesWithPermissions();
  }

  @Get('employees')
  @Permissions('users.manage')
  list() {
    return this.employees.listEmployees();
  }

  @Patch('employees/:membershipId/role')
  @Permissions('users.manage')
  @HttpCode(200)
  changeRole(
    @CurrentUser() user: AuthUser,
    @Param('membershipId') id: string,
    @Body() dto: ChangeRoleDto,
  ) {
    return this.employees.changeRole(id, dto.role, user, dto.currentPassword);
  }

  @Post('employees/:membershipId/deactivate')
  @Permissions('users.manage')
  @HttpCode(200)
  deactivate(
    @CurrentUser() user: AuthUser,
    @Param('membershipId') id: string,
    @Body() dto: ReauthDto,
  ) {
    return this.employees.deactivate(id, user, dto.currentPassword);
  }

  @Post('employees/:membershipId/activate')
  @Permissions('users.manage')
  @HttpCode(200)
  activate(
    @CurrentUser() user: AuthUser,
    @Param('membershipId') id: string,
    @Body() dto: ReauthDto,
  ) {
    return this.employees.activate(id, user, dto.currentPassword);
  }
}
