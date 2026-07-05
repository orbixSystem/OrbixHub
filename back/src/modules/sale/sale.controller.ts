import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { SaleService } from './sale.service';
import { CancelSaleDto, CreateSaleDto, ListSalesQueryDto } from './dto/sale.dto';

/**
 * Vendas de balcão. Contratável (gated por @RequiresModule('sale') +
 * ModuleAccessGuard: past_due libera leitura/bloqueia escrita; canceled bloqueia).
 * Escrita = `sale.write`; leitura = `sale.read`. Emitir nota = `invoice.issue`
 * (mesma permissão da OS; o Fiscal é o dono do dado).
 */
@Controller('sales')
@UseGuards(ModuleAccessGuard)
@RequiresModule('sale')
export class SaleController {
  constructor(private readonly sales: SaleService) {}

  @Post()
  @Permissions('sale.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateSaleDto) {
    return this.sales.createSale(user, dto);
  }

  @Get()
  @Permissions('sale.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ListSalesQueryDto) {
    return this.sales.listSales(user, query);
  }

  @Get(':id')
  @Permissions('sale.read')
  getOne(@CurrentUser() _user: AuthUser, @Param('id') id: string) {
    return this.sales.getSaleOrThrow(id);
  }

  @Post(':id/cancel')
  @Permissions('sale.write')
  @HttpCode(200)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CancelSaleDto,
  ) {
    return this.sales.cancelSale(user, id, dto);
  }

  // A venda dispara a emissão via o módulo Fiscal (service público). O caixa não
  // participa. Quando o Fiscal não está habilitado, o service propaga 503 (Noop).
  @Post(':id/invoice')
  @Permissions('invoice.issue')
  @HttpCode(200)
  emitInvoice(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.sales.emitInvoice(user, id);
  }
}
