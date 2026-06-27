import { CatalogProductStore } from './catalog-product.store';
import type { PrismaService } from '../../../common/database/prisma.service';

/** Mock manual do delegate `catalog_product` do Prisma client. */
function makePrisma() {
  const delegate = {
    findUnique: jest.fn(),
    upsert: jest.fn(),
  };
  const prisma = { catalog_product: delegate } as unknown as PrismaService;
  return { prisma, delegate };
}

const daysAgo = (n: number) => new Date(Date.now() - n * 24 * 60 * 60 * 1000);

describe('CatalogProductStore', () => {
  describe('get', () => {
    it('returns the hit when fetched_at is recent (fresh ≤ 60d)', async () => {
      const { prisma, delegate } = makePrisma();
      delegate.findUnique.mockResolvedValue({
        gtin: '7891000100103',
        name: 'Leite Moça',
        brand: 'Nestlé',
        ncm: '04029900',
        category: 'Laticínios',
        source: 'cosmos',
        fetched_at: new Date(),
        created_at: new Date(),
      });
      const store = new CatalogProductStore(prisma);

      const hit = await store.get('7891000100103');

      expect(hit).toEqual({
        name: 'Leite Moça',
        brand: 'Nestlé',
        ncm: '04029900',
        category: 'Laticínios',
      });
      expect(delegate.findUnique).toHaveBeenCalledWith({
        where: { gtin: '7891000100103' },
      });
    });

    it('omits absent optional fields in the mapped hit', async () => {
      const { prisma, delegate } = makePrisma();
      delegate.findUnique.mockResolvedValue({
        gtin: '7891000100103',
        name: 'Produto X',
        brand: null,
        ncm: null,
        category: null,
        source: 'openfoodfacts',
        fetched_at: daysAgo(1),
        created_at: daysAgo(1),
      });
      const store = new CatalogProductStore(prisma);

      const hit = await store.get('7891000100103');

      expect(hit).toEqual({ name: 'Produto X' });
    });

    it('returns null when the row is older than 60 days (stale)', async () => {
      const { prisma, delegate } = makePrisma();
      delegate.findUnique.mockResolvedValue({
        gtin: '7891000100103',
        name: 'Antigo',
        brand: null,
        ncm: null,
        category: null,
        source: 'cosmos',
        fetched_at: daysAgo(61),
        created_at: daysAgo(61),
      });
      const store = new CatalogProductStore(prisma);

      expect(await store.get('7891000100103')).toBeNull();
    });

    it('returns null when there is no row', async () => {
      const { prisma, delegate } = makePrisma();
      delegate.findUnique.mockResolvedValue(null);
      const store = new CatalogProductStore(prisma);

      expect(await store.get('0000000000000')).toBeNull();
    });

    it('degrades to null on DB error (cache best-effort)', async () => {
      const { prisma, delegate } = makePrisma();
      delegate.findUnique.mockRejectedValue(new Error('db down'));
      const store = new CatalogProductStore(prisma);

      expect(await store.get('7891000100103')).toBeNull();
    });
  });

  describe('upsert', () => {
    it('upserts by gtin with the right data and fetched_at = now()', async () => {
      const { prisma, delegate } = makePrisma();
      delegate.upsert.mockResolvedValue(undefined);
      const store = new CatalogProductStore(prisma);
      const before = Date.now();

      await store.upsert(
        '7891000100103',
        { name: 'Leite Moça', brand: 'Nestlé' },
        'cosmos',
      );

      expect(delegate.upsert).toHaveBeenCalledTimes(1);
      const arg = delegate.upsert.mock.calls[0][0];
      expect(arg.where).toEqual({ gtin: '7891000100103' });
      expect(arg.create).toMatchObject({
        gtin: '7891000100103',
        name: 'Leite Moça',
        brand: 'Nestlé',
        ncm: null,
        category: null,
        source: 'cosmos',
      });
      expect(arg.update).toMatchObject({
        name: 'Leite Moça',
        brand: 'Nestlé',
        source: 'cosmos',
      });
      const fetchedAt = (arg.create.fetched_at as Date).getTime();
      expect(fetchedAt).toBeGreaterThanOrEqual(before);
      expect(fetchedAt).toBeLessThanOrEqual(Date.now());
    });
  });
});
