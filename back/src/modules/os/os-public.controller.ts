import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/auth/decorators';
import { PublicThrottlerGuard } from '../../common/throttler/public-throttler.guard';
import { OsPublicService } from './os-public.service';
import { PostPublicMessageDto } from './dto/public-message.dto';

// Limite por IP para o POST público (chat do cliente). Mira o throttler nomeado
// `public` (só o PublicThrottlerGuard enforça); o global default fica intacto.
const PUBLIC_WRITE = { public: { ttl: 60_000, limit: 10 } };

/**
 * Acompanhamento público da OS (página de tracking + chat do cliente). Todas as
 * rotas são @Public (sem JWT / sem ModuleAccessGuard); o tenant é resolvido no
 * servidor a partir do public_token via função SECURITY DEFINER. NÃO é o controller
 * da OS (esse é gated por @RequiresModule('os')) — este vive fora do gate por design.
 */
@Controller('public/track')
@Public()
export class OsPublicController {
  constructor(private readonly osPublic: OsPublicService) {}

  @Get(':token')
  getTrack(@Param('token') token: string) {
    return this.osPublic.getPublicTrack(token);
  }

  @Get(':token/messages')
  getMessages(@Param('token') token: string) {
    return this.osPublic.getPublicMessages(token);
  }

  @Post(':token/messages')
  @HttpCode(201)
  @UseGuards(PublicThrottlerGuard)
  @Throttle(PUBLIC_WRITE)
  postMessage(
    @Param('token') token: string,
    @Body() dto: PostPublicMessageDto,
  ) {
    return this.osPublic.postPublicMessage(token, dto.body, dto.authorName);
  }
}
