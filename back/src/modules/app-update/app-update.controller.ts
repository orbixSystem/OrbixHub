import { Controller, Get, Query } from '@nestjs/common';
import { IsIn } from 'class-validator';
import { AppUpdateService, UpdatePlatform } from './app-update.service';

class UpdateQueryDto {
  @IsIn(['android', 'windows'])
  platform!: UpdatePlatform;
}

/**
 * Atualização do aplicativo instalado (Android/Windows). Genérico da
 * plataforma: basta estar autenticado (JwtAuthGuard é global) — não é módulo de
 * produto, então sem @RequiresModule/@Permissions. Quem usa o sistema precisa
 * poder atualizá-lo.
 */
@Controller('app')
export class AppUpdateController {
  constructor(private readonly updates: AppUpdateService) {}

  @Get('update')
  latest(@Query() query: UpdateQueryDto) {
    return this.updates.latest(query.platform);
  }
}
