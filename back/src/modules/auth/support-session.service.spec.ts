import { UnauthorizedException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { SupportSessionService } from './support-session.service';
import type { AuthRepository } from './auth.repository';
import type { PrismaService } from '../../common/database/prisma.service';
import type { TenantContext } from '../../common/database/tenant-context';
import type { AccessTokenService } from '../../common/auth/jwt.service';
import type { AuditService } from '../../common/audit/audit.service';
import type { Env } from '../../common/config/env.schema';

const DONO = 'user-dono';
const TENANT_A = '11111111-1111-1111-1111-111111111111';
const TENANT_B = '22222222-2222-2222-2222-222222222222';

interface Ott {
  id: string;
  user_id: string | null;
  purpose: string;
  token_hash: string;
  consumed_at: Date | null;
  expires_at: Date;
}

/**
 * O dono é o MESMO usuário nas duas empresas — é o caso que quebrava: o link
 * abria a sessão na primeira membership que o banco devolvesse, não naquela
 * para a qual o link foi gerado.
 */
function montar(memberships = [TENANT_B, TENANT_A]) {
  const tokens: Ott[] = [];

  const repo = {
    createOneTimeToken: jest.fn(
      async (userId: string, purpose: string, tokenHash: string, ttl: number) => {
        tokens.push({
          id: `ott-${tokens.length + 1}`,
          user_id: userId,
          purpose,
          token_hash: tokenHash,
          consumed_at: null,
          expires_at: new Date(Date.now() + ttl * 60_000),
        });
      },
    ),
    findOneTimeTokenByPurposePrefix: jest.fn(
      async (tokenHash: string, prefix: string) =>
        tokens.find(
          (t) =>
            t.token_hash === tokenHash &&
            t.purpose.startsWith(prefix) &&
            !t.consumed_at &&
            t.expires_at > new Date(),
        ) ?? null,
    ),
    consumeOneTimeToken: jest.fn(async (id: string) => {
      const t = tokens.find((x) => x.id === id);
      if (t) t.consumed_at = new Date();
    }),
    findUserMemberships: jest.fn(async () =>
      memberships.map((tenant_id) => ({
        tenant_id,
        tenant_slug: tenant_id.slice(0, 4),
        role_key: 'owner',
      })),
    ),
  } as unknown as AuthRepository;

  const prisma = {
    tenant: { findUnique: jest.fn(async () => ({ id: TENANT_A, slug: 'cliente-a' })) },
  } as unknown as PrismaService;

  const tenant = {
    runWithTenant: jest.fn(async <T,>(_id: string, fn: () => Promise<T>) => fn()),
    getClient: () => ({
      membership: {
        findFirst: async () => ({
          users: { id: DONO, email_normalized: 'dono@cliente-a.com' },
        }),
      },
    }),
  } as unknown as TenantContext;

  const assinados: Array<{ tid: string; sub: string }> = [];
  const accessTokens = {
    sign: jest.fn((p: { tid: string; sub: string }) => {
      assinados.push(p);
      return `jwt-para-${p.tid}`;
    }),
  } as unknown as AccessTokenService;

  const audit = { log: jest.fn(async () => undefined) } as unknown as AuditService;
  const env = { APP_PUBLIC_URL: 'https://app.orbix.test' } as Env;

  const svc = new SupportSessionService(prisma, tenant, repo, accessTokens, audit, env);
  return { svc, repo, audit, assinados, tokens };
}

function codigoDe(url: string): string {
  return new URL(url.replace('/#/', '/')).searchParams.get('code')!;
}

describe('SupportSessionService', () => {
  it('abre a sessão no tenant do LINK, não na primeira membership do dono', async () => {
    // `findUserMemberships` devolve B primeiro; o link é do A.
    const { svc, assinados } = montar([TENANT_B, TENANT_A]);

    const link = await svc.criarLink(TENANT_A, 'Kaue');
    await svc.consumir(codigoDe(link.url));

    expect(assinados).toHaveLength(1);
    expect(assinados[0].tid).toBe(TENANT_A);
  });

  it('audita a entrada no tenant do link', async () => {
    const { svc, audit } = montar([TENANT_B, TENANT_A]);

    const link = await svc.criarLink(TENANT_A, 'Kaue');
    await svc.consumir(codigoDe(link.url));

    expect(audit.log).toHaveBeenLastCalledWith(
      TENANT_A,
      DONO,
      'support_session',
      DONO,
      { acao: 'sessao_iniciada' },
    );
  });

  it('recusa quando o dono perdeu a membership do tenant do link', async () => {
    // Gera o link para A, mas o usuário só é membro de B na hora do consumo.
    const { svc } = montar([TENANT_B]);

    const link = await svc.criarLink(TENANT_A, 'Kaue');
    await expect(svc.consumir(codigoDe(link.url))).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('o código vale UMA vez', async () => {
    const { svc } = montar();

    const link = await svc.criarLink(TENANT_A, 'Kaue');
    const codigo = codigoDe(link.url);

    await svc.consumir(codigo);
    await expect(svc.consumir(codigo)).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('guarda só o HASH do código — quem lê o banco não entra', async () => {
    const { svc, tokens } = montar();

    const link = await svc.criarLink(TENANT_A, 'Kaue');
    const codigo = codigoDe(link.url);

    expect(tokens[0].token_hash).toBe(
      createHash('sha256').update(codigo).digest('hex'),
    );
    expect(tokens[0].token_hash).not.toContain(codigo);
    expect(tokens[0].purpose).toBe(`support_session:${TENANT_A}`);
  });

  it('o código viaja no FRAGMENTO da URL — não vai para access.log nem Referer', async () => {
    const { svc } = montar();

    const link = await svc.criarLink(TENANT_A, 'Kaue');
    const caminho = new URL(link.url);

    expect(caminho.search).toBe('');
    expect(caminho.hash).toContain('code=');
  });
});
