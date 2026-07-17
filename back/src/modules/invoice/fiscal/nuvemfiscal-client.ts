import { Inject, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';
import type { FiscalIdentity } from '../invoice.service';

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

  /**
   * Cadastra/atualiza a empresa (idempotente) no provedor a partir da identidade
   * fiscal do núcleo. Sem CNPJ não há como cadastrar — falha cedo, sem chamar HTTP.
   */
  async upsertEmpresa(id: FiscalIdentity): Promise<void> {
    if (!id.cnpj) throw new ServiceUnavailableException('Tenant sem CNPJ em Configurações da empresa');
    const payload = {
      cpf_cnpj: id.cnpj,
      nome_razao_social: id.razaoSocial ?? '',
      nome_fantasia: id.razaoSocial ?? '',
      email: id.email ?? '',
      inscricao_estadual: id.inscricaoEstadual ?? undefined,
      inscricao_municipal: id.inscricaoMunicipal ?? undefined,
      endereco: {
        logradouro: id.endereco.logradouro ?? '',
        numero: id.endereco.numero ?? '',
        bairro: id.endereco.bairro ?? '',
        cidade: id.endereco.municipio ?? '',
        uf: id.endereco.uf ?? '',
        cep: id.endereco.cep ?? '',
      },
    };
    // idempotente: cria; se já existe, atualiza via PUT
    const exists = await this.request('GET', `/empresas/${id.cnpj}`, { allow404: true });
    if (exists) await this.request('PUT', `/empresas/${id.cnpj}`, { body: payload });
    else await this.request('POST', `/empresas`, { body: payload });
  }

  /** Envia o certificado A1 (.pfx, base64) — passthrough puro: NUNCA persistido aqui. */
  async uploadCertificate(
    cnpj: string,
    pfxBase64: string,
    password: string,
  ): Promise<{ notValidAfter: string | null }> {
    const r = await this.request<{ not_valid_after?: string }>(
      'PUT',
      `/empresas/${cnpj}/certificado`,
      { body: { certificado: pfxBase64, password } },
    );
    return { notValidAfter: r?.not_valid_after ?? null };
  }
}
