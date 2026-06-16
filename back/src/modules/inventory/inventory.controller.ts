import {
  Body, Controller, Get, HttpCode, Param, Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { InventoryService } from './inventory.service';
import {
  CreateInventoryItemDto,
  ItemQueryDto,
  SkuSuggestionQueryDto,
  UpdateInventoryItemDto,
} from './dto/item.dto';
import { LookupQueryDto } from './dto/lookup.dto';
import { UpdateInventoryConfigDto } from './dto/config.dto';

@Controller('inventory')
@UseGuards(ModuleAccessGuard)
@RequiresModule('inventory')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  // --- rotas literais antes de items/:id ---
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

  @Get('lookup')
  @Permissions('inventory.read')
  lookup(@CurrentUser() user: AuthUser, @Query() query: LookupQueryDto) {
    return this.inventory.lookup(user, query.code);
  }

  @Get('low-stock')
  @Permissions('inventory.read')
  lowStock(@CurrentUser() user: AuthUser) {
    return this.inventory.lowStock(user);
  }

  @Get('sku-suggestion')
  @Permissions('inventory.write')
  suggestSku(@CurrentUser() user: AuthUser, @Query() q: SkuSuggestionQueryDto) {
    return this.inventory.suggestSku(user, q.name);
  }

  // --- itens ---
  @Post('items')
  @Permissions('inventory.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateInventoryItemDto) {
    return this.inventory.createItem(user, dto);
  }

  @Get('items')
  @Permissions('inventory.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ItemQueryDto) {
    return this.inventory.listItems(user, query);
  }

  @Get('items/:id')
  @Permissions('inventory.read')
  getOne(@CurrentUser() _user: AuthUser, @Param('id') id: string) {
    return this.inventory.getItemOrThrow(id);
  }

  @Patch('items/:id')
  @Permissions('inventory.write')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateInventoryItemDto,
  ) {
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
}
