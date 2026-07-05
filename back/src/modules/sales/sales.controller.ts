import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { SalesService } from './sales.service';
import {
  CancelSaleDto,
  CreateSaleDto,
  ListSalesQueryDto,
} from './dto/sale.dto';

/**
 * Vendas avulsas de produto (caixa). Contratável (@RequiresModule('sales')).
 * Leitura exige `cashier.read`; registrar/cancelar exigem `cashier.write`.
 */
@Controller('sales')
@UseGuards(ModuleAccessGuard)
@RequiresModule('sales')
export class SalesController {
  constructor(private readonly sales: SalesService) {}

  @Get()
  @Permissions('cashier.read')
  list(@Query() query: ListSalesQueryDto) {
    return this.sales.list(query);
  }

  @Get(':id')
  @Permissions('cashier.read')
  getOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.sales.getOne(id);
  }

  @Post()
  @Permissions('cashier.write')
  @HttpCode(201)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateSaleDto) {
    return this.sales.checkout(user, dto);
  }

  @Post(':id/cancel')
  @Permissions('cashier.write')
  @HttpCode(200)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelSaleDto,
  ) {
    return this.sales.cancel(user, id, dto);
  }
}
