import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { createReadStream } from 'node:fs';
import { promises as fs } from 'node:fs';
import * as path from 'node:path';
import { Public } from '../auth/decorators';
import { LOCAL_STORAGE_ROOT } from './local-storage.provider';

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
 * Rota pública que serve os arquivos do LocalStorageProvider em dev
 * (`GET /files/<key>`). Em prod (MinIO/S3) os arquivos são servidos pelo próprio
 * object storage e esta rota fica ociosa — inofensiva. `@Public` (sem JWT) por ser
 * conteúdo de mídia referenciado por URL; a key é um caminho não-adivinhável (uuid).
 */
@Controller('files')
export class FilesController {
  @Public()
  @Get('*')
  async serve(@Param('0') key: string, @Res() res: Response): Promise<void> {
    const dest = path.resolve(LOCAL_STORAGE_ROOT, key);
    // Barra path traversal: precisa ficar dentro da raiz.
    if (dest !== LOCAL_STORAGE_ROOT && !dest.startsWith(LOCAL_STORAGE_ROOT + path.sep)) {
      throw new NotFoundException('Arquivo não encontrado.');
    }
    try {
      await fs.access(dest);
    } catch {
      throw new NotFoundException('Arquivo não encontrado.');
    }
    const ext = path.extname(dest).slice(1).toLowerCase();
    // Flutter web (CanvasKit) busca os bytes da imagem por fetch e exige CORS
    // para conseguir desenhá-la (a foto está em :4500 e o app em :8090 —
    // cross-origin). Sem isso o <img> não renderiza.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    res.setHeader('Content-Type', CONTENT_TYPES[ext] ?? 'application/octet-stream');
    createReadStream(dest).pipe(res);
  }
}
