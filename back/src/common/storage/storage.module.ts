import { Global, Module, Provider } from '@nestjs/common';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';
import { FilesController } from './files.controller';
import { LocalStorageProvider } from './local-storage.provider';
import { MinioStorageProvider } from './minio-storage.provider';
import { S3StorageProvider } from './s3-storage.provider';
import { STORAGE_PROVIDER, StorageProvider } from './storage.provider';

/**
 * Factory de DI keyed em env.STORAGE_PROVIDER — mesmo padrão do catalogProviderFactory
 * do Inventory. Default `local` (disco, sem container); `minio` para S3-compatible
 * com chave estática (MinIO em dev); `s3` para a AWS, autenticando pela role da
 * instância (nenhum segredo no .env).
 */
export const storageProviderFactory: Provider = {
  provide: STORAGE_PROVIDER,
  inject: [ENV],
  useFactory: (env: Env): StorageProvider => {
    switch (env.STORAGE_PROVIDER) {
      case 's3':
        return new S3StorageProvider(env);
      case 'minio':
        return new MinioStorageProvider(env);
      default:
        return new LocalStorageProvider(env);
    }
  },
};

/**
 * Módulo global de storage: expõe o token STORAGE_PROVIDER para qualquer módulo
 * (ex.: OS injeta para upload de fotos) e registra a rota pública GET /files/*
 * que serve os arquivos de qualquer provider.
 */
@Global()
@Module({
  controllers: [FilesController],
  providers: [storageProviderFactory],
  exports: [STORAGE_PROVIDER],
})
export class StorageModule {}
