import { SaleService } from './sale.service';

/**
 * A venda NÃO é desfeita quando o estoque falha — o dinheiro já entrou. O que
 * mudou é que a falha deixou de ser invisível: até aqui ela morria num
 * `logger.warn` no servidor, quem vendeu via "venda concluída" e o saldo do
 * produto ficava errado para sempre, sem ninguém saber.
 *
 * Estes testes fixam as duas metades: a venda sobrevive E a divergência aparece
 * (na resposta, para quem vendeu; na notificação, para quem confere depois).
 */

const item = (over: Partial<Record<string, unknown>> = {}) => ({
  id: 'it1',
  kind: 'product',
  name: 'Filtro de óleo',
  inventory_item_id: 'inv1',
  quantity: 3,
  ...over,
});

function makeService(opts: { falhar?: boolean } = {}) {
  const notify = jest.fn().mockResolvedValue(undefined);
  const inventory = {
    reconcileConsumption: jest.fn().mockImplementation(() => {
      if (opts.falhar) throw new Error('Estoque insuficiente.');
      return Promise.resolve();
    }),
  };
  const svc = new SaleService(
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    inventory as never,
    {} as never,
    { notify } as never,
  );
  return { svc, notify, inventory };
}

/** `applyStock` é privado; o comportamento é o contrato desta camada. */
const aplicar = (
  svc: SaleService,
  itens: unknown[],
  mode: 'consume' | 'return' = 'consume',
) =>
  (
    svc as unknown as {
      applyStock: (
        u: unknown,
        id: string,
        num: string,
        items: unknown[],
        m: string,
      ) => Promise<Array<{ name: string; message: string }>>;
    }
  ).applyStock({ tenantId: 't1', userId: 'u1' }, 'sale1', 'VND-0007', itens, mode);

describe('estoque não aplicado na venda', () => {
  it('quando dá certo: nenhum aviso e nenhuma notificação', async () => {
    const { svc, notify } = makeService();
    await expect(aplicar(svc, [item()])).resolves.toEqual([]);
    expect(notify).not.toHaveBeenCalled();
  });

  it('quando falha: devolve o aviso com o nome do item e o motivo', async () => {
    const { svc } = makeService({ falhar: true });
    const avisos = await aplicar(svc, [item()]);
    expect(avisos).toHaveLength(1);
    expect(avisos[0].name).toBe('Filtro de óleo');
    expect(avisos[0].message).toContain('Estoque insuficiente');
  });

  it('quando falha: registra a divergência apontando para a venda', async () => {
    const { svc, notify } = makeService({ falhar: true });
    await aplicar(svc, [item()]);
    expect(notify).toHaveBeenCalledTimes(1);
    const [tenantId, payload] = notify.mock.calls[0] as [
      string,
      { type: string; title: string; body: string; refType: string; refId: string },
    ];
    expect(tenantId).toBe('t1');
    expect(payload.type).toBe('inventory_sale_unapplied');
    expect(payload.title).toContain('VND-0007');
    expect(payload.body).toContain('Filtro de óleo');
    // Aponta para a venda — quem abrir a notificação chega no documento.
    expect(payload).toMatchObject({ refType: 'sale', refId: 'sale1' });
  });

  it('uma notificação por venda, não uma por item', async () => {
    // Três itens falhando não podem virar três sinos para a mesma venda.
    const { svc, notify } = makeService({ falhar: true });
    const avisos = await aplicar(svc, [
      item({ id: 'a', name: 'Filtro' }),
      item({ id: 'b', name: 'Óleo' }),
      item({ id: 'c', name: 'Vela' }),
    ]);
    expect(avisos).toHaveLength(3);
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it('serviço e item avulso não tocam o estoque', async () => {
    const { svc, inventory } = makeService();
    await aplicar(svc, [
      item({ kind: 'service' }),
      item({ inventory_item_id: null }),
    ]);
    expect(inventory.reconcileConsumption).not.toHaveBeenCalled();
  });

  it('notificação que falha não derruba a venda já gravada', async () => {
    const { svc, notify } = makeService({ falhar: true });
    notify.mockRejectedValueOnce(new Error('sino fora do ar'));
    await expect(aplicar(svc, [item()])).resolves.toHaveLength(1);
  });

  it('no estorno o aviso fala em devolvido, não em baixado', async () => {
    const { svc, notify } = makeService({ falhar: true });
    await aplicar(svc, [item()], 'return');
    const [, payload] = notify.mock.calls[0] as [string, { title: string }];
    expect(payload.title).toContain('devolvido');
  });
});
