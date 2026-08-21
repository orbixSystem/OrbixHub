import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { SupportService } from './support.service';

class EnviarMensagemDto {
  @IsString() @MinLength(1) @MaxLength(4000) body!: string;
}

/**
 * Canal de suporte do tenant com a Orbix.
 *
 * SEM `@Permissions` e SEM `@RequiresModule` de propósito: pedir ajuda não é
 * funcionalidade contratada nem privilégio de cargo. Quem está dentro do
 * ambiente pode falar com o suporte — inclusive (e principalmente) quando algo
 * está bloqueado. Um canal de suporte que o plano vencido derruba é um canal
 * que falha exatamente na hora em que é necessário.
 */
@Controller('support')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Get('messages')
  thread(@CurrentUser() user: AuthUser) {
    return this.support.thread(user);
  }

  /** Badge discreto: quantas respostas da Orbix o cliente ainda não leu. */
  @Get('unread')
  async unread(@CurrentUser() user: AuthUser) {
    return { count: await this.support.naoLidas(user) };
  }

  @Post('messages')
  @HttpCode(201)
  enviar(@CurrentUser() user: AuthUser, @Body() dto: EnviarMensagemDto) {
    return this.support.enviar(user, dto.body);
  }
}
