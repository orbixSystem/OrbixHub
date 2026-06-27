import { OpenFoodFactsCatalogProvider } from './openfoodfacts-catalog.provider';

describe('OpenFoodFactsCatalogProvider', () => {
  const realFetch = global.fetch;
  let provider: OpenFoodFactsCatalogProvider;

  const okResponse = (body: unknown): Response =>
    ({
      ok: true,
      status: 200,
      json: () => Promise.resolve(body),
    }) as unknown as Response;

  beforeEach(() => {
    provider = new OpenFoodFactsCatalogProvider();
  });

  afterEach(() => {
    global.fetch = realFetch;
    jest.restoreAllMocks();
  });

  it('mapeia produto encontrado (status 1) para CatalogHit, com a primeira categoria', async () => {
    global.fetch = jest.fn().mockResolvedValue(
      okResponse({
        status: 1,
        product: {
          product_name: 'Refrigerante Coca-Cola 2Lt',
          brands: 'Coca-Cola',
          categories: 'Bebidas, Refrigerantes',
        },
      }),
    ) as unknown as typeof fetch;

    const hit = await provider.lookupByGtin('7894900011517');

    expect(hit).toEqual({
      name: 'Refrigerante Coca-Cola 2Lt',
      brand: 'Coca-Cola',
      category: 'Bebidas',
      ncm: undefined,
    });
  });

  it('retorna null quando status !== 1 (não encontrado)', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValue(okResponse({ status: 0 })) as unknown as typeof fetch;

    await expect(provider.lookupByGtin('0000000000000')).resolves.toBeNull();
  });

  it('retorna null (não lança) quando o fetch rejeita / erro de rede', async () => {
    global.fetch = jest
      .fn()
      .mockRejectedValue(new Error('network down')) as unknown as typeof fetch;

    await expect(provider.lookupByGtin('7894900011517')).resolves.toBeNull();
  });
});
