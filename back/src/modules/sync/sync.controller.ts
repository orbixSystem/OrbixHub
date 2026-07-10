import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { SyncService } from './sync.service';
import { PushDto, PullChangesQueryDto } from './dto/push.dto';

/**
 * Endpoints do sync offline-first. Protegidos pelos guards globais
 * (JwtAuthGuard + ActiveMembershipGuard) — NUNCA públicos. `sync` é capacidade
 * transversal do núcleo (sem `@RequiresModule`); a autorização é feita POR
 * mutação no service (espelhando o `@Permissions` da rota HTTP equivalente).
 */
@Controller('sync')
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  /** Pull incremental por cursor — `{ rows, nextCursor, serverTime }`. */
  @Get('changes')
  changes(
    @CurrentUser() user: AuthUser,
    @Query() query: PullChangesQueryDto,
  ) {
    return this.sync.getChanges(user, query);
  }

  /** Push idempotente do outbox — `{ results, serverTime }`. */
  @Post('push')
  push(@CurrentUser() user: AuthUser, @Body() dto: PushDto) {
    return this.sync.push(user, dto);
  }
}
