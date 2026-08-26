import { SEM_TETO, TetoDesconto, validarDesconto } from './cashier.discount';

/**
 * A alçada é o que impede um atendente de zerar a dívida de um amigo. Se estes
 * testes passarem por acidente, ninguém percebe até o prejuízo aparecer no
 * fechamento — daí cada caso aqui afirmar tanto o veredito quanto o motivo.
 */

const base = {
  desconto: 0,
  saldo: 100,
  amount: 100,
  podeConceder: true,
  teto: SEM_TETO as TetoDesconto,
};

describe('validarDesconto', () => {
  describe('sem desconto', () => {
    it('desconto zero passa mesmo sem permissão — não é conceder nada', () => {
      const r = validarDesconto({ ...base, desconto: 0, podeConceder: false });
      expect(r).toEqual({ ok: true, desconto: 0 });
    });
  });

  describe('permissão', () => {
    it('sem cashier.discount, qualquer desconto é recusado', () => {
      const r = validarDesconto({ ...base, desconto: 1, podeConceder: false });
      expect(r.ok).toBe(false);
      expect(r.ok === false && r.motivo).toMatch(/cargo não permite/i);
    });

    it('a recusa por permissão não revela o teto do tenant', () => {
      const r = validarDesconto({
        ...base,
        desconto: 999,
        podeConceder: false,
        teto: { maxPercentual: 10, maxValor: 50 },
      });
      // Quem não pode conceder não deve descobrir, pela mensagem, qual é o
      // limite de quem pode.
      expect(r.ok === false && r.motivo).not.toMatch(/10|50|alçada/i);
    });
  });

  describe('limites do próprio valor', () => {
    it('desconto negativo é recusado', () => {
      const r = validarDesconto({ ...base, desconto: -1 });
      expect(r.ok).toBe(false);
      expect(r.ok === false && r.motivo).toMatch(/negativo/i);
    });

    it('desconto maior que o saldo é recusado', () => {
      const r = validarDesconto({ ...base, desconto: 150, saldo: 100 });
      expect(r.ok).toBe(false);
      expect(r.ok === false && r.motivo).toMatch(/maior que o saldo/i);
    });

    it('desconto igual ao saldo passa — perdoar tudo é caso real', () => {
      const r = validarDesconto({ ...base, desconto: 100, saldo: 100, amount: 0 });
      expect(r).toEqual({ ok: true, desconto: 100 });
    });
  });

  describe('teto por valor', () => {
    const teto: TetoDesconto = { maxPercentual: null, maxValor: 50 };

    it('no teto exato passa', () => {
      expect(validarDesconto({ ...base, desconto: 50, teto }).ok).toBe(true);
    });

    it('um centavo acima recusa e diz o limite', () => {
      const r = validarDesconto({ ...base, desconto: 50.01, teto });
      expect(r.ok).toBe(false);
      expect(r.ok === false && r.motivo).toMatch(/50\.00/);
    });
  });

  describe('teto por percentual', () => {
    const teto: TetoDesconto = { maxPercentual: 10, maxValor: null };

    it('10% de 100 passa', () => {
      expect(validarDesconto({ ...base, desconto: 10, saldo: 100, teto }).ok).toBe(true);
    });

    it('11% de 100 recusa', () => {
      const r = validarDesconto({ ...base, desconto: 11, saldo: 100, teto });
      expect(r.ok).toBe(false);
      expect(r.ok === false && r.motivo).toMatch(/10%/);
    });

    it('arredondamento de centavo não derruba o limite', () => {
      // 10% de 33,33 = 3,333 → o operador digita 3,33, que é 9,99...%.
      // Recusar isso seria recusar o próprio teto por ruído de centavo.
      const r = validarDesconto({ ...base, desconto: 3.33, saldo: 33.33, teto });
      expect(r.ok).toBe(true);
    });

    it('saldo zero não divide por zero', () => {
      const r = validarDesconto({ ...base, desconto: 1, saldo: 0, teto });
      // Cai na regra de "maior que o saldo" antes de calcular percentual.
      expect(r.ok).toBe(false);
      expect(r.ok === false && r.motivo).toMatch(/maior que o saldo/i);
    });
  });

  describe('os dois tetos juntos', () => {
    const teto: TetoDesconto = { maxPercentual: 10, maxValor: 5 };

    it('o mais restritivo vence: 10 é 10% de 100, mas passa de R$ 5', () => {
      const r = validarDesconto({ ...base, desconto: 10, saldo: 100, teto });
      expect(r.ok).toBe(false);
      expect(r.ok === false && r.motivo).toMatch(/5\.00/);
    });
  });

  describe('arredondamento', () => {
    it('devolve o desconto já em centavos', () => {
      const r = validarDesconto({ ...base, desconto: 10.005, saldo: 100 });
      expect(r).toEqual({ ok: true, desconto: 10.01 });
    });
  });
});
