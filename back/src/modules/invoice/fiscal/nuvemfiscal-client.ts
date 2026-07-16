import { Inject, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';

/**
 * Cliente HTTP genérico para a API da Nuvem Fiscal (BaaS fiscal). Cuida da
 * autenticação OAuth2 (client-credentials) com cache do token até perto da
 * expiração, e expõe um wrapper de `fetch` que injeta Bearer + base URL e
 * normaliza erros. Empresa/certificado/emissão ficam em cima disto (Task 7+).
 */
@Injectable()
export class NuvemFiscalClient {
  private readonly logger = new Logger(NuvemFiscalClient.name);
  private cachedToken: { value: string; expiresAt: number } | null = null;

  constructor(@Inject(ENV) private readonly env: Env) {}

  async token(): Promise<string> {
    const now = Date.now();
    if (this.cachedToken && this.cachedToken.expiresAt > now + 30_000) {
      return this.cachedToken.value;
    }
    const body = new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: this.env.NUVEMFISCAL_CLIENT_ID,
      client_secret: this.env.NUVEMFISCAL_CLIENT_SECRET,
      scope: 'empresa nfse nfce nfe',
    });
    let res: Response;
    try {
      res = await fetch(this.env.NUVEMFISCAL_AUTH_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body,
      });
    } catch (err) {
      this.logger.error(`Falha de rede ao autenticar no provedor fiscal: ${String(err)}`);
      throw new ServiceUnavailableException('Erro na comunicação com o provedor fiscal');
    }
    if (!res.ok) {
      this.logger.error(`OAuth2 falhou: ${res.status}`);
      throw new ServiceUnavailableException('Falha ao autenticar no provedor fiscal');
    }
    const json = (await res.json()) as { access_token: string; expires_in: number };
    this.cachedToken = {
      value: json.access_token,
      expiresAt: now + json.expires_in * 1000,
    };
    return json.access_token;
  }

  async request<T>(
    method: string,
    path: string,
    opts?: { body?: unknown; allow404?: boolean },
  ): Promise<T | null> {
    const token = await this.token();
    let res: Response;
    try {
      res = await fetch(`${this.env.NUVEMFISCAL_BASE_URL}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: opts?.body !== undefined ? JSON.stringify(opts.body) : undefined,
      });
    } catch (err) {
      this.logger.error(`Falha de rede em ${method} ${path}: ${String(err)}`);
      throw new ServiceUnavailableException('Erro na comunicação com o provedor fiscal');
    }
    if (opts?.allow404 && res.status === 404) return null;
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      this.logger.error(`${method} ${path} -> ${res.status}: ${text}`);
      throw new ServiceUnavailableException('Erro na comunicação com o provedor fiscal');
    }
    if (res.status === 204) return null;
    return (await res.json()) as T;
  }
}
