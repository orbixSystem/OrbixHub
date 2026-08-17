import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { CurrentUser, Permissions } from '../../../common/auth/decorators';
import type { AuthUser } from '../../../common/auth/auth.types';
import { ModuleAccessGuard } from '../../../modules/billing/module-access.guard';
import { RequiresModule } from '../../../modules/billing/requires-module.decorator';
import { PlateLookupService } from './plate-lookup.service';

/**
 * Consulta de veículo por placa — rotas da VERTICAL, não do módulo genérico.
 *
 * As URLs continuam `/api/customers/plates/...` de propósito: caminho é
 * contrato com o app publicado, e renomeá-lo agora seria quebrar cliente por
 * estética. O que importava era tirar o código de dentro do `customers`, e isso
 * está feito — o módulo genérico não tem mais nenhuma linha sobre placa.
 *
 * Guards idênticos aos de antes: módulo `customers` habilitado + `subject.read`
 * (quem vê os objetos pode consultar a ficha deles).
 */
@Controller('customers/plates')
@UseGuards(ModuleAccessGuard)
@RequiresModule('customers')
export class PlatesController {
  constructor(private readonly plates: PlateLookupService) {}

  @Get('usage')
  @Permissions('subject.read')
  usage() {
    return this.plates.usage();
  }

  @Get(':plate')
  @Permissions('subject.read')
  lookup(@CurrentUser() user: AuthUser, @Param('plate') plate: string) {
    return this.plates.lookup(user, plate);
  }
}
