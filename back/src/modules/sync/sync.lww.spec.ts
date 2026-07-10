import { effectiveTsMs, lwwDiscards } from './sync.lww';

describe('sync LWW (S2) — clamp + decisão de descarte', () => {
  const NOW = Date.parse('2026-07-09T12:00:00.000Z');

  describe('effectiveTsMs — clamp do relógio', () => {
    it('timestamp futuro é clampado para o now do servidor', () => {
      const future = NOW + 3_600_000;
      expect(effectiveTsMs(future, NOW)).toBe(NOW);
    });

    it('timestamp passado permanece no passado', () => {
      const past = NOW - 3_600_000;
      expect(effectiveTsMs(past, NOW)).toBe(past);
    });

    it('timestamp inválido (NaN) perde (−Infinity)', () => {
      expect(effectiveTsMs(NaN, NOW)).toBe(Number.NEGATIVE_INFINITY);
    });
  });

  describe('lwwDiscards — servidor mais novo vence', () => {
    it('sem linha alvo (current=null) nunca descarta', () => {
      expect(lwwDiscards(null, NOW - 1000, NOW)).toBe(false);
    });

    it('linha do servidor MAIS NOVA que o timestamp do cliente → descarta', () => {
      const serverNewer = new Date(NOW); // atualizado agora
      const clientOld = NOW - 3_600_000; // cliente 1h atrás
      expect(lwwDiscards(serverNewer, clientOld, NOW)).toBe(true);
    });

    it('linha do servidor MAIS ANTIGA que o timestamp do cliente → aplica', () => {
      const serverOld = new Date(NOW - 3_600_000);
      const clientNew = NOW - 1000;
      expect(lwwDiscards(serverOld, clientNew, NOW)).toBe(false);
    });

    it('timestamp futuro forjado: clamp faz empatar com o now e NÃO descarta a escrita atual', () => {
      // servidor atualizado logo ANTES do push; cliente forja timestamp futuro.
      const server = new Date(NOW - 1);
      const clientFuture = NOW + 10_000_000;
      // effectiveTs = now (clamp); server(now-1) > now? não → aplica (sobrescreve).
      expect(lwwDiscards(server, clientFuture, NOW)).toBe(false);
    });
  });
});
