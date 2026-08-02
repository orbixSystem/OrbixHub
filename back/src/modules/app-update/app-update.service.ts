import { Inject, Injectable, Logger } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS } from '../../common/redis/redis.module';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { RELEASES_CLIENT, ReleasesClient } from './github-releases.client';

export type UpdatePlatform = 'android' | 'windows';

/** O que o app precisa saber para decidir e baixar. */
export interface UpdateInfo {
  enabled: boolean;
  platform?: UpdatePlatform;
  /** Versão publicada, ex.: "1.0.3". */
  version?: string;
  buildNumber?: number;
  /**
   * Menor versão que o backend ainda atende. Abaixo disso o app deve BLOQUEAR
   * o uso e exigir atualização — é a válvula para quando o servidor muda de um
   * jeito que o app antigo não suporta.
   */
  minSupported?: string;
  /**
   * Build mínimo aceito DENTRO da mesma versão. Sem isto, publicar 1.0.0+13
   * depois de 1.0.0+12 não bloquearia nada — o número da versão não mudou.
   */
  minSupportedBuild?: number;
  notes?: string;
  /** URL temporária de download (assinada, expira em minutos). */
  url?: string;
  /** Hash do arquivo: o app confere ANTES de instalar. */
  sha256?: string;
  sizeBytes?: number;
  publishedAt?: string;
}

/** Forma do manifest.json publicado como asset pela pipeline de release. */
interface ReleaseManifest {
  version?: string;
  buildNumber?: number;
  minSupported?: string;
  minSupportedBuild?: number;
  artifacts?: Record<string, { asset?: string; sha256?: string }>;
}

const MANIFEST_ASSET = 'manifest.json';
/** Metadados mudam pouco; a URL assinada é sempre resolvida na hora. */
const META_TTL_SECONDS = 600;

/**
 * Diz ao app qual é a última versão publicada e entrega o link de download
 * pronto. Passar pelo servidor (em vez de o app falar direto com o GitHub) é o
 * que permite decidir aqui o `minSupported` e cachear a consulta — a API
 * pública do GitHub corta em 60 req/h por IP, o que um parque de aparelhos
 * estouraria sozinho.
 */
@Injectable()
export class AppUpdateService {
  private readonly logger = new Logger(AppUpdateService.name);

  constructor(
    @Inject(RELEASES_CLIENT) private readonly releases: ReleasesClient,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async latest(platform: UpdatePlatform): Promise<UpdateInfo> {
    if (!this.env.APP_UPDATE_ENABLED) return { enabled: false };

    const meta = await this.metadata();
    if (!meta) return { enabled: false };

    const artifact = meta.manifest.artifacts?.[platform];
    const assetName = artifact?.asset;
    if (!assetName) return { enabled: false };

    const asset = meta.assets.find((a) => a.name === assetName);
    if (!asset) {
      this.logger.warn(`Release sem o asset "${assetName}" (${platform}).`);
      return { enabled: false };
    }

    // Repositório público: a URL do asset é estável e vem no próprio metadado.
    // Em repositório privado ela não existe, e aí resolvemos a URL assinada na
    // hora (essa expira em minutos, por isso nunca entra em cache).
    const url = asset.downloadUrl?.length
        ? asset.downloadUrl
        : await this.releases.assetDownloadUrl(asset.id);
    if (!url) return { enabled: false };

    return {
      enabled: true,
      platform,
      version: meta.manifest.version,
      buildNumber: meta.manifest.buildNumber,
      minSupported: meta.manifest.minSupported,
      minSupportedBuild: meta.manifest.minSupportedBuild,
      notes: meta.notes,
      url,
      sha256: artifact.sha256,
      sizeBytes: asset.size,
      publishedAt: meta.publishedAt,
    };
  }

  /** Release + manifest, com cache curto (a API do GitHub tem rate limit). */
  private async metadata(): Promise<{
    manifest: ReleaseManifest;
    assets: Array<{
      id: number;
      name: string;
      size: number;
      downloadUrl: string;
    }>;
    notes: string;
    publishedAt: string;
  } | null> {
    const key = 'appupdate:meta';
    try {
      const cached = await this.redis.get(key);
      if (cached) {
        return JSON.parse(cached) as Awaited<
          ReturnType<AppUpdateService['metadata']>
        >;
      }
    } catch {
      /* cache é best-effort */
    }

    const release = await this.releases.latest();
    if (!release) return null;

    const manifestAsset = release.assets.find((a) => a.name === MANIFEST_ASSET);
    if (!manifestAsset) {
      this.logger.warn('Release publicada sem manifest.json — ignorando.');
      return null;
    }
    const raw = await this.releases.assetText(manifestAsset.id);
    if (!raw) return null;

    let manifest: ReleaseManifest;
    try {
      manifest = JSON.parse(raw) as ReleaseManifest;
    } catch {
      this.logger.warn('manifest.json inválido na release.');
      return null;
    }

    const value = {
      manifest,
      assets: release.assets,
      notes: release.notes,
      publishedAt: release.publishedAt,
    };
    try {
      await this.redis.set(
        key,
        JSON.stringify(value),
        'EX',
        META_TTL_SECONDS,
      );
    } catch {
      /* best-effort */
    }
    return value;
  }
}
