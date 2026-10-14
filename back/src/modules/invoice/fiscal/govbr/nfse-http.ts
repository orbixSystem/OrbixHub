import { Inject, Injectable } from '@nestjs/common';
import { request as httpsRequest } from 'https';
import { gunzipSync, gzipSync } from 'zlib';
import { ENV } from '../../../../common/config/config.module';
import type { Env } from '../../../../common/config/env.schema';
import type { FiscalEnvironment } from '../fiscal-gateway';
import type { A1Certificate } from './a1-certificate';

export interface NfseHttpResponse {
  status: number;
  contentType: string;
  body: Buffer;
}

/** Falha de transporte (rede, TLS, timeout) — a Sefin pode OU NÃO ter recebido. */
export class NfseTransportError extends Error {}

/**
 * Transporte para a Sefin Nacional (emissão/eventos/consulta) e o ADN (DANFSe).
 * A autenticação é mTLS com o certificado A1 do PRÓPRIO contribuinte — não há
 * token/OAuth. Sem dependência de cliente HTTP: o `https` do Node aceita
 * chave+certificado PEM direto por requisição.
 */
@Injectable()
export class NfseHttp {
  constructor(@Inject(ENV) private readonly env: Env) {}

  baseUrl(service: 'sefin' | 'adn', environment: FiscalEnvironment): string {
    if (service === 'sefin') {
      return environment === 'producao' ? this.env.NFSE_SEFIN_URL_PRODUCAO : this.env.NFSE_SEFIN_URL_HOMOLOGACAO;
    }
    return environment === 'producao' ? this.env.NFSE_ADN_URL_PRODUCAO : this.env.NFSE_ADN_URL_HOMOLOGACAO;
  }

  request(
    method: 'GET' | 'POST',
    url: string,
    cert: A1Certificate,
    json?: unknown,
  ): Promise<NfseHttpResponse> {
    const payload = json === undefined ? undefined : Buffer.from(JSON.stringify(json), 'utf8');
    return new Promise((resolve, reject) => {
      const req = httpsRequest(
        url,
        {
          method,
          key: cert.privateKeyPem,
          cert: cert.certificatePem,
          timeout: this.env.NFSE_TIMEOUT_MS,
          headers: {
            Accept: 'application/json',
            ...(payload
              ? { 'Content-Type': 'application/json', 'Content-Length': String(payload.length) }
              : {}),
          },
        },
        (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (c: Buffer) => chunks.push(c));
          res.on('end', () =>
            resolve({
              status: res.statusCode ?? 0,
              contentType: String(res.headers['content-type'] ?? ''),
              body: Buffer.concat(chunks),
            }),
          );
          res.on('error', (e) => reject(new NfseTransportError(String(e))));
        },
      );
      req.on('timeout', () => req.destroy(new Error('timeout')));
      req.on('error', (e) => reject(new NfseTransportError(String(e))));
      if (payload) req.write(payload);
      req.end();
    });
  }
}

/** XML → gzip → base64 (formato dos campos *XmlGZipB64 da API). */
export function gzipB64(xml: string): string {
  return gzipSync(Buffer.from(xml, 'utf8')).toString('base64');
}

export function gunzipB64(b64: string): string {
  return gunzipSync(Buffer.from(b64, 'base64')).toString('utf8');
}
