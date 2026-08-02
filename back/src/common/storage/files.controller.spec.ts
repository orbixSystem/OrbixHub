import { NotFoundException } from '@nestjs/common';
import { Readable } from 'node:stream';
import type { Response } from 'express';
import { FilesController } from './files.controller';
import { StorageProvider } from './storage.provider';

/** Provider de teste: devolve o que o caso mandar, registra o que foi pedido. */
class FakeProvider extends StorageProvider {
  pedidas: string[] = [];
  constructor(private readonly resposta: Readable | null) {
    super();
  }
  put(): Promise<void> {
    return Promise.resolve();
  }
  url(key: string): string {
    return `https://exemplo/api/files/${key}`;
  }
  remove(): Promise<void> {
    return Promise.resolve();
  }
  getStream(key: string): Promise<Readable | null> {
    this.pedidas.push(key);
    return Promise.resolve(this.resposta);
  }
}

function fakeRes() {
  const headers: Record<string, string> = {};
  const chunks: unknown[] = [];
  const res = {
    setHeader: (k: string, v: string) => {
      headers[k] = v;
    },
    write: (c: unknown) => chunks.push(c),
    end: () => undefined,
    on: () => undefined,
    once: () => undefined,
    emit: () => undefined,
    headers,
    chunks,
  };
  return res as unknown as Response & { headers: Record<string, string> };
}

describe('FilesController', () => {
  it('pede a key ao provider — não toca no disco direto', async () => {
    const provider = new FakeProvider(Readable.from([Buffer.from('x')]));
    const res = fakeRes();

    await new FilesController(provider).serve('subject/abc/foto.png', res);

    expect(provider.pedidas).toEqual(['subject/abc/foto.png']);
  });

  it('404 quando o provider não acha o arquivo', async () => {
    const provider = new FakeProvider(null);

    await expect(
      new FilesController(provider).serve('nao/existe.png', fakeRes()),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('404 em path traversal — a key nunca escapa da raiz', async () => {
    const provider = new FakeProvider(null);

    await expect(
      new FilesController(provider).serve('../../etc/passwd', fakeRes()),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('deriva o Content-Type da extensão', async () => {
    const res = fakeRes();
    await new FilesController(new FakeProvider(Readable.from([Buffer.from('x')]))).serve(
      'a/b/foto.PNG',
      res,
    );
    expect(res.headers['Content-Type']).toBe('image/png');
  });

  it('cai em octet-stream quando a extensão é desconhecida', async () => {
    const res = fakeRes();
    await new FilesController(new FakeProvider(Readable.from([Buffer.from('x')]))).serve(
      'a/b/arquivo.xyz',
      res,
    );
    expect(res.headers['Content-Type']).toBe('application/octet-stream');
  });

  it('mantém os headers de CORS — o CanvasKit do Flutter web não desenha sem eles', async () => {
    const res = fakeRes();
    await new FilesController(new FakeProvider(Readable.from([Buffer.from('x')]))).serve(
      'a/b/foto.png',
      res,
    );
    expect(res.headers['Access-Control-Allow-Origin']).toBe('*');
    expect(res.headers['Cross-Origin-Resource-Policy']).toBe('cross-origin');
  });
});
