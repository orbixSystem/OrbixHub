import {
  Controller,
  Get,
  Inject,
  NotFoundException,
  Param,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import * as path from 'node:path';
import { Public } from '../auth/decorators';
import { STORAGE_PROVIDER, StorageProvider } from './storage.provider';

/** Content-Type por extensão (genérico; cobre os formatos de imagem comuns). */
const CONTENT_TYPES: Record<string, string> = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  gif: 'image/gif',
  webp: 'image/webp',
  bmp: 'image/bmp',
  svg: 'image/svg+xml',
  pdf: 'application/pdf',
};

/**
 * Rota pública que serve os arquivos do storage (`GET /api/files/<key>`),
 * qualquer que seja o provider — disco em dev, S3 em prod.
 *
 * Servir pela API (em vez de mandar o cliente direto ao bucket) é o que permite
 * manter o bucket PRIVADO e a URL ESTÁVEL: ela fica gravada no banco
 * (`subject.photo_url`, `service_order_photo.url`), então não pode expirar.
 *
 * `@Public` (sem JWT) por ser conteúdo de mídia referenciado por URL; a key é um
 * caminho não-adivinhável (uuid), e o provider barra qualquer tentativa de sair
 * da raiz.
 */
@Controller('files')
export class FilesController {
  constructor(
    @Inject(STORAGE_PROVIDER) private readonly storage: StorageProvider,
  ) {}

  @Public()
  @Get('*')
  async serve(@Param('0') key: string, @Res() res: Response): Promise<void> {
    const stream = await this.storage.getStream(key);
    if (!stream) throw new NotFoundException('Arquivo não encontrado.');

    const ext = path.extname(key).slice(1).toLowerCase();
    // Flutter web (CanvasKit) busca os bytes da imagem por fetch e exige CORS
    // para conseguir desenhá-la (a foto e o app podem estar em origens
    // diferentes). Sem isso o <img> não renderiza.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    res.setHeader('Content-Type', CONTENT_TYPES[ext] ?? 'application/octet-stream');
    stream.pipe(res);
  }
}
