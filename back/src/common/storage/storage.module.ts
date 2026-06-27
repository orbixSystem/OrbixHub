import { Global, Module, Provider } from '@nestjs/common';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';
import { FilesController } from './files.controller';
import { LocalStorageProvider } from './local-storage.provider';
import { MinioStorageProvider } from './minio-storage.provider';
import { STORAGE_PROVIDER, StorageProvider } from './storage.provider';

/**
 * Factory de DI keyed em env.STORAGE_PROVIDER — mesmo padrão do catalogProviderFactory
 * do Inventory. Default `local` (disco, sem container); `minio` para S3-compatible.
 */
export const storageProviderFactory: Provider = {
  provide: STORAGE_PROVIDER,
  inject: [ENV],
  useFactory: (env: Env): StorageProvider =>
    env.STORAGE_PROVIDER === 'minio'
      ? new MinioStorageProvider(env)
      : new LocalStorageProvider(env),
};

/**
 * Módulo global de storage: expõe o token STORAGE_PROVIDER para qualquer módulo
 * (ex.: OS injeta para upload de fotos) e registra a rota pública GET /files/*
 * que serve os arquivos do provider local em dev.
 */
@Global()
@Module({
  controllers: [FilesController],
  providers: [storageProviderFactory],
  exports: [STORAGE_PROVIDER],
})
export class StorageModule {}
