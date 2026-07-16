import { NuvemFiscalClient } from './nuvemfiscal-client';
import type { Env } from '../../../common/config/env.schema';

const env = {
  NUVEMFISCAL_CLIENT_ID: 'cid', NUVEMFISCAL_CLIENT_SECRET: 'sec',
  NUVEMFISCAL_BASE_URL: 'https://api.test', NUVEMFISCAL_AUTH_URL: 'https://auth.test/token',
} as unknown as Env;

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
});
