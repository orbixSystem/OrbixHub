import { InventoryRepository } from './inventory.repository';

/**
 * "Estoque baixo" e "Esgotados" são recortes da mesma pergunta, e um contém o
 * outro. O jeito de errar isso é silencioso: o filtro devolve linhas demais e
 * quem está repondo compra o que não precisava.
 */
function capturarWhere() {
  let capturado: Record<string, unknown> | undefined;
  const db = {
    inventory_item: {
      fields: { min_stock: Symbol('min_stock') },
      findMany: (args: { where: Record<string, unknown> }) => {
        capturado = args.where;
        return Promise.resolve([]);
      },
      count: () => Promise.resolve(0),
    },
  };
  const repo = new InventoryRepository({ getClient: () => db } as never);
  return { repo, where: () => capturado };
}

const clausulas = (where: Record<string, unknown> | undefined) =>
  (where?.AND as Array<Record<string, unknown>>) ?? [];

describe('filtros de estoque em listItems', () => {
  const base = { active: 'active' as const, skip: 0, take: 20 };

  it('sem filtro não acrescenta cláusula de estoque', async () => {
    const { repo, where } = capturarWhere();
    await repo.listItems(base);
    expect(clausulas(where())).toHaveLength(0);
  });

  it('lowStock cobre o abaixo do mínimo E o zerado', async () => {
    const { repo, where } = capturarWhere();
    await repo.listItems({ ...base, lowStock: true });
    const [c] = clausulas(where());
    expect(c.kind).toBe('product');
    expect(c.OR).toHaveLength(2);
  });

  it('outOfStock é só o zerado — sem OR, sem mínimo', async () => {
    const { repo, where } = capturarWhere();
    await repo.listItems({ ...base, outOfStock: true });
    const [c] = clausulas(where());
    expect(c).toEqual({ kind: 'product', current_stock: { lte: 0 } });
  });

  it('com os DOIS ligados, vence o recorte menor (esgotado)', async () => {
    // Pedir "só os que acabaram" dentro de "os que precisam de atenção" não
    // pode devolver MAIS linhas do que pedir só o primeiro.
    const { repo, where } = capturarWhere();
    await repo.listItems({ ...base, lowStock: true, outOfStock: true });
    const c = clausulas(where());
    expect(c).toHaveLength(1);
    expect(c[0]).toEqual({ kind: 'product', current_stock: { lte: 0 } });
  });

  it('serviço nunca entra: nasce com saldo 0 e não controla estoque', async () => {
    const { repo, where } = capturarWhere();
    await repo.listItems({ ...base, outOfStock: true });
    expect(clausulas(where())[0].kind).toBe('product');
  });

  it('busca textual convive com o filtro de estoque (duas cláusulas)', async () => {
    // Os dois usavam chaves `OR` irmãs, que se sobrescrevem em silêncio no
    // Prisma — por isso tudo vai num `AND` único.
    const { repo, where } = capturarWhere();
    await repo.listItems({ ...base, outOfStock: true, q: 'filtro' });
    expect(clausulas(where())).toHaveLength(2);
  });
});
