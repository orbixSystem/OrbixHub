import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
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
import { RegisterEmpresaDto, UpdateInvoiceConfigDto } from './dto/invoice-config.dto';

/**
 * Emissão/consulta de Nota Fiscal. Contratável (gated por @RequiresModule('invoice')).
 * Leitura exige `invoice.read`; emissão/cancelamento exigem `invoice.issue`.
 */
@Controller('invoices')
@UseGuards(ModuleAccessGuard)
@RequiresModule('invoice')
export class InvoiceController {
  constructor(private readonly invoice: InvoiceService) {}

  @Get('config')
  @Permissions('invoice.config')
  getConfig(@CurrentUser() user: AuthUser) {
    return this.invoice.getConfig(user.tenantId);
  }

  @Patch('config')
  @Permissions('invoice.config')
  @HttpCode(200)
  updateConfig(@CurrentUser() user: AuthUser, @Body() dto: UpdateInvoiceConfigDto) {
    return this.invoice.updateConfig(user, dto);
  }

  @Post('config/register-empresa')
  @Permissions('invoice.config')
  @HttpCode(200)
  registerEmpresa(@CurrentUser() user: AuthUser, @Body() _dto: RegisterEmpresaDto) {
    return this.invoice.registerEmpresa(user);
  }

  @Post('config/certificate')
  @Permissions('invoice.config')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } }))
  uploadCertificate(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: { buffer: Buffer; originalname: string } | undefined,
    @Body('password') password: string,
  ) {
    return this.invoice.uploadCertificate(user, file, password);
  }

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
