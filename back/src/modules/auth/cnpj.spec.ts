import { isValidCnpj, normalizeCnpj, formatCnpj } from './cnpj';

describe('cnpj', () => {
  describe('isValidCnpj', () => {
    it('accepts valid CNPJs (bare and masked)', () => {
      expect(isValidCnpj('11222333000181')).toBe(true);
      expect(isValidCnpj('11.222.333/0001-81')).toBe(true);
      expect(isValidCnpj('19.131.243/0001-97')).toBe(true); // BrasilAPI exemplo
    });
    it('rejects wrong check digits', () => {
      expect(isValidCnpj('11222333000180')).toBe(false);
      expect(isValidCnpj('19131243000196')).toBe(false);
    });
    it('rejects wrong length', () => {
      expect(isValidCnpj('1122233300018')).toBe(false);
      expect(isValidCnpj('112223330001810')).toBe(false);
      expect(isValidCnpj('')).toBe(false);
    });
    it('rejects all-equal-digit sequences', () => {
      expect(isValidCnpj('00000000000000')).toBe(false);
      expect(isValidCnpj('11111111111111')).toBe(false);
    });
    it('handles null/undefined', () => {
      expect(isValidCnpj(null)).toBe(false);
      expect(isValidCnpj(undefined)).toBe(false);
    });
  });

  describe('normalizeCnpj', () => {
    it('strips mask chars', () => {
      expect(normalizeCnpj('11.222.333/0001-81')).toBe('11222333000181');
    });
  });

  describe('formatCnpj', () => {
    it('formats 14 digits', () => {
      expect(formatCnpj('11222333000181')).toBe('11.222.333/0001-81');
    });
    it('returns input unchanged when not 14 digits', () => {
      expect(formatCnpj('123')).toBe('123');
    });
  });
});
