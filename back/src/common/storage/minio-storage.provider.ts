import { Injectable } from '@nestjs/common';
import { Client as MinioClient } from 'minio';
import type { Env } from '../config/env.schema';
import { StorageProvider } from './storage.provider';

/**
 * Impl S3-compatible via cliente `minio` (serve MinIO em dev e S3 em prod).
 * Cliente construído a partir do env (segredos via Zod). Em qualquer erro de I/O
 * a operação relança (o caller — OsService — decide o que fazer). Sempre FORA de
 * transação de banco (regra de ouro: nenhuma chamada externa dentro de tx).
 */
@Injectable()
export class MinioStorageProvider extends StorageProvider {
  private readonly client: MinioClient;
  private readonly bucket: string;
  private readonly publicBase: string;

  constructor(env: Env) {
    super();
    // S3_ENDPOINT ex.: http://localhost:9000 → host/port/useSSL para o minio Client.
    const endpoint = new URL(env.S3_ENDPOINT ?? 'http://localhost:9000');
    const useSSL = endpoint.protocol === 'https:';
    this.client = new MinioClient({
      endPoint: endpoint.hostname,
      port: endpoint.port ? Number(endpoint.port) : useSSL ? 443 : 80,
      useSSL,
      accessKey: env.S3_ACCESS_KEY ?? '',
      secretKey: env.S3_SECRET_KEY ?? '',
      region: env.S3_REGION,
    });
    this.bucket = env.S3_BUCKET ?? 'orbix-os';
    this.publicBase = (env.S3_PUBLIC_URL ?? env.S3_ENDPOINT ?? '').replace(
      /\/+$/,
      '',
    );
  }

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    await this.client.putObject(this.bucket, key, body, body.length, {
      'Content-Type': contentType,
    });
  }

  url(key: string): string {
    return `${this.publicBase}/${this.bucket}/${key}`;
  }

  async remove(key: string): Promise<void> {
    await this.client.removeObject(this.bucket, key);
  }
}
