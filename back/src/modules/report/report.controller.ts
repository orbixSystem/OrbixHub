import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { resolveRange } from '../../common/metrics/range';
import { ReportService } from './report.service';
import {
  ReportOsQueryDto,
  ReportRangeQueryDto,
  ReportTopItemsQueryDto,
} from './dto/report-query.dto';

/**
 * Módulo `report` — relatórios gated (contratável; habilitado em trial+pro hoje).
 * Todas as rotas: JWT (global) + @RequiresModule('report') + @Permissions('report.read').
 * O controller é fino: resolve o range e delega ao service (que compõe via os
 * services públicos de cada módulo). Leitura → sem audit.
 */
@Controller('report')
@UseGuards(ModuleAccessGuard)
@RequiresModule('report')
@Permissions('report.read')
export class ReportController {
  constructor(private readonly report: ReportService) {}

  /** OS operacional: linhas + agregados por status/técnico. */
  @Get('os')
  os(@CurrentUser() user: AuthUser, @Query() query: ReportOsQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.osReport(user.tenantId, {
      from,
      to,
      assignedTo: query.assignedTo,
      status: query.status,
    });
  }

  /** Faturamento: total, ticket médio, série por dia, quebra por status. */
  @Get('revenue')
  revenue(@CurrentUser() user: AuthUser, @Query() query: ReportRangeQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.revenue(user.tenantId, { from, to });
  }

  /** Rendimento da equipe: agregado por responsável. */
  @Get('team')
  team(@CurrentUser() user: AuthUser, @Query() query: ReportRangeQueryDto) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.team(user.tenantId, { from, to });
  }

  /** Top produtos/serviços por receita nas OS do range. */
  @Get('top-items')
  topItems(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportTopItemsQueryDto,
  ) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.topItems(user.tenantId, {
      from,
      to,
      kind: query.kind,
      limit: query.limit,
    });
  }

  /** Estoque (posição atual): linhas + valor total em estoque. */
  @Get('inventory')
  inventory(@CurrentUser() user: AuthUser) {
    return this.report.inventory_(user.tenantId);
  }

  /** Clientes: novos no range + total ativo. */
  @Get('customers')
  customers(
    @CurrentUser() user: AuthUser,
    @Query() query: ReportRangeQueryDto,
  ) {
    const { from, to } = resolveRange(query.from, query.to);
    return this.report.customersReport(user.tenantId, { from, to });
  }
}
