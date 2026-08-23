import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { SupportService } from './support.service';

class AbrirChamadoDto {
  @IsString() @MinLength(1) @MaxLength(120) subject!: string;
  @IsString() @MinLength(1) @MaxLength(4000) body!: string;
}

class ResponderDto {
  @IsString() @MinLength(1) @MaxLength(4000) body!: string;
}

/**
 * Chamados de suporte do tenant com a Orbix.
 *
 * SEM `@Permissions` e SEM `@RequiresModule` de propósito: pedir ajuda não é
 * funcionalidade contratada nem privilégio de cargo. Quem está dentro do
 * ambiente pode abrir chamado — inclusive (e principalmente) quando algo está
 * bloqueado. Um canal de suporte que o plano vencido derruba falha exatamente
 * na hora em que é necessário.
 */
@Controller('support')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Get('tickets')
  tickets(@CurrentUser() user: AuthUser) {
    return this.support.tickets(user);
  }

  @Post('tickets')
  @HttpCode(201)
  abrir(@CurrentUser() user: AuthUser, @Body() dto: AbrirChamadoDto) {
    return this.support.abrir(user, dto.subject, dto.body);
  }

  @Get('tickets/:id/messages')
  mensagens(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.support.mensagens(user, id);
  }

  @Post('tickets/:id/messages')
  @HttpCode(201)
  responder(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ResponderDto,
  ) {
    return this.support.responder(user, id, dto.body);
  }

  /**
   * Pede a reabertura de um chamado fechado, com o motivo. Quem reabre de fato
   * é a Orbix — aqui fica registrado o pedido.
   */
  @Post('tickets/:id/reopen-request')
  @HttpCode(200)
  solicitarReabertura(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ResponderDto,
  ) {
    return this.support.solicitarReabertura(user, id, dto.body);
  }

  @Post('tickets/:id/resolve')
  @HttpCode(200)
  async resolver(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    await this.support.resolver(user, id);
    return { ok: true };
  }

  /** Total de respostas não lidas — alimenta o ponto discreto na entrada. */
  @Get('unread')
  async unread(@CurrentUser() user: AuthUser) {
    return { count: await this.support.naoLidas(user) };
  }
}
