import {
  Body,
  Controller,
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
import { SaleService } from './sale.service';
import {
  CancelSaleDto,
  CreateSaleDto,
  ListSalesQueryDto,
  UpdateSaleDto,
} from './dto/sale.dto';

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

  // Editar a venda = reatribuir o cliente (o dinheiro não se edita: para isso é
  // cancelar-e-refazer). Resolve o fiado lançado sem identificar quem levou.
  @Patch(':id')
  @Permissions('sale.write')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateSaleDto,
  ) {
    return this.sales.updateSale(user, id, dto);
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

  /** Declara a venda como fiado (recebeu zero). Ver `SaleService.markFiado`. */
  @Post(':id/fiado')
  @Permissions('sale.write')
  @HttpCode(200)
  markFiado(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.sales.markFiado(user, id);
  }

  // A NOTA da venda é emitida pelo módulo `invoice` (POST /invoices { saleId })
  // — dependência one-way invoice→sale; a venda só guarda o snapshot fiscal.
}
