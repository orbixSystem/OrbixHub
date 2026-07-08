import {
  isIdUniqueViolation,
  isUniqueViolation,
} from './prisma-errors';

// Shapes reais observadas no Postgres local (ver comentário do módulo).
const p2002 = (target: unknown) => ({ code: 'P2002', meta: { target } });

describe('prisma-errors', () => {
  describe('isUniqueViolation', () => {
    it('true para P2002; false para outros códigos / não-erros', () => {
      expect(isUniqueViolation(p2002(['id']))).toBe(true);
      expect(isUniqueViolation({ code: 'P2025' })).toBe(false);
      expect(isUniqueViolation(new Error('x'))).toBe(false);
      expect(isUniqueViolation(null)).toBe(false);
      expect(isUniqueViolation(undefined)).toBe(false);
    });
  });

  describe('isIdUniqueViolation', () => {
    it("true SOMENTE quando o target é exatamente ['id'] (PK)", () => {
      expect(isIdUniqueViolation(p2002(['id']))).toBe(true);
    });

    it('false para natural keys (documento, sku, sessão por dispositivo, nº da OS)', () => {
      expect(isIdUniqueViolation(p2002(['tenant_id', 'document']))).toBe(false);
      expect(isIdUniqueViolation(p2002(['tenant_id', 'sku']))).toBe(false);
      expect(isIdUniqueViolation(p2002(['tenant_id', 'number']))).toBe(false);
      expect(
        isIdUniqueViolation(
          p2002([
            'tenant_id',
            'COALESCE(device_id',
            "'00000000-0000-0000-0000-000000000000'::uuid)",
          ]),
        ),
      ).toBe(false);
    });

    it('false para P2002 sem meta/target ou target não-array', () => {
      expect(isIdUniqueViolation({ code: 'P2002' })).toBe(false);
      expect(isIdUniqueViolation(p2002('id'))).toBe(false);
      expect(isIdUniqueViolation(p2002(undefined))).toBe(false);
    });

    it('false quando o Postgres suprime o detalhe sob RLS (target null)', () => {
      // Shape real do caminho da aplicação (app_user): o caller precisa
      // complementar com a checagem de existência por id (ver prisma-errors.ts).
      expect(isIdUniqueViolation(p2002(null))).toBe(false);
    });

    it('false para erros que nem são P2002', () => {
      expect(isIdUniqueViolation({ code: 'P2025', meta: { target: ['id'] } })).toBe(
        false,
      );
      expect(isIdUniqueViolation(null)).toBe(false);
    });
  });
});
