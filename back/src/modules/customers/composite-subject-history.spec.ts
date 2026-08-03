import { CompositeSubjectHistoryProvider } from './composite-subject-history.provider';
import type { SubjectHistoryEntry } from './subject-history.provider';

/**
 * Histórico do cliente = união das fontes (OS ∪ venda de balcão), em ordem
 * cronológica.
 *
 * O que isto protege: a venda avulsa não aparecia na ficha do cliente, porque o
 * seam aceitava uma fonte só e estava amarrado à OS — mesmo sendo a mesma
 * pergunta ("o que essa pessoa já comprou aqui").
 */

const entrada = (
  id: string,
  kind: string,
  occurredAt: string,
  subjectId?: string,
): SubjectHistoryEntry => ({
  id,
  kind,
  title: `${kind} ${id}`,
  status: 'ok',
  occurredAt,
  subjectId,
});

/** Fonte de teste; `falha: true` simula um módulo indisponível. */
class Fonte {
  constructor(
    private readonly porCliente: SubjectHistoryEntry[],
    private readonly porSubject: SubjectHistoryEntry[] = [],
    private readonly falha = false,
  ) {}

  async listByCustomer(): Promise<SubjectHistoryEntry[]> {
    if (this.falha) throw new Error('módulo fora do ar');
    return this.porCliente;
  }

  async listBySubject(): Promise<SubjectHistoryEntry[]> {
    if (this.falha) throw new Error('módulo fora do ar');
    return this.porSubject;
  }
}

describe('CompositeSubjectHistoryProvider', () => {
  it('une OS e vendas do cliente, mais recente primeiro', async () => {
    const os = new Fonte([
      entrada('os-1', 'os', '2026-07-01T10:00:00.000Z'),
      entrada('os-2', 'os', '2026-07-20T10:00:00.000Z'),
    ]);
    const vendas = new Fonte([
      entrada('v-1', 'sale', '2026-07-10T10:00:00.000Z'),
      entrada('v-2', 'sale', '2026-07-25T10:00:00.000Z'),
    ]);
    const provider = new CompositeSubjectHistoryProvider([os, vendas]);

    const timeline = await provider.listByCustomer('c1');
    expect(timeline.map((e) => e.id)).toEqual(['v-2', 'os-2', 'v-1', 'os-1']);
  });

  it('a venda entra no histórico do cliente (era o que faltava)', async () => {
    const provider = new CompositeSubjectHistoryProvider([
      new Fonte([entrada('os-1', 'os', '2026-07-01T10:00:00.000Z')]),
      new Fonte([entrada('v-1', 'sale', '2026-07-02T10:00:00.000Z')]),
    ]);
    const kinds = (await provider.listByCustomer('c1')).map((e) => e.kind);
    expect(kinds).toContain('sale');
    expect(kinds).toContain('os');
  });

  it('filtrando por VEÍCULO, só entram fontes com subject', async () => {
    // Venda não é "do carro": se aparecesse ao filtrar por veículo, sairia
    // repetida em todos os carros do cliente.
    const os = new Fonte(
      [],
      [entrada('os-1', 'os', '2026-07-01T10:00:00.000Z', 's1')],
    );
    const vendas = new Fonte([entrada('v-1', 'sale', '2026-07-02T10:00:00.000Z')]);
    const provider = new CompositeSubjectHistoryProvider([os, vendas]);

    const doVeiculo = await provider.listBySubject('s1');
    expect(doVeiculo.map((e) => e.id)).toEqual(['os-1']);
  });

  it('fonte que falha não derruba a timeline', async () => {
    // Histórico é leitura: melhor mostrar as OS sem as vendas do que uma tela
    // de erro na ficha do cliente.
    const provider = new CompositeSubjectHistoryProvider([
      new Fonte([entrada('os-1', 'os', '2026-07-01T10:00:00.000Z')]),
      new Fonte([], [], true),
    ]);
    const timeline = await provider.listByCustomer('c1');
    expect(timeline.map((e) => e.id)).toEqual(['os-1']);
  });

  it('sem fontes, devolve vazio (não explode)', async () => {
    const provider = new CompositeSubjectHistoryProvider([]);
    expect(await provider.listByCustomer('c1')).toEqual([]);
    expect(await provider.listBySubject('s1')).toEqual([]);
  });
});
