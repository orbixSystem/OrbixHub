import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { MessagesService } from './messages.service';
import { PostMessageDto } from './dto/post-message.dto';
import { ListConversationsQueryDto } from './dto/list-conversations.dto';

/**
 * Inbox de mensagens (lado staff). Módulo genérico, NÃO contratável — sem
 * @RequiresModule. Autorização por @Permissions: no v1 REUSAMOS as permissões da OS
 * (`os.read`/`os.write`) em vez de criar `messages.*` — a única origem de conversas
 * hoje é a OS. (Trocar por `messages.*` quando outros módulos alimentarem o inbox.)
 */
@Controller('messages')
export class MessagesController {
  constructor(private readonly messages: MessagesService) {}

  @Get('conversations')
  @Permissions('os.read') // v1: reusa os.read (ver nota da classe)
  listConversations(
    @CurrentUser() user: AuthUser,
    @Query() query: ListConversationsQueryDto,
  ) {
    return this.messages.listConversations(user, query);
  }

  @Get('conversations/:id')
  @Permissions('os.read') // v1: reusa os.read
  getThread(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messages.getThread(user, id);
  }

  @Post('conversations/:id/messages')
  @Permissions('os.write') // v1: reusa os.write
  postMessage(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: PostMessageDto,
  ) {
    return this.messages.postStaffMessage(user, id, dto.body);
  }

  @Post('conversations/:id/read')
  @Permissions('os.read') // v1: reusa os.read
  @HttpCode(200)
  markRead(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messages.markRead(user, id);
  }
}
