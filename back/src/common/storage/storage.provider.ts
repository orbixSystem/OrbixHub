/** Token de DI para a abstração de storage (troca local/MinIO/fake em teste). */
export const STORAGE_PROVIDER = Symbol('STORAGE_PROVIDER');

/**
 * Abstração de object storage. Impls: disco local (dev default) e MinIO/S3 (prod).
 * Operações de I/O — NUNCA chamadas dentro de transação de banco (regra de ouro).
 */
export abstract class StorageProvider {
  /** Grava o binário sob `key` (sobrescreve se existir). */
  abstract put(key: string, body: Buffer, contentType: string): Promise<void>;
  /** URL pública para servir o objeto identificado por `key`. */
  abstract url(key: string): string;
  /** Remove o objeto. Idempotente o quanto a impl permitir. */
  abstract remove(key: string): Promise<void>;
}
