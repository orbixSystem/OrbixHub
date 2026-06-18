import { Injectable, Logger } from '@nestjs/common';
import { promises as fs } from 'node:fs';
import * as path from 'node:path';
import type { Env } from '../config/env.schema';
import { StorageProvider } from './storage.provider';

/** Diretório raiz dos arquivos em dev (relativo ao processo — back/.storage). */
export const LOCAL_STORAGE_ROOT = path.resolve(process.cwd(), '.storage');

/**
 * Impl de disco local — default de dev (sem container). Grava em `back/.storage/<key>`;
 * `url(key)` aponta para a rota pública `GET /files/*` servida por FilesController.
 * Operações de I/O — sempre FORA de transação de banco.
 */
@Injectable()
export class LocalStorageProvider extends StorageProvider {
  private readonly logger = new Logger(LocalStorageProvider.name);
  private readonly publicBase: string;

  constructor(env: Env) {
    super();
    // STORAGE_PUBLIC_URL (ex.: http://localhost:4400) sem barra final.
    this.publicBase = env.STORAGE_PUBLIC_URL.replace(/\/+$/, '');
  }

  async put(key: string, body: Buffer): Promise<void> {
    const dest = this.resolve(key);
    await fs.mkdir(path.dirname(dest), { recursive: true });
    await fs.writeFile(dest, body);
    this.logger.debug(`Arquivo gravado em disco: ${key}`);
  }

  url(key: string): string {
    return `${this.publicBase}/files/${key}`;
  }

  async remove(key: string): Promise<void> {
    try {
      await fs.unlink(this.resolve(key));
    } catch (err) {
      // Ausente já é o estado desejado — não relança.
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') throw err;
    }
  }

  /** Resolve a key dentro da raiz, barrando path traversal (`..`). */
  private resolve(key: string): string {
    const dest = path.resolve(LOCAL_STORAGE_ROOT, key);
    if (dest !== LOCAL_STORAGE_ROOT && !dest.startsWith(LOCAL_STORAGE_ROOT + path.sep)) {
      throw new Error(`Chave de storage inválida: ${key}`);
    }
    return dest;
  }
}
