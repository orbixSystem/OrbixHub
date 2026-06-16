import {
  Body, Controller, Get, HttpCode, Param, Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { InventoryService } from './inventory.service';
import { CreateItemDto, ListItemsQueryDto, UpdateItemDto } from './dto/item.dto';
import { CreateMovementDto } from './dto/movement.dto';
import { UpdateInventoryConfigDto } from './dto/config.dto';

@Controller('inventory')
@UseGuards(ModuleAccessGuard)
@RequiresModule('inventory')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  @Get('config')
  @Permissions('inventory.read')
  getConfig(@CurrentUser() user: AuthUser) {
    return this.inventory.getConfig(user.tenantId);
  }

  @Patch('config')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateConfig(@CurrentUser() user: AuthUser, @Body() dto: UpdateInventoryConfigDto) {
    return this.inventory.updateConfig(user, dto);
  }

  @Get('low-stock')
  @Permissions('inventory.read')
  lowStock(@CurrentUser() user: AuthUser) {
    return this.inventory.lowStock(user);
  }

  @Post('items')
  @Permissions('inventory.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateItemDto) {
    return this.inventory.createItem(user, dto);
  }

  @Get('items')
  @Permissions('inventory.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ListItemsQueryDto) {
    return this.inventory.listItems(user, query);
  }

  @Get('items/:id')
  @Permissions('inventory.read')
  getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.getItemOrThrow(id);
  }

  @Patch('items/:id')
  @Permissions('inventory.write')
  update(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: UpdateItemDto) {
    return this.inventory.updateItem(user, id, dto);
  }

  @Post('items/:id/archive')
  @Permissions('inventory.write')
  @HttpCode(200)
  archive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.archiveItem(user, id);
  }

  @Post('items/:id/unarchive')
  @Permissions('inventory.write')
  @HttpCode(200)
  unarchive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.unarchiveItem(user, id);
  }

  @Get('items/:id/movements')
  @Permissions('inventory.read')
  movements(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.listMovements(user, id);
  }

  @Post('items/:id/movements')
  @Permissions('inventory.write')
  registerMovement(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: CreateMovementDto) {
    return this.inventory.registerMovement(user, id, dto);
  }
}
