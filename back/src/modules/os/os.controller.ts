import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { OsService, type UploadedImage } from './os.service';
import {
  ChangeStatusDto,
  CreateOrderDto,
  ListOrdersQueryDto,
  UpdateOrderDto,
} from './dto/order.dto';
import { CreateItemDto, UpdateItemDto } from './dto/item.dto';
import { CreateNoteDto } from './dto/note.dto';
import { CreateTemplateDto, UpdateTemplateDto } from './dto/template.dto';

@Controller('os')
@UseGuards(ModuleAccessGuard)
@RequiresModule('os')
export class OsController {
  constructor(private readonly os: OsService) {}

  // --- templates de serviço ---
  // Rotas literais `/os/templates...` declaradas ANTES de `/os/orders/...` para
  // não colidirem (segmentos distintos, mas mantemos explícito).
  @Get('templates')
  @Permissions('os.read')
  listTemplates(@CurrentUser() user: AuthUser) {
    return this.os.listTemplates(user);
  }

  @Get('templates/:id')
  @Permissions('os.read')
  getTemplate(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.os.getTemplate(user, id);
  }

  @Post('templates')
  @Permissions('os.write')
  createTemplate(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateTemplateDto,
  ) {
    return this.os.createTemplate(user, dto);
  }

  @Patch('templates/:id')
  @Permissions('os.write')
  updateTemplate(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateTemplateDto,
  ) {
    return this.os.updateTemplate(user, id, dto);
  }

  @Delete('templates/:id')
  @Permissions('os.write')
  @HttpCode(200)
  deleteTemplate(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.os.deleteTemplate(user, id);
  }

  @Post('orders/:id/apply-template/:templateId')
  @Permissions('os.write')
  @HttpCode(200)
  applyTemplate(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('templateId') templateId: string,
  ) {
    return this.os.applyTemplate(user, id, templateId);
  }

  // --- orders ---
  @Post('orders')
  @Permissions('os.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    return this.os.createOrder(user, dto);
  }

  @Get('orders')
  @Permissions('os.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ListOrdersQueryDto) {
    return this.os.listOrders(user, query);
  }

  @Get('orders/:id')
  @Permissions('os.read')
  getOne(@CurrentUser() _user: AuthUser, @Param('id') id: string) {
    return this.os.getOrderOrThrow(id);
  }

  @Patch('orders/:id')
  @Permissions('os.write')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateOrderDto,
  ) {
    return this.os.updateOrder(user, id, dto);
  }

  // os.approve (aprovar) é exigido no service para a transição → 'aprovada'.
  @Post('orders/:id/status')
  @Permissions('os.write')
  @HttpCode(200)
  changeStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: ChangeStatusDto,
  ) {
    return this.os.changeStatus(user, id, dto);
  }

  @Delete('orders/:id')
  @Permissions('os.write')
  @HttpCode(200)
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.os.deleteOrder(user, id);
  }

  // --- itens ---
  @Post('orders/:id/items')
  @Permissions('os.write')
  addItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateItemDto,
  ) {
    return this.os.addItem(user, id, dto);
  }

  @Patch('orders/:id/items/:itemId')
  @Permissions('os.write')
  updateItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('itemId') itemId: string,
    @Body() dto: UpdateItemDto,
  ) {
    return this.os.updateItem(user, id, itemId, dto);
  }

  @Delete('orders/:id/items/:itemId')
  @Permissions('os.write')
  @HttpCode(200)
  deleteItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('itemId') itemId: string,
  ) {
    return this.os.deleteItem(user, id, itemId);
  }

  // --- timeline / notas ---
  @Post('orders/:id/notes')
  @Permissions('os.write')
  addNote(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateNoteDto,
  ) {
    return this.os.createNote(user, id, dto);
  }

  // --- fotos (multipart) ---
  // Memory storage: o binário fica em file.buffer (sem tocar disco antes do StorageProvider).
  // Validação de tipo/tamanho fica no service.
  @Post('orders/:id/photos')
  @Permissions('os.write')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  addPhoto(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @UploadedFile() file: UploadedImage | undefined,
    @Body('caption') caption?: string,
  ) {
    return this.os.addPhoto(user, id, file, caption);
  }

  @Delete('orders/:id/photos/:photoId')
  @Permissions('os.write')
  @HttpCode(200)
  deletePhoto(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('photoId') photoId: string,
  ) {
    return this.os.deletePhoto(user, id, photoId);
  }
}
