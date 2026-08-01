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
import { CustomersMetricsService } from './customers-metrics.service';
import { CustomersMetricsQueryDto } from './dto/metrics.dto';
import { resolveRange } from '../../common/metrics/range';
import { SubjectLookupService } from './subject-lookup.service';
import { PlateLookupService } from './plates/plate-lookup.service';
import {
  CreateCustomerDto,
  ListCustomersQueryDto,
  UpdateCustomerDto,
} from './dto/customer.dto';
import { UpdateCustomersConfigDto } from './dto/config.dto';
import { CreateSubjectDto } from './dto/subject.dto';

@Controller('customers')
@UseGuards(ModuleAccessGuard)
@RequiresModule('customers')
export class CustomersController {
  constructor(
    private readonly customers: CustomersService,
    private readonly metrics: CustomersMetricsService,
    private readonly lookup: SubjectLookupService,
    private readonly plates: PlateLookupService,
  ) {}

  // --- métricas (Dashboard) — leitura agregada, gated pelo módulo + customer.read ---
  @Get('metrics')
  @Permissions('customer.read')
  metricsSummary(@Query() query: CustomersMetricsQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.metrics.metricsSummary({ from, to });
  }

  // --- config (rotas literais antes de :id) ---
  @Get('config')
  @Permissions('customer.read')
  getConfig(@CurrentUser() user: AuthUser) {
    return this.customers.getConfig(user.tenantId);
  }

  @Patch('config')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateConfig(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateCustomersConfigDto,
  ) {
    return this.customers.updateConfig(user, dto);
  }

  // --- autocomplete de campos de subject (marca/modelo via FIPE) ---
  @Get('lookups/:fonte')
  @Permissions('subject.read')
  lookups(
    @Param('fonte') fonte: string,
    @Query('marca') marca?: string,
    @Query('modelo') modelo?: string,
    @Query('q') q?: string,
  ) {
    return this.lookup.lookup(fonte, { marca, modelo, q });
  }

  // --- consulta de veículo por placa (API externa, cache + cota mensal) ---
  // Rotas literais ANTES das paramétricas (:id). `subject.read` como o lookup
  // FIPE: quem vê veículos pode consultar/gerar a ficha.
  @Get('plates/usage')
  @Permissions('subject.read')
  plateUsage() {
    return this.plates.usage();
  }

  @Get('plates/:plate')
  @Permissions('subject.read')
  plateLookup(@CurrentUser() user: AuthUser, @Param('plate') plate: string) {
    return this.plates.lookup(user, plate);
  }

  // --- customers ---
  @Post()
  @Permissions('customer.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCustomerDto) {
    return this.customers.createCustomer(user, dto);
  }

  @Get()
  @Permissions('customer.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ListCustomersQueryDto) {
    return this.customers.listCustomers(user, query);
  }

  @Get(':id')
  @Permissions('customer.read')
  getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.getCustomer(user, id);
  }

  // Timeline do cliente (histórico geral), com filtro opcional por subject.
  @Get(':id/history')
  @Permissions('customer.read')
  history(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query('subjectId') subjectId?: string,
  ) {
    return this.customers.getCustomerHistory(user, id, subjectId);
  }

  @Patch(':id')
  @Permissions('customer.write')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateCustomerDto,
  ) {
    return this.customers.updateCustomer(user, id, dto);
  }

  @Post(':id/archive')
  @Permissions('customer.write')
  @HttpCode(200)
  archive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.archiveCustomer(user, id);
  }

  @Post(':id/unarchive')
  @Permissions('customer.write')
  @HttpCode(200)
  unarchive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.unarchiveCustomer(user, id);
  }

  // Exclusão = soft delete (status 'deleted'); some das listas, linha preservada.
  @Delete(':id')
  @Permissions('customer.write')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customers.deleteCustomer(user, id);
  }

  // --- subjects aninhados sob o cliente (criação) ---
  @Post(':id/subjects')
  @Permissions('subject.write')
  createSubject(
    @CurrentUser() user: AuthUser,
    @Param('id') customerId: string,
    @Body() dto: CreateSubjectDto,
  ) {
    return this.customers.createSubject(user, customerId, dto);
  }
}
