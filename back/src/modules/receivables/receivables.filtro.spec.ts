import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  classificar,
  DevedorParaFiltro,
  filtrarDevedores,
  ordenarDevedores,
  paginar,
} from './receivables.filtro';

/**
 * A MESMA tabela é lida pelo teste Dart (front/test/receivables_filtro_test.dart).
 * Se um lado mudar a regra sem o outro, os dois ficam vermelhos — foi exatamente
 * a divergência online/offline que deixou o fiado vazando título entre devedores
 * e o filtro de estoque baixo discordando com e sem rede.
 */
interface Casos {
  hoje: string;
  devedores: Array<DevedorParaFiltro & { id: string }>;
  classificacao: Record<string, { nextDueAt: string | null; overdue: boolean }>;
  filtros: Array<{
    nome: string;
    f: { q?: string; vencimento: string; origem: string };
    esperado: string[];
  }>;
  ordenacoes: Array<{ ordem: string; esperado: string[] }>;
  paginacao: {
    pageSize: number;
    page: number;
    ordem: string;
    esperadoIds: string[];
    total: number;
  };
}

const casos = JSON.parse(
  readFileSync(join(__dirname, 'receivables-filtro.casos.json'), 'utf8'),
) as Casos;

const hoje = new Date(casos.hoje);
const classificados = casos.devedores.map((d) => ({
  ...classificar(d, hoje),
  id: d.id,
}));
const ids = (l: Array<{ id: string }>) => l.map((x) => x.id);

describe('receivables.filtro (tabela compartilhada com o front)', () => {
  it.each(Object.entries(casos.classificacao))(
    'classifica %s',
    (id, esperado) => {
      const d = classificados.find((x) => x.id === id);
      expect(d).toBeDefined();
      expect(d!.nextDueAt).toBe(esperado.nextDueAt);
      expect(d!.overdue).toBe(esperado.overdue);
    },
  );

  it.each(casos.filtros.map((c) => [c.nome, c] as const))(
    'filtro %s',
    (_nome, c) => {
      const r = filtrarDevedores(classificados, c.f as never, hoje);
      expect(ids(r).sort()).toEqual([...c.esperado].sort());
    },
  );

  it.each(casos.ordenacoes.map((c) => [c.ordem, c] as const))(
    'ordem %s',
    (_nome, c) => {
      expect(ids(ordenarDevedores(classificados, c.ordem as never))).toEqual(
        c.esperado,
      );
    },
  );

  it('paginação devolve a página pedida e o total geral', () => {
    const p = casos.paginacao;
    const ordenados = ordenarDevedores(classificados, p.ordem as never);
    const r = paginar(ordenados, p.page, p.pageSize);
    expect(ids(r.items)).toEqual(p.esperadoIds);
    expect(r.total).toBe(p.total);
  });

  it('página além do fim devolve vazio, mas mantém o total', () => {
    const r = paginar(classificados, 99, 2);
    expect(r.items).toEqual([]);
    expect(r.total).toBe(classificados.length);
  });
});
