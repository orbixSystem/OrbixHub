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
import { CashierServiceImpl } from './cashier.service.impl';
import { OpenSessionDto, CloseSessionDto } from './dto/session.dto';
import {
  CorrectEntryDto,
  CreateEntryDto,
  ReverseEntryDto,
  UpdateEntryDto,
} from './dto/entry.dto';
import {
  CurrentSessionQueryDto,
  EntryQueryDto,
  PaymentSummaryQueryDto,
  SessionQueryDto,
  SummaryQueryDto,
} from './dto/query.dto';
import { UpdateCashierConfigDto } from './dto/config.dto';

@Controller('cashier')
@UseGuards(ModuleAccessGuard)
@RequiresModule('cashier')
export class CashierController {
  constructor(private readonly cashier: CashierServiceImpl) {}

  // --- config (rotas literais antes de tudo) ---
  @Get('config')
  @Permissions('cashier.read')
  getConfig(@CurrentUser() user: AuthUser) {
    return this.cashier.getConfig(user.tenantId);
  }

  @Patch('config')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateConfig(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateCashierConfigDto,
  ) {
    return this.cashier.updateConfig(user, dto);
  }

  // --- sessões (caixa do dia) ---
  // Abrir/fechar o caixa é privilégio de gestão (dono/gerente), não do atendente.
  @Post('sessions/open')
  @Permissions('cashier.manage')
  @HttpCode(201)
  openSession(@CurrentUser() user: AuthUser, @Body() dto: OpenSessionDto) {
    return this.cashier.openSession(user, dto);
  }

  @Post('sessions/close')
  @Permissions('cashier.manage')
  @HttpCode(200)
  closeSession(@CurrentUser() user: AuthUser, @Body() dto: CloseSessionDto) {
    return this.cashier.closeSession(user, dto);
  }

  @Get('sessions/current')
  @Permissions('cashier.read')
  currentSession(
    @CurrentUser() user: AuthUser,
    @Query() query: CurrentSessionQueryDto,
  ) {
    return this.cashier.getCurrentSession(user, query.deviceId);
  }

  // `deviceId`/`status` opcionais: a tela sugere a abertura com o valor contado
  // no último fechamento DAQUELE ponto de caixa (o troco que ficou na gaveta).
  @Get('sessions')
  @Permissions('cashier.read')
  listSessions(@CurrentUser() user: AuthUser, @Query() query: SessionQueryDto) {
    return this.cashier.listSessions(user, query.page ?? 1, query.pageSize ?? 20, {
      deviceId: query.deviceId,
      status: query.status,
    });
  }

  // --- lançamentos (extrato) ---
  @Post('entries')
  @Permissions('cashier.write')
  createEntry(@CurrentUser() user: AuthUser, @Body() dto: CreateEntryDto) {
    return this.cashier.createEntry(user, dto);
  }

  // Estorno é sensível (encobre desvio) → só gestão (dono/gerente).
  @Post('entries/:id/reverse')
  @Permissions('cashier.manage')
  @HttpCode(200)
  reverseEntry(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReverseEntryDto,
  ) {
    return this.cashier.reverseEntry(user, id, dto);
  }

  // Editar o que o lançamento DIZ (descrição, categoria de mesma direção) —
  // nunca o quanto vale. É gestão, como o estorno: reescrever o texto de um
  // movimento de dinheiro é tão sensível quanto estorná-lo.
  @Patch('entries/:id')
  @Permissions('cashier.manage')
  updateEntry(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateEntryDto,
  ) {
    return this.cashier.updateEntry(user, id, dto);
  }

  // Corrigir o VALOR/forma: estorna e relança numa operação (o livro caixa não
  // sobrescreve movimento).
  @Post('entries/:id/correct')
  @Permissions('cashier.manage')
  @HttpCode(200)
  correctEntry(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CorrectEntryDto,
  ) {
    return this.cashier.correctEntry(user, id, dto);
  }

  @Get('entries')
  @Permissions('cashier.read')
  listEntries(@CurrentUser() user: AuthUser, @Query() query: EntryQueryDto) {
    return this.cashier.listEntries(user, query);
  }

  // --- resumos ---
  // Resumo por período = base do Histórico do caixa (relatório de gestão).
  @Get('summary')
  @Permissions('cashier.manage')
  summary(@CurrentUser() user: AuthUser, @Query() query: SummaryQueryDto) {
    return this.cashier.getCashSummary(user, query);
  }

  @Get('payment-summary')
  @Permissions('cashier.read')
  paymentSummary(
    @CurrentUser() user: AuthUser,
    @Query() query: PaymentSummaryQueryDto,
  ) {
    return this.cashier.getSalePaymentDetail(user, query.saleId, query.total);
  }
}
