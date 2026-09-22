import {
  DocumentoDeCliente,
  porReceita,
  porRecorrencia,
  ranquearClientes,
  RecebidoPorDocumento,
} from './customers-ranking';

/**
 * O cruzamento cliente × recebido é o coração do ranking, e erra em silêncio:
 * um cliente somado ao balde errado não estoura nada, só aparece na lista com
 * o número de outro. Daí cada caso aqui afirmar o número, não só a ordem.
 */

const d = (
  id: string,
  customerId: string | null,
  nome: string | null,
  dia: string,
): DocumentoDeCliente => ({
  id,
  customer_id: customerId,
  customer_name: nome,
  created_at: new Date(`2026-08-${dia}T10:00:00Z`),
});

const pago = (
  pares: Array<[string, number, number?]>,
): Map<string, RecebidoPorDocumento> =>
  new Map(
    pares.map(([id, recebido, desconto]) => [
      id,
      { recebido, desconto: desconto ?? 0 },
    ]),
  );

describe('ranquearClientes', () => {
  it('soma OS e venda do MESMO cliente numa linha só', () => {
    const r = ranquearClientes(
      [d('os1', 'c1', 'Maria', '01')],
      [d('v1', 'c1', 'Maria', '05')],
      pago([
        ['os1', 300],
        ['v1', 200],
      ]),
    );
    expect(r).toHaveLength(1);
    expect(r[0].recebido).toBe(500);
    expect(r[0].atendimentos).toBe(2);
    expect(r[0].osCount).toBe(1);
    expect(r[0].saleCount).toBe(1);
  });

  it('venda sem cliente cadastrado fica FORA', () => {
    // Somada, ela viraria o "cliente" campeão de qualquer oficina — liderando
    // a lista com um nome que não existe.
    const r = ranquearClientes(
      [],
      [d('v1', null, null, '01'), d('v2', 'c1', 'Ana', '02')],
      pago([
        ['v1', 9999],
        ['v2', 10],
      ]),
    );
    expect(r).toHaveLength(1);
    expect(r[0].customerName).toBe('Ana');
  });

  it('documento sem recebimento conta como ATENDIMENTO, com receita zero', () => {
    // OS aberta e não paga é relacionamento acontecendo; zerar o atendimento
    // esconderia o cliente que aparece toda semana e ainda não pagou.
    const r = ranquearClientes([d('os1', 'c1', 'Ana', '01')], [], pago([]));
    expect(r[0].atendimentos).toBe(1);
    expect(r[0].recebido).toBe(0);
    expect(r[0].ticketMedio).toBe(0);
  });

  it('desconto vem separado do recebido — não é dinheiro que entrou', () => {
    const r = ranquearClientes(
      [d('os1', 'c1', 'Ana', '01')],
      [],
      pago([['os1', 90, 10]]),
    );
    expect(r[0].recebido).toBe(90);
    expect(r[0].desconto).toBe(10);
  });

  it('ticket médio é recebido ÷ atendimentos', () => {
    const r = ranquearClientes(
      [d('os1', 'c1', 'Ana', '01'), d('os2', 'c1', 'Ana', '02')],
      [],
      pago([
        ['os1', 100],
        ['os2', 50],
      ]),
    );
    expect(r[0].ticketMedio).toBe(75);
  });

  it('guarda a primeira e a última visita', () => {
    const r = ranquearClientes(
      [d('os1', 'c1', 'Ana', '10'), d('os2', 'c1', 'Ana', '02')],
      [d('v1', 'c1', 'Ana', '20')],
      pago([]),
    );
    expect(r[0].primeiroEm).toContain('2026-08-02');
    expect(r[0].ultimoEm).toContain('2026-08-20');
  });

  it('usa o nome mais RECENTE quando o cliente mudou de razão social', () => {
    const r = ranquearClientes(
      [d('os1', 'c1', 'Oficina Velha ME', '01')],
      [d('v1', 'c1', 'Oficina Nova LTDA', '20')],
      pago([]),
    );
    expect(r[0].customerName).toBe('Oficina Nova LTDA');
  });

  it('arredonda a centavos — soma de decimais não pode vazar dízima', () => {
    const r = ranquearClientes(
      [d('os1', 'c1', 'Ana', '01'), d('os2', 'c1', 'Ana', '02')],
      [],
      pago([
        ['os1', 0.1],
        ['os2', 0.2],
      ]),
    );
    expect(r[0].recebido).toBe(0.3);
  });
});

describe('ordenações', () => {
  const base = {
    customerId: 'x',
    customerName: 'x',
    desconto: 0,
    osCount: 0,
    saleCount: 0,
    ticketMedio: 0,
    primeiroEm: '',
    ultimoEm: '',
  };
  const rico = { ...base, customerId: 'rico', recebido: 1000, atendimentos: 1 };
  const assiduo = {
    ...base,
    customerId: 'assiduo',
    recebido: 100,
    atendimentos: 20,
  };

  it('as duas listas discordam de propósito', () => {
    // É por isso que existem duas: quem traz mais dinheiro nem sempre é quem
    // volta mais, e a oficina trata os dois de jeitos diferentes.
    expect([rico, assiduo].sort(porReceita)[0].customerId).toBe('rico');
    expect([rico, assiduo].sort(porRecorrencia)[0].customerId).toBe('assiduo');
  });

  it('empate no dinheiro desempata pela recorrência', () => {
    const a = { ...base, customerId: 'a', recebido: 500, atendimentos: 2 };
    const b = { ...base, customerId: 'b', recebido: 500, atendimentos: 9 };
    expect([a, b].sort(porReceita)[0].customerId).toBe('b');
  });
});
