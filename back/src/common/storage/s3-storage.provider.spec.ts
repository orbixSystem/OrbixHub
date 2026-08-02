import { Readable } from 'node:stream';
import type { Env } from '../config/env.schema';
import { S3StorageProvider } from './s3-storage.provider';

const env = {
  STORAGE_PUBLIC_URL: 'https://hub.exemplo.com/api',
  S3_REGION: 'us-east-2',
  S3_BUCKET: 'meu-bucket',
} as unknown as Env;

/** Cliente S3 dublê: guarda o último comando recebido e devolve o que o caso mandar. */
function fakeClient(resposta?: unknown, erro?: unknown) {
  const enviados: unknown[] = [];
  return {
    enviados,
    send: (cmd: unknown) => {
      enviados.push(cmd);
      if (erro) return Promise.reject(erro);
      return Promise.resolve(resposta ?? {});
    },
  };
}

describe('S3StorageProvider', () => {
  it('url() devolve a rota da API — nunca o endereço do bucket', () => {
    const p = new S3StorageProvider(env, fakeClient() as never);

    // Importante: a URL fica gravada em subject.photo_url. Se apontasse para o S3
    // direto, o bucket teria de ser público e um link assinado expiraria no banco.
    expect(p.url('subject/abc/foto.png')).toBe(
      'https://hub.exemplo.com/api/files/subject/abc/foto.png',
    );
  });

  it('url() não duplica barra quando a base termina com /', () => {
    const p = new S3StorageProvider(
      { ...env, STORAGE_PUBLIC_URL: 'https://hub.exemplo.com/api/' } as unknown as Env,
      fakeClient() as never,
    );
    expect(p.url('a/b.png')).toBe('https://hub.exemplo.com/api/files/a/b.png');
  });

  it('put envia bucket, key e content-type', async () => {
    const client = fakeClient();
    await new S3StorageProvider(env, client as never).put(
      'a/b.png',
      Buffer.from('conteudo'),
      'image/png',
    );

    const input = (client.enviados[0] as { input: Record<string, unknown> }).input;
    expect(input.Bucket).toBe('meu-bucket');
    expect(input.Key).toBe('a/b.png');
    expect(input.ContentType).toBe('image/png');
  });

  it('getStream devolve o corpo do objeto', async () => {
    const corpo = Readable.from([Buffer.from('bytes')]);
    const p = new S3StorageProvider(env, fakeClient({ Body: corpo }) as never);

    await expect(p.getStream('a/b.png')).resolves.toBe(corpo);
  });

  it('getStream devolve null quando o objeto não existe', async () => {
    const naoAchou = Object.assign(new Error('NoSuchKey'), { name: 'NoSuchKey' });
    const p = new S3StorageProvider(env, fakeClient(undefined, naoAchou) as never);

    await expect(p.getStream('sumiu.png')).resolves.toBeNull();
  });

  it('getStream relança erro que não seja "não encontrado"', async () => {
    const negado = Object.assign(new Error('AccessDenied'), { name: 'AccessDenied' });
    const p = new S3StorageProvider(env, fakeClient(undefined, negado) as never);

    // Falha de permissão não pode virar 404 silencioso — some com a foto e
    // esconde o problema de configuração.
    await expect(p.getStream('a/b.png')).rejects.toThrow('AccessDenied');
  });

  it('remove é idempotente: objeto ausente não é erro', async () => {
    const naoAchou = Object.assign(new Error('NoSuchKey'), { name: 'NoSuchKey' });
    const p = new S3StorageProvider(env, fakeClient(undefined, naoAchou) as never);

    await expect(p.remove('sumiu.png')).resolves.toBeUndefined();
  });
});
