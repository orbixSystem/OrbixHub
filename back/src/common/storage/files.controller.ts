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
    createReadStream(dest).pipe(res);
  }
}
