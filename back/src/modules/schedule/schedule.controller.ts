import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { ScheduleService } from './schedule.service';
import { AgendaQueryDto, ScheduleItemDto, UpdateBusinessHoursDto } from './dto/schedule.dto';

@Controller('schedule')
@UseGuards(ModuleAccessGuard)
@RequiresModule('os')
export class ScheduleController {
  constructor(private readonly schedule: ScheduleService) {}

  // ---- Horários de funcionamento ----

  /** GET /schedule/business-hours — lista os 7 dias do tenant. */
  @Get('business-hours')
  @Permissions('os.read')
  getBusinessHours(@CurrentUser() user: AuthUser) {
    return this.schedule.getBusinessHours(user);
  }

  /** PATCH /schedule/business-hours/:day — atualiza um dia (0=Dom … 6=Sáb). */
  @Patch('business-hours/:day')
  @Permissions('settings.manage')
  updateBusinessHours(
    @CurrentUser() user: AuthUser,
    @Param('day', ParseIntPipe) day: number,
    @Body() dto: UpdateBusinessHoursDto,
  ) {
    return this.schedule.updateBusinessHours(user, day, dto);
  }

  // ---- Agenda ----

  /**
   * GET /schedule/agenda?from=&to=&assignedTo= — itens agendados no período.
   * `assignedTo` (opcional) filtra por técnico.
   */
  @Get('agenda')
  @Permissions('os.read')
  getAgenda(@CurrentUser() user: AuthUser, @Query() query: AgendaQueryDto) {
    return this.schedule.getAgenda(user, query);
  }

  // ---- Agendamento de itens de OS ----

  /**
   * POST /schedule/orders/:orderId/items/:itemId — atribui técnico e horário
   * a um item. Verifica conflito de agenda antes de persistir.
   */
  @Post('orders/:orderId/items/:itemId')
  @Permissions('os.write')
  scheduleItem(
    @CurrentUser() user: AuthUser,
    @Param('orderId') orderId: string,
    @Param('itemId') itemId: string,
    @Body() dto: ScheduleItemDto,
  ) {
    return this.schedule.scheduleItem(user, orderId, itemId, dto);
  }

  /**
   * DELETE /schedule/orders/:orderId/items/:itemId — remove atribuição e
   * agendamento do item.
   */
  @Delete('orders/:orderId/items/:itemId')
  @Permissions('os.write')
  @HttpCode(200)
  unscheduleItem(
    @CurrentUser() user: AuthUser,
    @Param('orderId') orderId: string,
    @Param('itemId') itemId: string,
  ) {
    return this.schedule.unscheduleItem(user, orderId, itemId);
  }
}
