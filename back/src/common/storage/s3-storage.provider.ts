import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { Injectable, Logger } from '@nestjs/common';
import type { Readable } from 'node:stream';
import type { Env } from '../config/env.schema';
import { StorageProvider } from './storage.provider';

/** Erros do S3 que significam "o objeto não está lá". */
const NAO_ENCONTRADO = new Set(['NoSuchKey', 'NotFound', 'NoSuchBucket']);

function ehNaoEncontrado(err: unknown): boolean {
  const nome = (err as { name?: string })?.name;
  const status = (err as { $metadata?: { httpStatusCode?: number } })?.$metadata
    ?.httpStatusCode;
  return (nome !== undefined && NAO_ENCONTRADO.has(nome)) || status === 404;
}

/**
 * Impl para o S3 da AWS em produção.
 *
 * Autentica pela **cadeia de credenciais padrão do SDK**, que na EC2 resolve para
 * a role da instância (`orbix-ec2-role`). De propósito: não há `S3_ACCESS_KEY`
 * nem `S3_SECRET_KEY` aqui — nenhum segredo de longa duração no `.env`, e a AWS
 * rotaciona as credenciais sozinha. Para MinIO em dev, use `STORAGE_PROVIDER=minio`,
 * que continua usando chave estática.
 *
 * Operações de I/O — sempre FORA de transação de banco.
 */
@Injectable()
export class S3StorageProvider extends StorageProvider {
  private readonly logger = new Logger(S3StorageProvider.name);
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicBase: string;

  constructor(env: Env, client?: S3Client) {
    super();
    this.client = client ?? new S3Client({ region: env.S3_REGION });
    this.bucket = env.S3_BUCKET ?? 'orbix-uploads';
    this.publicBase = env.STORAGE_PUBLIC_URL.replace(/\/+$/, '');
  }

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
      }),
    );
    this.logger.debug(`Objeto gravado no S3: ${key}`);
  }

  /**
   * Rota da própria API — NÃO o endereço do bucket. Ver a nota em
   * [StorageProvider.getStream]: a URL é persistida, então precisa ser estável
   * e servida por quem controla o acesso.
   */
  url(key: string): string {
    return `${this.publicBase}/files/${key}`;
  }

  async remove(key: string): Promise<void> {
    try {
      await this.client.send(
        new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
      );
    } catch (err) {
      // Ausente já é o estado desejado — não relança.
      if (!ehNaoEncontrado(err)) throw err;
    }
  }

  async getStream(key: string): Promise<Readable | null> {
    try {
      const out = await this.client.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      return (out.Body as Readable) ?? null;
    } catch (err) {
      if (ehNaoEncontrado(err)) return null;
      // AccessDenied e afins NÃO viram 404: isso esconderia erro de
      // configuração fazendo a foto simplesmente "sumir".
      throw err;
    }
  }
}
