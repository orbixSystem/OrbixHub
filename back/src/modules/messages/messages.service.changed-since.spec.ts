import { BadRequestException } from '@nestjs/common';
import { MessagesService } from './messages.service';

/**
 * Unit do recorte "sync pull" do MessagesService — deps mockadas (sem banco).
 * Cobre: whitelist de entidades (`conversation`/`message`), clamp do limite
 * (anti-DoS, [1, 500]) e delegação ao repo dentro do withTenantTx. É só LEITURA
 * (o histórico é sincronizado ao SQLite; enviar mensagem continua online).
 */

// TenantContext fake: roda o callback direto (sem tx real).
const tenant = {
  withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
} as unknown as ConstructorParameters<typeof MessagesService>[0];

function makeService() {
  const repo = {
    listChangedSince: jest
      .fn()
      .mockResolvedValue({ rows: [], nextCursor: null, hasMore: false }),
  };
  const svc = new MessagesService(
    tenant,
    repo as never,
    {} as never, // notifications
    {} as never, // events
  );
  return { svc, repo };
}

describe('MessagesService — listChangedSince (sync pull)', () => {
  it.each(['conversation', 'message'])(
    'delega %s ao repo com o limite clampado',
    async (entity) => {
      const { svc, repo } = makeService();
      const cursor = { ts: '2026-01-01T00:00:00.000000Z', id: 'm1' };
      const page = await svc.listChangedSince(entity, cursor, 999);
      expect(page).toEqual({ rows: [], nextCursor: null, hasMore: false });
      // 999 → clampado para 500 (teto anti-DoS).
      expect(repo.listChangedSince).toHaveBeenCalledWith(entity, cursor, 500);
    },
  );

  it('rejeita entidade fora do módulo messages', async () => {
    const { svc, repo } = makeService();
    await expect(svc.listChangedSince('service_order', null, 100)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(repo.listChangedSince).not.toHaveBeenCalled();
  });
});
