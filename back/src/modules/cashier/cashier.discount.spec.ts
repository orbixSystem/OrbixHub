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

  // Os testes de TETO saíram: o dono decidiu que a régua por valor/percentual
  // não fazia sentido no uso real, e o service passa SEM_TETO sempre. A função
  // continua suportando teto (o parâmetro existe) para o dia em que voltar,
  // mas testar um caminho que o produto não exercita seria documentação falsa
  // — alguém leria os testes e concluiria que há teto em produção.

  describe('arredondamento', () => {
    it('devolve o desconto já em centavos', () => {
      const r = validarDesconto({ ...base, desconto: 10.005, saldo: 100 });
      expect(r).toEqual({ ok: true, desconto: 10.01 });
    });
  });
});
