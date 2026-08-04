import { BadRequestException } from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import {
  MAX_PARCELAS,
  datasDasParcelas,
  ratearParcelas,
} from './expenses.config';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Compra parcelada: uma dívida, N vencimentos.
 *
 * Duas coisas aqui não podem errar por um centavo nem por um dia:
 *  - a SOMA das parcelas tem de ser exatamente o total combinado;
 *  - o dia do vencimento tem de encurtar em mês curto, não transbordar.
 */
const user = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
} as unknown as AuthUser;

/** Soma em centavos — comparar reais em float é o próprio bug que testamos. */
const somaCentavos = (vs: number[]) =>
  vs.reduce((a, v) => a + Math.round(v * 100), 0);

describe('ratearParcelas', () => {
  it('soma exatamente o total, com o resto na PRIMEIRA parcela', () => {
    // R$ 100 em 3x não divide redondo. A convenção brasileira põe os centavos de
    // resto na primeira e deixa as seguintes limpas.
    expect(ratearParcelas(100, 3)).toEqual([33.34, 33.33, 33.33]);
    expect(somaCentavos(ratearParcelas(100, 3))).toBe(10000);
  });

  it('divisão exata não inventa resto', () => {
    expect(ratearParcelas(900, 3)).toEqual([300, 300, 300]);
  });

  it('fecha o total para QUALQUER n até o teto (é a única garantia que importa)', () => {
    // Varredura: se alguma combinação perdesse ou criasse centavo, a dívida
    // cadastrada deixaria de ser a dívida real.
    for (const total of [0.03, 1, 9.99, 100, 1234.56, 99999.99]) {
      for (let n = 2; n <= MAX_PARCELAS; n++) {
        const vs = ratearParcelas(total, n);
        expect(vs).toHaveLength(n);
        expect(somaCentavos(vs)).toBe(Math.round(total * 100));
      }
    }
  });

  it('total menor que o número de parcelas não gera parcela negativa', () => {
    // R$ 0,02 em 3x: duas de zero e uma de dois centavos. Feio, mas honesto —
    // e nenhuma parcela negativa, que o CHECK do banco recusaria.
    const vs = ratearParcelas(0.02, 3);
    expect(vs.every((v) => v >= 0)).toBe(true);
    expect(somaCentavos(vs)).toBe(2);
  });
});

describe('datasDasParcelas', () => {
  const iso = (d: Date) => d.toISOString().slice(0, 10);

  it('primeira é o vencimento informado; as outras de mês em mês', () => {
    const ds = datasDasParcelas(new Date(Date.UTC(2026, 7, 10)), 3);
    expect(ds.map(iso)).toEqual(['2026-08-10', '2026-09-10', '2026-10-10']);
  });

  it('mês curto ENCURTA o dia, não transborda', () => {
    // 31/01 em 3x: fevereiro não tem 31. Transbordar para 03/03 jogaria a
    // parcela de fevereiro no mês de março, onde ninguém a procura.
    const ds = datasDasParcelas(new Date(Date.UTC(2026, 0, 31)), 3);
    expect(ds.map(iso)).toEqual(['2026-01-31', '2026-02-28', '2026-03-31']);
  });

  it('ano bissexto dá 29 de fevereiro', () => {
    const ds = datasDasParcelas(new Date(Date.UTC(2028, 0, 31)), 2);
    expect(ds.map(iso)).toEqual(['2028-01-31', '2028-02-29']);
  });

  it('atravessa a virada do ano', () => {
    const ds = datasDasParcelas(new Date(Date.UTC(2026, 10, 15)), 4);
    expect(ds.map(iso)).toEqual([
      '2026-11-15',
      '2026-12-15',
      '2027-01-15',
      '2027-02-15',
    ]);
  });

  it('12x não perde o dia ao dar a volta no calendário', () => {
    const ds = datasDasParcelas(new Date(Date.UTC(2026, 7, 5)), 12);
    expect(iso(ds[11])).toBe('2027-07-05');
    expect(ds).toHaveLength(12);
  });
});

describe('expenses — criação parcelada', () => {
  function montar() {
    const criadas: Array<Record<string, unknown>> = [];
    const repo = {
      findCategory: jest.fn(() => Promise.resolve({ id: 'c1' })),
      createMany: jest.fn((_t: string, rows: Array<Record<string, unknown>>) => {
        criadas.push(...rows);
        return Promise.resolve({ count: rows.length });
      }),
      listInstallmentGroup: jest.fn(() =>
        Promise.resolve(
          [...criadas].sort(
            (a, b) =>
              (a.installment_no as number) - (b.installment_no as number),
          ),
        ),
      ),
    };
    const tenant = { withTenantTx: <T>(fn: () => Promise<T>) => fn() };
    const audit = { log: jest.fn(() => Promise.resolve()) };
    const service = new ExpensesService(
      tenant as never,
      repo as never,
      audit as never,
      {} as never,
      {} as never,
    );
    return { service, repo, criadas };
  }

  const base = {
    description: 'Compressor',
    dueDate: '2026-08-10',
    amount: 900,
  };

  it('cria N linhas no MESMO grupo, numeradas 1..N', async () => {
    const { service, criadas } = montar();
    await service.create(user, { ...base, parcelas: 3 });

    expect(criadas).toHaveLength(3);
    expect(criadas.map((c) => c.installment_no)).toEqual([1, 2, 3]);
    expect(criadas.every((c) => c.installment_total === 3)).toBe(true);
    // Um grupo só: é ele que junta as irmãs no detalhe.
    expect(new Set(criadas.map((c) => c.installment_group_id)).size).toBe(1);
  });

  it('o `amount` recebido é o TOTAL — o servidor rateia', async () => {
    const { service, criadas } = montar();
    await service.create(user, { ...base, amount: 100, parcelas: 3 });
    expect(criadas.map((c) => c.amount)).toEqual([33.34, 33.33, 33.33]);
  });

  it('devolve a PRIMEIRA parcela (é a que a tela acabou de cadastrar)', async () => {
    const { service } = montar();
    const r = await service.create(user, { ...base, parcelas: 4 });
    expect(r.installment_no).toBe(1);
  });

  it('parcela não é recorrência: pedir as duas é erro explicado', async () => {
    // O CHECK do banco barra, mas a mensagem dele não ensina nada. Os dois
    // conceitos geram várias contas e por isso se confundem.
    const { service } = montar();
    await expect(
      service.create(user, {
        ...base,
        parcelas: 3,
        recorrencia: { frequency: 'monthly' },
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('não parcela "valor a confirmar" — sem total não há o que dividir', async () => {
    const { service } = montar();
    await expect(
      service.create(user, { ...base, amount: 0, parcelas: 3 }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('usa os ids vindos do cliente (replay offline não duplica parcelas)', async () => {
    // Sem isto, o cliente sem rede criaria 3 linhas locais e o replay geraria 3
    // OUTRAS: o pull seguinte mostraria 6 parcelas de uma compra em 3x.
    const { service, criadas } = montar();
    const ids = [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
      '33333333-3333-4333-8333-333333333333',
    ];
    await service.create(user, {
      ...base,
      parcelas: 3,
      installmentIds: ids,
      installmentGroupId: '44444444-4444-4444-8444-444444444444',
    });
    expect(criadas.map((c) => c.id)).toEqual(ids);
    expect(criadas[0].installment_group_id).toBe(
      '44444444-4444-4444-8444-444444444444',
    );
  });

  it('quantidade de ids diferente de `parcelas` é recusada', async () => {
    const { service } = montar();
    await expect(
      service.create(user, {
        ...base,
        parcelas: 3,
        installmentIds: ['11111111-1111-4111-8111-111111111111'],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('ids repetidos são recusados (dariam colisão de chave no meio do grupo)', async () => {
    const { service } = montar();
    const mesmo = '11111111-1111-4111-8111-111111111111';
    await expect(
      service.create(user, {
        ...base,
        parcelas: 2,
        installmentIds: [mesmo, mesmo],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('fornecedor é gravado em TODAS as parcelas, só com dígitos', async () => {
    const { service, criadas } = montar();
    await service.create(user, {
      ...base,
      parcelas: 2,
      supplierName: '  Distribuidora XYZ  ',
      supplierDoc: '12.345.678/0001-95',
    });
    expect(criadas.every((c) => c.supplier_doc === '12345678000195')).toBe(true);
    expect(criadas[0].supplier_name).toBe('Distribuidora XYZ');
  });

  it('documento de fornecedor com tamanho inválido é recusado', async () => {
    // O CHECK exige 11 (CPF) ou 14 (CNPJ) dígitos; recusar aqui devolve mensagem
    // que o usuário entende em vez do erro cru do Postgres.
    const { service } = montar();
    await expect(
      service.create(user, { ...base, supplierDoc: '123' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
