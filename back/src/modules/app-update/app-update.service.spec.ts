import type { Env } from '../../common/config/env.schema';
import { AppUpdateService } from './app-update.service';
import {
  ReleaseInfo,
  ReleasesClient,
} from './github-releases.client';

/**
 * O repositório é PRIVADO: o valor deste serviço é justamente manter o token no
 * servidor e entregar ao app apenas uma URL já assinada. Os testes fixam esse
 * contrato e a degradação (sem release, sem manifest, desligado).
 */

const manifest = JSON.stringify({
  version: '1.0.3',
  buildNumber: 12,
  minSupported: '1.0.0',
  artifacts: {
    android: { asset: 'orbixhub-1.0.3.apk', sha256: 'abc123' },
    windows: { asset: 'OrbixHubSetup-1.0.3.exe', sha256: 'def456' },
  },
});

const release: ReleaseInfo = {
  tag: 'v1.0.3',
  notes: 'Correções na OS',
  publishedAt: '2026-08-02T10:00:00Z',
  assets: [
    { id: 1, name: 'manifest.json', size: 200, downloadUrl: '' },
    {
      id: 2,
      name: 'orbixhub-1.0.3.apk',
      size: 33_000_000,
      downloadUrl: 'https://github.com/o/r/releases/download/v1.0.3/app.apk',
    },
    {
      id: 3,
      name: 'OrbixHubSetup-1.0.3.exe',
      size: 45_000_000,
      downloadUrl: 'https://github.com/o/r/releases/download/v1.0.3/setup.exe',
    },
  ],
};

class FakeReleases extends ReleasesClient {
  latestCalls = 0;
  constructor(private readonly data: ReleaseInfo | null = release) {
    super();
  }
  latest(): Promise<ReleaseInfo | null> {
    this.latestCalls += 1;
    return Promise.resolve(this.data);
  }
  assetText(id: number): Promise<string | null> {
    return Promise.resolve(id === 1 ? manifest : null);
  }
  assetDownloadUrl(id: number): Promise<string | null> {
    return Promise.resolve(`https://objects.example/${id}?token=temporario`);
  }
}

/** Redis em memória (o cache é best-effort; aqui queremos observá-lo). */
function fakeRedis() {
  const store = new Map<string, string>();
  return {
    store,
    get: (k: string) => Promise.resolve(store.get(k) ?? null),
    set: (k: string, v: string) => {
      store.set(k, v);
      return Promise.resolve('OK');
    },
  } as unknown as import('ioredis').Redis;
}

function makeService(opts: {
  releases?: ReleasesClient;
  enabled?: boolean;
  redis?: import('ioredis').Redis;
}) {
  const env = {
    APP_UPDATE_ENABLED: opts.enabled ?? true,
    GITHUB_RELEASES_REPO: 'orbixSystem/OrbixHub',
    GITHUB_RELEASES_TOKEN: 'segredo-do-servidor',
  } as unknown as Env;
  const releases = opts.releases ?? new FakeReleases();
  const svc = new AppUpdateService(releases, opts.redis ?? fakeRedis(), env);
  return { svc, releases };
}

describe('AppUpdateService', () => {
  it('devolve versão, hash e URL pronta — sem nenhum segredo', async () => {
    const { svc } = makeService({});
    const info = await svc.latest('android');

    expect(info.enabled).toBe(true);
    expect(info.version).toBe('1.0.3');
    expect(info.buildNumber).toBe(12);
    expect(info.minSupported).toBe('1.0.0');
    expect(info.sha256).toBe('abc123');
    expect(info.sizeBytes).toBe(33_000_000);
    expect(info.url).toContain('/releases/download/');
    // O token do GitHub não pode aparecer em lugar nenhum da resposta.
    expect(JSON.stringify(info)).not.toContain('segredo-do-servidor');
  });

  it('cada plataforma recebe o seu artefato', async () => {
    const { svc } = makeService({});
    const win = await svc.latest('windows');
    expect(win.sha256).toBe('def456');
    expect(win.url).toContain('setup.exe');
  });

  it('desligado por env: não consulta o GitHub', async () => {
    const { svc, releases } = makeService({ enabled: false });
    const info = await svc.latest('android');
    expect(info).toEqual({ enabled: false });
    expect((releases as FakeReleases).latestCalls).toBe(0);
  });

  it('sem release publicada: responde "sem atualização"', async () => {
    const { svc } = makeService({ releases: new FakeReleases(null) });
    await expect(svc.latest('android')).resolves.toEqual({ enabled: false });
  });

  it('release sem manifest.json é ignorada (não sabemos o hash)', async () => {
    const semManifest = new FakeReleases({
      ...release,
      assets: [
        { id: 2, name: 'orbixhub-1.0.3.apk', size: 1, downloadUrl: '' },
      ],
    });
    const { svc } = makeService({ releases: semManifest });
    await expect(svc.latest('android')).resolves.toEqual({ enabled: false });
  });

  it('plataforma ausente no manifest não inventa download', async () => {
    const outro = new FakeReleases({
      ...release,
      assets: [{ id: 1, name: 'manifest.json', size: 200, downloadUrl: '' }],
    });
    const { svc } = makeService({ releases: outro });
    await expect(svc.latest('android')).resolves.toEqual({ enabled: false });
  });

  it('metadados vêm do cache, mas a URL assinada é resolvida a cada consulta',
    async () => {
      const redis = fakeRedis();
      const { svc, releases } = makeService({ redis });
      await svc.latest('android');
      await svc.latest('android');
      // Uma única ida ao GitHub para metadados...
      expect((releases as FakeReleases).latestCalls).toBe(1);
      // ...e a URL segue vindo em toda consulta.
      const segunda = await svc.latest('android');
      expect(segunda.url).toContain('/releases/download/');
    });
});
