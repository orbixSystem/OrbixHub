import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ListDebtorsQueryDto } from './dto/list-debtors.dto';

/**
 * O DTO é o CONTRATO com o cliente, e a fronteira onde valor inválido tem de
 * virar 400 em vez de entrar na regra.
 *
 * Isto importa mais do que parece: `vencimento`/`origem`/`sort` viram `switch`
 * na regra pura — um valor fora da lista não cairia em nenhum `case` e o filtro
 * simplesmente não filtraria, devolvendo a carteira inteira como se estivesse
 * tudo certo. Falha silenciosa em tela de cobrança é o pior tipo.
 *
 * O app também depende disto ao contrário: os `wire` do enum Dart
 * (`receivables_query.dart`) precisam ser exatamente estes — se divergirem, o
 * servidor responde 400 e a tela quebra só em produção, nunca em teste de
 * widget. Por isso a lista de aceitos está escrita aqui, explícita.
 */
async function erros(query: Record<string, unknown>) {
  const dto = plainToInstance(ListDebtorsQueryDto, query, {
    enableImplicitConversion: false,
  });
  const falhas = await validate(dto);
  return falhas.map((f) => f.property);
}

describe('ListDebtorsQueryDto — o contrato da query', () => {
  it('aceita a query vazia (carteira inteira, primeira página)', async () => {
    expect(await erros({})).toEqual([]);
  });

  describe('vencimento', () => {
    // Exatamente os `wire` do enum Dart `VencimentoFiltro`.
    it.each(['todos', 'vencidos', 'vence7', 'a_vencer', 'sem_prazo'])(
      'aceita %s',
      async (v) => {
        expect(await erros({ vencimento: v })).toEqual([]);
      },
    );

    it.each(['SEM_PRAZO', 'atrasados', 'vence_7', '', 'null'])(
      'recusa %s',
      async (v) => {
        expect(await erros({ vencimento: v })).toEqual(['vencimento']);
      },
    );
  });

  describe('origem', () => {
    it.each(['todos', 'os', 'sale'])('aceita %s', async (v) => {
      expect(await erros({ origem: v })).toEqual([]);
    });

    it.each(['OS', 'venda', 'sales'])('recusa %s', async (v) => {
      expect(await erros({ origem: v })).toEqual(['origem']);
    });
  });

  describe('sort', () => {
    it.each(['valor', 'mais_antigo', 'nome', 'vencimento'])(
      'aceita %s',
      async (v) => {
        expect(await erros({ sort: v })).toEqual([]);
      },
    );

    it.each(['maisAntigo', 'valor_desc', 'data'])('recusa %s', async (v) => {
      expect(await erros({ sort: v })).toEqual(['sort']);
    });
  });

  describe('paginação', () => {
    it('aceita page e pageSize válidos', async () => {
      expect(await erros({ page: 3, pageSize: 20 })).toEqual([]);
    });

    it('recusa página zero ou negativa', async () => {
      expect(await erros({ page: 0 })).toEqual(['page']);
      expect(await erros({ page: -1 })).toEqual(['page']);
    });

    it('recusa página fracionada (não existe página 1,5)', async () => {
      expect(await erros({ page: 1.5 })).toEqual(['page']);
    });

    it('aceita o teto de 100 e recusa acima', async () => {
      expect(await erros({ pageSize: 100 })).toEqual([]);
      // Sem teto, um cliente pediria a carteira inteira numa tacada — a
      // varredura do servidor é em memória, então isso é proteção de carga.
      expect(await erros({ pageSize: 101 })).toEqual(['pageSize']);
    });

    it('recusa pageSize zero', async () => {
      expect(await erros({ pageSize: 0 })).toEqual(['pageSize']);
    });

    it('converte número em texto (query string sempre chega como texto)', async () => {
      // `@Type(() => Number)`: sem isso, "2" seria string e as travas de
      // mínimo/máximo nunca rodariam.
      const dto = plainToInstance(ListDebtorsQueryDto, { page: '2', pageSize: '50' });
      expect(await validate(dto)).toEqual([]);
      expect(dto.page).toBe(2);
      expect(dto.pageSize).toBe(50);
    });

    it('recusa texto que não é número', async () => {
      expect(await erros({ page: 'abc' })).toEqual(['page']);
    });
  });

  describe('busca', () => {
    it('aceita busca comum, com acento e espaços', async () => {
      expect(await erros({ q: '  José da Silva ' })).toEqual([]);
    });

    it('aceita o limite de 120 caracteres e recusa acima', async () => {
      expect(await erros({ q: 'a'.repeat(120) })).toEqual([]);
      expect(await erros({ q: 'a'.repeat(121) })).toEqual(['q']);
    });

    it('recusa q que não é texto', async () => {
      expect(await erros({ q: 42 })).toEqual(['q']);
    });
  });

  it('acumula as falhas em vez de parar na primeira', async () => {
    const falhas = await erros({ vencimento: 'x', origem: 'y', pageSize: 999 });
    expect(falhas.sort()).toEqual(['origem', 'pageSize', 'vencimento']);
  });
});
