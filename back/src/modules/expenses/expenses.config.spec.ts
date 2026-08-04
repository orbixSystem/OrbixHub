import {
  dataDaOcorrencia,
  limitesDoMes,
  proximasOcorrencias,
  ultimoDiaDoMes,
} from './expenses.config';

/**
 * Miolo da esteira de recorrência. Fevereiro, ano bissexto e virada de ano são
 * exatamente o tipo de erro que só aparece meses depois em produção — e que
 * custa nada cobrir aqui.
 */
const dia = (iso: string) => new Date(`${iso}T00:00:00.000Z`);
const iso = (d: Date) => d.toISOString().slice(0, 10);

describe('expenses — datas da recorrência', () => {
  describe('ultimoDiaDoMes', () => {
    it('resolve meses de 30, 31 e fevereiro', () => {
      expect(ultimoDiaDoMes(2026, 1)).toBe(31);
      expect(ultimoDiaDoMes(2026, 4)).toBe(30);
      expect(ultimoDiaDoMes(2026, 2)).toBe(28);
    });

    it('reconhece ano bissexto', () => {
      expect(ultimoDiaDoMes(2028, 2)).toBe(29);
      // Século não divisível por 400 NÃO é bissexto.
      expect(ultimoDiaDoMes(2100, 2)).toBe(28);
      expect(ultimoDiaDoMes(2000, 2)).toBe(29);
    });
  });

  describe('dataDaOcorrencia', () => {
    it('mês curto ENCURTA o dia em vez de transbordar', () => {
      // "Todo dia 31" em fevereiro cai em 28/02 — não em 03/03. Transbordar
      // faria a conta de fevereiro sumir do mês em que é devida.
      expect(iso(dataDaOcorrencia(2026, 2, 31))).toBe('2026-02-28');
      expect(iso(dataDaOcorrencia(2028, 2, 31))).toBe('2028-02-29');
      expect(iso(dataDaOcorrencia(2026, 4, 31))).toBe('2026-04-30');
    });

    it('mantém o dia pedido quando ele cabe no mês', () => {
      expect(iso(dataDaOcorrencia(2026, 3, 10))).toBe('2026-03-10');
    });
  });

  describe('proximasOcorrencias — mensal', () => {
    it('gera os meses seguintes ao já materializado', () => {
      const datas = proximasOcorrencias({
        frequency: 'monthly',
        dayOfMonth: 10,
        startsOn: dia('2026-09-10'),
        desde: dia('2026-09-10'),
        quantidade: 3,
      });
      expect(datas.map(iso)).toEqual([
        '2026-10-10',
        '2026-11-10',
        '2026-12-10',
      ]);
    });

    it('vira o ano sem caso especial', () => {
      const datas = proximasOcorrencias({
        frequency: 'monthly',
        dayOfMonth: 5,
        startsOn: dia('2026-11-05'),
        desde: dia('2026-11-05'),
        quantidade: 3,
      });
      expect(datas.map(iso)).toEqual([
        '2026-12-05',
        '2027-01-05',
        '2027-02-05',
      ]);
    });

    it('o dia pedido sobrevive a um mês curto no meio do caminho', () => {
      // Fevereiro encurta para 28, mas MARÇO volta para o dia 31 — o dia pedido
      // é preservado na regra, não sobrescrito pelo mês anterior.
      const datas = proximasOcorrencias({
        frequency: 'monthly',
        dayOfMonth: 31,
        startsOn: dia('2026-01-31'),
        desde: dia('2026-01-31'),
        quantidade: 3,
      });
      expect(datas.map(iso)).toEqual([
        '2026-02-28',
        '2026-03-31',
        '2026-04-30',
      ]);
    });

    it('para em ends_on', () => {
      const datas = proximasOcorrencias({
        frequency: 'monthly',
        dayOfMonth: 1,
        startsOn: dia('2026-09-01'),
        endsOn: dia('2026-11-30'),
        desde: dia('2026-09-01'),
        quantidade: 12,
      });
      expect(datas.map(iso)).toEqual(['2026-10-01', '2026-11-01']);
    });

    it('nunca gera antes do início da regra', () => {
      const datas = proximasOcorrencias({
        frequency: 'monthly',
        dayOfMonth: 15,
        startsOn: dia('2027-01-15'),
        desde: dia('2026-06-15'),
        quantidade: 4,
      });
      expect(datas.every((d) => d >= dia('2027-01-15'))).toBe(true);
    });
  });

  describe('proximasOcorrencias — anual', () => {
    it('anda de ano em ano no mês configurado', () => {
      const datas = proximasOcorrencias({
        frequency: 'yearly',
        dayOfMonth: 20,
        monthOfYear: 3,
        startsOn: dia('2026-03-20'),
        desde: dia('2026-03-20'),
        quantidade: 2,
      });
      expect(datas.map(iso)).toEqual(['2027-03-20', '2028-03-20']);
    });
  });

  describe('limitesDoMes', () => {
    it('devolve intervalo semiaberto [1º do mês, 1º do seguinte)', () => {
      // Semiaberto evita depender de "23:59:59.999" e não perde nada gravado no
      // último instante do mês.
      const { de, ate } = limitesDoMes(2026, 12);
      expect(iso(de)).toBe('2026-12-01');
      expect(iso(ate)).toBe('2027-01-01');
    });
  });
});
