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
import { OsService } from './os.service';
import {
  ChangeStatusDto,
  CreateOrderDto,
  ListOrdersQueryDto,
  UpdateOrderDto,
} from './dto/order.dto';
import { CreateItemDto, UpdateItemDto } from './dto/item.dto';

@Controller('os')
@UseGuards(ModuleAccessGuard)
@RequiresModule('os')
export class OsController {
  constructor(private readonly os: OsService) {}

  // --- orders ---
  @Post('orders')
  @Permissions('os.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    return this.os.createOrder(user, dto);
  }

  @Get('orders')
  @Permissions('os.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ListOrdersQueryDto) {
    return this.os.listOrders(user, query);
  }

  @Get('orders/:id')
  @Permissions('os.read')
  getOne(@CurrentUser() _user: AuthUser, @Param('id') id: string) {
    return this.os.getOrderOrThrow(id);
  }

  @Patch('orders/:id')
  @Permissions('os.write')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateOrderDto,
  ) {
    return this.os.updateOrder(user, id, dto);
  }

  // os.approve (aprovar) é exigido no service para a transição → 'aprovada'.
  @Post('orders/:id/status')
  @Permissions('os.write')
  @HttpCode(200)
  changeStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ChangeStatusDto,
  ) {
    return this.os.changeStatus(user, id, dto);
  }

  @Delete('orders/:id')
  @Permissions('os.write')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.os.deleteOrder(user, id);
  }

  // --- itens ---
  @Post('orders/:id/items')
  @Permissions('os.write')
  addItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateItemDto,
  ) {
    return this.os.addItem(user, id, dto);
  }

  @Patch('orders/:id/items/:itemId')
  @Permissions('os.write')
  updateItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('itemId') itemId: string,
    @Body() dto: UpdateItemDto,
  ) {
    return this.os.updateItem(user, id, itemId, dto);
  }

  @Delete('orders/:id/items/:itemId')
  @Permissions('os.write')
  @HttpCode(200)
  deleteItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('itemId') itemId: string,
  ) {
    return this.os.deleteItem(user, id, itemId);
  }
}
