import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { ExpensesService } from './expenses.service';
import {
  CreateExpenseDto,
  PayExpenseDto,
  UpdateExpenseDto,
} from './dto/expense.dto';
import {
  CreateExpenseCategoryDto,
  UpdateExpenseCategoryDto,
} from './dto/category.dto';
import {
  ExpenseCategoryQueryDto,
  ExpensesMonthQueryDto,
} from './dto/query.dto';

/**
 * Rotas do módulo Despesas (contas a pagar).
 *
 * Gated por `@RequiresModule('expenses')`. Permissões reaproveitam
 * `finance.read`/`finance.write` (semeadas desde a 0004 e sem consumidor até
 * aqui): pagar contas É financeiro, e criar `expense.*` seria um segundo
 * vocabulário para o mesmo conceito.
 */
@Controller('expenses')
@UseGuards(ModuleAccessGuard)
@RequiresModule('expenses')
export class ExpensesController {
  constructor(private readonly expenses: ExpensesService) {}

  // --- categorias (rotas literais ANTES de :id, senão `categories` seria
  //     capturado como um id) ---
  @Get('categories')
  @Permissions('finance.read')
  listCategories(
    @CurrentUser() user: AuthUser,
    @Query() query: ExpenseCategoryQueryDto,
  ) {
    return this.expenses.listCategories(user, query.includeDisabled ?? false);
  }

  @Post('categories')
  @Permissions('finance.write')
  createCategory(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateExpenseCategoryDto,
  ) {
    return this.expenses.createCategory(user, dto);
  }

  @Patch('categories/:id')
  @Permissions('finance.write')
  @HttpCode(200)
  updateCategory(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateExpenseCategoryDto,
  ) {
    return this.expenses.updateCategory(user, id, dto);
  }

  /**
   * Empresa pelo CNPJ, para preencher o fornecedor da conta.
   *
   * Rota literal ANTES de `:id` (senão `cnpj` viraria um id). Não reusa
   * `/customers/cnpj/:cnpj` porque `expenses` não pode exigir que o módulo de
   * clientes esteja no plano — o gateway consultado é o mesmo.
   */
  @Get('cnpj/:cnpj')
  @Permissions('finance.read')
  cnpjLookup(@Param('cnpj') cnpj: string) {
    return this.expenses.lookupCnpj(cnpj);
  }

  // --- contas ---
  @Get()
  @Permissions('finance.read')
  listMonth(
    @CurrentUser() user: AuthUser,
    @Query() query: ExpensesMonthQueryDto,
  ) {
    return this.expenses.listMonth(user, query);
  }

  @Post()
  @Permissions('finance.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateExpenseDto) {
    return this.expenses.create(user, dto);
  }

  /**
   * Uma conta com o contexto do detalhe: a regra que a gerou e as irmãs de
   * parcelamento. É também a porta do caminho **caixa → despesa** (o lançamento
   * guarda o id desta conta em `sale_id`).
   */
  @Get(':id')
  @Permissions('finance.read')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.expenses.findOne(id);
  }

  @Patch(':id')
  @Permissions('finance.write')
  @HttpCode(200)
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateExpenseDto,
  ) {
    return this.expenses.update(user, id, dto);
  }

  /** Dá baixa — e espelha a saída no Caixa. */
  @Post(':id/pay')
  @Permissions('finance.write')
  @HttpCode(200)
  pay(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PayExpenseDto,
  ) {
    return this.expenses.pay(user, id, dto);
  }

  /** Desfaz a baixa — e estorna o lançamento no Caixa. */
  @Post(':id/unpay')
  @Permissions('finance.write')
  @HttpCode(200)
  unpay(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.expenses.unpay(user, id);
  }

  /** Cancela (sem hard delete). */
  @Delete(':id')
  @Permissions('finance.write')
  @HttpCode(204)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.expenses.cancel(user, id);
  }
}
