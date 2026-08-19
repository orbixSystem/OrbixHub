import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { ReceivablesService } from './receivables.service';

/**
 * Controle de fiado (contas a receber) — leitura apenas.
 *
 * Faz parte do Caixa do ponto de vista comercial: é gated por
 * `@RequiresModule('cashier')` e exige `cashier.read`, as mesmas regras do
 * extrato. RECEBER um fiado não tem rota aqui — é um lançamento no caixa
 * (`POST /cashier/entries` com `saleKind`+`saleId`), que já aceita valor parcial
 * e é a única porta por onde dinheiro entra.
 */
@Controller('receivables')
@UseGuards(ModuleAccessGuard)
@RequiresModule('cashier')
export class ReceivablesController {
  constructor(private readonly receivables: ReceivablesService) {}

  /** Devedores e quanto cada um deve. */
  @Get()
  @Permissions('cashier.read')
  listCustomers(@CurrentUser() user: AuthUser) {
    return this.receivables.listCustomers(user);
  }

  /**
   * TODOS os títulos em aberto, achatados — alimenta o histórico do caixa, que
   * precisa mostrar a OS fiada junto da venda fiada. Rota literal antes do
   * `:customerId` (senão "titulos" cairia no ParseUUID).
   */
  @Get('titulos')
  @Permissions('cashier.read')
  listOpenTitles(@CurrentUser() user: AuthUser) {
    return this.receivables.listOpenTitles(user);
  }

  /**
   * Títulos em aberto das vendas de balcão SEM cliente identificado. Rota
   * literal antes do `:customerId` (senão "sem-cliente" cairia no ParseUUID).
   */
  @Get('sem-cliente')
  @Permissions('cashier.read')
  listAnonymous(@CurrentUser() user: AuthUser) {
    return this.receivables.listTitles(user, null);
  }

  /** Títulos em aberto de um cliente, separados e com os itens de cada. */
  @Get(':customerId')
  @Permissions('cashier.read')
  listTitles(
    @CurrentUser() user: AuthUser,
    @Param('customerId', ParseUUIDPipe) customerId: string,
  ) {
    return this.receivables.listTitles(user, customerId);
  }
}
