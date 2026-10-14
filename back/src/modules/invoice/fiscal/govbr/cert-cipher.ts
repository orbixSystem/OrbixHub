import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const IV_BYTES = 12;
const TAG_BYTES = 16;

/**
 * Cifra o certificado A1 (e a senha dele) antes de ir para o banco — AES-256-GCM,
 * chave só no env (FISCAL_CERT_KEY). Formato: base64(iv | tag | ciphertext).
 * GCM autentica: um byte adulterado no banco faz o decrypt falhar, em vez de
 * devolver lixo para a assinatura.
 */
export class CertCipher {
  private readonly key: Buffer;

  constructor(keyBase64: string) {
    this.key = Buffer.from(keyBase64, 'base64');
    if (this.key.length !== 32) throw new Error('FISCAL_CERT_KEY deve ter 32 bytes (base64)');
  }

  encrypt(plain: Buffer): string {
    const iv = randomBytes(IV_BYTES);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const ct = Buffer.concat([cipher.update(plain), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), ct]).toString('base64');
  }

  decrypt(payload: string): Buffer {
    const buf = Buffer.from(payload, 'base64');
    const iv = buf.subarray(0, IV_BYTES);
    const tag = buf.subarray(IV_BYTES, IV_BYTES + TAG_BYTES);
    const decipher = createDecipheriv('aes-256-gcm', this.key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(buf.subarray(IV_BYTES + TAG_BYTES)), decipher.final()]);
  }
}
