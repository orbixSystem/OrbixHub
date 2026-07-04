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
import { InvoiceService } from './invoice.service';
import {
  CancelInvoiceDto,
  IssueInvoiceDto,
  ListInvoicesQueryDto,
} from './dto/invoice.dto';

/**
 * Emissão/consulta de Nota Fiscal. Contratável (gated por @RequiresModule('invoice')).
 * Leitura exige `invoice.read`; emissão/cancelamento exigem `invoice.issue`.
 */
@Controller('invoices')
@UseGuards(ModuleAccessGuard)
@RequiresModule('invoice')
export class InvoiceController {
  constructor(private readonly invoice: InvoiceService) {}

  @Get()
  @Permissions('invoice.read')
  list(@Query() query: ListInvoicesQueryDto) {
    return this.invoice.list(query);
  }

  @Get(':id')
  @Permissions('invoice.read')
  getOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.invoice.getOne(id);
  }

  @Post()
  @Permissions('invoice.issue')
  @HttpCode(201)
  issue(@CurrentUser() user: AuthUser, @Body() dto: IssueInvoiceDto) {
    return this.invoice.issue(user, dto);
  }

  @Post(':id/cancel')
  @Permissions('invoice.issue')
  @HttpCode(200)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelInvoiceDto,
  ) {
    return this.invoice.cancel(user, id, dto);
  }
}
