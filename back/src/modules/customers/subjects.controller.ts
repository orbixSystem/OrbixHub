import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { CustomersService } from './customers.service';
import {
  ListSubjectsQueryDto,
  UpdateSubjectDto,
} from './dto/subject.dto';

@Controller('subjects')
@UseGuards(ModuleAccessGuard)
@RequiresModule('customers')
export class SubjectsController {
  constructor(private readonly customers: CustomersService) {}

  @Get()
  @Permissions('subject.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ListSubjectsQueryDto) {
    return this.customers.listSubjects(user, query);
  }

  @Get(':id')
  @Permissions('subject.read')
  getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.getSubject(user, id);
  }

  @Get(':id/history')
  @Permissions('subject.read')
  history(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.getSubjectHistory(user, id);
  }

  @Patch(':id')
  @Permissions('subject.write')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateSubjectDto,
  ) {
    return this.customers.updateSubject(user, id, dto);
  }

  @Post(':id/archive')
  @Permissions('subject.write')
  @HttpCode(200)
  archive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.archiveSubject(user, id);
  }

  @Post(':id/unarchive')
  @Permissions('subject.write')
  @HttpCode(200)
  unarchive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.unarchiveSubject(user, id);
  }

  // Exclusão = soft delete (status 'deleted'); some das listas, linha preservada.
  @Delete(':id')
  @Permissions('subject.write')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.deleteSubject(user, id);
  }
}
