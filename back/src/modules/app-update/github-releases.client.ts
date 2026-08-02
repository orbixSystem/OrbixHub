import { Logger } from '@nestjs/common';

/** Token de DI (permite trocar por um fake nos testes). */
export const RELEASES_CLIENT = Symbol('RELEASES_CLIENT');

export const GITHUB_API = 'https://api.github.com';

/** Timeout curto: a checagem de atualização não pode travar a abertura do app. */
const TIMEOUT_MS = 8000;

export interface ReleaseAsset {
  id: number;
  name: string;
  size: number;
  /** URL pública e estável (repositório público). Vazia em repo privado. */
  downloadUrl: string;
}

export interface ReleaseInfo {
  tag: string;
  notes: string;
  publishedAt: string;
  assets: ReleaseAsset[];
}

/**
 * Acesso às releases do repositório.
 *
 * Passa pelo servidor de propósito, mesmo com o repositório público: é aqui que
 * mora o `minSupported` (o servidor é quem sabe qual versão ainda atende), o
 * cache que evita o rate limit da API do GitHub (60 req/h por IP anônimo — com
 * muitos aparelhos consultando, estouraria) e a indireção que mantém o app
 * funcionando igual se o repositório virar privado um dia. O token é opcional:
 * sem ele usamos a API pública; com ele o limite sobe para 5.000 req/h.
 */
export abstract class ReleasesClient {
  abstract latest(): Promise<ReleaseInfo | null>;
  /** Conteúdo de um asset pequeno (usamos para o manifest.json). */
  abstract assetText(assetId: number): Promise<string | null>;
  /** URL temporária de download do asset (expira em minutos). */
  abstract assetDownloadUrl(assetId: number): Promise<string | null>;
}

/** Sem token/repo configurados: não há atualização a oferecer. */
export class NoopReleasesClient extends ReleasesClient {
  latest(): Promise<ReleaseInfo | null> {
    return Promise.resolve(null);
  }
  assetText(): Promise<string | null> {
    return Promise.resolve(null);
  }
  assetDownloadUrl(): Promise<string | null> {
    return Promise.resolve(null);
  }
}

export class GithubReleasesClient extends ReleasesClient {
  private readonly logger = new Logger(GithubReleasesClient.name);

  constructor(
    private readonly repo: string, // "owner/repo"
    private readonly token: string | undefined,
    private readonly baseUrl: string = GITHUB_API,
  ) {
    super();
  }

  private headers(accept: string): Record<string, string> {
    return {
      Accept: accept,
      // Sem token a API pública responde igual, só com limite menor.
      ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'OrbixHub-Updater',
    };
  }

  private async fetchWithTimeout(
    url: string,
    init: RequestInit,
  ): Promise<Response | null> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      return await fetch(url, { ...init, signal: controller.signal });
    } catch (err) {
      this.logger.warn(`GitHub indisponível: ${(err as Error).message}`);
      return null;
    } finally {
      clearTimeout(timer);
    }
  }

  async latest(): Promise<ReleaseInfo | null> {
    const res = await this.fetchWithTimeout(
      `${this.baseUrl}/repos/${this.repo}/releases/latest`,
      { headers: this.headers('application/vnd.github+json') },
    );
    if (!res) return null;
    if (res.status === 404) return null; // ainda não há release publicada
    if (!res.ok) {
      this.logger.warn(`GitHub releases HTTP ${res.status}`);
      return null;
    }
    const body = (await res.json()) as {
      tag_name?: string;
      body?: string;
      published_at?: string;
      assets?: Array<{
        id: number;
        name: string;
        size: number;
        browser_download_url?: string;
      }>;
    };
    return {
      tag: body.tag_name ?? '',
      notes: body.body ?? '',
      publishedAt: body.published_at ?? '',
      assets: (body.assets ?? []).map((a) => ({
        id: a.id,
        name: a.name,
        size: a.size,
        downloadUrl: a.browser_download_url ?? '',
      })),
    };
  }

  async assetText(assetId: number): Promise<string | null> {
    const res = await this.fetchWithTimeout(
      `${this.baseUrl}/repos/${this.repo}/releases/assets/${assetId}`,
      { headers: this.headers('application/octet-stream') },
    );
    if (!res?.ok) return null;
    return res.text();
  }

  /**
   * Link direto do asset para repositório PRIVADO: a API responde 302 para uma
   * URL assinada de vida curta. Em repositório público preferimos a
   * `browser_download_url`, que é estável e não expira.
   */
  async assetDownloadUrl(assetId: number): Promise<string | null> {
    const res = await this.fetchWithTimeout(
      `${this.baseUrl}/repos/${this.repo}/releases/assets/${assetId}`,
      {
        headers: this.headers('application/octet-stream'),
        redirect: 'manual',
      },
    );
    if (!res) return null;
    const location = res.headers.get('location');
    if (location) return location;
    // Alguns ambientes seguem o redirect sozinhos; aí a própria URL final serve.
    if (res.ok && res.url) return res.url;
    this.logger.warn(`Asset ${assetId} sem URL de download (HTTP ${res.status})`);
    return null;
  }
}
