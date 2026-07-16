import { ServiceUnavailableException } from '@nestjs/common';
import { NuvemFiscalClient } from './nuvemfiscal-client';
import type { Env } from '../../../common/config/env.schema';

const env = {
  NUVEMFISCAL_CLIENT_ID: 'cid', NUVEMFISCAL_CLIENT_SECRET: 'sec',
  NUVEMFISCAL_BASE_URL: 'https://api.test', NUVEMFISCAL_AUTH_URL: 'https://auth.test/token',
} as unknown as Env;

/** Mock de fetch: 1ª chamada = OAuth2 token, 2ª chamada = a resposta dada. */
function mockFetchWithToken(secondResponse: Response | (() => Promise<Response>)) {
  const tokenResponse = new Response(
    JSON.stringify({ access_token: 'abc', expires_in: 3600 }),
    { status: 200 },
  );
  return jest.spyOn(global, 'fetch').mockImplementationOnce(() => Promise.resolve(tokenResponse))
    .mockImplementationOnce(() =>
      typeof secondResponse === 'function' ? secondResponse() : Promise.resolve(secondResponse),
    );
}

describe('NuvemFiscalClient.token', () => {
  afterEach(() => jest.restoreAllMocks());

  it('busca e cacheia o token OAuth2', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ access_token: 'abc', expires_in: 3600 }), { status: 200 }),
    );
    const c = new NuvemFiscalClient(env);
    expect(await c.token()).toBe('abc');
    expect(await c.token()).toBe('abc'); // 2ª chamada usa cache
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock.mock.calls[0][0]).toBe('https://auth.test/token');
  });

  it('lança ServiceUnavailableException se o fetch do token falhar por erro de rede', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new TypeError('fetch failed'));
    const c = new NuvemFiscalClient(env);
    await expect(c.token()).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});

describe('NuvemFiscalClient.request', () => {
  afterEach(() => jest.restoreAllMocks());

  it('injeta Authorization: Bearer <token> e prefixa NUVEMFISCAL_BASE_URL', async () => {
    const fetchMock = mockFetchWithToken(
      new Response(JSON.stringify({ ok: true }), { status: 200 }),
    );
    const c = new NuvemFiscalClient(env);
    const result = await c.request<{ ok: boolean }>('GET', '/empresas/123');

    expect(result).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    const [url, init] = fetchMock.mock.calls[1];
    expect(url).toBe('https://api.test/empresas/123');
    expect((init?.headers as Record<string, string>).Authorization).toBe('Bearer abc');
  });

  it('allow404: true + resposta 404 resolve para null', async () => {
    mockFetchWithToken(new Response(null, { status: 404 }));
    const c = new NuvemFiscalClient(env);
    const result = await c.request('GET', '/empresas/inexistente', { allow404: true });
    expect(result).toBeNull();
  });

  it('resposta 204 resolve para null', async () => {
    mockFetchWithToken(new Response(null, { status: 204 }));
    const c = new NuvemFiscalClient(env);
    const result = await c.request('DELETE', '/empresas/123');
    expect(result).toBeNull();
  });

  it('status não-OK sem allow404 lança ServiceUnavailableException', async () => {
    mockFetchWithToken(new Response('erro interno', { status: 500 }));
    const c = new NuvemFiscalClient(env);
    await expect(c.request('GET', '/empresas/123')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('fetch que rejeita (erro de rede) lança ServiceUnavailableException', async () => {
    mockFetchWithToken(() => Promise.reject(new TypeError('network error')));
    const c = new NuvemFiscalClient(env);
    await expect(c.request('GET', '/empresas/123')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
