import type { Readable } from 'node:stream';

/** Token de DI para a abstração de storage (troca local/MinIO/S3/fake em teste). */
export const STORAGE_PROVIDER = Symbol('STORAGE_PROVIDER');

/**
 * Abstração de object storage. Impls: disco local (dev default), MinIO
 * (S3-compatible em dev) e S3 da AWS (prod).
 * Operações de I/O — NUNCA chamadas dentro de transação de banco (regra de ouro).
 */
export abstract class StorageProvider {
  /** Grava o binário sob `key` (sobrescreve se existir). */
  abstract put(key: string, body: Buffer, contentType: string): Promise<void>;
  /** URL pública para servir o objeto identificado por `key`. */
  abstract url(key: string): string;
  /** Remove o objeto. Idempotente o quanto a impl permitir. */
  abstract remove(key: string): Promise<void>;
  /**
   * Abre o objeto para leitura; `null` quando não existe.
   *
   * Existe para o FilesController servir arquivo sem saber onde ele mora — é o
   * que mantém a URL pública igual (`/api/files/<key>`) em qualquer provider.
   * Isso importa porque a URL fica GRAVADA no banco (ex.: `subject.photo_url`):
   * se apontasse para o bucket, ele teria de ser público, e um link assinado
   * expiraria deixando o registro quebrado.
   */
  abstract getStream(key: string): Promise<Readable | null>;
}
