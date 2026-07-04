import {
  Query,
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from '../../common/auth/decorators';
import { PublicThrottlerGuard } from '../../common/throttler/public-throttler.guard';
import { OsPublicService } from './os-public.service';
import { PostPublicMessageDto } from './dto/public-message.dto';

/**
 * Acompanhamento público da OS (página de tracking + chat do cliente). Todas as
 * rotas são @Public (sem JWT / sem ModuleAccessGuard); o tenant é resolvido no
 * servidor a partir do public_token via função SECURITY DEFINER. NÃO é o controller
 * da OS (esse é gated por @RequiresModule('os')) — este vive fora do gate por design.
 *
 * Rate-limit: o `PublicThrottlerGuard` cobre o controller inteiro (GET track,
 * GET mensagens e POST do chat) e chaveia pelo TOKEN do link — cada link tem seu
 * budget (60/min), então clientes atrás do mesmo IP de NAT não colidem. As rotas
 * saem do guard global por IP via `@SkipThrottle({ default: true })` — senão o
 * polling de 15s da página somava no balde por IP e derrubava tudo com 429.
 */
@Controller('public/track')
@Public()
@SkipThrottle({ default: true })
@UseGuards(PublicThrottlerGuard)
export class OsPublicController {
  constructor(private readonly osPublic: OsPublicService) {}

  @Get(':token')
  getTrack(@Param('token') token: string) {
    return this.osPublic.getPublicTrack(token);
  }

  @Get(':token/messages')
  getMessages(
    @Param('token') token: string,
    @Query('before') before?: string,
  ) {
    return this.osPublic.getPublicMessages(token, before);
  }

  @Post(':token/messages')
  @HttpCode(201)
  postMessage(
    @Param('token') token: string,
    @Body() dto: PostPublicMessageDto,
  ) {
    return this.osPublic.postPublicMessage(token, dto.body, dto.authorName);
  }
}
